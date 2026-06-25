import { IsIn, IsInt } from 'class-validator';

export class EnableAiDto {
  @IsInt()
  @IsIn([0, 1])
  status: number;
}
