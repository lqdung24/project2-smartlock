/*
  Warnings:

  - You are about to drop the `House_Request` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "House_Request" DROP CONSTRAINT "House_Request_ownerId_fkey";

-- DropForeignKey
ALTER TABLE "House_Request" DROP CONSTRAINT "House_Request_requesterId_fkey";

-- DropTable
DROP TABLE "House_Request";

-- DropEnum
DROP TYPE "RequestStatus";
