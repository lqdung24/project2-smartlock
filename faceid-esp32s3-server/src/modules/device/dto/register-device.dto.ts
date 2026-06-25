import { IsBoolean, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class RegisterDeviceDto {
  @IsString()
  @IsNotEmpty()
  name: string;

  @IsString()
  @IsNotEmpty()
  hardwareId: string;

  @IsBoolean()
  @IsOptional()
  resetToken?: boolean;
}