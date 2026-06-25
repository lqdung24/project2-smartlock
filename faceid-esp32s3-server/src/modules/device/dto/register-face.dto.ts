import { IsNotEmpty, IsString, IsUrl, IsOptional } from 'class-validator';

export class RegisterFaceDto {
  @IsString()
  @IsNotEmpty()
  hardwareId: string;

  @IsUrl()
  @IsNotEmpty()
  imageUrl: string;

  @IsString()
  @IsOptional()
  label?: string;
}
