/*
  Warnings:

  - You are about to drop the column `deviceId` on the `Device` table. All the data in the column will be lost.
  - Added the required column `houseId` to the `Device` table without a default value. This is not possible if the table is not empty.

*/
-- DropForeignKey
ALTER TABLE "User_Token" DROP CONSTRAINT "User_Token_userId_fkey";

-- DropIndex
DROP INDEX "Device_deviceId_key";

-- AlterTable
ALTER TABLE "Device" DROP COLUMN "deviceId",
ADD COLUMN     "houseId" INTEGER NOT NULL;

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "houseId" INTEGER;

-- CreateTable
CREATE TABLE "House" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,

    CONSTRAINT "House_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_houseId_fkey" FOREIGN KEY ("houseId") REFERENCES "House"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "User_Token" ADD CONSTRAINT "User_Token_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Device" ADD CONSTRAINT "Device_houseId_fkey" FOREIGN KEY ("houseId") REFERENCES "House"("id") ON DELETE CASCADE ON UPDATE CASCADE;
