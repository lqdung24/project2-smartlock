-- CreateTable
CREATE TABLE "DeviceLog" (
    "id" SERIAL NOT NULL,
    "deviceId" INTEGER NOT NULL,
    "time" TIMESTAMP(3) NOT NULL,
    "userId" INTEGER,

    CONSTRAINT "DeviceLog_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "DeviceLog" ADD CONSTRAINT "DeviceLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DeviceLog" ADD CONSTRAINT "DeviceLog_deviceId_fkey" FOREIGN KEY ("deviceId") REFERENCES "Device"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
