import { Timestamp } from 'firebase-admin/firestore';

import type { CourseSyncStatus, UdemyProgressRecord } from './types';

function coerceDate(value: unknown): Date | null {
  if (value instanceof Date) return value;
  if (value instanceof Timestamp) return value.toDate();
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function coerceInt(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.round(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? Math.round(parsed) : null;
  }
  return null;
}

function coercePercent(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) {
    if (value <= 1) return Math.round(value * 100);
    return Math.round(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const normalized = value.trim().replace('%', '');
    const parsed = Number(normalized);
    if (!Number.isFinite(parsed)) return null;
    if (parsed <= 1) return Math.round(parsed * 100);
    return Math.round(parsed);
  }
  return null;
}

function readFirst(
  source: Record<string, unknown>,
  paths: string[][],
): unknown {
  for (const path of paths) {
    let current: unknown = source;
    let found = true;
    for (const segment of path) {
      if (
        current !== null &&
        typeof current === 'object' &&
        segment in (current as Record<string, unknown>)
      ) {
        current = (current as Record<string, unknown>)[segment];
      } else {
        found = false;
        break;
      }
    }
    if (found && current !== undefined && current !== null) {
      return current;
    }
  }
  return null;
}

function normalizePayload(
  payload: unknown,
): Record<string, unknown> | null {
  if (payload === null || typeof payload !== 'object') return null;
  const source = { ...(payload as Record<string, unknown>) };

  if (Array.isArray(source.results) && source.results.length > 0) {
    const first = source.results[0];
    if (first !== null && typeof first === 'object') {
      return { ...source, ...(first as Record<string, unknown>) };
    }
  }

  if (source.data !== null && typeof source.data === 'object') {
    return { ...source, ...(source.data as Record<string, unknown>) };
  }

  return source;
}

function derivePercent(source: Record<string, unknown>): number | null {
  const completed = coerceInt(
    readFirst(source, [
      ['completedSteps'],
      ['completed_lectures'],
      ['completedLectures'],
      ['num_completed_lectures'],
      ['lecture_completed_count'],
      ['progress', 'completed'],
    ]),
  );
  const total = coerceInt(
    readFirst(source, [
      ['totalSteps'],
      ['total_lectures'],
      ['totalLectures'],
      ['num_lectures'],
      ['lecture_count'],
      ['progress', 'total'],
    ]),
  );
  if (completed === null || total === null || total <= 0) return null;
  return Math.round((completed / total) * 100);
}

export function normalizeUdemyProgressPayload(
  payload: unknown,
  options: {
    fallbackCourseExternalId: string;
    fallbackCourseTitle?: string | null;
    source: UdemyProgressRecord['source'];
    learnerEmail?: string | null;
  },
): UdemyProgressRecord {
  const source = normalizePayload(payload);
  if (source === null) {
    throw new Error('Udemy progress payload was empty.');
  }

  const progressPercent =
    coercePercent(
      readFirst(source, [
        ['progressPercent'],
        ['progress_percentage'],
        ['percent_complete'],
        ['progress'],
        ['completion_percentage'],
        ['result', 'score', 'scaled'],
      ]),
    ) ?? derivePercent(source);

  if (progressPercent === null) {
    throw new Error('Udemy progress payload did not include a usable percentage.');
  }

  const completedSteps = coerceInt(
    readFirst(source, [
      ['completedSteps'],
      ['completed_lectures'],
      ['completedLectures'],
      ['num_completed_lectures'],
      ['lecture_completed_count'],
      ['progress', 'completed'],
    ]),
  );
  const totalSteps = coerceInt(
    readFirst(source, [
      ['totalSteps'],
      ['total_lectures'],
      ['totalLectures'],
      ['num_lectures'],
      ['lecture_count'],
      ['progress', 'total'],
    ]),
  );
  const rawUpdatedAt = coerceDate(
    readFirst(source, [
      ['rawUpdatedAt'],
      ['updatedAt'],
      ['lastSyncedAt'],
      ['syncedAt'],
      ['createdAt'],
      ['timestamp'],
    ]),
  );
  const courseTitle =
    String(
      readFirst(source, [
        ['courseTitle'],
        ['title'],
        ['course_name'],
        ['name'],
      ]) ?? options.fallbackCourseTitle ?? '',
    ).trim() || null;
  const courseExternalId =
    String(
      readFirst(source, [
        ['courseExternalId'],
        ['courseId'],
        ['course_id'],
        ['courseKey'],
      ]) ?? options.fallbackCourseExternalId,
    ).trim() || options.fallbackCourseExternalId;

  const normalizedPercent = Math.min(Math.max(progressPercent, 0), 100);
  const syncStatus: CourseSyncStatus =
    normalizedPercent >= 100 ? 'completed' : 'synced';

  return {
    progressPercent: normalizedPercent,
    completedSteps,
    totalSteps,
    courseTitle,
    courseExternalId,
    source: options.source,
    updatedAt: new Date(),
    rawUpdatedAt,
    syncStatus,
    learnerEmail: options.learnerEmail?.trim() || null,
    rawPayload: source,
  };
}
