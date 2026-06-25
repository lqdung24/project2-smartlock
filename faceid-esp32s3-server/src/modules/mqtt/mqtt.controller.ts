import { Controller, Logger } from '@nestjs/common';
import { Ctx, MessagePattern, MqttContext } from '@nestjs/microservices';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { RedisService } from '../redis/redis.service';
import { PrismaService } from '../../prisma/prisma.service';
import { MqttService } from './mqtt.service';
import { Prisma, Source } from '@prisma/client';

@Controller()
export class MqttController {
  private readonly logger = new Logger(MqttController.name);

  constructor(
    private eventEmitter: EventEmitter2,
    private redisService: RedisService,
    private prisma: PrismaService,
    private mqttService: MqttService,
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

      default:
        // Handle face enrollment event (eventType is face_id)
        this.logger.log(
          `Handling as face enrollment/recognition event for face_id: ${eventType}`,
        );
        await this.handleEnrollEvent(data);
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

    const userId = data.readInt32LE(4);
    const timestamp = data.readUInt32LE(8);

    try {
      await this.prisma.deviceLog.create({
        data: {
          deviceId: device.id,
          userId: userId === -1 ? null : userId,
          time: new Date(timestamp * 1000),
          source: Source.FACEID,
        },
      });
      this.logger.log(
        `Successfully logged unlock event for device ${hardwareId}. UserID: ${userId}`,
      );
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

    const logsToCreate: Prisma.DeviceLogCreateManyInput[] = [];
    for (let i = 0; i < logCount; i++) {
      const offset = 12 + i * 8;
      const userId = data.readInt32LE(offset);
      const logTimestamp = data.readUInt32LE(offset + 4);
      const actualTimestamp = logTimestamp + timeOffset;

      logsToCreate.push({
        deviceId: device.id,
        userId: userId === -1 ? null : userId,
        time: new Date(actualTimestamp * 1000),
        source: Source.FACEID,
      });
    }

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

  private async handleEnrollEvent(data: Buffer) {
    if (data.length < 36) {
      this.logger.error(
        `[Enroll] Payload too small to contain face_id and redis_key. Length: ${data.length}`,
      );
      return;
    }

    try {
      const face_id = data.readInt32LE(0);
      const redisKeyBuffer = data.slice(4, 36);
      const nullIndex = redisKeyBuffer.indexOf(0);
      const redis_key = redisKeyBuffer
        .slice(0, nullIndex !== -1 ? nullIndex : 32)
        .toString('utf8');

      this.logger.log(`[Enroll] Parsed Face ID: ${face_id}`);
      this.logger.log(`[Enroll] Parsed Redis Key: "${redis_key}"`);

      const cachedData = await this.redisService.get(redis_key);

      if (!cachedData) {
        this.logger.warn(
          `[Enroll] Redis key "${redis_key}" not found or expired.`,
        );
        return;
      }

      if (face_id === -1) {
        this.eventEmitter.emit(redis_key, {
          message: 'ok',
          face_id: -1,
          detail: 'No face detected or registration failed on device.',
        });
        await this.redisService.del(redis_key);
        return;
      }

      if (data.length < 2084) {
        this.logger.error(
          `[Enroll] Face ID is valid, but payload is missing embedding vectors.`,
        );
        this.eventEmitter.emit(redis_key, {
          error: 'Incomplete data received from device.',
        });
        await this.redisService.del(redis_key);
        return;
      }

      const embedVector = Buffer.from(data.subarray(36, 2084));

      await this.prisma.faceData.create({
        data: {
          label: cachedData.label || 'Unknown',
          img_url: cachedData.imageUrl,
          userId: cachedData.userId,
          face_id: face_id,
          embedVector: embedVector,
        },
      });

      this.eventEmitter.emit(redis_key, { message: 'ok', face_id });
      await this.redisService.del(redis_key);
      this.logger.log(
        `[Enroll] Successfully registered face ${face_id} for key ${redis_key}`,
      );
    } catch (error) {
      this.logger.error(
        '[Enroll] Failed to parse or process enroll event.',
        error.stack,
      );
      const redisKeyBuffer = data.slice(4, 36);
      const nullIndex = redisKeyBuffer.indexOf(0);
      const redis_key = redisKeyBuffer
        .slice(0, nullIndex !== -1 ? nullIndex : 32)
        .toString('utf8');
      if (redis_key) {
        this.eventEmitter.emit(redis_key, {
          error: 'Internal server error while processing face data.',
        });
        await this.redisService.del(redis_key);
      }
    }
  }
}
