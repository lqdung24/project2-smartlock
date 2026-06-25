import { Injectable, NestMiddleware, Logger } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';

@Injectable()
export class LoggerMiddleware implements NestMiddleware {
  // Khởi tạo Logger gắn với tên của Middleware này
  private logger = new Logger('HTTP');

  use(req: Request, res: Response, next: NextFunction): void {
    const { ip, method, originalUrl } = req;
    const userAgent = req.get('user-agent') || '';
    const startTime = Date.now();

    // Lắng nghe sự kiện khi phản hồi (response) đã được gửi xong cho client
    res.on('finish', () => {
      const { statusCode } = res;
      const duration = Date.now() - startTime;

      // Log ra thông tin có màu sắc phân biệt của NestJS
      this.logger.log(
        `${method} ${originalUrl} ${statusCode} ${duration}ms - ${ip} [${userAgent}]`,
      );
    });

    next();
  }
}
