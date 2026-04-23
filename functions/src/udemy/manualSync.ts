import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

import { firestore } from '../firebaseAdmin';
import { normalizeUdemyProgressPayload } from './normalizeProgress';
import { fanOutMirroredUdemyProgress } from './goalSync';
import {
  udemyApiBaseUrl,
  udemyApiClientId,
  udemyApiClientSecret,
} from './config';
import { writeMirroredUdemyProgress, writeUdemyIngestionLog } from './writeMirror';

function buildAuthHeaders(): Record<string, string> {
  const clientId = udemyApiClientId.value().trim();
  const clientSecret = udemyApiClientSecret.value().trim();
  if (!clientId || !clientSecret) {
    throw new HttpsError(
      'failed-precondition',
      'Udemy API credentials are not configured.',
    );
  }

  const token = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  return {
    Authorization: `Basic ${token}`,
    Accept: 'application/json',
  };
}

function resolveProgressUrl(courseExternalId: string, userEmail: string): string {
  const baseUrl = udemyApiBaseUrl.value().trim();
  if (!baseUrl) {
    throw new HttpsError(
      'failed-precondition',
      'Udemy API base URL is not configured.',
    );
  }

  return baseUrl
    .replace('{courseExternalId}', encodeURIComponent(courseExternalId))
    .replace('{courseId}', encodeURIComponent(courseExternalId))
    .replace('{userEmail}', encodeURIComponent(userEmail));
}

export const syncUdemyProgressNow = onCall(
  {
    region: 'africa-south1',
    cors: true,
    secrets: [udemyApiBaseUrl, udemyApiClientId, udemyApiClientSecret],
  },
  async (request) => {
    const uid = request.auth?.uid;
    const userEmail = request.auth?.token.email;
    if (!uid || !userEmail) {
      throw new HttpsError('unauthenticated', 'You must be signed in.');
    }

    const goalId = String(request.data?.goalId ?? '').trim();
    if (!goalId) {
      throw new HttpsError('invalid-argument', 'goalId is required.');
    }

    const goalSnap = await firestore.collection('goals').doc(goalId).get();
    if (!goalSnap.exists) {
      throw new HttpsError('not-found', 'Goal not found.');
    }
    const goalData = goalSnap.data() ?? {};
    if (String(goalData.userId ?? '').trim() !== uid) {
      throw new HttpsError(
        'permission-denied',
        'You cannot sync another user’s goal.',
      );
    }

    const courseExternalId = String(goalData.courseExternalId ?? '').trim();
    if (!courseExternalId) {
      throw new HttpsError(
        'failed-precondition',
        'This goal is missing its Udemy course id.',
      );
    }

    const requestUrl = resolveProgressUrl(courseExternalId, userEmail);
    const headers = buildAuthHeaders();

    try {
      const httpResponse = await fetch(requestUrl, {
        method: 'GET',
        headers,
      });
      if (!httpResponse.ok) {
        throw new HttpsError(
          'internal',
          `Udemy progress request failed with status ${httpResponse.status}.`,
        );
      }

      const payload = (await httpResponse.json()) as Record<string, unknown>;
      const normalized = normalizeUdemyProgressPayload(payload, {
        fallbackCourseExternalId: courseExternalId,
        fallbackCourseTitle: String(goalData.courseTitle ?? goalData.title ?? '').trim(),
        learnerEmail: userEmail,
        source: 'rest_poll',
      });

      await writeMirroredUdemyProgress(uid, normalized);
      const updatedGoals = await fanOutMirroredUdemyProgress(
        uid,
        normalized.courseExternalId,
        normalized,
      );

      await writeUdemyIngestionLog(`manual:${uid}:${goalId}`, {
        status: 'processed',
        trigger: 'manual_sync',
        userId: uid,
        goalId,
        courseExternalId: normalized.courseExternalId,
        progressPercent: normalized.progressPercent,
        updatedGoals,
      });

      return {
        ok: true,
        progressPercent: normalized.progressPercent,
        completedSteps: normalized.completedSteps ?? null,
        totalSteps: normalized.totalSteps ?? null,
        courseTitle: normalized.courseTitle ?? null,
        syncStatus: normalized.syncStatus,
        syncedAt: normalized.updatedAt.toISOString(),
        updatedGoals,
      };
    } catch (error) {
      logger.error('syncUdemyProgressNow failed', error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError('internal', 'Udemy sync failed.');
    }
  },
);
