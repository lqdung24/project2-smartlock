/*
  Warnings:

  - Added the required column `face_id` to the `FaceData` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "FaceData" ADD COLUMN     "face_id" INTEGER NOT NULL;
