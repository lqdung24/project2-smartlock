-- CreateTable
CREATE TABLE "User_Token" (
    "id" SERIAL NOT NULL,
    "userId" INTEGER NOT NULL,
    "refreshToken" TEXT NOT NULL,
    "expireTime" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_Token_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "User_Token" ADD CONSTRAINT "User_Token_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
