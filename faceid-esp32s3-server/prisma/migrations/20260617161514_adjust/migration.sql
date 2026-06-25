-- CreateEnum
CREATE TYPE "Source" AS ENUM ('APP', 'FACEID');

-- AlterTable
ALTER TABLE "DeviceLog" ADD COLUMN     "source" "Source" NOT NULL DEFAULT 'FACEID';
