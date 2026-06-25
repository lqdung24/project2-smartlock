import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MicroserviceOptions, Transport } from '@nestjs/microservices';

async function bootstrap() {
  // Create a hybrid application that can handle both HTTP and microservice requests
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService);

  // Connect the MQTT microservice transport layer
  app.connectMicroservice<MicroserviceOptions>({
    transport: Transport.MQTT,
    options: {
      host: configService.get<string>('MQTT_HOST'),
      port: configService.get<number>('MQTT_PORT'),
      username: configService.get<string>('MQTT_USERNAME'), // Add MQTT username
      password: configService.get<string>('MQTT_PASSWORD'), // Add MQTT password
    },
  });

  // --- Global settings for the HTTP server ---
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    }),
  );
  app.enableCors();
  
  // --- Start both services ---
  await app.startAllMicroservices();
  const port = configService.get<number>('PORT', 3030);
  await app.listen(port, '0.0.0.0');

  console.log(
    `Application is running on: http://127.0.0.1:${port}`,
  );
  console.log('MQTT microservice is listening for messages.');
}
bootstrap();
