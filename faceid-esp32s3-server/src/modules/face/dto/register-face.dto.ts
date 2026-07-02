import { IsNotEmpty, IsString, IsOptional } from 'class-validator';

export class RegisterFaceDto {
  @IsString()
  @IsNotEmpty()
  imageUrl: string;

  @IsString()
  @IsOptional()
  label?: string;
}