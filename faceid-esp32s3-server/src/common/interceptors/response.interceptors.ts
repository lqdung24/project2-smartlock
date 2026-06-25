import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { IS_PUBLIC_API_RESPONSE_KEY } from '../decorators/public-api-response.decorator';

@Injectable()
export class ResponseInterceptor implements NestInterceptor {
  constructor(private reflector: Reflector) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const isPublicApiResponse = this.reflector.getAllAndOverride<boolean>(
      IS_PUBLIC_API_RESPONSE_KEY,
      [context.getHandler(), context.getClass()],
    );

    // Nếu có decorator @PublicApiResponse() thì trả về response "trần"
    if (isPublicApiResponse) {
      return next.handle();
    }

    const ctx = context.switchToHttp();
    const response = ctx.getResponse();
    const request = ctx.getRequest();

    return next.handle().pipe(
      map((data) => {
        return {
          success: true,
          statusCode: response.statusCode,
          message: data?.message || 'OK',
          data: data,
          timestamp: new Date().toISOString(),
          path: request.url,
        };
      }),
    );
  }
}