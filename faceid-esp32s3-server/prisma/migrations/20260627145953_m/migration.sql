-- CreateEnum
CREATE TYPE "DeviceStatus" AS ENUM ('RUNNING', 'DELETED');

-- AlterTable
ALTER TABLE "Device" ADD COLUMN     "status" "DeviceStatus" NOT NULL DEFAULT 'RUNNING';
