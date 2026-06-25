import { IsNotEmpty, IsString } from 'class-validator';

export class ConfirmDeviceDto {
  @IsString()
  @IsNotEmpty()
  hardwareId: string;

  @IsString()
  @IsNotEmpty()
  provisionToken: string;
}