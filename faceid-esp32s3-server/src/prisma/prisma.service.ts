import { Injectable, OnModuleInit, INestApplication } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { ConfigService } from '@nestjs/config';
import { Pool } from 'pg';
import { PrismaPg } from '@prisma/adapter-pg';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  constructor(private configService: ConfigService) {
    // 1. Lấy URL động từ ConfigService (hoặc fallback về chuỗi mặc định nếu trống)
    const connectionString =
      configService.get<string>('DATABASE_URL') ||
      'postgresql://postgres:your_password@127.0.0.1:5432/smart_lock_db';

    // 2. Tạo một kết nối Pool từ thư viện 'pg'
    const pool = new Pool({ connectionString });

    // 3. Khởi tạo Adapter theo đúng chuẩn Prisma 7
    const adapter = new PrismaPg(pool);

    // 4. Truyền adapter vào hàm super() của PrismaClient
    super({ adapter });
  }

  async onModuleInit() {
    await this.$connect();
    console.log(
      'Runtime DB (onModuleInit): Kết nối Prisma thành công qua Adapter!',
    );
  }

  enableShutdownHooks(app: INestApplication) {
    process.on('beforeExit', () => {
      void app.close();
    });
  }
}
