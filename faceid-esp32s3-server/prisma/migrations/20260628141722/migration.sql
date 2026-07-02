/*
  Warnings:

  - You are about to drop the column `face_id` on the `FaceData` table. All the data in the column will be lost.

*/
-- AlterTable
ALTER TABLE "FaceData" DROP COLUMN "face_id",
ALTER COLUMN "embedVector" DROP NOT NULL;
