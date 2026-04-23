import {
  FieldValue,
  Timestamp,
  type DocumentData,
  type QueryDocumentSnapshot,
} from 'firebase-admin/firestore';

import { firestore } from '../firebaseAdmin';
import type { GoalCourseSyncTarget, UdemyProgressRecord } from './types';

function asInt(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.round(value);
  }
  if (typeof value === 'string' && value.trim().length > 0) {
    const parsed = Number(value.trim());
    return Number.isFinite(parsed) ? Math.round(parsed) : 0;
  }
  return 0;
}

function asNonEmptyString(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function determineGoalStatus(progress: number): string {
  if (progress <= 0) return 'notStarted';
  return 'inProgress';
}

function deriveSeasonMilestoneStatus(options: {
  criteria: Record<string, unknown>;
  goalProgress: number;
  goalStatus: string;
  goalApprovalStatus: string;
  goalApprovalRequested: boolean;
  goalHasEvidence: boolean;
  hasPendingReview: boolean;
  hasStartedCustomMilestone: boolean;
}): string {
  const {
    criteria,
    goalProgress,
    goalStatus,
    goalApprovalStatus,
    goalApprovalRequested,
    goalHasEvidence,
    hasPendingReview,
    hasStartedCustomMilestone,
  } = options;

  if (criteria.managerReview === true || criteria.proofApproval === true) {
    const hasFinalApproval =
      (goalApprovalRequested && goalApprovalStatus === 'approved') ||
      goalStatus === 'acknowledged';
    const hasFinalSubmission =
      goalApprovalRequested || goalStatus === 'completed' || goalHasEvidence;
    if (hasFinalApproval) return 'completed';
    if (hasFinalSubmission || hasPendingReview) return 'inProgress';
    return 'notStarted';
  }

  const progressThreshold =
    typeof criteria.progress === 'number'
      ? Math.round(criteria.progress)
      : null;
  if (progressThreshold !== null) {
    if (goalProgress >= progressThreshold) return 'completed';
    if (goalProgress > 0) return 'inProgress';
    return 'notStarted';
  }

  const action = String(criteria.action ?? '').trim();
  const hasStartedGoal =
    goalProgress > 0 ||
    goalStatus === 'inProgress' ||
    goalStatus === 'completed' ||
    goalStatus === 'acknowledged';

  if (
    action === 'start_learning' ||
    action === 'project_start' ||
    action === 'goal_set' ||
    action === 'skill_assessment'
  ) {
    return hasStartedGoal ? 'completed' : 'notStarted';
  }

  if (action === 'project_complete') {
    if (goalProgress >= 100) return 'completed';
    if (hasStartedGoal) return 'inProgress';
    return 'notStarted';
  }

  if (hasStartedCustomMilestone) return 'inProgress';
  if (hasStartedGoal) return 'inProgress';
  return 'notStarted';
}

async function syncSeasonGoalFromGoalState(
  goalId: string,
  goalData: Record<string, unknown>,
): Promise<void> {
  if (goalData.isSeasonGoal !== true) return;

  const seasonId = asNonEmptyString(goalData.seasonId);
  const challengeId = asNonEmptyString(goalData.challengeId);
  const userId = asNonEmptyString(goalData.userId);
  if (seasonId === null || challengeId === null || userId === null) return;

  const seasonRef = firestore.collection('seasons').doc(seasonId);
  const seasonSnap = await seasonRef.get();
  if (!seasonSnap.exists) return;
  const seasonData = seasonSnap.data() ?? {};
  const challenges = Array.isArray(seasonData.challenges)
    ? (seasonData.challenges as Record<string, unknown>[])
    : [];
  const challenge = challenges.find(
    (entry) => asNonEmptyString(entry.id) === challengeId,
  );
  if (!challenge) return;

  const milestones = Array.isArray(challenge.milestones)
    ? (challenge.milestones as Record<string, unknown>[])
    : [];
  const participations =
    seasonData.participations && typeof seasonData.participations === 'object'
      ? (seasonData.participations as Record<string, Record<string, unknown>>)
      : {};
  const participation = participations[userId] ?? {};
  const milestoneProgress =
    participation.milestoneProgress &&
    typeof participation.milestoneProgress === 'object'
      ? (participation.milestoneProgress as Record<string, unknown>)
      : {};

  const goalMilestoneSnap = await firestore
      .collection('goals')
      .doc(goalId)
      .collection('milestones')
      .get();
  const goalMilestones = goalMilestoneSnap.docs.map((doc) => doc.data());

  const goalProgress = asInt(goalData.progress);
  const goalStatus = String(goalData.status ?? '').trim();
  const goalApprovalStatus = String(goalData.approvalStatus ?? '').trim();
  const goalApprovalRequested = goalData.approvalRequestedAt != null;
  const rawGoalEvidence = goalData.evidence;
  const goalHasEvidence =
    (Array.isArray(rawGoalEvidence) && rawGoalEvidence.length > 0) ||
    (typeof rawGoalEvidence === 'string' && rawGoalEvidence.trim().length > 0);
  const hasPendingReview = goalMilestones.some(
    (entry) => String(entry.status ?? '').trim() === 'pendingManagerReview',
  );
  const hasStartedCustomMilestone = goalMilestones.some((entry) => {
    const status = String(entry.status ?? '').trim();
    return (
      status === 'inProgress' ||
      status === 'pendingManagerReview' ||
      status === 'completed' ||
      status === 'completedAcknowledged'
    );
  });

  const updates: Record<string, unknown> = {
    [`participations.${userId}.lastActivity`]: FieldValue.serverTimestamp(),
    'metrics.lastUpdated': FieldValue.serverTimestamp(),
  };

  let hasAnyChange = false;
  for (const milestone of milestones) {
    const milestoneId = asNonEmptyString(milestone.id);
    if (milestoneId === null) continue;
    const criteria =
      milestone.criteria && typeof milestone.criteria === 'object'
        ? (milestone.criteria as Record<string, unknown>)
        : {};
    const desiredStatus = deriveSeasonMilestoneStatus({
      criteria,
      goalProgress,
      goalStatus,
      goalApprovalStatus,
      goalApprovalRequested,
      goalHasEvidence,
      hasPendingReview,
      hasStartedCustomMilestone,
    });

    const dottedKey = `${challengeId}.${milestoneId}`;
    const currentStatus = String(
      milestoneProgress[dottedKey] ?? milestoneProgress[milestoneId] ?? '',
    ).trim();
    if (currentStatus === desiredStatus) continue;
    if (currentStatus === 'completed' && desiredStatus !== 'completed') continue;

    updates[`participations.${userId}.milestoneProgress.${milestoneId}`] =
      desiredStatus;
    updates[`participations.${userId}.milestoneProgress.${dottedKey}`] =
      desiredStatus;
    hasAnyChange = true;
  }

  if (hasAnyChange) {
    await seasonRef.set(updates, { merge: true });
  }
}

export async function fanOutMirroredUdemyProgress(
  userId: string,
  courseExternalId: string,
  progress: UdemyProgressRecord,
): Promise<number> {
  const goalsSnap = await firestore
    .collection('goals')
    .where('userId', '==', userId)
    .where('courseSyncProvider', '==', 'udemy')
    .where('courseExternalId', '==', courseExternalId)
    .get();

  if (goalsSnap.empty) {
    return 0;
  }

  for (const doc of goalsSnap.docs) {
    await applyGoalProgressFromMirror(doc, progress);
  }

  return goalsSnap.size;
}

async function applyGoalProgressFromMirror(
  doc: QueryDocumentSnapshot<DocumentData>,
  progress: UdemyProgressRecord,
): Promise<void> {
  const goalRef = doc.ref;
  const normalizedProgress = Math.min(Math.max(progress.progressPercent, 0), 100);
  await goalRef.set(
    {
      progress: normalizedProgress,
      courseProviderProgress: normalizedProgress,
      courseCompletedSteps: progress.completedSteps ?? null,
      courseTotalSteps: progress.totalSteps ?? null,
      courseLastSyncedAt: Timestamp.fromDate(progress.updatedAt),
      courseSyncStatus: progress.syncStatus,
      courseSyncError: null,
      courseExternalId: progress.courseExternalId,
      courseTitle: progress.courseTitle ?? null,
      status: determineGoalStatus(normalizedProgress),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const updatedGoalSnap = await goalRef.get();
  const updatedGoalData = updatedGoalSnap.data() ?? {};
  await syncSeasonGoalFromGoalState(goalRef.id, updatedGoalData);
}
