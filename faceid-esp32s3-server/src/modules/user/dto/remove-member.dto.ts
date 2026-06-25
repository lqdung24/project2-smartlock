import { IsInt, IsNotEmpty } from 'class-validator';

export class RemoveMemberDto {
  @IsInt()
  @IsNotEmpty()
  memberId: number;
}
