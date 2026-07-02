import { forwardRef, Module } from '@nestjs/common';
import { FaceController } from './face.controller';
import { FaceService } from './face.service';
import { MqttModule } from '../mqtt/mqtt.module';
import { PrismaModule } from '../../prisma/prisma.module';
import { RedisModule } from '../redis/redis.module';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { DeviceModule } from '../device/device.module'; // Import DeviceModule

@Module({
  imports: [
    forwardRef(() => MqttModule),
    PrismaModule,
    RedisModule,
    EventEmitterModule,
    DeviceModule, // Add DeviceModule here
  ],
  controllers: [FaceController],
  providers: [FaceService],
  exports: [FaceService],
})
export class FaceModule {}