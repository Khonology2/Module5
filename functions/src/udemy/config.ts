import { defineSecret } from 'firebase-functions/params';

export const udemyWebhookSecret = defineSecret('UDEMY_WEBHOOK_SECRET');
export const udemyApiBaseUrl = defineSecret('UDEMY_API_BASE_URL');
export const udemyApiClientId = defineSecret('UDEMY_API_CLIENT_ID');
export const udemyApiClientSecret = defineSecret('UDEMY_API_CLIENT_SECRET');
