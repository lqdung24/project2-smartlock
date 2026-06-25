/*
  Warnings:

  - Changed the type of `embedVector` on the `FaceData` table. No cast exists, the column would be dropped and recreated, which cannot be done if there is data, since the column is required.

*/
-- AlterTable
ALTER TABLE "FaceData" DROP COLUMN "embedVector",
ADD COLUMN     "embedVector" BYTEA NOT NULL;
