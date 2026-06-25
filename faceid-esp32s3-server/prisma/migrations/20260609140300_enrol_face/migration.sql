-- CreateTable
CREATE TABLE "EnrolFace" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "img_url" TEXT NOT NULL,
    "userId" INTEGER NOT NULL,
    "createAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "embedVector" TEXT NOT NULL,

    CONSTRAINT "EnrolFace_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "User_Lock" (
    "id" SERIAL NOT NULL,
    "userId" INTEGER NOT NULL,
    "lockId" INTEGER NOT NULL,

    CONSTRAINT "User_Lock_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "EnrolFace" ADD CONSTRAINT "EnrolFace_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "User_Lock" ADD CONSTRAINT "User_Lock_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "User_Lock" ADD CONSTRAINT "User_Lock_lockId_fkey" FOREIGN KEY ("lockId") REFERENCES "Device"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
