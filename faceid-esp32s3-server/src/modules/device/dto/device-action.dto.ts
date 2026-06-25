import { IsNotEmpty, IsString } from 'class-validator';

export class DeviceActionDto {
  @IsString()
  @IsNotEmpty()
  hardwareId: string;
}