import { FieldValue, Timestamp } from 'firebase-admin/firestore';

import { firestore } from '../firebaseAdmin';
import type { UdemyProgressRecord } from './types';

export async function writeMirroredUdemyProgress(
  userId: string,
  progress: UdemyProgressRecord,
): Promise<void> {
  await firestore
    .collection('users')
    .doc(userId)
    .collection('udemyCourseProgress')
    .doc(progress.courseExternalId)
    .set(
      {
        progressPercent: progress.progressPercent,
        completedSteps: progress.completedSteps ?? null,
        totalSteps: progress.totalSteps ?? null,
        courseTitle: progress.courseTitle ?? null,
        courseExternalId: progress.courseExternalId,
        source: progress.source,
        learnerEmail: progress.learnerEmail ?? null,
        syncStatus: progress.syncStatus,
        updatedAt: Timestamp.fromDate(progress.updatedAt),
        rawUpdatedAt: progress.rawUpdatedAt
          ? Timestamp.fromDate(progress.rawUpdatedAt)
          : null,
        rawPayload: progress.rawPayload ?? null,
        serverUpdatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

export async function writeUdemyIngestionLog(
  logId: string,
  data: Record<string, unknown>,
): Promise<void> {
  await firestore.collection('udemy_ingestion_logs').doc(logId).set(
    {
      ...data,
      loggedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}
