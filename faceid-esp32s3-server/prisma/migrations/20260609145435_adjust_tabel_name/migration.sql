/*
  Warnings:

  - You are about to drop the `EnrolFace` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropForeignKey
ALTER TABLE "EnrolFace" DROP CONSTRAINT "EnrolFace_userId_fkey";

-- DropTable
DROP TABLE "EnrolFace";

-- CreateTable
CREATE TABLE "FaceData" (
    "id" SERIAL NOT NULL,
    "label" TEXT NOT NULL,
    "img_url" TEXT NOT NULL,
    "userId" INTEGER NOT NULL,
    "createAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "embedVector" TEXT NOT NULL,

    CONSTRAINT "FaceData_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "FaceData" ADD CONSTRAINT "FaceData_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
