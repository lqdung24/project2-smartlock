import {
  Controller,
  Get,
  Post,
  Delete,
  Put,
  Body,
  Param,
  Req,
  UseGuards,
  ParseIntPipe,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { FaceService } from './face.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RegisterFaceDto } from './dto/register-face.dto';
import { UpdateFaceDto } from './dto/update-face.dto';

@Controller('face')
@UseGuards(JwtAuthGuard)
export class FaceController {
  private readonly logger = new Logger(FaceController.name);
  constructor(private readonly faceService: FaceService) {}

  @Get('all')
  async getAllFaces(@Req() req: any) {
    const houseId = req.user.houseId;
    this.logger.log(`Attempting to get all faces for houseId: ${houseId}`);
    if (!houseId) {
      throw new ForbiddenException('User is not associated with a house.');
    }
    return this.faceService.getAllFaces(houseId);
  }

  @Post('regis')
  async registerFace(@Body() registerFaceDto: RegisterFaceDto, @Req() req: any) {
    const { id: userId, houseId } = req.user;
    if (!houseId) {
      throw new ForbiddenException('User is not associated with a house.');
    }
    return this.faceService.registerFace(registerFaceDto, userId, houseId);
  }

  @Delete(':id/:hardwareId')
  async deleteFace(
    @Param('id', ParseIntPipe) id: number,
    @Param('hardwareId') hardwareId: string,
  ) {
    return this.faceService.deleteFace(id, hardwareId);
  }

  @Put(':id')
  async updateFace(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateFaceDto: UpdateFaceDto,
  ) {
    return this.faceService.updateFace(id, updateFaceDto);
  }
}