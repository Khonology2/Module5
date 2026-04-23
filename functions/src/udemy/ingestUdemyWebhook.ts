import { onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

import { normalizeUdemyProgressPayload } from './normalizeProgress';
import { fanOutMirroredUdemyProgress } from './goalSync';
import { findUserIdByEmail } from './userLookup';
import { udemyWebhookSecret } from './config';
import { writeMirroredUdemyProgress, writeUdemyIngestionLog } from './writeMirror';

export const ingestUdemyWebhook = onRequest(
  {
    region: 'africa-south1',
    cors: true,
    secrets: [udemyWebhookSecret],
  },
  async (request, response) => {
    if (request.method !== 'POST') {
      response.status(405).json({ error: 'Method not allowed' });
      return;
    }

    const expectedSecret = udemyWebhookSecret.value().trim();
    const providedSecret =
      String(request.header('x-udemy-webhook-secret') ?? '').trim();
    if (!expectedSecret || providedSecret !== expectedSecret) {
      response.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const body =
      request.body && typeof request.body === 'object' ? request.body : {};
    const learnerEmail = String(
      (body as Record<string, unknown>).learnerEmail ??
        (body as Record<string, unknown>).email ??
        (body as Record<string, unknown>).actorEmail ??
        '',
    ).trim();
    const fallbackCourseExternalId = String(
      (body as Record<string, unknown>).courseExternalId ??
        (body as Record<string, unknown>).courseId ??
        (body as Record<string, unknown>).course_id ??
        '',
    ).trim();

    if (!learnerEmail || !fallbackCourseExternalId) {
      response.status(400).json({
        error: 'learnerEmail and courseExternalId are required.',
      });
      return;
    }

    const logId = String(
      (body as Record<string, unknown>).eventId ??
        (body as Record<string, unknown>).id ??
        `${learnerEmail}:${fallbackCourseExternalId}`,
    );

    try {
      const userId = await findUserIdByEmail(learnerEmail);
      if (!userId) {
        await writeUdemyIngestionLog(logId, {
          status: 'user_not_found',
          learnerEmail,
          courseExternalId: fallbackCourseExternalId,
          payload: body,
        });
        response.status(404).json({ error: 'No app user matches that email.' });
        return;
      }

      const normalized = normalizeUdemyProgressPayload(body, {
        fallbackCourseExternalId,
        fallbackCourseTitle: String(
          (body as Record<string, unknown>).courseTitle ??
            (body as Record<string, unknown>).title ??
            '',
        ).trim(),
        learnerEmail,
        source: 'xapi',
      });

      await writeMirroredUdemyProgress(userId, normalized);
      const updatedGoals = await fanOutMirroredUdemyProgress(
        userId,
        normalized.courseExternalId,
        normalized,
      );

      await writeUdemyIngestionLog(logId, {
        status: 'processed',
        learnerEmail,
        userId,
        courseExternalId: normalized.courseExternalId,
        progressPercent: normalized.progressPercent,
        updatedGoals,
      });

      response.status(200).json({
        ok: true,
        userId,
        updatedGoals,
        progressPercent: normalized.progressPercent,
      });
    } catch (error) {
      logger.error('ingestUdemyWebhook failed', error);
      await writeUdemyIngestionLog(logId, {
        status: 'error',
        learnerEmail,
        courseExternalId: fallbackCourseExternalId,
        error: String(error),
      });
      response.status(500).json({ error: 'Webhook processing failed.' });
    }
  },
);
