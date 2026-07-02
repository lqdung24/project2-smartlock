import { Injectable, BadRequestException, NotFoundException, InternalServerErrorException, RequestTimeoutException, Logger, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RedisService } from '../redis/redis.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { ConfirmDeviceDto } from './dto/confirm-device.dto';
import * as crypto from 'crypto';
import { ConfigService } from '@nestjs/config';
import { MqttService } from '../mqtt/mqtt.service';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { Source, Status } from '@prisma/client';
import { EventsGateway } from '../events/events.gateway';
import { ResetTokenDto } from './dto/reset-token.dto';

@Injectable()
export class DeviceService {
  private readonly logger = new Logger(DeviceService.name);

  constructor(
    private prisma: PrismaService,
    private redisService: RedisService,
    private configService: ConfigService,
    private mqttService: MqttService,
    private eventEmitter: EventEmitter2,
    private eventsGateway: EventsGateway,
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
        status: {
          not: Status.DELETED,
        },
        hardwareId: {
          not: '000000000000',
        },
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

  async pingDevices(houseId: number): Promise<any> {
    const devices = await this.prisma.device.findMany({
      where: { houseId, status: Status.ACTIVE },
    });

    if (devices.length === 0) {
      return [];
    }

    const pingPayload = JSON.stringify({ cmd: 'ping' });
    const onlineDevices = new Set<string>();

    const listener = (hardwareId: string) => {
      onlineDevices.add(hardwareId);
    };
    this.eventEmitter.on('device.pong', listener);

    devices.forEach((device) => {
      const topic = `esp32/${device.hardwareId}/control`;
      this.mqttService.publish(topic, pingPayload);
    });

    await new Promise((resolve) => setTimeout(resolve, 1000)); // Wait 1 second

    this.eventEmitter.removeListener('device.pong', listener);

    return devices.map((device) => ({
      ...device,
      status: onlineDevices.has(device.hardwareId) ? 'online' : 'offline',
    }));
  }

  async getDeviceLogs(houseId: number) {
    return this.prisma.deviceLog.findMany({
      where: {
        device: {
          houseId: houseId,
        },
      },
      include: {
        face: {
          select: {
            id: true,
            label: true,
            user: {
              select: {
                id: true,
                name: true,
                email: true,
              },
            },
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

    // If a device exists and is active, and the user is not trying to reset it, throw an error.
    if (existingDevice && existingDevice.status !== Status.DELETED && !resetToken) {
      throw new BadRequestException('An active device with this hardware ID already exists. Use reset token to override.');
    }
    
    // If resetToken is true and device exists, we simply proceed.
    // The old device record will be updated in the confirmDevice step.
    // This avoids the foreign key constraint violation by not deleting.

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

    const deviceData = {
      name: cachedData.name,
      hardwareId: normalizedId,
      houseId: cachedData.houseId,
      mqttToken: mqttToken,
      tokenExpiry: tokenExpiry,
      status: Status.ACTIVE, // Ensure the device is active
    };

    const confirmedDevice = await this.prisma.device.upsert({
      where: { hardwareId: normalizedId },
      update: deviceData,
      create: deviceData,
    });

    await this.redisService.del(redisKey);

    return {
      mqttToken: confirmedDevice.mqttToken,
      mqttHost: this.configService.get<string>('MQTT_HOST_PUBLIC'),
      mqttPort: this.configService.get<number>('MQTT_PORT'),
      message: 'Device confirmed successfully.',
    };
  }

  async resetMqttToken(resetTokenDto: ResetTokenDto) {
    const { hardwareId, oldToken } = resetTokenDto;
    const normalizedId = this.normalizeHardwareId(hardwareId);

    const device = await this.prisma.device.findUnique({
      where: { hardwareId: normalizedId },
    });

    if (!device) {
      throw new NotFoundException(`Device with hardware ID ${normalizedId} not found.`);
    }

    if (device.mqttToken !== oldToken) {
      throw new UnauthorizedException('Invalid old token.');
    }

    const newMqttToken = crypto.randomBytes(64).toString('hex');
    const newExpiry = new Date();
    newExpiry.setFullYear(newExpiry.getFullYear() + 1);

    await this.prisma.device.update({
      where: { hardwareId: normalizedId },
      data: {
        mqttToken: newMqttToken,
        tokenExpiry: newExpiry,
      },
    });

    return {
      mqttToken: newMqttToken,
      mqttHost: this.configService.get<string>('MQTT_HOST_PUBLIC'),
      mqttPort: this.configService.get<number>('MQTT_PORT'),
      message: 'Token reset successfully.',
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
    const newLog = await this.prisma.deviceLog.create({
      data: {
        deviceId: device.id,
        time: new Date(),
        source: Source.APP,
      },
      include: {
        device: true,
      },
    });

    this.eventsGateway.sendToAll('unlock_event', newLog);

    return { message: `Command 'open' sent to device ${hardwareId}` };
  }

  async resetDevice(hardwareId: string) {
    const topic = `esp32/${hardwareId}/control`;
    const payload = JSON.stringify({ cmd: 'reset' });
    this.mqttService.publish(topic, payload);
    return { message: `Command 'reset' sent to device ${hardwareId}` };
  }

  async deleteDevice(hardwareId: string) {
    const topic = `esp32/${hardwareId}/control`;
    const payload = JSON.stringify({ cmd: 'delete' });
    this.mqttService.publish(topic, payload);

    await this.prisma.device.update({
      where: { hardwareId },
      data: { status: Status.DELETED },
    });

    return { message: `Device ${hardwareId} marked as deleted.` };
  }

  async enableAi(hardwareId: string, status: number) {
    const topic = `esp32/${hardwareId}/control`;
    const payload = JSON.stringify({ cmd: 'ai_enable', status });
    this.mqttService.publish(topic, payload);
    return { message: `Command 'ai_enable' with status ${status} sent to device ${hardwareId}` };
  }
}