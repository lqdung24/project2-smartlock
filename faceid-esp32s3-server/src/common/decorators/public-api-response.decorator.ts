import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_API_RESPONSE_KEY = 'isPublicApiResponse';
export const PublicApiResponse = () => SetMetadata(IS_PUBLIC_API_RESPONSE_KEY, true);