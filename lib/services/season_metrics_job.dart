import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/models/season.dart';

class SeasonMetricsJob {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Recompute season metrics for a single season document.
  static Future<void> recomputeSeasonMetrics(String seasonId) async {
    try {
      final doc = await _firestore.collection('seasons').doc(seasonId).get();
      if (!doc.exists) {
        developer.log('Season $seasonId not found. Skipping metrics job.');
        return;
      }
      final season = Season.fromFirestore(doc);
      final metrics = _recalculateMetrics(season);

      final Map<String, dynamic> updates = {
        'metrics.totalParticipants': metrics.totalParticipants,
        'metrics.activeParticipants': metrics.activeParticipants,
        'metrics.completedChallenges': metrics.completedChallenges,
        'metrics.totalChallenges': metrics.totalChallenges,
        'metrics.totalPointsEarned': metrics.totalPointsEarned,
        'metrics.averageProgress': metrics.averageProgress,
        'metrics.challengeCompletions':
            metrics.challengeCompletions.map((key, value) => MapEntry(key.name, value)),
        'metrics.totalTeamPoints': metrics.totalTeamPoints,
        'metrics.completedTeamChallenges': metrics.completedTeamChallenges,
        'metrics.lastUpdated': FieldValue.serverTimestamp(),
      };

      metrics.completedChallengesPerParticipant.forEach((userId, count) {
        updates['participations.$userId.completedChallenges'] = count;
      });

      await doc.reference.update(updates);
      developer.log('Recomputed metrics for season $seasonId');
    } catch (e, st) {
      developer.log('Failed to recompute metrics for season $seasonId: $e',
          stackTrace: st);
      rethrow;
    }
  }

  /// Optional helper to recompute every season (useful for manual maintenance).
  static Future<void> recomputeAllSeasons() async {
    final snapshot = await _firestore.collection('seasons').get();
    for (final doc in snapshot.docs) {
      await recomputeSeasonMetrics(doc.id);
    }
  }

  static _RecomputedMetrics _recalculateMetrics(Season season) {
    final participants = season.participations.values.toList();
    final int totalParticipants = participants.length;
    int activeParticipants = 0;
    int totalPointsEarned = 0;
    double progressSum = 0.0;

    final Map<String, SeasonChallenge> milestoneLookup = {};
    for (final challenge in season.challenges) {
      for (final milestone in challenge.milestones) {
        milestoneLookup['${challenge.id}.${milestone.id}'] = challenge;
        milestoneLookup[milestone.id] = challenge;
      }
    }

    final Map<ChallengeType, int> challengeCompletionsByType = {
      for (final type in ChallengeType.values) type: 0,
    };
    final Map<String, int> completedChallengesPerParticipant = {};

    for (final participation in participants) {
      final progress = _calculateParticipantProgress(participation, season);
      if (progress > 0) activeParticipants++;
      progressSum += progress;
      totalPointsEarned += participation.totalPoints;

      int participantCompleted = 0;
      for (final challenge in season.challenges) {
        if (_hasCompletedChallenge(participation, challenge)) {
          participantCompleted++;
        }
      }
      completedChallengesPerParticipant[participation.userId] =
          participantCompleted;

      participation.milestoneProgress.forEach((key, value) {
        if (value == MilestoneStatus.completed) {
          final challenge = milestoneLookup[key];
          if (challenge != null) {
            challengeCompletionsByType[challenge.type] =
                (challengeCompletionsByType[challenge.type] ?? 0) + 1;
          }
        }
      });
    }

    final totalChallenges = season.metrics.totalChallenges == 0
        ? season.challenges.length
        : season.metrics.totalChallenges;
    final averageProgress =
        totalParticipants > 0 ? progressSum / totalParticipants : 0.0;

    return _RecomputedMetrics(
      totalParticipants: totalParticipants,
      activeParticipants: activeParticipants,
      completedChallenges:
          completedChallengesPerParticipant.values.fold(0, (sum, value) => sum + value),
      totalChallenges: totalChallenges,
      totalPointsEarned: totalPointsEarned,
      averageProgress: averageProgress,
      challengeCompletions: challengeCompletionsByType,
      totalTeamPoints: totalPointsEarned,
      completedTeamChallenges:
          challengeCompletionsByType.values.fold(0, (sum, value) => sum + value),
      completedChallengesPerParticipant: completedChallengesPerParticipant,
    );
  }

  static double _calculateParticipantProgress(
    SeasonParticipation participation,
    Season season,
  ) {
    if (season.challenges.isEmpty) return 0.0;
    int totalMilestones = 0;
    int completedMilestones = 0;

    for (final challenge in season.challenges) {
      totalMilestones += challenge.milestones.length;
      for (final milestone in challenge.milestones) {
        final keyDot = '${challenge.id}.${milestone.id}';
        final status = participation.milestoneProgress[keyDot] ??
            participation.milestoneProgress[milestone.id];
        if (status == MilestoneStatus.completed) {
          completedMilestones++;
        }
      }
    }

    return totalMilestones > 0 ? completedMilestones / totalMilestones : 0.0;
  }

  static bool _hasCompletedChallenge(
    SeasonParticipation participation,
    SeasonChallenge challenge,
  ) {
    for (final milestone in challenge.milestones) {
      final keyDot = '${challenge.id}.${milestone.id}';
      final status = participation.milestoneProgress[keyDot] ??
          participation.milestoneProgress[milestone.id];
      if (status != MilestoneStatus.completed) {
        return false;
      }
    }
    return true;
  }
}

class _RecomputedMetrics {
  final int totalParticipants;
  final int activeParticipants;
  final int completedChallenges;
  final int totalChallenges;
  final int totalPointsEarned;
  final double averageProgress;
  final Map<ChallengeType, int> challengeCompletions;
  final int totalTeamPoints;
  final int completedTeamChallenges;
  final Map<String, int> completedChallengesPerParticipant;

  _RecomputedMetrics({
    required this.totalParticipants,
    required this.activeParticipants,
    required this.completedChallenges,
    required this.totalChallenges,
    required this.totalPointsEarned,
    required this.averageProgress,
    required this.challengeCompletions,
    required this.totalTeamPoints,
    required this.completedTeamChallenges,
    required this.completedChallengesPerParticipant,
  });
}

