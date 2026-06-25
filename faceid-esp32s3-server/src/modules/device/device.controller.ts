import { Controller, Get, Post, Body, Req, UseGuards, ForbiddenException, Param, ParseIntPipe, BadRequestException } from '@nestjs/common';
import { DeviceService } from './device.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { OwnerGuard } from '../auth/guards/owner.guard';
import { ConfirmDeviceDto } from './dto/confirm-device.dto';
import { PublicApiResponse } from '../../common/decorators/public-api-response.decorator';
import { DeviceActionDto } from './dto/device-action.dto';
import { DeviceOwnerGuard } from './guards/device-owner.guard';
import { RegisterFaceDto } from './dto/register-face.dto';

@Controller('device')
export class DeviceController {
  constructor(private deviceService: DeviceService) {}

  @UseGuards(JwtAuthGuard)
  @Get()
  async getAllDevice(@Req() req: any) {
    const houseId = req.user.houseId;
    if (!houseId) {
      throw new ForbiddenException('User is not associated with a house.');
    }
    return this.deviceService.getAllDevicesByHouseId(houseId);
  }

  @UseGuards(JwtAuthGuard)
  @Get('log')
  async getDeviceLogs(@Req() req: any) {
    const houseId = req.user.houseId;
    if (!houseId) {
      throw new ForbiddenException('User is not associated with a house.');
    }
    return this.deviceService.getDeviceLogs(houseId);
  }

  @UseGuards(JwtAuthGuard, OwnerGuard)
  @Post('regis')
  async registerDevice(
    @Body() registerDeviceDto: RegisterDeviceDto,
    @Req() req: any,
  ) {
    const { id, houseId } = req.user;
    if (!houseId) {
      throw new ForbiddenException('User is not associated with a house.');
    }
    return this.deviceService.registerDevice(registerDeviceDto, id, houseId);
  }

  @PublicApiResponse()
  @Post('confirm')
  async confirmDevice(@Body() confirmDeviceDto: ConfirmDeviceDto) {
    return this.deviceService.confirmDevice(confirmDeviceDto);
  }

  @UseGuards(JwtAuthGuard, DeviceOwnerGuard)
  @Post('open')
  async openDevice(@Body() deviceActionDto: DeviceActionDto, @Req() req: any) {
    const { id } = req.user;
    return this.deviceService.openDevice(deviceActionDto.hardwareId, id);
  }

  @UseGuards(JwtAuthGuard)
  @Post('regisface')
  async registerFace(@Body() registerFaceDto: RegisterFaceDto, @Req() req: any) {
    const { id } = req.user;
    return this.deviceService.registerFace(registerFaceDto, id);
  }

  @UseGuards(JwtAuthGuard, DeviceOwnerGuard)
  @Post(':hardwareId/enable-ai/:status')
  async enableAi(
    @Param('hardwareId') hardwareId: string,
    @Param('status', ParseIntPipe) status: number,
  ) {
    if (status !== 0 && status !== 1) {
      throw new BadRequestException('Status must be 0 or 1.');
    }
    return this.deviceService.enableAi(hardwareId, status);
  }
}