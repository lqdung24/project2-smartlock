import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as mqtt from 'mqtt';
import { MqttClient } from 'mqtt';

@Injectable()
export class MqttService implements OnModuleInit, OnModuleDestroy {
  private client: MqttClient;
  private readonly logger = new Logger(MqttService.name);

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
      this.logger.log('MQTT client connected successfully');
      this.client.subscribe('server/+/control', (err) => {
        if (!err) {
          this.logger.log('Subscribed to server/+/control');
        }
      });
    });

    this.client.on('message', (topic, message) => {
      this.logger.log(`Received message from topic: ${topic}`);
      this.logger.log(`Message: ${message.toString()}`);
    });

    this.client.on('error', (error) => {
      this.logger.error('MQTT client error:', error);
    });
  }

  onModuleDestroy() {
    if (this.client) {
      this.client.end();
    }
  }

  publish(topic: string, message: string, options?: mqtt.IClientPublishOptions) {
    if (this.client) {
      // Default to QoS 1 to ensure messages are stored for offline clients
      const publishOptions: mqtt.IClientPublishOptions = {
        qos: 1,
        ...options,
      };
      this.client.publish(topic, message, publishOptions, (error) => {
        if (error) {
          this.logger.error(`Failed to publish to ${topic}`, error);
        } else {
          this.logger.log(`Published to ${topic} with QoS ${publishOptions.qos}`);
        }
      });
    }
  }
}