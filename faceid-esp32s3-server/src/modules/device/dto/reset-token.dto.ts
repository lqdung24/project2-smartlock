import { IsNotEmpty, IsString } from 'class-validator';

export class ResetTokenDto {
  @IsString()
  @IsNotEmpty()
  hardwareId: string;

  @IsString()
  @IsNotEmpty()
  oldToken: string;
}
