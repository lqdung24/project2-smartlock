import { IsInt, IsNotEmpty } from 'class-validator';

export class RespondRequestDto {
  @IsInt()
  @IsNotEmpty()
  requesterId: number;
}
