import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/manager_realtime_service.dart';

class SeasonService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

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

      final seasonId = _firestore.collection('seasons').doc().id;
      final season = Season(
        id: seasonId,
        title: title,
        description: description,
        theme: theme,
        status: SeasonStatus.active,
        startDate: startDate,
        endDate: endDate,
        createdAt: DateTime.now(),
        createdBy: currentUser.uid,
        createdByName: currentUser.displayName ?? 'Manager',
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

      await _firestore
          .collection('seasons')
          .doc(seasonId)
          .set(season.toFirestore());

      // Record activity
      await ManagerRealtimeService.recordEmployeeActivity(
        employeeId: currentUser.uid,
        activityType: 'season_created',
        description: 'Created season: $title',
        metadata: {'seasonId': seasonId, 'theme': theme},
      );

      // Notify all employees about the new season
      await _notifyEmployeesAboutNewSeason(seasonId, title, theme, department);

      developer.log('Season created: $seasonId');
      return seasonId;
    } catch (e) {
      developer.log('Error creating season: $e');
      rethrow;
    }
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
    final season = await getSeason(seasonId);
    if (season == null) throw Exception('Season not found');

    final seasonRef = _firestore.collection('seasons').doc(seasonId);
    final batch = _firestore.batch();

    // Optionally remove zero-progress participants
    if (removeZeroProgress) {
      final List<String> zeroIds = [];
      season.participations.forEach((userId, p) {
        final completed = p.milestoneProgress.values
            .where((s) => _isCompletedStatus(s))
            .length;
        final isZero = completed == 0 && (p.totalPoints == 0);
        if (isZero) zeroIds.add(userId);
      });

      for (final userId in zeroIds) {
        batch.update(seasonRef, {
          'participantIds': FieldValue.arrayRemove([userId]),
          'participations.$userId': FieldValue.delete(),
          'metrics.lastUpdated': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      for (final userId in zeroIds) {
        await AlertService.createMotivationalAlert(
          userId: userId,
          message:
              'You were removed from the season "${season.title}" due to zero progress. Future seasons await you! 💪',
        );
      }
    }

    await updateSeasonStatus(seasonId, SeasonStatus.completed);

    // Congratulate remaining participants
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
  static Future<Map<String, dynamic>> evaluateSeasonCompletion(String seasonId) async {
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
    final List<String> zeroIds = List<String>.from(result['zeroProgressIds'] as List);

    final seasonRef = _firestore.collection('seasons').doc(seasonId);
    final batch = _firestore.batch();

    // Remove zero-progress participants and alert them
    for (final userId in zeroIds) {
      batch.update(seasonRef, {
        'participantIds': FieldValue.arrayRemove([userId]),
        'participations.$userId': FieldValue.delete(),
        'metrics.lastUpdated': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    // Notify removed employees
    for (final userId in zeroIds) {
      await AlertService.createMotivationalAlert(
        userId: userId,
        message: 'You were removed from the season "${season.title}" due to zero progress. You can rejoin future seasons and try again!',
      );
    }

    // Re-evaluate after removals
    final reevaluated = await evaluateSeasonCompletion(seasonId);
    final bool allCompleteNow = reevaluated['allComplete'] as bool;

    if (!allCompleteNow) {
      throw Exception('Season cannot be completed until all remaining participants reach 100%.');
    }

    await updateSeasonStatus(seasonId, SeasonStatus.completed);

    // Congratulate all remaining participants
    final updatedSeason = await getSeason(seasonId);
    if (updatedSeason != null) {
      for (final entry in updatedSeason.participations.entries) {
        final p = entry.value;
        await AlertService.createMotivationalAlert(
          userId: p.userId,
          message: 'Congratulations! "${updatedSeason.title}" has been completed. Great work this season! 🎉',
        );
      }

      // Notify manager about season completion
      try {
        await _firestore.collection('alerts').add({
          'userId': updatedSeason.createdBy,
          'type': AlertType.seasonCompleted.name,
          'priority': AlertPriority.high.name,
          'title': 'Season Completed 🎉',
          'message': 'Your season "${updatedSeason.title}" has been completed by all participants.',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'isDismissed': false,
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
          'metadata': {
            'seasonId': updatedSeason.id,
            'seasonTitle': updatedSeason.title,
          },
        });
      } catch (_) {}
    }
  }

  // Extend a season end date
  static Future<void> extendSeason(String seasonId, DateTime newEndDate) async {
    await _firestore.collection('seasons').doc(seasonId).update({
      'endDate': Timestamp.fromDate(newEndDate),
      'metrics.lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  // Pause or resume season via settings.paused flag (non-breaking)
  static Future<void> setSeasonPaused(String seasonId, bool paused) async {
    await _firestore.collection('seasons').doc(seasonId).update({
      'settings.paused': paused,
      'metrics.lastUpdated': FieldValue.serverTimestamp(),
    });
  }
  // Get season by ID
  static Future<Season?> getSeason(String seasonId) async {
    try {
      final doc = await _firestore.collection('seasons').doc(seasonId).get();
      if (!doc.exists) return null;
      return Season.fromFirestore(doc);
    } catch (e) {
      developer.log('Error getting season: $e');
      return null;
    }
  }

  // Get a stream for a single season
  static Stream<Season> getSeasonStream(String seasonId) {
    try {
      return _firestore
          .collection('seasons')
          .doc(seasonId)
          .snapshots()
          .map((doc) => Season.fromFirestore(doc));
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

      return _firestore
          .collection('seasons')
          .where('createdBy', isEqualTo: currentUser.uid)
          .snapshots()
          .map((snapshot) {
            final seasons = snapshot.docs
                .map((doc) => Season.fromFirestore(doc))
                .toList();
            // Sort in memory to avoid composite index requirement
            seasons.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return seasons;
          });
    } catch (e) {
      developer.log('Error getting manager seasons: $e');
      return const Stream.empty();
    }
  }

  // Get active seasons for employees
  static Stream<List<Season>> getActiveSeasonsStream({String? department}) {
    try {
      Query query = _firestore
          .collection('seasons')
          .where('status', isEqualTo: SeasonStatus.active.name);

      if (department != null && department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }

      return query.snapshots().map((snapshot) {
        final seasons = snapshot.docs
            .map((doc) => Season.fromFirestore(doc))
            .toList();
        // Sort in memory to avoid composite index requirement
        seasons.sort((a, b) => b.startDate.compareTo(a.startDate));
        return seasons;
      });
    } catch (e) {
      developer.log('Error getting active seasons: $e');
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
      final batch = _firestore.batch();
      final seasonRef = _firestore.collection('seasons').doc(seasonId);

      // Get season details first
      final seasonDoc = await seasonRef.get();
      if (!seasonDoc.exists) {
        throw Exception('Season not found');
      }
      final season = Season.fromFirestore(seasonDoc);

      // Add user to participants
      batch.update(seasonRef, {
        'participantIds': FieldValue.arrayUnion([userId]),
        'participations.$userId': SeasonParticipation(
          userId: userId,
          userName: userName,
          joinedAt: DateTime.now(),
          milestoneProgress: {},
          customGoals: customGoals,
          totalPoints: 0,
          badgesEarned: [],
        ).toMap(),
      });

      // Update metrics
      final updatedMetrics = SeasonMetrics(
        totalParticipants: season.participantIds.length + 1,
        activeParticipants: season.metrics.activeParticipants + 1,
        completedChallenges: season.metrics.completedChallenges,
        totalChallenges: season.metrics.totalChallenges,
        totalPointsEarned: season.metrics.totalPointsEarned,
        averageProgress: season.metrics.averageProgress,
        challengeCompletions: season.metrics.challengeCompletions,
        lastUpdated: DateTime.now(),
      );

      batch.update(seasonRef, {'metrics': updatedMetrics.toMap()});

      await batch.commit();

      // Create season goals for the employee
      await _createSeasonGoalsForEmployee(season, userId, userName);

      // Record activity
      await ManagerRealtimeService.recordEmployeeActivity(
        employeeId: userId,
        activityType: 'season_joined',
        description: 'Joined season: ${season.title}',
        metadata: {'seasonId': seasonId, 'seasonTitle': season.title},
      );

      // Notify manager that an employee joined this season
      try {
        final managerId = season.createdBy;
        await _firestore.collection('alerts').add({
          'userId': managerId,
          'type': AlertType.seasonJoined.name,
          'priority': AlertPriority.medium.name,
          'title': 'Employee Joined Season',
          'message': '$userName joined the season "${season.title}"',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'isDismissed': false,
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
          'metadata': {
            'seasonId': seasonId,
            'seasonTitle': season.title,
            'employeeId': userId,
            'employeeName': userName,
          },
        });
      } catch (_) {}

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
  }) async {
    try {
      final batch = _firestore.batch();
      final seasonRef = _firestore.collection('seasons').doc(seasonId);

      // Update milestone status
      batch.update(seasonRef, {
        'participations.$userId.milestoneProgress.$milestoneId': status.name,
        'participations.$userId.lastActivity': FieldValue.serverTimestamp(),
      });

      // If milestone completed, award points and check for badges
      if (status == MilestoneStatus.completed) {
        final seasonDoc = await seasonRef.get();
        if (seasonDoc.exists) {
          final season = Season.fromFirestore(seasonDoc);

          // Find the milestone that was completed
          SeasonMilestone? completedMilestone;
          ChallengeType? completedChallengeType;
          for (var challenge in season.challenges) {
            for (var milestone in challenge.milestones) {
              if (milestone.id == milestoneId) {
                completedMilestone = milestone;
                completedChallengeType = challenge.type;
                break;
              }
            }
            if (completedMilestone != null) break;
          }

          if (completedMilestone != null) {
            // Update points for the user
            batch.update(seasonRef, {
              'participations.$userId.totalPoints': FieldValue.increment(completedMilestone.points),
            });

            // Update season metrics: total points and challenge-type completions
            if (completedChallengeType != null) {
              batch.update(seasonRef, {
                'metrics.totalPointsEarned': FieldValue.increment(completedMilestone.points),
                'metrics.challengeCompletions.${completedChallengeType.name}': FieldValue.increment(1),
                'metrics.lastUpdated': FieldValue.serverTimestamp(),
              });
            }

            // Update corresponding employee goal progress
            await _updateEmployeeGoalProgress(
              userId: userId,
              seasonId: seasonId,
              challengeId: completedMilestone.challengeId,
              milestoneId: milestoneId,
              points: completedMilestone.points,
            );

            // Check for badge eligibility for the employee
            await _checkAndAwardBadges(season, userId, batch);

            // Update team metrics and check for manager badges
            await _updateTeamMetricsAndCheckManagerBadges(
              season,
              completedMilestone.points,
            );
          }
        }
      }

      await batch.commit();

      // Record activity
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

  // Check and award badges for managers
  static Future<void> _checkAndAwardManagerBadges(Season season) async {
    try {
      final managerId = season.createdBy;
      final metrics = season.metrics;
      final earnedBadgeIds = metrics.managerBadgesEarned.toSet();

      final managerBadges = [
        SeasonBadge(
          id: 'team_builder',
          name: 'Team Builder',
          description: 'Assembled a team of 5+ for a season',
          icon: '👥',
          color: '#3498DB',
          points: 50,
          criteria: {'participants': 5},
        ),
        SeasonBadge(
          id: 'momentum_maker',
          name: 'Momentum Maker',
          description: 'Team earned over 500 points in a season',
          icon: '🚀',
          color: '#E67E22',
          points: 100,
          criteria: {'points': 500},
        ),
        SeasonBadge(
          id: 'challenge_crusher',
          name: 'Challenge Crusher',
          description: 'Team completed 10+ challenges in a season',
          icon: '💥',
          color: '#E74C3C',
          points: 150,
          criteria: {'challenges': 10},
        ),
      ];

      for (final badge in managerBadges) {
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
            await _firestore.collection('seasons').doc(season.id).update({
              'metrics.managerBadgesEarned': FieldValue.arrayUnion([badge.id]),
            });

            await _syncBadgeWithEmployeeSystem(
              managerId,
              badge,
              season,
              isManager: true,
            );
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
      final seasonRef = _firestore.collection('seasons').doc(season.id);

      // Increment team points and challenges
      await seasonRef.update({
        'metrics.totalTeamPoints': FieldValue.increment(pointsAwarded),
        'metrics.completedTeamChallenges': FieldValue.increment(1),
        'metrics.lastUpdated': FieldValue.serverTimestamp(),
      });

      // Refetch season data to get the latest metrics
      final updatedSeasonDoc = await seasonRef.get();
      if (!updatedSeasonDoc.exists) return;
      final updatedSeason = Season.fromFirestore(updatedSeasonDoc);

      await _checkAndAwardManagerBadges(updatedSeason);
    } catch (e) {
      developer.log('Error updating team metrics: $e');
    }
  }

  // Sync season badge with employee's main badge system
  static Future<void> _syncBadgeWithEmployeeSystem(
    String userId,
    SeasonBadge seasonBadge,
    Season season,
    {bool isManager = false}
  ) async {
    try {
      // Create a badge in the employee's badge collection
      final badgeRef = _firestore.collection('badges').doc();
      await badgeRef.set({
        'userId': userId,
        'name': seasonBadge.name,
        'description': '${seasonBadge.description} - ${season.title}',
        'icon': seasonBadge.icon,
        'color': seasonBadge.color,
        'points': seasonBadge.points,
        'category': 'season',
        'seasonId': season.id,
        'seasonTitle': season.title,
        'earnedAt': FieldValue.serverTimestamp(),
        'type': 'season_badge',
      });

      // Also write to users/{userId}/badges in Badge model structure so it shows in the standard badges UI
      final userBadgeId = '${seasonBadge.id}_${season.id}';
      final userBadgeRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('badges')
          .doc(userBadgeId);
      await userBadgeRef.set({
        'name': seasonBadge.name,
        'description': '${seasonBadge.description} - ${season.title}',
        'iconName': 'emoji_events',
        'category': 'leadership',
        'rarity': 'common',
        'pointsRequired': seasonBadge.points,
        'criteria': {
          'source': 'season',
          'seasonId': season.id,
          'seasonTitle': season.title,
          'isManager': isManager,
        },
        'earnedAt': FieldValue.serverTimestamp(),
        'isEarned': true,
        'progress': 1,
        'maxProgress': 1,
      }, SetOptions(merge: true));

      // Update user's total points
      await _firestore.collection('users').doc(userId).update({
        'totalPoints': FieldValue.increment(seasonBadge.points),
        'totalBadges': FieldValue.increment(1),
      });

      // Create a general badge alert (not just season-specific)
      await AlertService.createBadgeAlert(
        userId: userId,
        badgeName: seasonBadge.name,
        isManager: isManager,
      );

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
      final goalDoc = await _firestore.collection('goals').doc(goalId).get();
      if (!goalDoc.exists) {
        throw Exception('Goal not found');
      }

      final goalData = goalDoc.data()!;

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
      await goalDoc.reference.update({
        'status': 'completed',
        'progress': 100,
        'completedAt': FieldValue.serverTimestamp(),
        'evidence': evidence,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update user's total points
      await _firestore.collection('users').doc(userId).update({
        'totalPoints': FieldValue.increment(points),
      });

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

      final batch = _firestore.batch();
      final seasonRef = _firestore.collection('seasons').doc(seasonId);

      // Mark all milestones for this challenge as completed
      for (final milestone in challenge.milestones) {
        batch.update(seasonRef, {
          'participations.$userId.milestoneProgress.$challengeId.${milestone.id}':
              MilestoneStatus.completed.name,
        });
      }

      // Award points for all milestones
      final totalMilestonePoints = challenge.milestones.fold<int>(
        0,
        (sum, m) => sum + m.points,
      );
      batch.update(seasonRef, {
        'participations.$userId.totalPoints': FieldValue.increment(
          totalMilestonePoints,
        ),
        'participations.$userId.lastActivity': FieldValue.serverTimestamp(),
      });

      // Update season metrics for bulk completion via goal
      batch.update(seasonRef, {
        'metrics.totalPointsEarned': FieldValue.increment(totalMilestonePoints),
        'metrics.challengeCompletions.${challenge.type.name}': FieldValue.increment(challenge.milestones.length),
        'metrics.lastUpdated': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Check for badge awards
      await _checkAndAwardBadges(season, userId, batch);

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

      final seasonDoc = await _firestore
          .collection('seasons')
          .doc(seasonId)
          .get();
      if (!seasonDoc.exists) return;

      final seasonData = seasonDoc.data()!;
      final managerId = seasonData['createdBy'];
      if (managerId == null) return;

      // Get employee details with robust fallbacks
      final employeeDoc = await _firestore
          .collection('users')
          .doc(employeeId)
          .get();
      String employeeName = 'Employee';
      try {
        // Prefer the name stored in the season participation (captured at join time)
        final participationName = season.participations[employeeId]?.userName;
        if (participationName != null && participationName.trim().isNotEmpty) {
          employeeName = participationName;
        } else if (employeeDoc.exists) {
          final data = employeeDoc.data() ?? {};
          final candidates = [
            data['displayName'],
            data['fullName'],
            data['badgeName'],
            data['email'],
          ];
          for (final c in candidates) {
            if (c is String && c.trim().isNotEmpty) {
              employeeName = c;
              break;
            }
          }
        }
      } catch (_) {}

      // Check if all employees have completed their goals
      final allParticipants = season.participantIds;
      bool allParticipantsCompleted = true;
      int completedParticipants = 0;

      for (final participantId in allParticipants) {
        final participantGoalsQuery = await _firestore
            .collection('goals')
            .where('userId', isEqualTo: participantId)
            .where('seasonId', isEqualTo: seasonId)
            .where('isSeasonGoal', isEqualTo: true)
            .get();

        final participantGoals = participantGoalsQuery.docs;
        final participantCompletedGoals = participantGoals
            .where((doc) => doc.data()['status'] == 'completed')
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
      final alertRef = _firestore.collection('alerts').doc();
      await alertRef.set({
        'userId': managerId,
        'type': (allParticipantsCompleted
                ? AlertType.seasonCompleted
                : AlertType.seasonProgressUpdate)
            .name,
        'priority': allParticipantsCompleted
            ? AlertPriority.high.name
            : AlertPriority.medium.name,
        'title': allParticipantsCompleted
            ? 'Season Ready for Completion! 🎉'
            : 'Season Progress Update 📈',
        'message': allParticipantsCompleted
            ? 'All employees have completed their goals in "${season.title}". You can now complete the season!'
            : '$employeeName completed "$goalTitle" in "${season.title}". Progress: $completedParticipants/${allParticipants.length} employees completed.',
        'actionText': allParticipantsCompleted
            ? 'Complete Season'
            : 'View Progress',
        'actionRoute': allParticipantsCompleted
            ? '/season_management'
            : '/team_challenges_seasons',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDismissed': false,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
        'metadata': {
          'seasonId': seasonId,
          'seasonTitle': season.title,
          'employeeId': employeeId,
          'employeeName': employeeName,
          'goalTitle': goalTitle,
          'completedParticipants': completedParticipants,
          'totalParticipants': allParticipants.length,
          'allCompleted': allParticipantsCompleted,
        },
      });

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
  static List<SeasonChallenge> createDefaultChallenges(String theme) {
    switch (theme.toLowerCase()) {
      case 'learning':
        return [
          SeasonChallenge(
            id: 'learning_goal_1',
            title: 'Complete Learning Module',
            description: 'Finish a learning module related to your role',
            type: ChallengeType.learning,
            points: 50,
            milestones: [
              SeasonMilestone(
                id: 'milestone_1',
                title: 'Start Learning',
                description: 'Begin a new learning module',
                points: 10,
                challengeId: 'learning_goal_1',
                criteria: {'action': 'start_learning'},
              ),
              SeasonMilestone(
                id: 'milestone_2',
                title: 'Halfway Point',
                description: 'Complete 50% of the module',
                points: 20,
                challengeId: 'learning_goal_1',
                criteria: {'progress': 50},
              ),
              SeasonMilestone(
                id: 'milestone_3',
                title: 'Module Complete',
                description: 'Complete the entire learning module',
                points: 20,
                challengeId: 'learning_goal_1',
                criteria: {'progress': 100},
              ),
            ],
            requirements: {'module_type': 'any'},
          ),
        ];
      case 'skill':
        return [
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
        ];
      case 'collaboration':
        return [
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
                title: 'Team Meetings',
                description: 'Participate in 3 team meetings',
                points: 25,
                challengeId: 'collab_goal_1',
                criteria: {'meetings': 3},
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
        ];
      default:
        return [
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
        ];
    }
  }

  // Update season status and handle completion side-effects
  static Future<void> updateSeasonStatus(
    String seasonId,
    SeasonStatus status,
  ) async {
    try {
      await _firestore.collection('seasons').doc(seasonId).update({
        'status': status.name,
        'metrics.lastUpdated': FieldValue.serverTimestamp(),
      });
      if (status == SeasonStatus.completed) {
        final celebration = await getSeasonCelebration(seasonId);
        await _firestore
            .collection('season_celebrations')
            .doc(seasonId)
            .set(celebration);
      }
      developer.log('Updated season $seasonId status to ${status.name}');
    } catch (e) {
      developer.log('Error updating season status: $e');
      rethrow;
    }
  }

  // Build a celebration summary for a season
  static Future<Map<String, dynamic>> getSeasonCelebration(String seasonId) async {
    try {
      final season = await getSeason(seasonId);
      if (season == null) {
        throw Exception('Season not found');
      }

      // Compute top performers from participations
      final participants = season.participations.values.toList();
      participants.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
      final topPerformers = participants.take(5).map((p) => {
            'userId': p.userId,
            'userName': p.userName,
            'totalPoints': p.totalPoints,
            'badgesEarned': p.badgesEarned.length,
          }).toList();

      // Challenge breakdown by type using available metrics if present
      final Map<String, dynamic> challengeBreakdown = {};
      for (final challenge in season.challenges) {
        final key = challenge.type.name;
        final completions = season.metrics.challengeCompletions[key] ?? 0;
        challengeBreakdown[key] = completions;
      }

      // Summary based on metrics
      final summary = {
        'totalParticipants': season.metrics.totalParticipants,
        'completedChallenges': season.metrics.completedChallenges,
        'totalChallenges': season.metrics.totalChallenges,
        'totalPointsEarned': season.metrics.totalPointsEarned,
        'averageProgress': season.metrics.averageProgress,
        'lastUpdated': season.metrics.lastUpdated.toIso8601String(),
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

  static Future<void> _notifyEmployeesAboutNewSeason(
    String seasonId,
    String title,
    String theme,
    String? department,
  ) async {
    try {
      Query usersQuery = _firestore.collection('users');
      if (department != null && department.isNotEmpty) {
        usersQuery = usersQuery.where('department', isEqualTo: department);
      }
      final usersSnapshot = await usersQuery.get();
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        await _firestore.collection('alerts').add({
          'userId': userId,
          'type': 'season_available',
          'priority': 'high',
          'title': 'New Season Started! 🎉',
          'message': 'A new "$title" season on theme "$theme" has started. Join and earn points!',
          'actionText': 'View Seasons',
          'actionRoute': '/team_challenges_seasons',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'isDismissed': false,
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 14)),
          ),
          'metadata': {
            'seasonId': seasonId,
            'seasonTitle': title,
            'theme': theme,
            if (department != null) 'department': department,
          },
        });
      }
    } catch (e) {
      developer.log('Error notifying employees about new season: $e');
    }
  }

  static Future<void> _createSeasonGoalsForEmployee(
    Season season,
    String userId,
    String userName,
  ) async {
    try {
      for (final challenge in season.challenges) {
        final category = _mapChallengeTypeToGoalCategory(challenge.type);
        await _firestore.collection('goals').add({
          'userId': userId,
          'title': challenge.title,
          'description': challenge.description,
          'category': category,
          'priority': 'medium',
          'status': 'notStarted',
          'progress': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'targetDate': Timestamp.fromDate(season.endDate),
          'points': challenge.points,
          'isSeasonGoal': true,
          'seasonId': season.id,
          'challengeId': challenge.id,
          'createdByName': userName,
        });
      }
    } catch (e) {
      developer.log('Error creating season goals for employee: $e');
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
      final increment = milestonesCount > 0 ? (100 / milestonesCount).round() : 0;

      final goalsQuery = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: userId)
          .where('seasonId', isEqualTo: seasonId)
          .where('challengeId', isEqualTo: challengeId)
          .where('isSeasonGoal', isEqualTo: true)
          .limit(1)
          .get();

      if (goalsQuery.docs.isEmpty) return;
      final goalRef = goalsQuery.docs.first.reference;
      final goalData = goalsQuery.docs.first.data();
      final currentProgress = (goalData['progress'] ?? 0) as int;
      final newProgress = (currentProgress + increment).clamp(0, 100);

      final updates = <String, dynamic>{
        'progress': newProgress,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
      if (newProgress >= 100) {
        updates['status'] = 'completed';
        updates['completedAt'] = FieldValue.serverTimestamp();
      } else {
        updates['status'] = 'inProgress';
      }
      await goalRef.update(updates);
    } catch (e) {
      developer.log('Error updating employee goal progress: $e');
    }
  }

  static Future<void> _checkAndAwardBadges(
    Season season,
    String userId,
    WriteBatch batch,
  ) async {
    try {
      final participation = season.participations[userId];
      if (participation == null) return;
      if (participation.totalPoints >= 100) {
        final badge = SeasonBadge(
          id: 'season_starter',
          name: 'Season Starter',
          description: 'Earned 100+ points in a season',
          icon: '🎯',
          color: '#8E44AD',
          points: 25,
          criteria: {'points': 100},
        );
        await _syncBadgeWithEmployeeSystem(userId, badge, season);
      }
    } catch (e) {
      developer.log('Error checking and awarding badges: $e');
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
        final participantGoalsQuery = await _firestore
            .collection('goals')
            .where('userId', isEqualTo: participantId)
            .where('seasonId', isEqualTo: seasonId)
            .where('isSeasonGoal', isEqualTo: true)
            .get();

        final participantGoals = participantGoalsQuery.docs;
        if (participantGoals.isEmpty) {
          allParticipantsCompleted = false;
          break;
        }

        final participantCompletedGoals = participantGoals
            .where((doc) => doc.data()['status'] == 'completed')
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

        // Notify manager that the season is completed
        try {
          final managerId = season.createdBy;
          await _firestore.collection('alerts').add({
            'userId': managerId,
            'type': 'season_completed',
            'priority': 'high',
            'title': 'Season Completed 🎉',
            'message': 'All employees completed their goals in "${season.title}". The season has been marked as completed.',
            'actionText': 'View Summary',
            'actionRoute': '/season_management',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
            'isDismissed': false,
            'expiresAt': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 14)),
            ),
            'metadata': {
              'seasonId': seasonId,
              'seasonTitle': season.title,
              'completedParticipants': allParticipants.length,
              'totalParticipants': allParticipants.length,
              'allCompleted': true,
            },
          });
        } catch (e) {
          developer.log('Error notifying manager about season completion: $e');
        }

        developer.log('Season $seasonId completed after user $userId goal completion');
      }
    } catch (e) {
      developer.log('Error checking season completion: $e');
    }
  }
}
