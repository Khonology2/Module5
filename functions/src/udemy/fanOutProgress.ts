import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import { Timestamp } from 'firebase-admin/firestore';

import { fanOutMirroredUdemyProgress } from './goalSync';
import type { UdemyProgressRecord } from './types';

function coerceDate(value: unknown): Date {
  if (value instanceof Timestamp) return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return new Date();
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function asInt(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.round(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? Math.round(parsed) : null;
  }
  return null;
}

export const fanOutUdemyProgressMirror = onDocumentWritten(
  {
    region: 'africa-south1',
    document: 'users/{userId}/udemyCourseProgress/{courseExternalId}',
  },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;

    const userId = event.params.userId;
    const courseExternalId = event.params.courseExternalId;
    const data = after.data() ?? {};
    const record: UdemyProgressRecord = {
      progressPercent: asInt(data.progressPercent) ?? 0,
      completedSteps: asInt(data.completedSteps),
      totalSteps: asInt(data.totalSteps),
      courseTitle: asString(data.courseTitle) || null,
      courseExternalId,
      source:
        (asString(data.source) as UdemyProgressRecord['source']) || 'mirror',
      updatedAt: coerceDate(data.updatedAt),
      rawUpdatedAt: data.rawUpdatedAt ? coerceDate(data.rawUpdatedAt) : null,
      syncStatus:
        (asString(data.syncStatus) as UdemyProgressRecord['syncStatus']) ||
        ((asInt(data.progressPercent) ?? 0) >= 100 ? 'completed' : 'synced'),
      learnerEmail: asString(data.learnerEmail) || null,
      rawPayload:
        data.rawPayload && typeof data.rawPayload === 'object'
          ? (data.rawPayload as Record<string, unknown>)
          : null,
    };

    try {
      await fanOutMirroredUdemyProgress(userId, courseExternalId, record);
    } catch (error) {
      logger.error('fanOutUdemyProgressMirror failed', error);
      throw error;
    }
  },
);
