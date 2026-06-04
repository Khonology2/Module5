import 'dart:developer' as developer;

import 'package:pdh/models/season.dart';
import 'package:pdh/services/backend_auth_service.dart';

class SeasonMetricsJob {
  static final BackendAuthService _backend = BackendAuthService.instance;

  /// Recompute season metrics for a single season document.
  static Future<void> recomputeSeasonMetrics(String seasonId) async {
    try {
      final data = await _backend.getSeason(seasonId);
      if (data.isEmpty) {
        developer.log('Season $seasonId not found. Skipping metrics job.');
        return;
      }
      final season = Season.fromMap(data, id: seasonId);
      final metrics = _recalculateMetrics(season);

      final Map<String, dynamic> updates = {
        'metrics': {
          'totalParticipants': metrics.totalParticipants,
          'activeParticipants': metrics.activeParticipants,
          'completedChallenges': metrics.completedChallenges,
          'totalChallenges': metrics.totalChallenges,
          'totalPointsEarned': metrics.totalPointsEarned,
          'averageProgress': metrics.averageProgress,
          'challengeCompletions': metrics.challengeCompletions.map(
            (key, value) => MapEntry(key.name, value),
          ),
          'totalTeamPoints': metrics.totalTeamPoints,
          'completedTeamChallenges': metrics.completedTeamChallenges,
          'managerPointsEarned': metrics.managerPointsEarned,
          'lastUpdated': DateTime.now().toIso8601String(),
        },
      };

      if (metrics.completedChallengesPerParticipant.isNotEmpty) {
        updates['participations'] = {
          for (final entry in metrics.completedChallengesPerParticipant.entries)
            entry.key: {'completedChallenges': entry.value},
        };
      }

      await _backend.patchSeason(seasonId, updates);
      developer.log('Recomputed metrics for season $seasonId');
    } catch (e, st) {
      developer.log(
        'Failed to recompute metrics for season $seasonId: $e',
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Optional helper to recompute every season (useful for manual maintenance).
  static Future<void> recomputeAllSeasons() async {
    final seasons = await _backend.getSeasons(limit: 500);
    for (final season in seasons) {
      final seasonId = (season['id'] ?? '').toString();
      if (seasonId.isEmpty) continue;
      await recomputeSeasonMetrics(seasonId);
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
      completedChallenges: completedChallengesPerParticipant.values.fold(
        0,
        (total, value) => total + value,
      ),
      totalChallenges: totalChallenges,
      totalPointsEarned: totalPointsEarned,
      averageProgress: averageProgress,
      challengeCompletions: challengeCompletionsByType,
      totalTeamPoints: totalPointsEarned,
      completedTeamChallenges: challengeCompletionsByType.values.fold(
        0,
        (total, value) => total + value,
      ),
      managerPointsEarned: season.metrics.managerPointsEarned,
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
  final int managerPointsEarned;
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
    required this.managerPointsEarned,
    required this.completedChallengesPerParticipant,
  });
}
