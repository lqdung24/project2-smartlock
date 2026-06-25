import { ExtractJwt, Strategy } from 'passport-jwt';
import { PassportStrategy } from '@nestjs/passport';
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(private configService: ConfigService) {
    const jwt_ket = configService.get('JWT_SECRET_KEY');
    super({
      // Lấy token từ Header: Authorization: Bearer <token>
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false, // Bắt buộc phải check hạn sử dụng (hết hạn là chặn luôn)
      secretOrKey: jwt_ket, // Khóa bí mật dùng để ký AT lúc login
    });
  }

  // Hàm này TỰ ĐỘNG CHẠY sau khi NestJS giải mã token thành công
  async validate(payload: any) {
    // Nếu giải mã thành công, object payload (chứa userId, email) sẽ nhảy vào đây
    // Những gì bạn return ở đây sẽ được NestJS ném thẳng vào object `req.user`
    return { userId: payload.sub, email: payload.email };
  }
}
