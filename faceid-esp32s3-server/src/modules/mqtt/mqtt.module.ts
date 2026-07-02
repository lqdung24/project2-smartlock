import { Global, Module, forwardRef } from '@nestjs/common'; // Import forwardRef
import { MqttService } from './mqtt.service';
import { ConfigModule } from '@nestjs/config';
import { MqttController } from './mqtt.controller';
import { FaceModule } from '../face/face.module';
import { EventsModule } from '../events/events.module';
import { CloudinaryModule } from '../cloudinary/cloudinary.module';

@Global()
@Module({
  imports: [
    ConfigModule,
    forwardRef(() => FaceModule),
    EventsModule,
    CloudinaryModule,
  ], // Use forwardRef here
  controllers: [MqttController],
  providers: [MqttService],
  exports: [MqttService],
})
export class MqttModule {}