import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(Strategy, 'jwt-refresh') {
  constructor(private configService: ConfigService) {
    const secretKey = configService.get<string>('JWT_SECRET_KEY');
    
    // Đảm bảo secretKey luôn có giá trị để tránh lỗi TypeScript
    if (!secretKey) {
      throw new Error('JWT_SECRET_KEY is not defined in environment variables');
    }

    super({
      jwtFromRequest: ExtractJwt.fromBodyField('refresh_token'),
      ignoreExpiration: false,
      secretOrKey: secretKey,
    });
  }

  async validate(payload: any) {
    return { userId: payload.sub, email: payload.email, houseId: payload.houseId };
  }
}
