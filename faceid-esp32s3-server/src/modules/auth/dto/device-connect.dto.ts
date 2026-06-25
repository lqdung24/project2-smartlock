import { IsEmail, IsNotEmpty, IsString } from 'class-validator';

export class DeviceConnectDto {
  @IsString()
  username: string;

  @IsNotEmpty()
  @IsString()
  password: string;
}
