import { Controller, Get, Post, Body, Req, UseGuards } from '@nestjs/common';
import { UserService } from './user.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ChangePasswordDto } from './dto/change-password.dto';
import { OwnerGuard } from '../auth/guards/owner.guard';
import { RemoveMemberDto } from './dto/remove-member.dto';

@Controller('user')
export class UserController {
  constructor(private readonly userService: UserService) {}

  @UseGuards(JwtAuthGuard)
  @Post('change-password')
  async changePassword(
    @Req() req: any,
    @Body() changePasswordDto: ChangePasswordDto,
  ) {
    const userId = req.user.id;
    return this.userService.changePassword(userId, changePasswordDto);
  }

  @UseGuards(JwtAuthGuard, OwnerGuard)
  @Post('remove-member')
  async removeMember(
    @Req() req: any,
    @Body() removeMemberDto: RemoveMemberDto,
  ) {
    const ownerId = req.user.id;
    return this.userService.removeMember(ownerId, removeMemberDto.memberId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('all')
  async getHouseMembers(@Req() req: any) {
    const houseId = req.user.houseId;
    return this.userService.getHouseMembers(houseId);
  }
}