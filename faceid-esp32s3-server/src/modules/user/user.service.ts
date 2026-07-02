import { Injectable, UnauthorizedException, BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { Role } from '@prisma/client';
import { ChangePasswordDto } from './dto/change-password.dto';
import * as bcrypt from 'bcrypt';

@Injectable()
export class UserService {
  constructor(private prisma: PrismaService) {}

  async changePassword(userId: number, changePasswordDto: ChangePasswordDto) {
    const { oldPassword, newPassword } = changePasswordDto;

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    const isPasswordValid = await bcrypt.compare(oldPassword, user.password);
    if (!isPasswordValid) {
      throw new BadRequestException('Invalid old password');
    }

    const hashedNewPassword = await bcrypt.hash(newPassword, 10);

    await this.prisma.user.update({
      where: { id: userId },
      data: { password: hashedNewPassword },
    });

    return { message: 'Password changed successfully' };
  }

  async removeMember(ownerId: number, memberId: number) {
    const owner = await this.prisma.user.findUnique({ where: { id: ownerId } });
    if (!owner || owner.role !== Role.OWNER || !owner.houseId) {
      throw new ForbiddenException('You are not an owner of a house.');
    }

    const member = await this.prisma.user.findUnique({ where: { id: memberId } });
    if (!member || member.houseId !== owner.houseId) {
      throw new NotFoundException('Member not found in your house.');
    }

    await this.prisma.user.update({
      where: { id: memberId },
      data: { houseId: null, role: Role.OWNER }, // Reset role to OWNER as they are no longer part of a house
    });

    return { message: 'Member removed successfully.' };
  }

  async getHouseMembers(houseId: number) {
    return this.prisma.user.findMany({
      where: {
        houseId: houseId,
      },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
      },
    });
  }
}