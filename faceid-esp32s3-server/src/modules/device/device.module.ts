import { Module } from '@nestjs/common';
import { DeviceService } from './device.service';
import { DeviceController } from './device.controller';
import { PrismaModule } from '../../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { ConfigModule } from '@nestjs/config';
import { DeviceOwnerGuard } from './guards/device-owner.guard';
import { EventsModule } from '../events/events.module';

@Module({
  imports: [PrismaModule, AuthModule, ConfigModule, EventsModule],
  providers: [DeviceService, DeviceOwnerGuard],
  controllers: [DeviceController],
  exports: [DeviceService],
})
export class DeviceModule {}