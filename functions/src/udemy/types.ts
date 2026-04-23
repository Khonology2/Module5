export type CourseSyncStatus =
  | 'ready_to_sync'
  | 'queued'
  | 'syncing'
  | 'synced'
  | 'completed'
  | 'setup_required'
  | 'link_error'
  | 'error';

export interface UdemyProgressRecord {
  progressPercent: number;
  completedSteps?: number | null;
  totalSteps?: number | null;
  courseTitle?: string | null;
  courseExternalId: string;
  source: 'manual_sync' | 'rest_poll' | 'xapi' | 'mirror';
  updatedAt: Date;
  rawUpdatedAt?: Date | null;
  syncStatus: CourseSyncStatus;
  learnerEmail?: string | null;
  rawPayload?: Record<string, unknown> | null;
}

export interface GoalCourseSyncTarget {
  goalId: string;
  userId: string;
  seasonId?: string | null;
  challengeId?: string | null;
  goalTitle?: string | null;
}
