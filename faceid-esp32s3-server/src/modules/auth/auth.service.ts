import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { MqttAuthDto } from './dto/mqtt-auth.dto';
import * as bcrypt from 'bcrypt';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Role } from '@prisma/client';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private configService: ConfigService,
  ) {}

  async generateAccessToken(payload: any) {
    const secretKey = this.configService.get<string>('JWT_SECRET_KEY');
    return this.jwtService.sign(payload, {
      secret: secretKey,
      expiresIn: '1d',
    });
  }

  async generateRefreshToken(payload: any) {
    const secretKey = this.configService.get<string>('JWT_SECRET_KEY');
    return this.jwtService.sign(payload, {
      secret: secretKey,
      expiresIn: '7d',
    });
  }

  async register(registerDto: RegisterDto) {
    const { email, password, name, houseName } = registerDto;

    const existingUser = await this.prisma.user.findUnique({
      where: { email },
    });
    if (existingUser) {
      throw new BadRequestException('User with this email already exists');
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // By default, a new user is an OWNER. The concept of 'MEMBER' through requests is removed.
    const role = Role.OWNER;

    let user = await this.prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        name: name === 'none' ? '' : name,
        role: role,
        houseId: null,
      },
    });

    // If a house name is provided, create a new house and assign the user as its owner.
    if (houseName && houseName !== 'none') {
      const house = await this.prisma.house.create({
        data: {
          name: houseName,
        },
      });
      user = await this.prisma.user.update({
        where: { id: user.id },
        data: { houseId: house.id },
      });
    }

    const payload = { email: user.email, sub: user.id, houseId: user.houseId, role: user.role };
    return {
      access_token: await this.generateAccessToken(payload),
      refresh_token: await this.generateRefreshToken(payload),
    };
  }

  async login(loginDto: LoginDto) {
    const { email, password } = loginDto;

    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const payload = { email: user.email, sub: user.id, houseId: user.houseId, role: user.role };
    return {
      access_token: await this.generateAccessToken(payload),
      refresh_token: await this.generateRefreshToken(payload),
    };
  }

  async refreshToken(refreshToken: string) {
    try {
      const secretKey = this.configService.get<string>('JWT_SECRET_KEY');
      
      const payload = await this.jwtService.verifyAsync(refreshToken, {
        secret: secretKey,
      });

      const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) {
        throw new UnauthorizedException('User not found');
      }

      const newPayload = { email: user.email, sub: user.id, houseId: user.houseId, role: user.role };
      return {
        access_token: await this.generateAccessToken(newPayload),
        refresh_token: await this.generateRefreshToken(newPayload),
      };
    } catch (e) {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }
  }

  async getMe(userId: number) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        email: true,
        name: true,
        role: true,
      },
    });

    if (!user) {
      throw new UnauthorizedException('User not found');
    }

    return user;
  }

  async validateMqttClient(mqttAuthDto: MqttAuthDto) {
    const { username, password } = mqttAuthDto;

    // Giả định username do EMQX gửi lên là hardwareId, password là mqttToken
    const device = await this.prisma.device.findUnique({
      where: { hardwareId: username },
    });

    // Nếu không tìm thấy thiết bị, hoặc token không khớp, hoặc token đã hết hạn
    if (!device || device.mqttToken !== password || new Date() > device.tokenExpiry) {
      // EMQX yêu cầu trả về HTTP status 200, nhưng body chứa { result: "deny" } để từ chối
      return { result: 'deny' };
    }

    // Nếu tất cả hợp lệ, trả về allow
    return { result: 'allow' };
  }
}