import { IsNotEmpty, IsString } from 'class-validator';

export class UpdateFaceDto {
  @IsString()
  @IsNotEmpty()
  label: string;
}