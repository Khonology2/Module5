import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/season_metrics_job.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';

class SeasonService {
  static final BackendAuthService _backend = BackendAuthService.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static Set<String>? _cachedAdminUserIds;
  static DateTime? _cachedAdminUserIdsAt;


  static String _userIdFromMap(Map<String, dynamic> data) {
    return (data['id'] ?? data['uid'] ?? data['userId'] ?? '').toString();
  }

  static Season _seasonFromMap(Map<String, dynamic> data, {String? id}) {
    final resolvedId = (id ?? data['id'] ?? '').toString();
    return Season.fromMap(
      data,
      id: resolvedId.isNotEmpty ? resolvedId : null,
    );
  }

  static Future<Season?> _fetchSeason(String seasonId) async {
    try {
      final data = await _backend.getSeason(seasonId);
      return _seasonFromMap(data, id: seasonId);
    } catch (e) {
      developer.log('Error fetching season $seasonId: $e');
      return null;
    }
  }

  static Future<void> _saveSeason(Season season) async {
    await _backend.patchSeason(season.id, season.toMap(includeId: false));
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? fallback;
  }

  static SeasonMetrics _metricsWithLastUpdated(SeasonMetrics metrics) {
    return SeasonMetrics(
      totalParticipants: metrics.totalParticipants,
      activeParticipants: metrics.activeParticipants,
      completedChallenges: metrics.completedChallenges,
      totalChallenges: metrics.totalChallenges,
      totalPointsEarned: metrics.totalPointsEarned,
      averageProgress: metrics.averageProgress,
      challengeCompletions: metrics.challengeCompletions,
      lastUpdated: DateTime.now(),
      totalTeamPoints: metrics.totalTeamPoints,
      completedTeamChallenges: metrics.completedTeamChallenges,
      managerBadgesEarned: metrics.managerBadgesEarned,
      managerPointsEarned: metrics.managerPointsEarned,
    );
  }

  static const int _managerSeasonCreationBonus = 100;
  static const int _managerSeasonExtensionBonus = 30;
  static const int _managerSeasonCompletionBonus = 150;

  static const Map<String, SeasonBadge> _managerActionBadges = {
    'season_architect': SeasonBadge(
      id: 'season_architect',
      name: 'Season Architect',
      description: 'Launched a growth season for your team',
      icon: '🏗️',
      color: '#9B59B6',
      points: 75,
      criteria: {'action': 'create'},
    ),
    'season_guardian': SeasonBadge(
      id: 'season_guardian',
      name: 'Season Guardian',
      description: 'Extended a season to give your team more time',
      icon: '🛡️',
      color: '#1ABC9C',
      points: 40,
      criteria: {'action': 'extend'},
    ),
    'season_closer': SeasonBadge(
      id: 'season_closer',
      name: 'Season Closer',
      description: 'Successfully completed a team season',
      icon: '🏁',
      color: '#E74C3C',
      points: 100,
      criteria: {'action': 'complete'},
    ),
  };

  static const Map<String, SeasonBadge> _managerPerformanceBadges = {
    'team_builder': SeasonBadge(
      id: 'team_builder',
      name: 'Team Builder',
      description: 'Assembled a team of 5+ for a season',
      icon: '👥',
      color: '#3498DB',
      points: 50,
      criteria: {'participants': 5},
    ),
    'momentum_maker': SeasonBadge(
      id: 'momentum_maker',
      name: 'Momentum Maker',
      description: 'Team earned over 500 points in a season',
      icon: '🚀',
      color: '#E67E22',
      points: 100,
      criteria: {'points': 500},
    ),
    'challenge_crusher': SeasonBadge(
      id: 'challenge_crusher',
      name: 'Challenge Crusher',
      description: 'Team completed 10+ challenges in a season',
      icon: '💥',
      color: '#E74C3C',
      points: 150,
      criteria: {'challenges': 10},
    ),
  };

  static Map<String, SeasonBadge> _allManagerSeasonBadges() {
    return {..._managerActionBadges, ..._managerPerformanceBadges};
  }

  // Create a new season
  static Future<String> createSeason({
    required String title,
    required String description,
    required String theme,
    required DateTime startDate,
    required DateTime endDate,
    String? department,
    List<SeasonChallenge> challenges = const [],
    Map<String, dynamic> settings = const {},
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No authenticated user');
      final creatorRole = await _resolveUserRole(currentUser.uid);

      final createdByName = creatorRole == 'admin'
          ? 'Admin'
          : (currentUser.displayName ?? 'Manager');
      final season = Season(
        id: '',
        title: title,
        description: description,
        theme: theme,
        status: SeasonStatus.active,
        startDate: startDate,
        endDate: endDate,
        createdAt: DateTime.now(),
        createdBy: currentUser.uid,
        createdByName: createdByName,
        department: department,
        challenges: challenges,
        participantIds: [],
        participations: {},
        metrics: SeasonMetrics(
          totalParticipants: 0,
          activeParticipants: 0,
          completedChallenges: 0,
          totalChallenges: challenges.length,
          totalPointsEarned: 0,
          averageProgress: 0.0,
          challengeCompletions: {},
          lastUpdated: DateTime.now(),
        ),
        settings: settings,
      );

      final payload = season.toMap(includeId: false);
      payload['createdByRole'] = creatorRole;
      final created = await _backend.createSeason(payload);
      final seasonId = (created['id'] ?? '').toString();
      if (seasonId.isEmpty) {
        throw Exception('Failed to create season');
      }
      final persistedSeason = season.copyWith(id: seasonId);

      // Manager-specific rewards/telemetry should only apply to manager-created seasons.
      if (creatorRole != 'admin') {
        await _awardManagerActionBadge(persistedSeason, 'season_architect');
        await _awardManagerSeasonPoints(
          season: persistedSeason,
          points: _managerSeasonCreationBonus,
          reason: 'Season created',
        );

        // Record activity
        await ManagerRealtimeService.recordEmployeeActivity(
          employeeId: currentUser.uid,
          activityType: 'season_created',
          description: 'Created season: $title',
          metadata: {'seasonId': seasonId, 'theme': theme},
        );
      }

      // Notify all employees about the new season
      await _notifyEmployeesAboutNewSeason(
        seasonId,
        title,
        theme,
        department,
        creatorRole: creatorRole,
        creatorId: currentUser.uid,
        creatorName: createdByName,
      );

      developer.log('Season created: $seasonId');
      return seasonId;
    } catch (e) {
      developer.log('Error creating season: $e');
      rethrow;
    }
  }

  static Future<String> _resolveUserRole(String uid) async {
    try {
      final userDoc = await _backend.getUser(uid);
      final role = (userDoc['role'] ?? '').toString().trim().toLowerCase();
      if (role.isNotEmpty) return role;
    } catch (_) {
      // Fall through to default.
    }
    return 'manager';
  }

  static Future<Set<String>> _getAdminUserIds({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedAdminUserIds != null &&
        _cachedAdminUserIdsAt != null &&
        now.difference(_cachedAdminUserIdsAt!).inMinutes < 5) {
      return _cachedAdminUserIds!;
    }

    try {
      final users = await _backend.listUsers(role: 'admin', limit: 500);
      _cachedAdminUserIds = users
          .map(_userIdFromMap)
          .where((id) => id.isNotEmpty)
          .toSet();      _cachedAdminUserIdsAt = now;
      return _cachedAdminUserIds!;
    } catch (e) {
      developer.log('Error loading admin user ids: $e');
      return _cachedAdminUserIds ?? <String>{};
    }
  }

  static Future<void> recomputeSeasonMetrics(String seasonId) async {
    try {
      await SeasonMetricsJob.recomputeSeasonMetrics(seasonId);
      await refreshParticipantDisplayNames(seasonId);
      developer.log('Manually recomputed metrics for season $seasonId');
    } catch (e) {
      developer.log('Error recomputing metrics for season $seasonId: $e');
      rethrow;
    }
  }

  static Future<void> refreshParticipantDisplayNames(String seasonId) async {
    try {
      final season = await _fetchSeason(seasonId);
      if (season == null) return;
      var participations = Map<String, SeasonParticipation>.from(season.participations);
      var changed = false;
      for (final entry in season.participations.entries) {
        final resolved = await _resolveUserDisplayName(
          entry.key,
          fallback: entry.value.userName,
        );
        if (resolved.trim().isEmpty || resolved == entry.value.userName) {
          continue;
        }
        participations[entry.key] = SeasonParticipation(
          userId: entry.value.userId,
          userName: resolved,
          joinedAt: entry.value.joinedAt,
          milestoneProgress: entry.value.milestoneProgress,
          challengeSubmissions: entry.value.challengeSubmissions,
          customGoals: entry.value.customGoals,
          totalPoints: entry.value.totalPoints,
          badgesEarned: entry.value.badgesEarned,
          completedChallenges: entry.value.completedChallenges,
          lastActivity: entry.value.lastActivity,
        );
        changed = true;
      }
      if (changed) {
        await _saveSeason(season.copyWith(participations: participations));
        developer.log('Refreshed participant names for season $seasonId');
      }
    } catch (e) {
      developer.log('Error refreshing participant names: $e');
    }
  }

  static Future<void> deleteSeasonAndNotify(String seasonId) async {
    try {
      final season = await getSeason(seasonId);
      if (season == null) {
        throw Exception('Season not found');
      }

      final participantIds = List<String>.from(season.participantIds);

      for (final userId in participantIds) {
        try {
          await _createSeasonAlert(
            userId: userId,
            type: AlertType.seasonCompleted,
            priority: AlertPriority.medium,
            title: 'Season Deleted',
            message:
                'The season "${season.title}" has been deleted by your manager.',
            metadata: {
              'seasonId': season.id,
              'seasonTitle': season.title,
              'action': 'deleted',
            },
          );
        } catch (_) {}
      }

      await _backend.deleteSeason(seasonId);

      try {
        await _createSeasonAlert(
          userId: season.createdBy,
          type: AlertType.seasonCompleted,
          priority: AlertPriority.medium,
          title: 'Season Deleted',
          message:
              'You deleted the season "${season.title}". Participants were notified.',
          metadata: {
            'seasonId': season.id,
            'seasonTitle': season.title,
            'action': 'deleted',
          },
        );
      } catch (_) {}
    } catch (e) {
      developer.log('Error deleting season: $e');
      rethrow;
    }
  }

  static Future<Season> _removeZeroProgressParticipants(Season season) async {
    final zeroIds = <String>[];
    season.participations.forEach((userId, p) {
      final completed = p.milestoneProgress.values
          .where((s) => _isCompletedStatus(s))
          .length;
      if (completed == 0 && p.totalPoints == 0) {
        zeroIds.add(userId);
      }
    });
    if (zeroIds.isEmpty) return season;

    final participantIds = List<String>.from(season.participantIds)
      ..removeWhere(zeroIds.contains);
    final participations = Map<String, SeasonParticipation>.from(
      season.participations,
    )..removeWhere((key, _) => zeroIds.contains(key));
    final updated = season.copyWith(
      participantIds: participantIds,
      participations: participations,
      metrics: _metricsWithLastUpdated(season.metrics),
    );
    await _saveSeason(updated);
    return updated;
  }

  // Normalize milestone status to completed boolean (handles enum or string)
  static bool _isCompletedStatus(dynamic s) {
    if (s == null) return false;
    if (s is MilestoneStatus) return s == MilestoneStatus.completed;
    if (s is String) return s == MilestoneStatus.completed.name;
    return false;
  }

  // Manager override: force complete season regardless of progress
  static Future<void> completeSeasonManagerOverride(
    String seasonId, {
    bool removeZeroProgress = true,
  }) async {
    var season = await getSeason(seasonId);
    if (season == null) throw Exception('Season not found');

    if (removeZeroProgress) {
      final beforeIds = season.participations.keys.toSet();
      season = await _removeZeroProgressParticipants(season);
      final removedIds = beforeIds.difference(season.participations.keys.toSet());
      for (final userId in removedIds) {
        await AlertService.createMotivationalAlert(
          userId: userId,
          message:
              'You were removed from the season "${season.title}" due to zero progress. Future seasons await you! 💪',
        );
      }
    }

    await updateSeasonStatus(seasonId, SeasonStatus.completed);

    final updatedSeason = await getSeason(seasonId);
    if (updatedSeason != null) {
      for (final entry in updatedSeason.participations.entries) {
        final p = entry.value;
        await AlertService.createMotivationalAlert(
          userId: p.userId,
          message:
              'Congratulations! "${updatedSeason.title}" has been completed. Great work this season! 🎉',
        );
      }
    }
  }

  // Evaluate if a season is eligible for completion and find zero-progress participants
  static Future<Map<String, dynamic>> evaluateSeasonCompletion(
    String seasonId,
  ) async {
    final season = await getSeason(seasonId);
    if (season == null) throw Exception('Season not found');

    int totalMilestones = 0;
    for (final c in season.challenges) {
      totalMilestones += c.milestones.length;
    }

    final List<String> zeroProgressIds = [];
    bool allComplete = season.participations.isNotEmpty;

    season.participations.forEach((userId, p) {
      int completed = p.milestoneProgress.values
          .where((s) => _isCompletedStatus(s))
          .length;
      final isZero = completed == 0 && (p.totalPoints == 0);
      if (isZero) zeroProgressIds.add(userId);
      if (totalMilestones > 0) {
        if (completed < totalMilestones) {
          allComplete = false;
        }
      } else {
        // No milestones configured means cannot reach 100%
        allComplete = false;
      }
    });

    return {
      'allComplete': allComplete,
      'zeroProgressIds': zeroProgressIds,
      'totalMilestones': totalMilestones,
    };
  }

  // Complete season only if eligible; remove zero-progress participants and alert them first
  static Future<void> completeSeasonIfEligible(String seasonId) async {
    final season = await getSeason(seasonId);
    if (season == null) throw Exception('Season not found');

    final result = await evaluateSeasonCompletion(seasonId);
    final List<String> zeroIds = List<String>.from(
      result['zeroProgressIds'] as List,
    );

    if (zeroIds.isNotEmpty) {
      var updated = season;
      final participantIds = List<String>.from(updated.participantIds)
        ..removeWhere(zeroIds.contains);
      final participations = Map<String, SeasonParticipation>.from(
        updated.participations,
      )..removeWhere((key, _) => zeroIds.contains(key));
      updated = updated.copyWith(
        participantIds: participantIds,
        participations: participations,
        metrics: _metricsWithLastUpdated(updated.metrics),
      );
      await _saveSeason(updated);

      for (final userId in zeroIds) {
        await AlertService.createMotivationalAlert(
          userId: userId,
          message:
              'You were removed from the season "${season.title}" due to zero progress. You can rejoin future seasons and try again!',
        );
      }
    }

    final reevaluated = await evaluateSeasonCompletion(seasonId);
    final bool allCompleteNow = reevaluated['allComplete'] as bool;

    if (!allCompleteNow) {
      throw Exception(
        'Season cannot be completed until all remaining participants reach 100%.',
      );
    }

    await updateSeasonStatus(seasonId, SeasonStatus.completed);

    final updatedSeason = await getSeason(seasonId);
    if (updatedSeason != null) {
      for (final entry in updatedSeason.participations.entries) {
        final p = entry.value;
        await AlertService.createMotivationalAlert(
          userId: p.userId,
          message:
              'Congratulations! "${updatedSeason.title}" has been completed. Great work this season! 🎉',
        );
      }

      try {
        await _createSeasonAlert(
          userId: updatedSeason.createdBy,
          type: AlertType.seasonCompleted,
          priority: AlertPriority.high,
          title: 'Season Completed 🎉',
          message:
              'Your season "${updatedSeason.title}" has been completed by all participants.',
          metadata: {
            'seasonId': updatedSeason.id,
            'seasonTitle': updatedSeason.title,
          },
        );
      } catch (_) {}
    }
  }

  // Extend a season end date
  static Future<void> extendSeason(String seasonId, DateTime newEndDate) async {
    final season = await _fetchSeason(seasonId);
    if (season == null) {
      throw Exception('Season not found');
    }
    final updated = season.copyWith(
      endDate: newEndDate,
      metrics: _metricsWithLastUpdated(season.metrics),
    );
    await _saveSeason(updated);

    await _awardManagerActionBadge(updated, 'season_guardian');
    await _awardManagerSeasonPoints(
      season: updated,
      points: _managerSeasonExtensionBonus,
      reason: 'Season extended',
    );
  }

  // Pause or resume season via settings.paused flag (non-breaking)
  static Future<void> setSeasonPaused(String seasonId, bool paused) async {
    final season = await _fetchSeason(seasonId);
    if (season == null) throw Exception('Season not found');
    await _saveSeason(
      season.copyWith(
        settings: {...season.settings, 'paused': paused},
        metrics: _metricsWithLastUpdated(season.metrics),
      ),
    );
  }

  // Get season by ID
  static Future<Season?> getSeason(String seasonId) async {
    return _fetchSeason(seasonId);
  }

  // Get a stream for a single season
  static Stream<Season> getSeasonStream(String seasonId) {
    try {
      return backendPollingStream<Season>(
        fetch: () async {
          final season = await _fetchSeason(seasonId);
          if (season == null) throw Exception('Season not found');
          return season;
        },
      );
    } catch (e) {
      developer.log('Error getting season stream: $e');
      return const Stream.empty();
    }
  }

  // Get all seasons for a manager
  static Stream<List<Season>> getManagerSeasonsStream() {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return const Stream.empty();

      return backendPollingStream<List<Season>>(
        initialValue: const [],
        fetch: () async {
          final adminIds = await _getAdminUserIds();
          final items = await _backend.getSeasons(limit: 500);
          final seasons = items
              .where((data) {
                final createdBy = (data['createdBy'] ?? '').toString();
                final createdByRole =
                    (data['createdByRole'] ??
                            (data['settings'] as Map?)?['createdByRole'] ??
                            '')
                        .toString()
                        .trim()
                        .toLowerCase();

                if (createdBy == currentUser.uid) return true;
                if (createdByRole == 'admin') return true;
                return adminIds.contains(createdBy);
              })
              .map(_seasonFromMap)
              .toList();
          seasons.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          for (final season in seasons) {
            // ignore: unawaited_futures
            refreshParticipantDisplayNames(season.id);
          }
          return seasons;
        },
      );
    } catch (e) {
      developer.log('Error getting manager seasons: $e');
      return const Stream.empty();
    }
  }

  // Get active seasons.
  // Set [includeAdminCreated] to false for employee context.
  static Stream<List<Season>> getActiveSeasonsStream({
    String? department,
    bool includeAdminCreated = true,
  }) {
    try {
      return backendPollingStream<List<Season>>(
        initialValue: const [],
        fetch: () async {
          final adminIds = includeAdminCreated
              ? const <String>{}
              : await _getAdminUserIds();
          final items = await _backend.getSeasons(
            status: SeasonStatus.active.name,
            limit: 500,
          );
          final seasons = items
              .where((data) {
                if (includeAdminCreated) return true;
                final createdBy = (data['createdBy'] ?? '').toString();
                final createdByRole =
                    (data['createdByRole'] ??
                            (data['settings'] as Map?)?['createdByRole'] ??
                            '')
                        .toString()
                        .trim()
                        .toLowerCase();
                if (createdByRole == 'admin') return false;
                return !adminIds.contains(createdBy);
              })
              .map(_seasonFromMap)
              .toList();
          seasons.sort((a, b) => b.startDate.compareTo(a.startDate));
          for (final season in seasons) {
            // ignore: unawaited_futures
            refreshParticipantDisplayNames(season.id);
          }
          return seasons;
        },
      );
    } catch (e) {
      developer.log('Error getting active seasons: $e');
      return const Stream.empty();
    }
  }
  
  /// Seasons an employee has participated in (active + completed + etc).
  /// Uses only `arrayContains` and sorts client-side to avoid composite indexes.
  static Stream<List<Season>> getParticipantSeasonsStream(
    String participantId,
  ) {
    try {
      if (participantId.trim().isEmpty) return const Stream.empty();
      return backendPollingStream<List<Season>>(
        initialValue: const [],
        fetch: () async {
          final items = await _backend.getSeasons(
            userId: participantId,
            limit: 500,
          );
          final seasons = items.map(_seasonFromMap).toList();
          seasons.sort((a, b) => b.endDate.compareTo(a.endDate));
          for (final season in seasons) {
            // ignore: unawaited_futures
            refreshParticipantDisplayNames(season.id);
          }
          return seasons;
        },
      );
    } catch (e) {
      developer.log('Error getting participant seasons: $e');
      return const Stream.empty();
    }
  }

  // Join a season
  static Future<void> joinSeason({
    required String seasonId,
    required String userId,
    required String userName,
    Map<String, dynamic> customGoals = const {},
  }) async {
    try {
      final season = await _fetchSeason(seasonId);
      if (season == null) {
        throw Exception('Season not found');
      }
      if (season.participantIds.contains(userId)) {
        return;
      }

      final resolvedName = await _resolveUserDisplayName(
        userId,
        fallback: userName,
      );

      final participation = SeasonParticipation(
        userId: userId,
        userName: resolvedName,
        joinedAt: DateTime.now(),
        milestoneProgress: {},
        challengeSubmissions: const {},
        customGoals: customGoals,
        totalPoints: 0,
        badgesEarned: [],
        completedChallenges: 0,
      );

      final updatedMetrics = SeasonMetrics(
        totalParticipants: season.participantIds.length + 1,
        activeParticipants: season.metrics.activeParticipants + 1,
        completedChallenges: season.metrics.completedChallenges,
        totalChallenges: season.metrics.totalChallenges,
        totalPointsEarned: season.metrics.totalPointsEarned,
        averageProgress: season.metrics.averageProgress,
        challengeCompletions: season.metrics.challengeCompletions,
        lastUpdated: DateTime.now(),
        totalTeamPoints: season.metrics.totalTeamPoints,
        completedTeamChallenges: season.metrics.completedTeamChallenges,
        managerBadgesEarned: season.metrics.managerBadgesEarned,
        managerPointsEarned: season.metrics.managerPointsEarned,
      );

      final updatedSeason = season.copyWith(
        participantIds: [...season.participantIds, userId],
        participations: {
          ...season.participations,
          userId: participation,
        },
        metrics: updatedMetrics,
      );
      await _saveSeason(updatedSeason);

      await _createSeasonGoalsForEmployee(updatedSeason, userId, userName);

      await ManagerRealtimeService.recordEmployeeActivity(
        employeeId: userId,
        activityType: 'season_joined',
        description: 'Joined season: ${updatedSeason.title}',
        metadata: {'seasonId': seasonId, 'seasonTitle': updatedSeason.title},
      );

      await _createSeasonAlert(
        userId: updatedSeason.createdBy,
        type: AlertType.seasonJoined,
        priority: AlertPriority.medium,
        title: 'Employee Joined Season',
        message: '$userName joined the season "${updatedSeason.title}"',
        actionText: 'View Season',
        actionRoute: '/team_challenges_seasons',
        metadata: {
          'seasonId': seasonId,
          'seasonTitle': updatedSeason.title,
          'employeeId': userId,
          'employeeName': userName,
        },
      );

      developer.log('User $userId joined season $seasonId');
    } catch (e) {
      developer.log('Error joining season: $e');
      rethrow;
    }
  }

  // Update milestone progress
  static Future<void> updateMilestoneProgress({
    required String seasonId,
    required String userId,
    required String milestoneId,
    required MilestoneStatus status,
    bool notifyManager = true,
    bool syncGoalProgress = true,
  }) async {
    try {
      final season = await _fetchSeason(seasonId);
      if (season == null) {
        throw Exception('Season not found');
      }
      final participation = season.participations[userId];
      if (participation == null) {
        throw Exception('Participation not found');
      }

      String? dottedMilestoneKey;
      for (final challenge in season.challenges) {
        final hasMilestone = challenge.milestones.any((m) => m.id == milestoneId);
        if (hasMilestone) {
          dottedMilestoneKey = '${challenge.id}.$milestoneId';
          break;
        }
      }
      final currentStatus =
          (dottedMilestoneKey != null
              ? participation.milestoneProgress[dottedMilestoneKey]
              : null) ??
          participation.milestoneProgress[milestoneId];
      if (currentStatus == status) {
        return;
      }

      var milestoneProgress = Map<String, MilestoneStatus>.from(
        participation.milestoneProgress,
      );
      milestoneProgress[milestoneId] = status;

      var updatedParticipation = SeasonParticipation(
        userId: participation.userId,
        userName: participation.userName,
        joinedAt: participation.joinedAt,
        milestoneProgress: milestoneProgress,
        challengeSubmissions: participation.challengeSubmissions,
        customGoals: participation.customGoals,
        totalPoints: participation.totalPoints,
        badgesEarned: participation.badgesEarned,
        completedChallenges: participation.completedChallenges,
        lastActivity: DateTime.now(),
      );

      var metrics = season.metrics;
      SeasonMilestone? completedMilestone;
      SeasonChallenge? parentChallenge;

      if (status == MilestoneStatus.completed) {
        for (final challenge in season.challenges) {
          for (final milestone in challenge.milestones) {
            if (milestone.id == milestoneId) {
              completedMilestone = milestone;
              parentChallenge = challenge;
              break;
            }
          }
          if (completedMilestone != null) break;
        }

        if (completedMilestone != null && parentChallenge != null) {
          final challengeCompletions = Map<ChallengeType, int>.from(
            metrics.challengeCompletions,
          );
          challengeCompletions[parentChallenge.type] =
              (challengeCompletions[parentChallenge.type] ?? 0) + 1;

          var completedChallenges = metrics.completedChallenges;
          var participantCompletedChallenges =
              updatedParticipation.completedChallenges;
          if (_didNewlyCompleteChallenge(
            participation: participation,
            challenge: parentChallenge,
            newlyCompletedMilestones: {milestoneId},
          )) {
            completedChallenges += 1;
            participantCompletedChallenges += 1;
          }

          updatedParticipation = SeasonParticipation(
            userId: updatedParticipation.userId,
            userName: updatedParticipation.userName,
            joinedAt: updatedParticipation.joinedAt,
            milestoneProgress: updatedParticipation.milestoneProgress,
            challengeSubmissions: updatedParticipation.challengeSubmissions,
            customGoals: updatedParticipation.customGoals,
            totalPoints:
                updatedParticipation.totalPoints + completedMilestone.points,
            badgesEarned: updatedParticipation.badgesEarned,
            completedChallenges: participantCompletedChallenges,
            lastActivity: updatedParticipation.lastActivity,
          );

          metrics = SeasonMetrics(
            totalParticipants: metrics.totalParticipants,
            activeParticipants: metrics.activeParticipants,
            completedChallenges: completedChallenges,
            totalChallenges: metrics.totalChallenges,
            totalPointsEarned:
                metrics.totalPointsEarned + completedMilestone.points,
            averageProgress: metrics.averageProgress,
            challengeCompletions: challengeCompletions,
            lastUpdated: DateTime.now(),
            totalTeamPoints: metrics.totalTeamPoints,
            completedTeamChallenges: metrics.completedTeamChallenges,
            managerBadgesEarned: metrics.managerBadgesEarned,
            managerPointsEarned: metrics.managerPointsEarned,
          );
        }
      }

      final updatedSeason = season.copyWith(
        participations: {
          ...season.participations,
          userId: updatedParticipation,
        },
        metrics: metrics,
      );
      await _saveSeason(updatedSeason);

      if (status == MilestoneStatus.completed &&
          completedMilestone != null &&
          parentChallenge != null) {
        if (syncGoalProgress) {
          await _updateEmployeeGoalProgress(
            userId: userId,
            seasonId: seasonId,
            challengeId: completedMilestone.challengeId,
            milestoneId: milestoneId,
            points: completedMilestone.points,
          );
        }

        await _checkAndAwardBadges(updatedSeason, userId);
        await _updateTeamMetricsAndCheckManagerBadges(
          updatedSeason,
          completedMilestone.points,
        );

        final participantName =
            updatedSeason.participations[userId]?.userName ?? 'Employee';
        if (notifyManager) {
          await _createSeasonAlert(
            userId: updatedSeason.createdBy,
            type: AlertType.seasonProgressUpdate,
            priority: AlertPriority.low,
            title: 'Milestone Completed',
            message:
                '$participantName completed "${completedMilestone.title}" in "${updatedSeason.title}".',
            metadata: {
              'seasonId': updatedSeason.id,
              'seasonTitle': updatedSeason.title,
              'employeeId': userId,
              'employeeName': participantName,
              'milestoneId': milestoneId,
              'milestoneTitle': completedMilestone.title,
            },
          );
        }
      }

      await ManagerRealtimeService.recordEmployeeActivity(
        employeeId: userId,
        activityType: 'milestone_updated',
        description: 'Updated milestone: $milestoneId',
        metadata: {
          'seasonId': seasonId,
          'milestoneId': milestoneId,
          'status': status.name,
        },
      );

      developer.log('Updated milestone $milestoneId for user $userId');
    } catch (e) {
      developer.log('Error updating milestone progress: $e');
      rethrow;
    }
  }

  static Future<void> submitChallengeProof({
    required String seasonId,
    required String userId,
    required String challengeId,
    required String evidence,
  }) async {
    final trimmedEvidence = evidence.trim();
    if (trimmedEvidence.isEmpty) {
      throw Exception('Please provide a certificate link, screenshot link, or note.');
    }

    try {
      final season = await getSeason(seasonId);
      if (season == null) throw Exception('Season not found');
      final challenge = _findChallengeById(season, challengeId);
      if (challenge == null) throw Exception('Challenge not found');
      if (!challenge.proofRequired) {
        throw Exception('This challenge does not require proof.');
      }

      final participation = season.participations[userId];
      if (participation == null) {
        throw Exception('Participation not found');
      }

      final submission = SeasonChallengeSubmission(
        challengeId: challengeId,
        evidence: trimmedEvidence,
        status: ChallengeSubmissionStatus.submitted,
        submittedBy: userId,
        submittedAt: DateTime.now(),
      );

      var milestoneProgress = Map<String, MilestoneStatus>.from(
        participation.milestoneProgress,
      );
      final reviewMilestone = _managerReviewMilestoneForChallenge(challenge);
      if (reviewMilestone != null) {
        milestoneProgress[reviewMilestone.id] = MilestoneStatus.inProgress;
      }

      final updatedParticipation = SeasonParticipation(
        userId: participation.userId,
        userName: participation.userName,
        joinedAt: participation.joinedAt,
        milestoneProgress: milestoneProgress,
        challengeSubmissions: {
          ...participation.challengeSubmissions,
          challengeId: submission,
        },
        customGoals: participation.customGoals,
        totalPoints: participation.totalPoints,
        badgesEarned: participation.badgesEarned,
        completedChallenges: participation.completedChallenges,
        lastActivity: DateTime.now(),
      );

      await _saveSeason(
        season.copyWith(
          participations: {
            ...season.participations,
            userId: updatedParticipation,
          },
        ),
      );

      final participantName =
          season.participations[userId]?.userName ?? 'Employee';
      await _createSeasonAlert(
        userId: season.createdBy,
        type: AlertType.seasonProgressUpdate,
        priority: AlertPriority.medium,
        title: 'Course Proof Submitted',
        message:
            '$participantName submitted ${challenge.proofType ?? 'learning proof'} for "${challenge.title}".',
        actionText: 'Review Submission',
        actionRoute: '/team_challenges_seasons',
        metadata: {
          'seasonId': season.id,
          'seasonTitle': season.title,
          'challengeId': challenge.id,
          'challengeTitle': challenge.title,
          'employeeId': userId,
          'employeeName': participantName,
          'submissionStatus': ChallengeSubmissionStatus.submitted.name,
        },
      );

      await ManagerRealtimeService.recordEmployeeActivity(
        employeeId: userId,
        activityType: 'season_proof_submitted',
        description: 'Submitted proof for ${challenge.title}',
        metadata: {
          'seasonId': seasonId,
          'challengeId': challengeId,
          'proofType': challenge.proofType,
        },
      );
    } catch (e) {
      developer.log('Error submitting challenge proof: $e');
      rethrow;
    }
  }

  static Future<void> reviewChallengeProof({
    required String seasonId,
    required String employeeId,
    required String challengeId,
    required bool approved,
    String? feedback,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('No authenticated user');

      final season = await getSeason(seasonId);
      if (season == null) throw Exception('Season not found');
      final challenge = _findChallengeById(season, challengeId);
      if (challenge == null) throw Exception('Challenge not found');

      final submission =
          season.participations[employeeId]?.challengeSubmissions[challengeId];
      if (submission == null ||
          submission.status != ChallengeSubmissionStatus.submitted) {
        throw Exception('No pending proof submission found.');
      }

      final participation = season.participations[employeeId];
      if (participation == null) {
        throw Exception('Participation not found');
      }

      final updatedSubmission = SeasonChallengeSubmission(
        challengeId: submission.challengeId,
        evidence: submission.evidence,
        status: approved
            ? ChallengeSubmissionStatus.approved
            : ChallengeSubmissionStatus.rejected,
        submittedBy: submission.submittedBy,
        submittedAt: submission.submittedAt,
        feedback: feedback?.trim().isNotEmpty == true ? feedback!.trim() : null,
        reviewedBy: currentUser.uid,
        reviewedAt: DateTime.now(),
      );

      var milestoneProgress = Map<String, MilestoneStatus>.from(
        participation.milestoneProgress,
      );
      final reviewMilestone = _managerReviewMilestoneForChallenge(challenge);
      if (!approved && reviewMilestone != null) {
        milestoneProgress[reviewMilestone.id] = MilestoneStatus.notStarted;
      }

      final updatedParticipation = SeasonParticipation(
        userId: participation.userId,
        userName: participation.userName,
        joinedAt: participation.joinedAt,
        milestoneProgress: milestoneProgress,
        challengeSubmissions: {
          ...participation.challengeSubmissions,
          challengeId: updatedSubmission,
        },
        customGoals: participation.customGoals,
        totalPoints: participation.totalPoints,
        badgesEarned: participation.badgesEarned,
        completedChallenges: participation.completedChallenges,
        lastActivity: DateTime.now(),
      );

      await _saveSeason(
        season.copyWith(
          participations: {
            ...season.participations,
            employeeId: updatedParticipation,
          },
        ),
      );

      if (approved && reviewMilestone != null) {
        await updateMilestoneProgress(
          seasonId: seasonId,
          userId: employeeId,
          milestoneId: reviewMilestone.id,
          status: MilestoneStatus.completed,
          notifyManager: false,
        );
      }

      await _createSeasonAlert(
        userId: employeeId,
        type: approved
            ? AlertType.seasonProgressUpdate
            : AlertType.managerGeneral,
        priority: approved ? AlertPriority.medium : AlertPriority.high,
        title: approved ? 'Learning Proof Approved' : 'Learning Proof Needs Updates',
        message: approved
            ? 'Your submission for "${challenge.title}" was approved.'
            : 'Your submission for "${challenge.title}" was sent back for updates.',
        actionText: 'View Season',
        actionRoute: '/season_challenges',
        metadata: {
          'seasonId': season.id,
          'seasonTitle': season.title,
          'challengeId': challenge.id,
          'challengeTitle': challenge.title,
          'reviewStatus': approved
              ? ChallengeSubmissionStatus.approved.name
              : ChallengeSubmissionStatus.rejected.name,
          if (feedback?.trim().isNotEmpty == true) 'feedback': feedback!.trim(),
        },
      );
    } catch (e) {
      developer.log('Error reviewing challenge proof: $e');
      rethrow;
    }
  }

  static Future<void> _awardManagerActionBadge(
    Season season,
    String badgeId,
  ) async {
    try {
      final badge = _managerActionBadges[badgeId];
      if (badge == null) return;
      final managerId = season.createdBy;
      if (managerId.isEmpty) return;
      if (season.metrics.managerBadgesEarned.contains(badgeId)) {
        return;
      }

      final updatedBadges = [...season.metrics.managerBadgesEarned, badgeId];
      final updatedSeason = season.copyWith(
        metrics: SeasonMetrics(
          totalParticipants: season.metrics.totalParticipants,
          activeParticipants: season.metrics.activeParticipants,
          completedChallenges: season.metrics.completedChallenges,
          totalChallenges: season.metrics.totalChallenges,
          totalPointsEarned: season.metrics.totalPointsEarned,
          averageProgress: season.metrics.averageProgress,
          challengeCompletions: season.metrics.challengeCompletions,
          lastUpdated: DateTime.now(),
          totalTeamPoints: season.metrics.totalTeamPoints,
          completedTeamChallenges: season.metrics.completedTeamChallenges,
          managerBadgesEarned: updatedBadges,
          managerPointsEarned: season.metrics.managerPointsEarned,
        ),
      );
      await _saveSeason(updatedSeason);

      await _syncBadgeWithEmployeeSystem(
        managerId,
        badge,
        updatedSeason,
        isManager: true,
      );
    } catch (e) {
      developer.log('Error awarding manager action badge $badgeId: $e');
    }
  }

  static Future<void> _awardManagerSeasonPoints({
    required Season season,
    required int points,
    String reason = '',
    bool logActivity = true,
  }) async {
    if (points <= 0) return;
    final managerId = season.createdBy;
    if (managerId.isEmpty) return;

    try {
      final updatedSeason = season.copyWith(
        metrics: SeasonMetrics(
          totalParticipants: season.metrics.totalParticipants,
          activeParticipants: season.metrics.activeParticipants,
          completedChallenges: season.metrics.completedChallenges,
          totalChallenges: season.metrics.totalChallenges,
          totalPointsEarned: season.metrics.totalPointsEarned,
          averageProgress: season.metrics.averageProgress,
          challengeCompletions: season.metrics.challengeCompletions,
          lastUpdated: DateTime.now(),
          totalTeamPoints: season.metrics.totalTeamPoints,
          completedTeamChallenges: season.metrics.completedTeamChallenges,
          managerBadgesEarned: season.metrics.managerBadgesEarned,
          managerPointsEarned: season.metrics.managerPointsEarned + points,
        ),
      );
      await _saveSeason(updatedSeason);

      final currentUid = _auth.currentUser?.uid;
      if (currentUid == managerId) {
        final userDoc = await _backend.getUser(managerId);
        final currentTotal = _asInt(userDoc['totalPoints']);
        final currentManagerSeasonPoints = _asInt(userDoc['managerSeasonPoints']);
        await _backend.updateUserProfile(managerId, {
          'totalPoints': currentTotal + points,
          'managerSeasonPoints': currentManagerSeasonPoints + points,
        });
      }

      if (logActivity) {
        final description = reason.isNotEmpty
            ? 'Earned $points pts · $reason'
            : 'Earned $points manager season pts';
        await ManagerRealtimeService.recordEmployeeActivity(
          employeeId: managerId,
          activityType: 'manager_season_points',
          description: description,
          metadata: {
            'seasonId': season.id,
            'seasonTitle': season.title,
            'points': points,
            if (reason.isNotEmpty) 'reason': reason,
          },
        );
      }
    } catch (e) {
      developer.log('Error awarding manager season points: $e');
    }
  }

  /// Reconcile/sync the manager's season points into their own `users/{uid}` document.
  /// Needed because employee milestone updates should not write to the manager's user doc
  /// in all sessions, but the manager still "earns" points via season metrics.
  static Future<void> syncCurrentManagerSeasonPoints() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      final managerId = currentUser.uid;

      final items = await _backend.getSeasons(limit: 500);
      var computedTotal = 0;
      for (final data in items) {
        if ((data['createdBy'] ?? '').toString() != managerId) continue;
        final metrics = (data['metrics'] as Map<String, dynamic>?) ?? {};
        computedTotal += _asInt(metrics['managerPointsEarned']);
      }

      final userDoc = await _backend.getUser(managerId);
      final currentManagerSeasonPoints = _asInt(userDoc['managerSeasonPoints']);
      final delta = computedTotal - currentManagerSeasonPoints;
      if (delta == 0) return;

      await _backend.updateUserProfile(managerId, {
        'managerSeasonPoints': computedTotal,
        'totalPoints': _asInt(userDoc['totalPoints']) + delta,
      });

      developer.log(
        'Synced managerSeasonPoints for $managerId: $currentManagerSeasonPoints -> $computedTotal (delta $delta)',
      );
    } catch (e) {
      developer.log('Error syncing manager season points: $e');
    }
  }

  /// Reconcile/sync an employee's season challenge points into their user profile.
  /// This sums participation points from completed seasons and applies the delta
  /// to `users/{uid}.totalPoints`, storing the season subtotal in `seasonChallengePoints`.
  static Future<void> syncCurrentEmployeeSeasonPoints() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      final userId = currentUser.uid;

      final items = await _backend.getSeasons(userId: userId, limit: 500);
      var computedTotal = 0;
      for (final data in items) {
        final season = _seasonFromMap(data);
        if (season.status != SeasonStatus.completed) continue;
        final participation = season.participations[userId];
        if (participation == null) continue;
        computedTotal += participation.totalPoints;
      }

      final userDoc = await _backend.getUser(userId);
      final currentSeasonPoints = _asInt(userDoc['seasonChallengePoints']);
      final delta = computedTotal - currentSeasonPoints;
      if (delta <= 0) return;

      await _backend.updateUserProfile(userId, {
        'seasonChallengePoints': computedTotal,
        'totalPoints': _asInt(userDoc['totalPoints']) + delta,
      });

      developer.log(
        'Synced season challenge points for $userId: $currentSeasonPoints -> $computedTotal (delta $delta)',
      );
    } catch (e) {
      developer.log('Error syncing employee season points: $e');
    }
  }

  /// Ensure manager season badges earned (tracked on seasons) are written to
  /// `users/{managerId}/badges` and their badge points applied to the manager profile.
  ///
  /// Reason: employees can update season metrics but cannot write to a manager's
  /// user subcollections due to security rules.
  static Future<void> syncCurrentManagerSeasonBadges() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      final managerId = currentUser.uid;

      final items = await _backend.getSeasons(limit: 500);
      final managerSeasons = items
          .where((data) => (data['createdBy'] ?? '').toString() == managerId)
          .toList();
      if (managerSeasons.isEmpty) return;

      final catalog = _allManagerSeasonBadges();
      final existingBadges = await _backend.getBadges(managerId, limit: 500);
      final earnedBadgeIds = existingBadges
          .where((badge) => badge['isEarned'] == true)
          .map((badge) => (badge['id'] ?? badge['badgeId'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      var awardedCount = 0;
      final userDoc = await _backend.getUser(managerId);
      var totalPoints = _asInt(userDoc['totalPoints']);
      var totalBadges = _asInt(userDoc['totalBadges']);

      for (final seasonData in managerSeasons) {
        final seasonId = (seasonData['id'] ?? '').toString();
        final seasonTitle = (seasonData['title'] ?? '').toString();
        final metrics = (seasonData['metrics'] as Map<String, dynamic>?) ?? {};
        final earned = (metrics['managerBadgesEarned'] as List<dynamic>?) ?? [];

        for (final raw in earned) {
          if (raw is! String || raw.trim().isEmpty) continue;
          final badgeId = raw.trim();
          final badge = catalog[badgeId];
          if (badge == null) continue;

          final userBadgeId = '${badgeId}_$seasonId';
          if (earnedBadgeIds.contains(userBadgeId)) {
            await _backend.patchBadge(managerId, userBadgeId, {
              'category': 'achievement',
            });
            continue;
          }

          var managerLevel = 4;
          switch (badgeId) {
            case 'season_guardian':
              managerLevel = 2;
              break;
            case 'season_architect':
              managerLevel = 3;
              break;
            case 'season_closer':
              managerLevel = 4;
              break;
            case 'team_builder':
              managerLevel = 3;
              break;
            case 'momentum_maker':
              managerLevel = 4;
              break;
            case 'challenge_crusher':
              managerLevel = 4;
              break;
          }

          await _backend.upsertBadge(managerId, userBadgeId, {
            'name': badge.name,
            'description': '${badge.description} - $seasonTitle',
            'iconName': 'emoji_events',
            'category': 'achievement',
            'rarity': 'common',
            'pointsRequired': badge.points,
            'criteria': {
              'source': 'season',
              'seasonId': seasonId,
              'seasonTitle': seasonTitle,
              'isManager': true,
              'managerLevel': managerLevel,
              'badgeId': badgeId,
            },
            'earnedAt': DateTime.now().toIso8601String(),
            'isEarned': true,
            'progress': 1,
            'maxProgress': 1,
          });

          totalPoints += badge.points;
          totalBadges += 1;
          awardedCount++;
          earnedBadgeIds.add(userBadgeId);
        }
      }

      if (awardedCount > 0) {
        await _backend.updateUserProfile(managerId, {
          'totalPoints': totalPoints,
          'totalBadges': totalBadges,
        });
        await BadgeService.updateUserBadgeSummary(managerId);
        developer.log(
          'Synced $awardedCount manager season badges for $managerId',
        );
      }
    } catch (e) {
      developer.log('Error syncing manager season badges: $e');
    }
  }

  /// Payout season-earned points into the current user's global `users/{uid}.totalPoints`
  /// once a season is completed.
  ///
  /// - Employees accumulate points inside `seasons/{seasonId}.participations.{uid}.totalPoints`
  ///   while doing season milestones.
  /// - When the season is completed, each participant should receive those points in their
  ///   global total (Badges & Points screen).
  /// - Managers cannot write to employee user docs due to security rules, so each user
  ///   claims their own payout (idempotent) and marks it in the season doc.
  static Future<void> syncCurrentUserSeasonPayouts() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;
      final uid = currentUser.uid;
      if (uid.trim().isEmpty) return;

      final items = await _backend.getSeasons(userId: uid, limit: 500);
      if (items.isEmpty) return;

      for (final seasonData in items) {
        final seasonId = (seasonData['id'] ?? '').toString();
        if (seasonId.isEmpty) continue;
        if ((seasonData['status'] ?? '').toString() !=
            SeasonStatus.completed.name) {
          continue;
        }

        final participations =
            Map<String, dynamic>.from(seasonData['participations'] ?? {});
        final myPart = Map<String, dynamic>.from(participations[uid] ?? {});
        if (myPart.isEmpty) continue;
        if (myPart['payoutApplied'] == true) continue;

        final points = _asInt(myPart['totalPoints']);
        if (points <= 0) {
          participations[uid] = {
            ...myPart,
            'payoutApplied': true,
            'payoutAppliedAt': DateTime.now().toIso8601String(),
            'payoutPoints': 0,
          };
          try {
            await _backend.patchSeason(seasonId, {
              'participations': participations,
            });
          } catch (_) {}
          continue;
        }

        final freshSeason = await _backend.getSeason(seasonId);
        final freshParts = Map<String, dynamic>.from(
          freshSeason['participations'] ?? {},
        );
        final freshMyPart = Map<String, dynamic>.from(freshParts[uid] ?? {});
        if (freshMyPart.isEmpty || freshMyPart['payoutApplied'] == true) {
          continue;
        }

        final myPts = _asInt(freshMyPart['totalPoints']);
        if (myPts <= 0) continue;

        final userDoc = await _backend.getUser(uid);
        await _backend.updateUserProfile(uid, {
          'totalPoints': _asInt(userDoc['totalPoints']) + myPts,
        });

        freshParts[uid] = {
          ...freshMyPart,
          'payoutApplied': true,
          'payoutAppliedAt': DateTime.now().toIso8601String(),
          'payoutPoints': myPts,
        };
        await _backend.patchSeason(seasonId, {'participations': freshParts});
      }
    } catch (e) {
      developer.log('Error syncing season payouts for current user: $e');
    }
  }

  // Check and award badges for managers
  static Future<void> _checkAndAwardManagerBadges(Season season) async {
    try {
      final managerId = season.createdBy;
      final metrics = season.metrics;
      final earnedBadgeIds = metrics.managerBadgesEarned.toSet();

      for (final badge in _managerPerformanceBadges.values) {
        if (!earnedBadgeIds.contains(badge.id)) {
          bool shouldAward = false;
          if (badge.criteria.containsKey('participants')) {
            shouldAward =
                metrics.totalParticipants >= badge.criteria['participants'];
          } else if (badge.criteria.containsKey('points')) {
            shouldAward = metrics.totalTeamPoints >= badge.criteria['points'];
          } else if (badge.criteria.containsKey('challenges')) {
            shouldAward =
                metrics.completedTeamChallenges >= badge.criteria['challenges'];
          }

          if (shouldAward) {
            final updatedBadges = [...metrics.managerBadgesEarned, badge.id];
            final updatedSeason = season.copyWith(
              metrics: SeasonMetrics(
                totalParticipants: metrics.totalParticipants,
                activeParticipants: metrics.activeParticipants,
                completedChallenges: metrics.completedChallenges,
                totalChallenges: metrics.totalChallenges,
                totalPointsEarned: metrics.totalPointsEarned,
                averageProgress: metrics.averageProgress,
                challengeCompletions: metrics.challengeCompletions,
                lastUpdated: DateTime.now(),
                totalTeamPoints: metrics.totalTeamPoints,
                completedTeamChallenges: metrics.completedTeamChallenges,
                managerBadgesEarned: updatedBadges,
                managerPointsEarned: metrics.managerPointsEarned,
              ),
            );
            await _saveSeason(updatedSeason);

            if (_auth.currentUser?.uid == managerId) {
              await _syncBadgeWithEmployeeSystem(
                managerId,
                badge,
                updatedSeason,
                isManager: true,
              );
            }
          }
        }
      }
    } catch (e) {
      developer.log('Error checking manager badges: $e');
    }
  }

  // Update team metrics and check for manager badges
  static Future<void> _updateTeamMetricsAndCheckManagerBadges(
    Season season,
    int pointsAwarded,
  ) async {
    try {
      final updatedSeason = season.copyWith(
        metrics: SeasonMetrics(
          totalParticipants: season.metrics.totalParticipants,
          activeParticipants: season.metrics.activeParticipants,
          completedChallenges: season.metrics.completedChallenges,
          totalChallenges: season.metrics.totalChallenges,
          totalPointsEarned: season.metrics.totalPointsEarned,
          averageProgress: season.metrics.averageProgress,
          challengeCompletions: season.metrics.challengeCompletions,
          lastUpdated: DateTime.now(),
          totalTeamPoints: season.metrics.totalTeamPoints + pointsAwarded,
          completedTeamChallenges:
              season.metrics.completedTeamChallenges + 1,
          managerBadgesEarned: season.metrics.managerBadgesEarned,
          managerPointsEarned: season.metrics.managerPointsEarned,
        ),
      );
      await _saveSeason(updatedSeason);

      if (pointsAwarded > 0) {
        await _awardManagerSeasonPoints(
          season: updatedSeason,
          points: pointsAwarded,
          reason: 'Team milestone progress',
          logActivity: false,
        );
      }

      final latestSeason = await _fetchSeason(updatedSeason.id);
      if (latestSeason == null) return;
      await _checkAndAwardManagerBadges(latestSeason);
    } catch (e) {
      developer.log('Error updating team metrics: $e');
    }
  }

  // Sync season badge with employee's main badge system
  static Future<void> _syncBadgeWithEmployeeSystem(
    String userId,
    SeasonBadge seasonBadge,
    Season season, {
    bool isManager = false,
  }) async {
    try {
      final userBadgeId = '${seasonBadge.id}_${season.id}';

      var managerLevel = 4;
      switch (seasonBadge.id) {
        case 'season_guardian':
          managerLevel = 2;
          break;
        case 'season_architect':
          managerLevel = 3;
          break;
        case 'season_closer':
          managerLevel = 4;
          break;
        default:
          managerLevel = 4;
      }

      await _backend.upsertBadge(userId, userBadgeId, {
        'name': seasonBadge.name,
        'description': '${seasonBadge.description} - ${season.title}',
        'iconName': 'emoji_events',
        'category': isManager ? 'leadership' : 'achievement',
        'rarity': 'common',
        'pointsRequired': seasonBadge.points,
        'criteria': {
          'source': 'season',
          'seasonId': season.id,
          'seasonTitle': season.title,
          'isManager': isManager,
          'managerLevel': managerLevel,
          'badgeId': seasonBadge.id,
        },
        'earnedAt': DateTime.now().toIso8601String(),
        'isEarned': true,
        'progress': 1,
        'maxProgress': 1,
      });

      final userDoc = await _backend.getUser(userId);
      await _backend.updateUserProfile(userId, {
        'totalPoints': _asInt(userDoc['totalPoints']) + seasonBadge.points,
        'totalBadges': _asInt(userDoc['totalBadges']) + 1,
      });

      await AlertService.createBadgeAlert(
        userId: userId,
        badgeName: seasonBadge.name,
        isManager: isManager,
      );

      await BadgeService.updateUserBadgeSummary(userId);

      developer.log(
        'Synced season badge ${seasonBadge.name} with employee system for user $userId',
      );
    } catch (e) {
      developer.log('Error syncing badge with employee system: $e');
    }
  }

  // Allow employee to mark season goal as complete
  static Future<void> completeSeasonGoal({
    required String goalId,
    required String userId,
    String? evidence,
  }) async {
    try {
      final goals = await _backend.getGoals(goalId: goalId, limit: 1);
      if (goals.isEmpty) {
        throw Exception('Goal not found');
      }

      final goalData = goals.first;

      // Verify this is a season goal and belongs to the user
      if (goalData['userId'] != userId || goalData['isSeasonGoal'] != true) {
        throw Exception('Unauthorized to complete this goal');
      }

      final String? seasonId = goalData['seasonId'] is String
          ? goalData['seasonId'] as String
          : null;
      final String? challengeId = goalData['challengeId'] is String
          ? goalData['challengeId'] as String
          : null;
      final int points = goalData['points'] is int
          ? goalData['points'] as int
          : int.tryParse('${goalData['points'] ?? 0}') ?? 0;

      // Update goal status
      await _backend.patchGoal(goalId, {
        'status': 'completed',
        'progress': 100,
        'completedAt': DateTime.now().toIso8601String(),
        'evidence': evidence,
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      // Do NOT update global user points for season goals.
      // Points are awarded within the season participation via milestone completion.

      // Update season milestone progress if this is a challenge goal
      if (challengeId != null && seasonId != null) {
        await _updateSeasonMilestoneFromGoal(
          seasonId,
          userId,
          challengeId,
          goalId,
        );
      } else {
        throw Exception('Goal is missing seasonId or challengeId.');
      }

      // Check if season should be completed (seasonId is non-null here due to prior throw)
      await _checkSeasonCompletion(seasonId, userId);

      // Create alert for goal completion
      await AlertService.createMotivationalAlert(
        userId: userId,
        message:
            'Congratulations! You completed "${goalData['title']}" and earned $points points!',
      );

      // Notify manager about employee goal completion
      await _notifyManagerAboutGoalCompletion(
        seasonId,
        userId,
        goalData['title'],
      );

      developer.log('Employee $userId completed season goal $goalId');
    } catch (e, st) {
      developer.log('Error completing season goal: $e', stackTrace: st);
      rethrow;
    }
  }

  static Future<void> finalizeApprovedSeasonGoal({
    required String goalId,
  }) async {
    try {
      final goals = await _backend.getGoals(goalId: goalId, limit: 1);
      if (goals.isEmpty) {
        throw Exception('Goal not found');
      }

      final goalData = goals.first;
      if (goalData['isSeasonGoal'] != true) {
        throw Exception('Goal is not a season goal');
      }
      if (goalData['seasonCompletionFinalizedAt'] != null) {
        return;
      }

      final String? seasonId = goalData['seasonId'] is String
          ? goalData['seasonId'] as String
          : null;
      final String? challengeId = goalData['challengeId'] is String
          ? goalData['challengeId'] as String
          : null;
      final String userId = (goalData['userId'] ?? '').toString();
      if (seasonId == null ||
          seasonId.isEmpty ||
          challengeId == null ||
          challengeId.isEmpty ||
          userId.isEmpty) {
        throw Exception('Goal is missing season identifiers.');
      }

      await _backend.patchGoal(goalId, {
        'seasonCompletionFinalizedAt': DateTime.now().toIso8601String(),
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      await _updateSeasonMilestoneFromGoal(seasonId, userId, challengeId, goalId);
      await _checkSeasonCompletion(seasonId, userId);
    } catch (e, st) {
      developer.log('Error finalizing approved season goal: $e', stackTrace: st);
      rethrow;
    }
  }

  // Update season milestone progress when goal is completed
  static Future<void> _updateSeasonMilestoneFromGoal(
    String seasonId,
    String userId,
    String challengeId,
    String goalId,
  ) async {
    try {
      if (seasonId.isEmpty || userId.isEmpty || challengeId.isEmpty) {
        throw Exception('Invalid identifiers for milestone update');
      }
      final season = await getSeason(seasonId);
      if (season == null) return;

      // Find the challenge and mark all its milestones as completed
      final challenge = season.challenges.firstWhere(
        (c) => c.id == challengeId,
        orElse: () => throw Exception('Challenge not found'),
      );

      final newlyCompletedMilestoneIds = challenge.milestones
          .map((m) => m.id)
          .toSet();

      final totalMilestonePoints = challenge.milestones.fold<int>(
        0,
        (acc, m) => acc + m.points,
      );

      final participation = season.participations[userId];
      if (participation == null) return;

      final milestoneProgress = Map<String, MilestoneStatus>.from(
        participation.milestoneProgress,
      );
      for (final milestone in challenge.milestones) {
        milestoneProgress[milestone.id] = MilestoneStatus.completed;
      }

      var participantCompletedChallenges = participation.completedChallenges;
      var completedChallenges = season.metrics.completedChallenges;
      if (_didNewlyCompleteChallenge(
        participation: participation,
        challenge: challenge,
        newlyCompletedMilestones: newlyCompletedMilestoneIds,
      )) {
        participantCompletedChallenges += 1;
        completedChallenges += 1;
      }

      final challengeCompletions = Map<ChallengeType, int>.from(
        season.metrics.challengeCompletions,
      );
      challengeCompletions[challenge.type] =
          (challengeCompletions[challenge.type] ?? 0) +
          challenge.milestones.length;

      final updatedParticipation = SeasonParticipation(
        userId: participation.userId,
        userName: participation.userName,
        joinedAt: participation.joinedAt,
        milestoneProgress: milestoneProgress,
        challengeSubmissions: participation.challengeSubmissions,
        customGoals: participation.customGoals,
        totalPoints: participation.totalPoints + totalMilestonePoints,
        badgesEarned: participation.badgesEarned,
        completedChallenges: participantCompletedChallenges,
        lastActivity: DateTime.now(),
      );

      final updatedSeason = season.copyWith(
        participations: {
          ...season.participations,
          userId: updatedParticipation,
        },
        metrics: SeasonMetrics(
          totalParticipants: season.metrics.totalParticipants,
          activeParticipants: season.metrics.activeParticipants,
          completedChallenges: completedChallenges,
          totalChallenges: season.metrics.totalChallenges,
          totalPointsEarned:
              season.metrics.totalPointsEarned + totalMilestonePoints,
          averageProgress: season.metrics.averageProgress,
          challengeCompletions: challengeCompletions,
          lastUpdated: DateTime.now(),
          totalTeamPoints: season.metrics.totalTeamPoints,
          completedTeamChallenges: season.metrics.completedTeamChallenges,
          managerBadgesEarned: season.metrics.managerBadgesEarned,
          managerPointsEarned: season.metrics.managerPointsEarned,
        ),
      );
      await _saveSeason(updatedSeason);

      await _updateTeamMetricsAndCheckManagerBadges(
        updatedSeason,
        totalMilestonePoints,
      );

      await _checkAndAwardBadges(updatedSeason, userId);

      developer.log('Updated season milestones for goal completion');
    } catch (e) {
      developer.log('Error updating season milestone from goal: $e');
    }
  }

  // Notify manager about employee goal completion
  static Future<void> _notifyManagerAboutGoalCompletion(
    String seasonId,
    String employeeId,
    String goalTitle,
  ) async {
    try {
      // Get season details to find the manager
      final season = await getSeason(seasonId);
      if (season == null) return;

      final managerId = season.createdBy;
      if (managerId.isEmpty) return;

      var employeeName = 'Employee';
      try {
        final participationName = season.participations[employeeId]?.userName;
        if (participationName != null && participationName.trim().isNotEmpty) {
          employeeName = participationName;
        } else {
          employeeName = await _resolveUserDisplayName(employeeId);
        }
      } catch (_) {}

      final allParticipants = season.participantIds;
      var allParticipantsCompleted = true;
      var completedParticipants = 0;

      for (final participantId in allParticipants) {
        final participantGoals = (await _backend.getGoals(
          userId: participantId,
          limit: 500,
        )).where((goal) {
          return goal['isSeasonGoal'] == true &&
              (goal['seasonId'] ?? '').toString() == seasonId;
        }).toList();

        final participantCompletedGoals = participantGoals
            .where((goal) => goal['status'] == 'completed')
            .length;
        final participantTotalGoals = participantGoals.length;

        if (participantCompletedGoals == participantTotalGoals &&
            participantTotalGoals > 0) {
          completedParticipants++;
        } else {
          allParticipantsCompleted = false;
        }
      }

      // Create alert for manager
      await _createSeasonAlert(
        userId: managerId,
        type: allParticipantsCompleted
            ? AlertType.seasonCompleted
            : AlertType.seasonProgressUpdate,
        priority: allParticipantsCompleted
            ? AlertPriority.high
            : AlertPriority.medium,
        title: allParticipantsCompleted
            ? 'Season Ready for Completion! 🎉'
            : 'Season Progress Update 📈',
        message: allParticipantsCompleted
            ? 'All employees have completed their goals in "${season.title}". You can now complete the season!'
            : '$employeeName completed "$goalTitle" in "${season.title}". Progress: $completedParticipants/${allParticipants.length} employees completed.',
        actionText: allParticipantsCompleted
            ? 'Complete Season'
            : 'View Progress',
        actionRoute: allParticipantsCompleted
            ? '/season_management'
            : '/team_challenges_seasons',
        metadata: {
          'seasonId': seasonId,
          'seasonTitle': season.title,
          'employeeId': employeeId,
          'employeeName': employeeName,
          'goalTitle': goalTitle,
          'completedParticipants': completedParticipants,
          'totalParticipants': allParticipants.length,
          'allCompleted': allParticipantsCompleted,
        },
      );

      developer.log(
        'Notified manager $managerId about goal completion by $employeeId',
      );
    } catch (e) {
      developer.log('Error notifying manager about goal completion: $e');
    }
  }

  // Map challenge type to goal category
  static String _mapChallengeTypeToGoalCategory(ChallengeType type) {
    switch (type) {
      case ChallengeType.learning:
        return 'learning';
      case ChallengeType.skill:
        return 'skill';
      case ChallengeType.collaboration:
        return 'work';
      case ChallengeType.innovation:
        return 'innovation';
      case ChallengeType.wellness:
        return 'wellness';
    }
  }

  // Create default challenges for a season
  static List<SeasonChallenge> createDefaultChallenges(
    String theme, {
    SeasonCourseResource? learningResource,
    bool proofRequired = false,
    String? proofType,
    String? courseLevel,
    int? estimatedHours,
  }) {
    switch (theme.toLowerCase()) {
      case 'learning':
        final resource = learningResource;
        final hasLinkedCourse = resource != null && resource.url.trim().isNotEmpty;
        final challengeId = hasLinkedCourse
            ? 'linked_course_learning_goal'
            : 'learning_goal_1';
        final learningMilestones = <SeasonMilestone>[
          SeasonMilestone(
            id: hasLinkedCourse ? 'course_started' : 'milestone_1',
            title: hasLinkedCourse ? 'Start Course' : 'Start Learning',
            description: hasLinkedCourse
                ? 'Open the linked course and begin learning'
                : 'Begin a new learning module',
            points: 10,
            challengeId: challengeId,
            criteria: {'action': 'start_learning'},
          ),
          SeasonMilestone(
            id: hasLinkedCourse ? 'course_midway' : 'milestone_2',
            title: 'Halfway Point',
            description: hasLinkedCourse
                ? 'Complete at least half of the linked course'
                : 'Complete 50% of the module',
            points: 20,
            challengeId: challengeId,
            criteria: {'progress': 50},
          ),
          SeasonMilestone(
            id: hasLinkedCourse ? 'course_complete' : 'milestone_3',
            title: hasLinkedCourse ? 'Course Complete' : 'Module Complete',
            description: hasLinkedCourse
                ? 'Finish the linked learning resource'
                : 'Complete the entire learning module',
            points: 20,
            challengeId: challengeId,
            criteria: {'progress': 100},
          ),
        ];
        if (proofRequired) {
          learningMilestones.add(
            SeasonMilestone(
              id: 'proof_review_complete',
              title: 'Proof Approved',
              description:
                  'Manager reviews and approves the learning proof you submitted',
              points: 10,
              challengeId: challengeId,
              criteria: {'proofApproval': true, 'managerReview': true},
            ),
          );
        }

        return [
          SeasonChallenge(
            id: challengeId,
            title: hasLinkedCourse
                ? resource.title
                : 'Complete Learning Module',
            description: hasLinkedCourse
                ? 'Complete the linked ${resource.provider} learning resource and track milestones in the app.'
                : 'Finish a learning module related to your role',
            type: ChallengeType.learning,
            points: proofRequired ? 60 : 50,
            milestones: learningMilestones,
            requirements: {
              'module_type': 'any',
              if (hasLinkedCourse) ...{
                'resourceType': 'externalCourse',
                'provider': resource.provider,
                'resourceUrl': resource.url,
              },
            },
            resources: hasLinkedCourse ? [resource] : const [],
            proofRequired: proofRequired,
            proofType: proofRequired
                ? (proofType?.trim().isNotEmpty == true
                      ? proofType!.trim()
                      : 'certificate or screenshot')
                : null,
            courseLevel: courseLevel,
            estimatedHours: estimatedHours,
          ),
        ];
      case 'skill':
        return [
          _attachLinkedResourceToChallenge(
            SeasonChallenge(
              id: 'skill_goal_1',
              title: 'Skill Development Sprint',
              description: 'Develop a new skill or improve an existing one',
              type: ChallengeType.skill,
              points: 75,
              milestones: [
                SeasonMilestone(
                  id: 'skill_milestone_1',
                  title: 'Skill Assessment',
                  description: 'Assess your current skill level',
                  points: 15,
                  challengeId: 'skill_goal_1',
                  criteria: {'action': 'skill_assessment'},
                ),
                SeasonMilestone(
                  id: 'skill_milestone_2',
                  title: 'Practice Sessions',
                  description: 'Complete 5 practice sessions',
                  points: 30,
                  challengeId: 'skill_goal_1',
                  criteria: {'sessions': 5},
                ),
                SeasonMilestone(
                  id: 'skill_milestone_3',
                  title: 'Skill Demonstration',
                  description: 'Demonstrate your improved skill',
                  points: 30,
                  challengeId: 'skill_goal_1',
                  criteria: {'action': 'skill_demo'},
                ),
              ],
              requirements: {'skill_type': 'any'},
            ),
            learningResource: learningResource,
            proofRequired: proofRequired,
            proofType: proofType,
            courseLevel: courseLevel,
            estimatedHours: estimatedHours,
          ),
        ];
      case 'collaboration':
        return [
          _attachLinkedResourceToChallenge(
            SeasonChallenge(
              id: 'collab_goal_1',
              title: 'Team Collaboration',
              description: 'Work on a collaborative project with team members',
              type: ChallengeType.collaboration,
              points: 60,
              milestones: [
                SeasonMilestone(
                  id: 'collab_milestone_1',
                  title: 'Project Kickoff',
                  description: 'Start a collaborative project',
                  points: 15,
                  challengeId: 'collab_goal_1',
                  criteria: {'action': 'project_start'},
                ),
                SeasonMilestone(
                  id: 'collab_milestone_2',
                  title: 'Collaboration Progress 75%',
                  description: 'Reach 75% progress on the collaboration goal',
                  points: 25,
                  challengeId: 'collab_goal_1',
                  criteria: {'progress': 75},
                ),
                SeasonMilestone(
                  id: 'collab_milestone_3',
                  title: 'Project Completion',
                  description: 'Complete the collaborative project',
                  points: 20,
                  challengeId: 'collab_goal_1',
                  criteria: {'action': 'project_complete'},
                ),
              ],
              requirements: {'team_size': 2},
            ),
            learningResource: learningResource,
            proofRequired: proofRequired,
            proofType: proofType,
            courseLevel: courseLevel,
            estimatedHours: estimatedHours,
          ),
        ];
      default:
        return [
          _attachLinkedResourceToChallenge(
            SeasonChallenge(
              id: 'general_goal_1',
              title: 'Personal Growth',
              description: 'Set and achieve a personal development goal',
              type: ChallengeType.learning,
              points: 40,
              milestones: [
                SeasonMilestone(
                  id: 'general_milestone_1',
                  title: 'Goal Setting',
                  description: 'Set a personal development goal',
                  points: 10,
                  challengeId: 'general_goal_1',
                  criteria: {'action': 'goal_set'},
                ),
                SeasonMilestone(
                  id: 'general_milestone_2',
                  title: 'Progress Update',
                  description: 'Update your progress on the goal',
                  points: 15,
                  challengeId: 'general_goal_1',
                  criteria: {'progress': 50},
                ),
                SeasonMilestone(
                  id: 'general_milestone_3',
                  title: 'Goal Achievement',
                  description: 'Complete your personal development goal',
                  points: 15,
                  challengeId: 'general_goal_1',
                  criteria: {'progress': 100},
                ),
              ],
              requirements: {'goal_type': 'personal'},
            ),
            learningResource: learningResource,
            proofRequired: proofRequired,
            proofType: proofType,
            courseLevel: courseLevel,
            estimatedHours: estimatedHours,
          ),
        ];
    }
  }

  static SeasonChallenge _attachLinkedResourceToChallenge(
    SeasonChallenge challenge, {
    SeasonCourseResource? learningResource,
    required bool proofRequired,
    String? proofType,
    String? courseLevel,
    int? estimatedHours,
  }) {
    final resource = learningResource;
    final hasLinkedResource = resource != null && resource.url.trim().isNotEmpty;
    return SeasonChallenge(
      id: challenge.id,
      title: challenge.title,
      description: hasLinkedResource
          ? '${challenge.description} Includes a linked ${resource.provider} resource that participants open and track inside the app.'
          : challenge.description,
      type: challenge.type,
      points: challenge.points,
      milestones: challenge.milestones,
      requirements: {
        ...challenge.requirements,
        if (hasLinkedResource) ...{
          'resourceType': 'externalCourse',
          'provider': resource.provider,
          'resourceUrl': resource.url,
        },
      },
      resources: hasLinkedResource ? [resource] : challenge.resources,
      proofRequired: hasLinkedResource ? proofRequired : challenge.proofRequired,
      proofType: hasLinkedResource
          ? (proofType?.trim().isNotEmpty == true
                ? proofType!.trim()
                : 'certificate or screenshot')
          : challenge.proofType,
      courseLevel: hasLinkedResource ? courseLevel : challenge.courseLevel,
      estimatedHours: hasLinkedResource ? estimatedHours : challenge.estimatedHours,
      isOptional: challenge.isOptional,
    );
  }

  static SeasonChallenge? _findChallengeById(Season season, String challengeId) {
    for (final challenge in season.challenges) {
      if (challenge.id == challengeId) return challenge;
    }
    return null;
  }

  static SeasonMilestone? _managerReviewMilestoneForChallenge(
    SeasonChallenge challenge,
  ) {
    for (final milestone in challenge.milestones) {
      if (milestone.criteria['managerReview'] == true ||
          milestone.criteria['proofApproval'] == true) {
        return milestone;
      }
    }
    return null;
  }

  // Update season status and handle completion side-effects
  static Future<void> updateSeasonStatus(
    String seasonId,
    SeasonStatus status,
  ) async {
    try {
      final existingSeason = await getSeason(seasonId);
      if (existingSeason == null) {
        throw Exception('Season not found');
      }

      await _saveSeason(
        existingSeason.copyWith(
          status: status,
          metrics: _metricsWithLastUpdated(existingSeason.metrics),
        ),
      );

      if (status == SeasonStatus.completed) {
        try {
          final celebration = await getSeasonCelebration(seasonId);
          final payload = {...celebration, 'id': seasonId};
          try {
            await _backend.createCollectionItem('season_celebrations', payload);
          } catch (_) {
            await _backend.patchCollectionItem(
              'season_celebrations',
              seasonId,
              payload,
            );
          }
        } catch (e) {
          developer.log('Skipping celebration doc write for $seasonId: $e');
        }
        await SeasonMetricsJob.recomputeSeasonMetrics(seasonId);
        await refreshParticipantDisplayNames(seasonId);

        await _awardManagerActionBadge(existingSeason, 'season_closer');
        await _awardManagerSeasonPoints(
          season: existingSeason,
          points: _managerSeasonCompletionBonus,
          reason: 'Season completed',
        );
      }
      developer.log('Updated season $seasonId status to ${status.name}');
    } catch (e) {
      developer.log('Error updating season status: $e');
      rethrow;
    }
  }

  // Build a celebration summary for a season
  static Future<Map<String, dynamic>> getSeasonCelebration(
    String seasonId,
  ) async {
    try {
      final season = await getSeason(seasonId);
      if (season == null) {
        throw Exception('Season not found');
      }

      // Compute top performers from participations
      final participants = season.participations.values.toList();
      participants.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
      final topPerformers = participants
          .take(5)
          .map(
            (p) => {
              'userId': p.userId,
              'userName': p.userName,
              'totalPoints': p.totalPoints,
              'badgesEarned': p.badgesEarned.length,
            },
          )
          .toList();

      // Challenge breakdown by type using available metrics if present
      final Map<String, dynamic> challengeBreakdown = {};
      for (final challenge in season.challenges) {
        final type = challenge.type; // enum ChallengeType
        final completions = season.metrics.challengeCompletions[type] ?? 0;
        challengeBreakdown[type.name] = completions;
      }

      final totalBadges = season.participations.values
          .map((p) => p.badgesEarned.length)
          .fold<int>(0, (total, badgeCount) => total + badgeCount);

      // Summary based on metrics
      final summary = {
        'totalParticipants': season.metrics.totalParticipants,
        'completedChallenges': season.metrics.completedChallenges,
        'totalChallenges': season.metrics.totalChallenges,
        'totalPointsEarned': season.metrics.totalPointsEarned,
        'averageProgress': season.metrics.averageProgress,
        'lastUpdated': season.metrics.lastUpdated.toIso8601String(),
        'badgesAwarded': totalBadges,
      };

      return {
        'seasonId': season.id,
        'title': season.title,
        'theme': season.theme,
        'summary': summary,
        'topPerformers': topPerformers,
        'challengeBreakdown': challengeBreakdown,
      };
    } catch (e) {
      developer.log('Error building season celebration: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getSeasonCelebrationDocument(
    String seasonId,
  ) async {
    try {
      final data = await _backend.getCollectionItem(
        'season_celebrations',
        seasonId,
      );
      if (data.isEmpty) return null;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      developer.log('Error fetching celebration doc: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getOrCreateSeasonCelebrationDoc(
    String seasonId,
  ) async {
    final existing = await getSeasonCelebrationDocument(seasonId);
    if (existing != null) return existing;
    final generated = await getSeasonCelebration(seasonId);
    try {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null) {
        final season = await getSeason(seasonId);
        final canPersist = season != null && season.createdBy == currentUid;
        if (canPersist) {
          final payload = {...generated, 'id': seasonId};
          try {
            await _backend.createCollectionItem('season_celebrations', payload);
          } catch (_) {
            await _backend.patchCollectionItem(
              'season_celebrations',
              seasonId,
              payload,
            );
          }
        }
      }
    } catch (e) {
      developer.log('Could not persist celebration doc for $seasonId: $e');
    }
    return generated;
  }

  static Stream<Map<String, dynamic>?> watchSeasonCelebrationDocument(
    String seasonId,
  ) {
    return backendPollingStream<Map<String, dynamic>?>(
      fetch: () async {
        try {
          final data = await _backend.getCollectionItem(
            'season_celebrations',
            seasonId,
          );
          if (data.isEmpty) return null;
          return Map<String, dynamic>.from(data);
        } catch (_) {
          return null;
        }
      },
    );
  }

  static Future<void> _notifyEmployeesAboutNewSeason(
    String seasonId,
    String title,
    String theme,
    String? department,
    {
    required String creatorRole,
    required String creatorId,
    required String creatorName,
  }
  ) async {
    try {
      final users = await _backend.listUsers(
        department: department,
        limit: 500,
      );
      final expiresAt = DateTime.now().add(const Duration(days: 14)).toIso8601String();
      final createdAt = DateTime.now().toIso8601String();

      for (final userData in users) {
        final userId = _userIdFromMap(userData);
        if (userId.isEmpty) continue;
        final role = (userData['role'] ?? '').toString().trim().toLowerCase();

        if (creatorRole == 'admin' && role != 'manager' && role != 'admin') {
          continue;
        }

        if (role == 'manager' && creatorRole == 'admin') {
          await _backend.createAlert(userId, {
            'type': AlertType.seasonProgressUpdate.name,
            'audience': AlertAudience.team.name,
            'priority': AlertPriority.high.name,
            'title': 'New Season Started! 🎉',
            'message':
                'Admin launched "$title" on theme "$theme". Join from Manager Workspace Team Challenges.',
            'actionText': 'View Seasons',
            'actionRoute': '/manager_gw_menu_season_challenges',
            'createdAt': createdAt,
            'isRead': false,
            'isDismissed': false,
            'expiresAt': expiresAt,
            'fromUserId': creatorId,
            'fromUserName': creatorName,
            'metadata': {
              'seasonId': seasonId,
              'seasonTitle': title,
              'theme': theme,
              'createdByRole': creatorRole,
              'department': ?department,
            },
          });
          continue;
        }

        if (role == 'admin' && creatorRole == 'admin') {
          final isCreator = userId == creatorId;
          await _backend.createAlert(userId, {
            'type': AlertType.managerGeneral.name,
            'audience': AlertAudience.personal.name,
            'priority': AlertPriority.medium.name,
            'title': 'Season Published',
            'message': isCreator
                ? 'You published "$title" ($theme). Managers and employees were notified.'
                : '$creatorName published "$title" ($theme).',
            'actionText': 'View Inbox',
            'actionRoute': '/admin_inbox',
            'createdAt': createdAt,
            'isRead': false,
            'isDismissed': false,
            'expiresAt': expiresAt,
            'fromUserId': creatorId,
            'fromUserName': creatorName,
            'metadata': {
              'seasonId': seasonId,
              'seasonTitle': title,
              'theme': theme,
              'createdByRole': creatorRole,
              'department': ?department,
            },
          });
          continue;
        }

        await _backend.createAlert(userId, {
          'type': AlertType.teamGoalAvailable.name,
          'audience': AlertAudience.personal.name,
          'priority': AlertPriority.high.name,
          'title': 'New Season Started! 🎉',
          'message':
              'A new "$title" season on theme "$theme" has started. Join and earn points!',
          'actionText': 'View Seasons',
          'actionRoute': '/season_challenges',
          'createdAt': createdAt,
          'isRead': false,
          'isDismissed': false,
          'expiresAt': expiresAt,
          'fromUserId': creatorId,
          'fromUserName': creatorName,
          'metadata': {
            'seasonId': seasonId,
            'seasonTitle': title,
            'theme': theme,
            'createdByRole': creatorRole,
            'department': ?department,
          },
        });
      }
    } catch (e) {
      developer.log('Error notifying employees about new season: $e');
    }
  }

  static Map<String, dynamic> _seasonGoalPayload({
    required Season season,
    required SeasonChallenge challenge,
    required String userId,
    required String userName,
    required String category,
  }) {
    return {
      'userId': userId,
      'title': challenge.title,
      'description': challenge.description,
      'category': category,
      'priority': 'medium',
      'status': 'notStarted',
      'progress': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'targetDate': season.endDate.toIso8601String(),
      'points': challenge.points,
      'isSeasonGoal': true,
      'seasonId': season.id,
      'challengeId': challenge.id,
      'createdByName': userName,
      'approvalStatus': 'approved',
    };
  }

  static Future<void> _createSeasonGoalsForEmployee(
    Season season,
    String userId,
    String userName,
  ) async {
    try {
      for (final challenge in season.challenges) {
        final category = _mapChallengeTypeToGoalCategory(challenge.type);
        await _backend.createGoal(
          _seasonGoalPayload(
            season: season,
            challenge: challenge,
            userId: userId,
            userName: userName,
            category: category,
          ),
        );
      }
    } catch (e) {
      developer.log('Error creating season goals for employee: $e');
    }
  }

  static Future<void> ensureSeasonGoalsForEmployee({
    required Season season,
    required String userId,
    required String userName,
  }) async {
    try {
      final existing = await _backend.getGoals(userId: userId, limit: 500);
      final existingChallengeIds = existing
          .where((goal) {
            return goal['isSeasonGoal'] == true &&
                (goal['seasonId'] ?? '').toString() == season.id;
          })
          .map((goal) => (goal['challengeId'] ?? '').toString())
          .where((id) => id.trim().isNotEmpty)
          .toSet();

      for (final challenge in season.challenges) {
        if (existingChallengeIds.contains(challenge.id)) {
          continue;
        }
        final category = _mapChallengeTypeToGoalCategory(challenge.type);
        await _backend.createGoal(
          _seasonGoalPayload(
            season: season,
            challenge: challenge,
            userId: userId,
            userName: userName,
            category: category,
          ),
        );
      }
    } catch (e) {
      developer.log('Error ensuring season goals for employee: $e');
      rethrow;
    }
  }

  static Future<void> _updateEmployeeGoalProgress({
    required String userId,
    required String seasonId,
    required String challengeId,
    required String milestoneId,
    required int points,
  }) async {
    try {
      final season = await getSeason(seasonId);
      if (season == null) return;
      final challenge = season.challenges.firstWhere(
        (c) => c.id == challengeId,
        orElse: () => throw Exception('Challenge not found'),
      );
      final milestonesCount = challenge.milestones.length;
      final increment = milestonesCount > 0
          ? (100 / milestonesCount).round()
          : 0;

      final goals = (await _backend.getGoals(userId: userId, limit: 500))
          .where((goal) {
            return goal['isSeasonGoal'] == true &&
                (goal['seasonId'] ?? '').toString() == seasonId &&
                (goal['challengeId'] ?? '').toString() == challengeId;
          })
          .toList();

      if (goals.isEmpty) return;
      final goalData = goals.first;
      final goalId = (goalData['id'] ?? goalData['goalId'] ?? '').toString();
      if (goalId.isEmpty) return;

      final currentProgress = _asInt(goalData['progress']);
      final newProgress = (currentProgress + increment).clamp(0, 100);

      final updates = <String, dynamic>{
        'progress': newProgress,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      if (newProgress >= 100) {
        updates['status'] = 'completed';
        updates['completedAt'] = DateTime.now().toIso8601String();
      } else {
        updates['status'] = 'inProgress';
      }
      await _backend.patchGoal(goalId, updates);
    } catch (e) {
      developer.log('Error updating employee goal progress: $e');
    }
  }

  static Future<void> _checkAndAwardBadges(
    Season season,
    String userId,
  ) async {
    // Employee-facing badges are v2-only. SeasonService's legacy badge syncing is disabled
    // so employees don't receive old-system badges.
    return;
  }

  static bool _didNewlyCompleteChallenge({
    required SeasonParticipation participation,
    required SeasonChallenge challenge,
    required Set<String> newlyCompletedMilestones,
  }) {
    bool wasComplete = true;
    bool completeAfter = true;

    for (final milestone in challenge.milestones) {
      final keyDot = '${challenge.id}.${milestone.id}';
      final status =
          participation.milestoneProgress[keyDot] ??
          participation.milestoneProgress[milestone.id];
      final completedBefore = status == MilestoneStatus.completed;
      if (!completedBefore) {
        wasComplete = false;
      }
      final completedAfter =
          completedBefore || newlyCompletedMilestones.contains(milestone.id);
      if (!completedAfter) {
        completeAfter = false;
      }
    }

    return completeAfter && !wasComplete;
  }

  static bool _hasCompletedChallenge(
    SeasonParticipation participation,
    SeasonChallenge challenge,
  ) {
    for (final milestone in challenge.milestones) {
      final keyDot = '${challenge.id}.${milestone.id}';
      final status =
          participation.milestoneProgress[keyDot] ??
          participation.milestoneProgress[milestone.id];
      if (status != MilestoneStatus.completed) {
        return false;
      }
    }
    return true;
  }

  static Future<void> backfillChallengeCompletionMetrics() async {
    final items = await _backend.getSeasons(limit: 500);
    for (final data in items) {
      final season = _seasonFromMap(data);
      if (season.challenges.isEmpty || season.participations.isEmpty) continue;

      var totalCompletedChallenges = 0;
      final participations = Map<String, SeasonParticipation>.from(
        season.participations,
      );

      participations.forEach((userId, participation) {
        var participantCompleted = 0;
        for (final challenge in season.challenges) {
          if (_hasCompletedChallenge(participation, challenge)) {
            participantCompleted++;
          }
        }
        totalCompletedChallenges += participantCompleted;
        participations[userId] = SeasonParticipation(
          userId: participation.userId,
          userName: participation.userName,
          joinedAt: participation.joinedAt,
          milestoneProgress: participation.milestoneProgress,
          challengeSubmissions: participation.challengeSubmissions,
          customGoals: participation.customGoals,
          totalPoints: participation.totalPoints,
          badgesEarned: participation.badgesEarned,
          completedChallenges: participantCompleted,
          lastActivity: participation.lastActivity,
        );
      });

      await _saveSeason(
        season.copyWith(
          participations: participations,
          metrics: SeasonMetrics(
            totalParticipants: season.metrics.totalParticipants,
            activeParticipants: season.metrics.activeParticipants,
            completedChallenges: totalCompletedChallenges,
            totalChallenges: season.metrics.totalChallenges,
            totalPointsEarned: season.metrics.totalPointsEarned,
            averageProgress: season.metrics.averageProgress,
            challengeCompletions: season.metrics.challengeCompletions,
            lastUpdated: DateTime.now(),
            totalTeamPoints: season.metrics.totalTeamPoints,
            completedTeamChallenges: season.metrics.completedTeamChallenges,
            managerBadgesEarned: season.metrics.managerBadgesEarned,
            managerPointsEarned: season.metrics.managerPointsEarned,
          ),
        ),
      );
      developer.log('Backfilled challenge metrics for season ${season.id}');
    }
  }

  static Future<void> _checkSeasonCompletion(
    String seasonId,
    String userId,
  ) async {
    try {
      final season = await getSeason(seasonId);
      if (season == null) return;

      final allParticipants = season.participantIds;
      if (allParticipants.isEmpty) return;

      bool allParticipantsCompleted = true;

      for (final participantId in allParticipants) {
        final participantGoals = (await _backend.getGoals(
          userId: participantId,
          limit: 500,
        )).where((goal) {
          return goal['isSeasonGoal'] == true &&
              (goal['seasonId'] ?? '').toString() == seasonId;
        }).toList();

        if (participantGoals.isEmpty) {
          allParticipantsCompleted = false;
          break;
        }

        final participantCompletedGoals = participantGoals
            .where((goal) => goal['status'] == 'completed')
            .length;
        final participantTotalGoals = participantGoals.length;

        if (!(participantCompletedGoals == participantTotalGoals &&
            participantTotalGoals > 0)) {
          allParticipantsCompleted = false;
          break;
        }
      }

      if (allParticipantsCompleted && season.status != SeasonStatus.completed) {
        await updateSeasonStatus(seasonId, SeasonStatus.completed);

        try {
          await _createSeasonAlert(
            userId: season.createdBy,
            type: AlertType.seasonCompleted,
            priority: AlertPriority.high,
            title: 'Season Completed 🎉',
            message:
                'All employees completed their goals in "${season.title}". The season has been marked as completed.',
            actionText: 'View Summary',
            actionRoute: '/season_management',
            ttl: const Duration(days: 14),
            metadata: {
              'seasonId': seasonId,
              'seasonTitle': season.title,
              'completedParticipants': allParticipants.length,
              'totalParticipants': allParticipants.length,
              'allCompleted': true,
            },
          );
        } catch (e) {
          developer.log('Error notifying manager about season completion: $e');
        }

        developer.log(
          'Season $seasonId completed after user $userId goal completion',
        );
      }
    } catch (e) {
      developer.log('Error checking season completion: $e');
    }
  }

  static Future<void> _createSeasonAlert({
    required String userId,
    required AlertType type,
    required AlertPriority priority,
    required String title,
    required String message,
    String? actionText,
    String? actionRoute,
    Map<String, dynamic>? metadata,
    Duration ttl = const Duration(days: 7),
  }) async {
    try {
      await _backend.createAlert(userId, {
        'type': type.name,
        'priority': priority.name,
        'title': title,
        'message': message,
        'actionText': ?actionText,
        'actionRoute': ?actionRoute,
        'createdAt': DateTime.now().toIso8601String(),
        'isRead': false,
        'isDismissed': false,
        'expiresAt': DateTime.now().add(ttl).toIso8601String(),
        'metadata': metadata ?? {},
      });
    } catch (e) {
      developer.log('Error creating season alert: $e');
    }
  }

  static Future<String> _resolveUserDisplayName(
    String userId, {
    String? fallback,
  }) async {
    final defaultName = fallback?.trim().isNotEmpty == true
        ? fallback!.trim()
        : _fallbackEmployeeName(userId);
    try {
      final data = await _backend.getUser(userId);
      if (data.isEmpty) return defaultName;
      final candidates = [
        data['displayName'],
        data['fullName'],
        data['badgeName'],
        data['preferredName'],
        data['firstName'],
        data['lastName'],
        data['email'],
      ];
      for (final candidate in candidates) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
      return defaultName;
    } catch (e) {
      developer.log('Error resolving display name for $userId: $e');
      return defaultName;
    }
  }

  static String _fallbackEmployeeName(String userId) {
    final suffix = userId.isNotEmpty
        ? userId.substring(0, userId.length >= 6 ? 6 : userId.length)
        : '000000';
    return 'Employee #$suffix';
  }
}
