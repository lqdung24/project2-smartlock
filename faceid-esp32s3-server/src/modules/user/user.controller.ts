import { Controller, Get, Post, Body, Req, UseGuards } from '@nestjs/common';
import { UserService } from './user.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ChangePasswordDto } from './dto/change-password.dto';
import { OwnerGuard } from '../auth/guards/owner.guard';
import { RespondRequestDto } from './dto/respond-request.dto';
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
  @Post('accept')
  async acceptRequest(
    @Req() req: any,
    @Body() respondRequestDto: RespondRequestDto,
  ) {
    const ownerId = req.user.id;
    return this.userService.acceptRequest(ownerId, respondRequestDto.requesterId);
  }

  @UseGuards(JwtAuthGuard, OwnerGuard)
  @Post('reject')
  async rejectRequest(
    @Req() req: any,
    @Body() respondRequestDto: RespondRequestDto,
  ) {
    const ownerId = req.user.id;
    return this.userService.rejectRequest(ownerId, respondRequestDto.requesterId);
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

  @UseGuards(JwtAuthGuard)
  @Get('request')
  async getHouseRequests(@Req() req: any) {
    const ownerId = req.user.id;
    return this.userService.getHouseRequests(ownerId);
  }
}