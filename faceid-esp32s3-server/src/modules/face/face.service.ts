import {
  Injectable,
  InternalServerErrorException,
  NotFoundException,
  RequestTimeoutException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { MqttService } from '../mqtt/mqtt.service';
import { EventEmitter2, OnEvent } from '@nestjs/event-emitter';
import { RegisterFaceDto } from './dto/register-face.dto';
import { UpdateFaceDto } from './dto/update-face.dto';
import { DeviceService } from '../device/device.service';
import { Status } from '@prisma/client';

@Injectable()
export class FaceService {
  private readonly logger = new Logger(FaceService.name);

  constructor(
    private prisma: PrismaService,
    private mqttService: MqttService,
    private eventEmitter: EventEmitter2,
    private deviceService: DeviceService,
  ) {}

  private cleanCloudinaryUrl(url: string): string {
    if (!url) return url;
    const uploadStr = '/upload/';
    const uploadIndex = url.indexOf(uploadStr);
    if (uploadIndex !== -1) {
      const pathPart = url.substring(uploadIndex + uploadStr.length);
      const versionIndex = pathPart.search(/v\d+\//);
      if (versionIndex !== -1) {
        const publicIdAndBeyond = pathPart.substring(versionIndex);
        const baseUrl = url.substring(0, uploadIndex + uploadStr.length);
        return baseUrl + publicIdAndBeyond;
      }
    }
    return url;
  }

  async getAllFaces(houseId: number) {
    const faces = await this.prisma.faceData.findMany({
      where: { user: { houseId }, status: Status.ACTIVE },
      select: {
        id: true,
        label: true,
        img_url: true,
        userId: true,
        createAt: true,
        user: { select: { id: true, name: true } },
      },
    });
    return faces.map((face) => ({
      ...face,
      img_url: this.cleanCloudinaryUrl(face.img_url),
    }));
  }

  async registerFace(
    registerFaceDto: RegisterFaceDto,
    userId: number,
    houseId: number,
  ): Promise<any> {
    const { imageUrl, label } = registerFaceDto;

    const allDevices = await this.prisma.device.findMany({
      where: { houseId, status: Status.ACTIVE },
    });

    if (allDevices.length === 0) {
      throw new NotFoundException('No active devices found in this house.');
    }

    this.logger.log(`Pinging ${allDevices.length} active devices for house ${houseId}.`);
    const deviceStatus = await this.deviceService.pingDevices(houseId);
    const onlineDevices = deviceStatus.filter(d => d.status === 'online');

    this.logger.log(`Found ${onlineDevices.length} online devices.`);

    const cleanedImageUrl = this.cleanCloudinaryUrl(imageUrl);
    const newFaceEntry = await this.prisma.faceData.create({
      data: {
        label: label || 'Unknown',
        img_url: cleanedImageUrl,
        userId: userId,
      },
    });

    const faceId = newFaceEntry.id;
    const transformation = 'w_240,h_320,c_fill,f_jpg,fl_progressive:none';
    const transformedImageUrl = cleanedImageUrl.replace(
      '/upload/',
      `/upload/${transformation}/`,
    );

    const mqttPayload = JSON.stringify({
      cmd: 'regis',
      img_url: transformedImageUrl,
      face_id: faceId,
      user_id: userId,
      label: label || 'Unknown',
    });

    allDevices.forEach((device) => {
      const topic = `esp32/${device.hardwareId}/control`;
      this.mqttService.publish(topic, mqttPayload);
    });

    if (onlineDevices.length === 0) {
      this.logger.log(
        'No devices online. Responding immediately to client.',
      );
      return {
        message:
          'No devices are online. Face will be registered when a device is available.',
        faceId: faceId,
      };
    }

    this.logger.log(
      'At least one device is online. Waiting for registration confirmation.',
    );
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.eventEmitter.removeAllListeners(`face.registered.${faceId}`);
        this.eventEmitter.removeAllListeners(`face.register_failed.${faceId}`);
        reject(new RequestTimeoutException('Face registration timed out. No response from device.'));
      }, 30000);

      const onSuccess = (payload) => {
        clearTimeout(timeout);
        this.eventEmitter.removeAllListeners(`face.register_failed.${faceId}`);
        resolve({
          message: 'Face registered successfully.',
          faceId: payload.faceId,
        });
      };

      const onError = (payload) => {
        clearTimeout(timeout);
        this.eventEmitter.removeAllListeners(`face.registered.${faceId}`);
        reject(
          new InternalServerErrorException(
            `Face registration failed: ${payload.error}`,
          ),
        );
      };

      this.eventEmitter.once(`face.registered.${faceId}`, onSuccess);
      this.eventEmitter.once(`face.register_failed.${faceId}`, onError);
    });
  }

  @OnEvent('face.registered')
  async finalizeFaceRegistration(
    faceId: number,
    embedVector?: Buffer,
    error?: string,
  ) {
    if (error) {
      this.logger.error(
        `Error during face registration for faceId ${faceId}: ${error}. Deleting entry.`,
      );
      await this.prisma.faceData.delete({ where: { id: faceId } }).catch((e) =>
        this.logger.error(
          `Failed to delete face entry ${faceId} after error: ${e.message}`,
        ),
      );
      this.eventEmitter.emit(`face.register_failed.${faceId}`, {
        faceId,
        error,
      });
      return;
    }

    if (!embedVector) {
      const errorMessage = 'No embedding vector received.';
      this.logger.error(
        `No embedVector provided for faceId ${faceId}. Deleting entry.`,
      );
      await this.prisma.faceData.delete({ where: { id: faceId } }).catch((e) =>
        this.logger.error(
          `Failed to delete face entry ${faceId} due to missing embedVector: ${e.message}`,
        ),
      );
      this.eventEmitter.emit(`face.register_failed.${faceId}`, {
        faceId,
        error: errorMessage,
      });
      return;
    }

    try {
      const compatibleEmbedVector = Buffer.from(embedVector);
      await this.prisma.faceData.update({
        where: { id: faceId },
        data: { embedVector: compatibleEmbedVector },
      });
      this.logger.log(
        `Face ${faceId} successfully registered with embedVector.`,
      );
      this.eventEmitter.emit(`face.registered.${faceId}`, { faceId });
    } catch (e) {
      this.logger.error(
        `Failed to update face ${faceId} with embedVector: ${e.message}`,
      );
      await this.prisma.faceData.delete({ where: { id: faceId } }).catch((e) =>
        this.logger.error(
          `Failed to delete face entry ${faceId} after update error: ${e.message}`,
        ),
      );
      this.eventEmitter.emit(`face.register_failed.${faceId}`, {
        faceId,
        error: 'Failed to save embedding vector to database.',
      });
    }
  }

  async deleteFace(faceId: number, hardwareId: string) {
    const face = await this.prisma.faceData.findUnique({
      where: { id: faceId },
    });

    if (!face) {
      throw new NotFoundException(`Face with ID ${faceId} not found.`);
    }

    const topic = `esp32/${hardwareId}/control`;
    const payload = JSON.stringify({ cmd: 'delete_face', id: faceId });
    this.mqttService.publish(topic, payload);

    await this.prisma.faceData.update({
      where: { id: faceId },
      data: { status: Status.DELETED },
    });

    return { message: `Face with ID ${faceId} marked as deleted.` };
  }

  async updateFace(faceId: number, updateFaceDto: UpdateFaceDto) {
    const { label } = updateFaceDto;
    return this.prisma.faceData.update({
      where: { id: faceId },
      data: { label },
    });
  }
}
