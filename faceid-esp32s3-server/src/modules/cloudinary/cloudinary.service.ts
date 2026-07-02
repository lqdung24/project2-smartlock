import { Injectable, Logger } from '@nestjs/common';
import { UploadApiErrorResponse, UploadApiResponse, v2 as cloudinary } from 'cloudinary';
import * as streamifier from 'streamifier';

@Injectable()
export class CloudinaryService {
  private readonly logger = new Logger(CloudinaryService.name);

  uploadImage(
    fileBuffer: Buffer,
  ): Promise<UploadApiResponse | UploadApiErrorResponse> {
    return new Promise((resolve, reject) => {
      const uploadStream = cloudinary.uploader.upload_stream(
        {
          folder: 'face-id-images', // Optional: you can organize uploads in folders
          resource_type: 'image',
        },
        (error, result) => {
          if (error) {
            this.logger.error('Cloudinary Upload Error:', error);
            return reject(error);
          }
          // Ensure result is not undefined before proceeding
          if (result) {
            this.logger.log('Cloudinary Upload Success:', result.secure_url);
            resolve(result);
          } else {
            // This case is unlikely if there's no error, but it's safer to handle it.
            const unknownError = new Error('Cloudinary upload failed without returning an error or result.');
            this.logger.error(unknownError.message);
            reject(unknownError);
          }
        },
      );

      streamifier.createReadStream(fileBuffer).pipe(uploadStream);
    });
  }
}
