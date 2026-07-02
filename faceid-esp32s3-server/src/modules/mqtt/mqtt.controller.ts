import { Controller, Logger } from '@nestjs/common';
import { Ctx, MessagePattern, MqttContext } from '@nestjs/microservices';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { RedisService } from '../redis/redis.service';
import { PrismaService } from '../../prisma/prisma.service';
import { MqttService } from './mqtt.service';
import { Prisma, Source, Status, Role } from '@prisma/client';
import { EventsGateway } from '../events/events.gateway';
import { CloudinaryService } from '../cloudinary/cloudinary.service';

@Controller()
export class MqttController {
  private readonly logger = new Logger(MqttController.name);

  constructor(
    private eventEmitter: EventEmitter2,
    private redisService: RedisService,
    private prisma: PrismaService,
    private mqttService: MqttService,
    private eventsGateway: EventsGateway,
    private cloudinaryService: CloudinaryService,
  ) {}

  @MessagePattern('esp32/+/status')
  async handleDeviceStatus(@Ctx() context: MqttContext) {
    const topic = context.getTopic();
    const topicParts = topic.split('/');
    if (topicParts.length < 3) {
      this.logger.warn(`Received message on invalid topic: ${topic}`);
      return;
    }
    const hardwareId = topicParts[1];

    const packet = context.getPacket();
    const rawPayload = packet.payload.toString();

    try {
      const payload = JSON.parse(rawPayload);

      if (payload && payload.status === 'ping') {
        this.logger.log(`Received ping from device ${hardwareId}`);
        const redisKey = `lock:${hardwareId}:status`;
        try {
          await this.redisService.set(redisKey, 'online', 360);
          this.logger.log(
            `Status for device ${hardwareId} updated in Redis. Key will expire in 360 seconds.`,
          );
        } catch (error) {
          this.logger.error(
            `Failed to set status for device ${hardwareId} in Redis`,
            error.stack,
          );
        }
      } else if (payload && payload.status === 'pong') {
        this.logger.log(`Received pong from device ${hardwareId}`);
        this.eventEmitter.emit('device.pong', hardwareId);
      } else {
        this.logger.warn(
          `Received unexpected payload on ${topic}: ${rawPayload}`,
        );
      }
    } catch (e) {
      this.logger.warn(
        `Failed to parse JSON payload on ${topic}. Raw payload: ${rawPayload}`,
      );
    }
  }

  @MessagePattern('esp32/+/event')
  async handleEvent(@Ctx() context: MqttContext) {
    const topic = context.getTopic();
    const packet = context.getPacket();
    const data: Buffer = packet.payload;
    const topicParts = topic.split('/');
    if (topicParts.length < 2) {
      this.logger.error(`Invalid event topic: ${topic}`);
      return;
    }
    const hardwareId = topicParts[1];

    this.logger.log(
      `Received message on esp32/+/event topic: ${topic}, payload size: ${data.length} bytes`,
    );

    if (data.length < 4) {
      this.logger.error(
        `Payload too small to determine event type. Length: ${data.length}`,
      );
      return;
    }

    const eventType = data.readInt32LE(0);
    this.logger.log(`Parsed event_type / face_id: ${eventType}`);

    switch (eventType) {
      case 0:
        // Handle simple time synchronization request
        if (data.length === 4) {
          this.logger.log(`Received time sync request from device ${hardwareId}`);
          this.sendSyncTime(hardwareId);
        } else {
          this.logger.warn(
            `Received event_type 0 with unexpected payload size: ${data.length}`,
          );
        }
        break;

      case -2:
        // Handle real-time unlock event
        this.logger.log(`Received unlock event from device ${hardwareId}`);
        await this.handleUnlockEvent(data, hardwareId);
        break;

      case -3:
        // Handle offline log synchronization
        this.logger.log(
          `Received offline log sync request from device ${hardwareId}`,
        );
        await this.handleOfflineLogs(data, hardwareId);
        break;
      
      case -4:
        // Handle local enrollment event
        this.logger.log(`Received local enrollment event from device ${hardwareId}`);
        await this.handleLocalEnrollment(data, hardwareId);
        break;

      default:
        // Handle face enrollment event (eventType is face_id)
        this.logger.log(
          `Handling as face enrollment/recognition event for face_id: ${eventType}`,
        );
        await this.handleFaceEnrollmentResponse(data);
        break;
    }
  }

  private sendSyncTime(hardwareId: string) {
    const controlTopic = `esp32/${hardwareId}/control`;
    const payload = {
      cmd: 'sync_time',
      timestamp: Math.floor(Date.now() / 1000),
    };
    this.mqttService.publish(controlTopic, JSON.stringify(payload));
    this.logger.log(`Sent time sync response to ${controlTopic}`);
  }

  private async handleUnlockEvent(data: Buffer, hardwareId: string) {
    if (data.length < 12) {
      this.logger.error(
        `Payload for unlock event (event_type -2) is too small. Length: ${data.length}`,
      );
      return;
    }

    const device = await this.prisma.device.findUnique({
      where: { hardwareId },
    });
    if (!device) {
      this.logger.error(
        `Device with hardwareId ${hardwareId} not found during unlock event processing.`,
      );
      return;
    }

    const faceId = data.readInt32LE(4);
    const timestamp = data.readUInt32LE(8);
    let validFaceId: number | null = null;

    if (faceId !== -1) {
      const face = await this.prisma.faceData.findUnique({
        where: { id: faceId },
      });
      if (face) {
        validFaceId = face.id;
      } else {
        this.logger.warn(
          `Received unlock event with non-existent faceId: ${faceId}. Storing as null.`,
        );
      }
    }

    try {
      const newLog = await this.prisma.deviceLog.create({
        data: {
          deviceId: device.id,
          faceid: validFaceId,
          time: new Date(timestamp * 1000),
          source: Source.FACEID,
        },
        include: {
          face: {
            include: {
              user: true,
            },
          },
          device: true,
        },
      });
      this.logger.log(
        `Successfully logged unlock event for device ${hardwareId}. FaceID: ${faceId}`,
      );
      this.eventsGateway.sendToAll('unlock_event', newLog);
    } catch (error) {
      this.logger.error(
        `Failed to save unlock event for device ${hardwareId}`,
        error.stack,
      );
    }
  }

  private async handleOfflineLogs(data: Buffer, hardwareId: string) {
    if (data.length < 12) {
      this.logger.error(
        `Payload for offline logs (event_type -3) is too small. Length: ${data.length}`,
      );
      return;
    }

    const espCurrentTime = data.readUInt32LE(4);
    const logCount = data.readUInt32LE(8);
    this.logger.log(`Device time: ${espCurrentTime}, Log count: ${logCount}`);

    const expectedSize = 12 + logCount * 8;
    if (data.length < expectedSize) {
      this.logger.error(
        `Payload size mismatch for offline logs. Expected ${expectedSize}, got ${data.length}`,
      );
      return;
    }

    const device = await this.prisma.device.findUnique({
      where: { hardwareId },
    });
    if (!device) {
      this.logger.error(
        `Device with hardwareId ${hardwareId} not found during offline log processing.`,
      );
      this.sendSyncTime(hardwareId);
      return;
    }

    const serverCurrentTime = Math.floor(Date.now() / 1000);
    const timeOffset = serverCurrentTime - espCurrentTime;

    const logsData: { faceId: number; timestamp: number }[] = [];
    for (let i = 0; i < logCount; i++) {
      const offset = 12 + i * 8;
      logsData.push({
        faceId: data.readInt32LE(offset),
        timestamp: data.readUInt32LE(offset + 4) + timeOffset,
      });
    }

    const incomingFaceIds = logsData
      .map((log) => log.faceId)
      .filter((id) => id !== -1);

    const existingFaces = await this.prisma.faceData.findMany({
      where: {
        id: { in: incomingFaceIds },
      },
      select: {
        id: true,
      },
    });
    const existingFaceIds = new Set(existingFaces.map((face) => face.id));

    const logsToCreate: Prisma.DeviceLogCreateManyInput[] = logsData.map(
      (log) => ({
        deviceId: device.id,
        faceid:
          log.faceId !== -1 && existingFaceIds.has(log.faceId)
            ? log.faceId
            : null,
        time: new Date(log.timestamp * 1000),
        source: Source.FACEID,
      }),
    );

    if (logsToCreate.length > 0) {
      try {
        await this.prisma.deviceLog.createMany({
          data: logsToCreate,
        });
        this.logger.log(
          `Successfully saved ${logCount} offline logs for device ${hardwareId}`,
        );
      } catch (error) {
        this.logger.error(
          `Failed to save offline logs for device ${hardwareId}`,
          error.stack,
        );
      }
    }

    this.sendSyncTime(hardwareId);
  }

  private async handleFaceEnrollmentResponse(data: Buffer) {
    const faceId = data.readInt32LE(0);
    this.logger.log(`[Enroll Response] Received response for faceId: ${faceId}`);

    if (data.length < 2084) {
      this.logger.error(
        `[Enroll Response] Face ID is valid, but payload is missing embedding vectors. Length: ${data.length}`,
      );
      this.eventEmitter.emit(
        'face.registered',
        faceId,
        undefined,
        'Incomplete data received from device.',
      );
      return;
    }

    // Explicitly create a Buffer from a standard ArrayBuffer to ensure type compatibility
    const rawUint8Array = data.subarray(4, 2084);
    const arrayBuffer =
      rawUint8Array.buffer.slice(
        rawUint8Array.byteOffset,
        rawUint8Array.byteOffset + rawUint8Array.byteLength,
      );
    const embedVector = Buffer.from(arrayBuffer);

    this.eventEmitter.emit('face.registered', faceId, embedVector);
  }

  private async handleLocalEnrollment(data: Buffer, hardwareId: string) {
    // eventType (-4) + deviceFaceId (4) + features (2048) + jpeg_image (variable)
    const MIN_PAYLOAD_SIZE = 4 + 4 + 2048;
    if (data.length <= MIN_PAYLOAD_SIZE) {
      this.logger.error(`Payload for local enrollment is too small. Length: ${data.length}`);
      return;
    }

    const deviceFaceId = data.readInt32LE(4);
    const embedVector = data.subarray(8, 8 + 2048);
    const jpegImage = data.subarray(8 + 2048);

    this.logger.log(`Processing local enrollment for deviceFaceId: ${deviceFaceId} from ${hardwareId}. Image size: ${jpegImage.length} bytes.`);

    try {
      const device = await this.prisma.device.findUnique({
        where: { hardwareId },
      });

      if (!device || !device.houseId) {
        this.logger.error(`Device ${hardwareId} or its associated house not found.`);
        return;
      }

      const houseOwner = await this.prisma.user.findFirst({
        where: {
          houseId: device.houseId,
          role: Role.OWNER,
        },
      });

      if (!houseOwner) {
        this.logger.error(`Owner for houseId ${device.houseId} not found.`);
        return;
      }

      // Upload image to Cloudinary
      const uploadResult = await this.cloudinaryService.uploadImage(jpegImage);
      if (!uploadResult || !uploadResult.secure_url) {
        this.logger.error('Failed to upload image to Cloudinary.');
        return;
      }

      // Create the face data entry
      const newFace = await this.prisma.faceData.create({
        data: {
          userId: houseOwner.id,
          label: `New Face from ${hardwareId}`,
          img_url: uploadResult.secure_url,
          embedVector: Buffer.from(embedVector), // Ensure it's a standard Buffer
        },
      });

      // Update the label with the actual ID for easier identification
      const finalFace = await this.prisma.faceData.update({
        where: { id: newFace.id },
        data: { label: `Face ${newFace.id}` },
        include: { user: true },
      });

      this.logger.log(`Successfully created new face with server ID: ${finalFace.id} for user ${houseOwner.email}`);

      // Send confirmation back to the device
      const controlTopic = `esp32/${hardwareId}/control`;
      const responsePayload = {
        cmd: 'return_regis',
        face_id: finalFace.id,
      };
      this.mqttService.publish(controlTopic, JSON.stringify(responsePayload));
      this.logger.log(`Sent registration confirmation to ${controlTopic} with server face ID ${finalFace.id}`);

      // Notify web clients
      this.eventsGateway.sendToAll('new_face_enrolled', finalFace);

    } catch (error) {
      this.logger.error(`Failed to process local enrollment for device ${hardwareId}:`, error.stack);
    }
  }
}