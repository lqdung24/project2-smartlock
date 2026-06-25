import { IsNotEmpty, IsString } from 'class-validator';

export class MqttAuthDto {
  @IsString()
  @IsNotEmpty()
  username: string;

  @IsString()
  @IsNotEmpty()
  password: string;
}