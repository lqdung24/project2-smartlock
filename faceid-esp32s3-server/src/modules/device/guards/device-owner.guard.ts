import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service';

@Injectable()
export class DeviceOwnerGuard implements CanActivate {
  constructor(private prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;
    
    // Check hardwareId from either params (URL) or body
    const hardwareId = request.params.hardwareId || request.body.hardwareId;

    if (!user || !user.houseId) {
      throw new ForbiddenException('User is not associated with a house.');
    }

    if (!hardwareId) {
      // This case should be caught by DTO validation, but it's good to have a safeguard
      throw new ForbiddenException('Hardware ID is missing.');
    }

    const device = await this.prisma.device.findUnique({
      where: { hardwareId },
    });

    if (!device) {
      throw new NotFoundException('Device not found.');
    }

    if (device.houseId !== user.houseId) {
      throw new ForbiddenException('You do not have permission to control this device.');
    }

    // Attach device to request for later use if needed
    request.device = device;

    return true;
  }
}
