import { Injectable, BadRequestException, NotFoundException, InternalServerErrorException, RequestTimeoutException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { ConfirmDeviceDto } from './dto/confirm-device.dto';
import * as crypto from 'crypto';
import { ConfigService } from '@nestjs/config';
import { MqttService } from '../mqtt/mqtt.service';
import { RegisterFaceDto } from './dto/register-face.dto';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Source } from '@prisma/client';

@Injectable()
export class DeviceService {
  constructor(
    private prisma: PrismaService,
    private redisService: RedisService,
    private configService: ConfigService,
    private mqttService: MqttService,
    private eventEmitter: EventEmitter2,
  ) {}

  private normalizeHardwareId(hardwareId: string): string {
    return hardwareId.replace(/[^a-zA-Z0-9]/g, '').toUpperCase();
  }

  private getProvisionKey(normalizedHardwareId: string): string {
    return `device-provision-${normalizedHardwareId}`;
  }

  async getAllDevicesByHouseId(houseId: number) {
    const devices = await this.prisma.device.findMany({
      where: {
        houseId: houseId,
      },
    });

    const devicesWithStatus = await Promise.all(
      devices.map(async (device) => {
        const statusKey = `lock:${device.hardwareId}:status`;
        const status = await this.redisService.get(statusKey);
        return {
          ...device,
          status: status || 'offline',
        };
      }),
    );

    return devicesWithStatus;
  }

  async getDeviceLogs(houseId: number) {
    return this.prisma.deviceLog.findMany({
      where: {
        device: {
          houseId: houseId,
        },
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        device: {
          select: {
            id: true,
            name: true,
            hardwareId: true,
          },
        },
      },
      orderBy: {
        time: 'desc',
      },
    });
  }

  async registerDevice(
    registerDeviceDto: RegisterDeviceDto,
    userId: number,
    houseId: number,
  ) {
    const { name, hardwareId, resetToken } = registerDeviceDto;
    const normalizedId = this.normalizeHardwareId(hardwareId);

    const existingDevice = await this.prisma.device.findUnique({
      where: { hardwareId: normalizedId },
    });

    if (existingDevice) {
      if (resetToken) {
        // Delete the existing device if resetToken is true
        await this.prisma.device.delete({
          where: { hardwareId: normalizedId },
        });
      } else {
        throw new BadRequestException('Device with this hardware ID already exists');
      }
    }

    const provisionToken = crypto.randomBytes(32).toString('hex');

    const payload = {
      provisionToken,
      name,
      userId,
      houseId,
    };

    const redisKey = this.getProvisionKey(normalizedId);
    await this.redisService.set(redisKey, payload, 300);

    return { provisionToken };
  }

  async confirmDevice(confirmDeviceDto: ConfirmDeviceDto) {
    const { hardwareId, provisionToken } = confirmDeviceDto;
    const normalizedId = this.normalizeHardwareId(hardwareId);
    const redisKey = this.getProvisionKey(normalizedId);

    const cachedData = await this.redisService.get(redisKey);

    if (!cachedData) {
      throw new NotFoundException('Provisioning data not found or expired.');
    }

    if (cachedData.provisionToken !== provisionToken) {
      throw new BadRequestException('Invalid provisioning token.');
    }

    const mqttToken = crypto.randomBytes(64).toString('hex');
    const tokenExpiry = new Date();
    tokenExpiry.setFullYear(tokenExpiry.getFullYear() + 1);

    const newDevice = await this.prisma.device.create({
      data: {
        name: cachedData.name,
        hardwareId: normalizedId,
        houseId: cachedData.houseId,
        mqttToken: mqttToken,
        tokenExpiry: tokenExpiry,
      },
    });

    await this.redisService.del(redisKey);

    return {
      mqttToken: newDevice.mqttToken,
      mqttHost: this.configService.get<string>('MQTT_HOST_PUBLIC'),
      mqttPort: this.configService.get<number>('MQTT_PORT'),
      message: 'Device confirmed successfully.',
    };
  }

  async openDevice(hardwareId: string, userId: number) {
    const device = await this.prisma.device.findUnique({
      where: { hardwareId },
    });

    if (!device) {
      throw new NotFoundException(`Device with hardware ID ${hardwareId} not found.`);
    }

    const topic = `esp32/${hardwareId}/control`;
    const payload = JSON.stringify({ cmd: 'open' });
    this.mqttService.publish(topic, payload);

    // Log the event from the app
    await this.prisma.deviceLog.create({
      data: {
        deviceId: device.id,
        userId: userId,
        time: new Date(),
        source: Source.APP,
      },
    });

    return { message: `Command 'open' sent to device ${hardwareId}` };
  }

  async registerFace(registerFaceDto: RegisterFaceDto, userId: number): Promise<any> {
    const { hardwareId, imageUrl, label } = registerFaceDto;
    const timestamp = Date.now();
    
    const transformation = 'w_240,h_320,c_fill,f_jpg,fl_progressive:none';
    const transformedImageUrl = imageUrl.replace('/upload/', `/upload/${transformation}/`);

    const redisKey = `${userId}_${label || 'null'}_${timestamp}`;
    
    await this.redisService.set(redisKey, { label: label || null, imageUrl: transformedImageUrl, userId, createdAt: new Date() }, 300);

    const topic = `esp32/${hardwareId}/control`;
    const mqttPayload = JSON.stringify({
      cmd: 'regis',
      img_url: transformedImageUrl,
      user_id: userId,
      redis_key: redisKey
    });
    
    this.mqttService.publish(topic, mqttPayload);
    
    return new Promise((resolve, reject) => {
      const waitTimeout = setTimeout(() => {
        this.eventEmitter.removeAllListeners(redisKey);
        reject(new RequestTimeoutException('ESP device did not respond in time.'));
      }, 30000);

      this.eventEmitter.once(redisKey, (data) => {
        clearTimeout(waitTimeout);
        // Nếu có trường 'error', reject để trả về lỗi 500
        if (data.error) {
          reject(new InternalServerErrorException(data.error));
        } else {
          // Nếu không, resolve để trả về 200 OK với payload nhận được
          resolve(data);
        }
      });
    });
  }

  async enableAi(hardwareId: string, status: number) {
    const topic = `esp32/${hardwareId}/control`;
    const payload = JSON.stringify({ cmd: 'ai_enable', status });
    this.mqttService.publish(topic, payload);
    return { message: `Command 'ai_enable' with status ${status} sent to device ${hardwareId}` };
  }
}