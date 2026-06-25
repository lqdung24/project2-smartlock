import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as mqtt from 'mqtt';
import { MqttClient } from 'mqtt';

@Injectable()
export class MqttService implements OnModuleInit, OnModuleDestroy {
  private client: MqttClient;

  constructor(private configService: ConfigService) {}

  onModuleInit() {
    const host = this.configService.get<string>('MQTT_HOST');
    const port = this.configService.get<number>('MQTT_PORT');
    const username = this.configService.get<string>('MQTT_USERNAME');
    const password = this.configService.get<string>('MQTT_PASSWORD');
    const url = `mqtt://${host}:${port}`;

    this.client = mqtt.connect(url, {
      username,
      password,
      clientId: `nestjs_server_${Math.random().toString(16).substr(2, 8)}`,
    });

    this.client.on('connect', () => {
      console.log('MQTT client connected successfully');
      // Ví dụ: subscribe vào một topic chung khi kết nối thành công
      this.client.subscribe('server/+/control', (err) => {
        if (!err) {
          console.log('Subscribed to server/+/control');
        }
      });
    });

    this.client.on('message', (topic, message) => {
      // Xử lý các message nhận được ở đây
      console.log(`Received message from topic: ${topic}`);
      console.log(`Message: ${message.toString()}`);
    });

    this.client.on('error', (error) => {
      console.error('MQTT client error:', error);
    });
  }

  onModuleDestroy() {
    if (this.client) {
      this.client.end();
    }
  }

  publish(topic: string, message: string, options?: mqtt.IClientPublishOptions) {
    if (this.client) {
      this.client.publish(topic, message, options);
    }
  }
}