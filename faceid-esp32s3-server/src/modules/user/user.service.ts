import { Injectable, UnauthorizedException, BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RequestStatus, Role } from '@prisma/client';
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

  async acceptRequest(ownerId: number, requesterId: number) {
    const owner = await this.prisma.user.findUnique({ where: { id: ownerId } });
    if (!owner || owner.role !== Role.OWNER || !owner.houseId) {
      throw new ForbiddenException('You are not an owner of a house.');
    }

    const request = await this.prisma.house_Request.findFirst({
      where: {
        requesterId,
        ownerId,
        status: RequestStatus.PENDING,
      },
    });

    if (!request) {
      throw new NotFoundException('Pending request not found.');
    }

    await this.prisma.user.update({
      where: { id: requesterId },
      data: { houseId: owner.houseId },
    });

    await this.prisma.house_Request.update({
      where: { id: request.id },
      data: { status: RequestStatus.APPROVED },
    });

    return { message: 'User request approved successfully.' };
  }

  async rejectRequest(ownerId: number, requesterId: number) {
    const request = await this.prisma.house_Request.findFirst({
      where: {
        requesterId,
        ownerId,
        status: RequestStatus.PENDING,
      },
    });

    if (!request) {
      throw new NotFoundException('Pending request not found.');
    }

    await this.prisma.house_Request.update({
      where: { id: request.id },
      data: { status: RequestStatus.REJECTED },
    });

    return { message: 'User request rejected successfully.' };
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
      data: { houseId: null },
    });

    const request = await this.prisma.house_Request.findFirst({
      where: {
        requesterId: memberId,
        ownerId: ownerId,
      },
    });

    if (request) {
      await this.prisma.house_Request.update({
        where: { id: request.id },
        data: { status: RequestStatus.DELETED },
      });
    }

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

  async getHouseRequests(ownerId: number) {
    return this.prisma.house_Request.findMany({
      where: {
        ownerId: ownerId,
        status: RequestStatus.PENDING,
      },
      include: {
        requestUser: {
          select: {
            id: true,
            email: true,
            name: true,
          },
        },
      },
    });
  }
}