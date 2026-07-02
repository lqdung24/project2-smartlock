/*
  Warnings:

  - You are about to drop the column `userId` on the `DeviceLog` table. All the data in the column will be lost.

*/
-- DropForeignKey
ALTER TABLE "DeviceLog" DROP CONSTRAINT "DeviceLog_userId_fkey";

-- AlterTable
ALTER TABLE "DeviceLog" DROP COLUMN "userId",
ADD COLUMN     "faceid" INTEGER;

-- AddForeignKey
ALTER TABLE "DeviceLog" ADD CONSTRAINT "DeviceLog_faceid_fkey" FOREIGN KEY ("faceid") REFERENCES "FaceData"("id") ON DELETE SET NULL ON UPDATE CASCADE;
