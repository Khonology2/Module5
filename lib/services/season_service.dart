import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/alert_service.dart';
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

          // Find milestone and award points
          for (final challenge in season.challenges) {
            for (final milestone in challenge.milestones) {
              if (milestone.id == milestoneId) {
                batch.update(seasonRef, {
                  'participations.$userId.totalPoints': FieldValue.increment(
                    milestone.points,
                  ),
                });

                // Update corresponding employee goal progress
                await _updateEmployeeGoalProgress(
                  userId: userId,
                  seasonId: seasonId,
                  challengeId: challenge.id,
                  milestoneId: milestoneId,
                  points: milestone.points,
                );
                break;
              }
            }
          }

          // Check for badge eligibility
          await _checkAndAwardBadges(season, userId, batch);
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

  // Check and award badges
  static Future<void> _checkAndAwardBadges(
    Season season,
    String userId,
    WriteBatch batch,
  ) async {
    try {
      final participation = season.participations[userId];
      if (participation == null) return;

      final completedMilestones = participation.milestoneProgress.values
          .where((status) => status == MilestoneStatus.completed)
          .length;

      final totalPoints = participation.totalPoints;
      // Track earned badge IDs for checking
      final earnedBadgeIds = participation.badgesEarned.toSet();

      // Define badge criteria
      final badges = [
        SeasonBadge(
          id: 'first_milestone',
          name: 'First Steps',
          description: 'Completed your first milestone',
          icon: '🎯',
          color: '#FFD700',
          points: 10,
          criteria: {'milestones': 1},
        ),
        SeasonBadge(
          id: 'halfway_hero',
          name: 'Halfway Hero',
          description: 'Completed half of all milestones',
          icon: '🏆',
          color: '#C0C0C0',
          points: 25,
          criteria: {'milestones': (season.challenges.length * 0.5).ceil()},
        ),
        SeasonBadge(
          id: 'season_champion',
          name: 'Season Champion',
          description: 'Completed all milestones',
          icon: '👑',
          color: '#FF6B35',
          points: 50,
          criteria: {'milestones': season.challenges.length},
        ),
        SeasonBadge(
          id: 'point_master',
          name: 'Point Master',
          description: 'Earned 100+ points in the season',
          icon: '⭐',
          color: '#9B59B6',
          points: 30,
          criteria: {'points': 100},
        ),
      ];

      for (final badge in badges) {
        if (!earnedBadgeIds.contains(badge.id)) {
          bool shouldAward = false;

          if (badge.criteria.containsKey('milestones')) {
            shouldAward = completedMilestones >= badge.criteria['milestones'];
          } else if (badge.criteria.containsKey('points')) {
            shouldAward = totalPoints >= badge.criteria['points'];
          }

          if (shouldAward) {
            batch.update(_firestore.collection('seasons').doc(season.id), {
              'participations.$userId.badgesEarned': FieldValue.arrayUnion([
                badge.id,
              ]),
              'participations.$userId.totalPoints': FieldValue.increment(
                badge.points,
              ),
            });

            // Create alert for badge earned
            await AlertService.createBadgeAlert(
              userId: userId,
              badgeName: badge.name,
            );

            // Sync badge with employee's main badge system
            await _syncBadgeWithEmployeeSystem(userId, badge, season);
          }
        }
      }
    } catch (e) {
      developer.log('Error checking badges: $e');
    }
  }

  // Update season status
  static Future<void> updateSeasonStatus(
    String seasonId,
    SeasonStatus status,
  ) async {
    try {
      await _firestore.collection('seasons').doc(seasonId).update({
        'status': status.name,
        'metrics.lastUpdated': FieldValue.serverTimestamp(),
      });

      // If season is completed, create celebration data
      if (status == SeasonStatus.completed) {
        await _createSeasonCelebration(seasonId);
      }

      developer.log('Updated season $seasonId status to $status');
    } catch (e) {
      developer.log('Error updating season status: $e');
      rethrow;
    }
  }

  // Create season celebration data
  static Future<void> _createSeasonCelebration(String seasonId) async {
    try {
      final season = await getSeason(seasonId);
      if (season == null) return;

      final celebrationData = {
        'seasonId': seasonId,
        'title': season.title,
        'theme': season.theme,
        'totalParticipants': season.metrics.totalParticipants,
        'totalPointsEarned': season.metrics.totalPointsEarned,
        'topPerformers': _getTopPerformers(season),
        'badgesAwarded': _getTotalBadgesAwarded(season),
        'challengeCompletions': season.metrics.challengeCompletions.map(
          (key, value) => MapEntry(key.name, value),
        ),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('season_celebrations')
          .doc(seasonId)
          .set(celebrationData);

      // Notify all participants about season completion
      for (final participantId in season.participantIds) {
        await AlertService.createMotivationalAlert(
          userId: participantId,
          message:
              'The "${season.title}" season has ended! 🎉 Check out the celebration and see how your team performed!',
        );
      }

      developer.log('Created celebration for season $seasonId');
    } catch (e) {
      developer.log('Error creating season celebration: $e');
    }
  }

  // Get top performers for celebration
  static List<Map<String, dynamic>> _getTopPerformers(Season season) {
    final participations = season.participations.values.toList();
    participations.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    return participations
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
  }

  // Get total badges awarded
  static int _getTotalBadgesAwarded(Season season) {
    return season.participations.values
        .map((p) => p.badgesEarned.length)
        .fold(0, (sum, count) => sum + count);
  }

  // Get season celebration data
  static Future<Map<String, dynamic>?> getSeasonCelebration(
    String seasonId,
  ) async {
    try {
      final doc = await _firestore
          .collection('season_celebrations')
          .doc(seasonId)
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      developer.log('Error getting season celebration: $e');
      return null;
    }
  }

  // Notify employees about new season
  static Future<void> _notifyEmployeesAboutNewSeason(
    String seasonId,
    String seasonTitle,
    String theme,
    String? department,
  ) async {
    try {
      // Get all employees (or filter by department if specified)
      Query query = _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee');

      if (department != null && department.isNotEmpty) {
        query = query.where('department', isEqualTo: department);
      }

      final employeesSnapshot = await query.get();

      // Create notifications for each employee
      final batch = _firestore.batch();
      for (final employeeDoc in employeesSnapshot.docs) {
        final employeeId = employeeDoc.id;

        // Create alert for new season
        final alertRef = _firestore.collection('alerts').doc();
        batch.set(alertRef, {
          'userId': employeeId,
          'type': 'season_available',
          'priority': 'high',
          'title': 'New Growth Season Available! 🎯',
          'message':
              'Your manager created a new $theme season: "$seasonTitle". Join now to earn points and badges!',
          'actionText': 'Join Season',
          'actionRoute': '/season_challenges',
          'createdAt': FieldValue.serverTimestamp(),
          'isRead': false,
          'isDismissed': false,
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 14)),
          ),
          'metadata': {
            'seasonId': seasonId,
            'seasonTitle': seasonTitle,
            'theme': theme,
          },
        });
      }

      await batch.commit();
      developer.log(
        'Notified ${employeesSnapshot.docs.length} employees about new season',
      );
    } catch (e) {
      developer.log('Error notifying employees about new season: $e');
    }
  }

  // Create season goals for employee
  static Future<void> _createSeasonGoalsForEmployee(
    Season season,
    String userId,
    String userName,
  ) async {
    try {
      final batch = _firestore.batch();

      // Create a main season participation goal
      final mainGoalRef = _firestore.collection('goals').doc();
      batch.set(mainGoalRef, {
        'userId': userId,
        'title': 'Season Challenge: ${season.title}',
        'description':
            'Participate in the ${season.theme.toLowerCase()} season and complete challenges to earn points and badges.',
        'category': 'work',
        'priority': 'medium',
        'status': 'inProgress',
        'progress': 0,
        'points': 100, // Base participation points
        'createdAt': FieldValue.serverTimestamp(),
        'targetDate': Timestamp.fromDate(season.endDate),
        'seasonId': season.id,
        'seasonTitle': season.title,
        'isSeasonGoal': true,
      });

      // Create individual challenge goals
      for (final challenge in season.challenges) {
        final challengeGoalRef = _firestore.collection('goals').doc();
        batch.set(challengeGoalRef, {
          'userId': userId,
          'title': '${season.title}: ${challenge.title}',
          'description': challenge.description,
          'category': _mapChallengeTypeToGoalCategory(challenge.type),
          'priority': 'medium',
          'status': 'notStarted',
          'progress': 0,
          'points': challenge.points,
          'createdAt': FieldValue.serverTimestamp(),
          'targetDate': Timestamp.fromDate(season.endDate),
          'seasonId': season.id,
          'challengeId': challenge.id,
          'isSeasonGoal': true,
          'milestones': challenge.milestones
              .map(
                (m) => {
                  'id': m.id,
                  'title': m.title,
                  'description': m.description,
                  'points': m.points,
                  'completed': false,
                },
              )
              .toList(),
        });
      }

      await batch.commit();

      // Create alert for employee about season goals created
      await AlertService.createMotivationalAlert(
        userId: userId,
        message:
            'Your season goals for "${season.title}" have been created. Start working on them to earn points!',
      );

      developer.log(
        'Created ${season.challenges.length + 1} season goals for user $userId',
      );
    } catch (e) {
      developer.log('Error creating season goals for employee: $e');
    }
  }

  // Update employee goal progress when season milestone is completed
  static Future<void> _updateEmployeeGoalProgress({
    required String userId,
    required String seasonId,
    required String challengeId,
    required String milestoneId,
    required int points,
  }) async {
    try {
      // Find the corresponding goal for this season challenge
      final goalsQuery = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: userId)
          .where('seasonId', isEqualTo: seasonId)
          .where('challengeId', isEqualTo: challengeId)
          .where('isSeasonGoal', isEqualTo: true)
          .get();

      if (goalsQuery.docs.isNotEmpty) {
        final goalDoc = goalsQuery.docs.first;
        final goalData = goalDoc.data();
        final milestones = List<Map<String, dynamic>>.from(
          goalData['milestones'] ?? [],
        );

        // Update the specific milestone
        for (int i = 0; i < milestones.length; i++) {
          if (milestones[i]['id'] == milestoneId) {
            milestones[i]['completed'] = true;
            break;
          }
        }

        // Calculate overall progress
        final completedMilestones = milestones
            .where((m) => m['completed'] == true)
            .length;
        final totalMilestones = milestones.length;
        final progress = totalMilestones > 0
            ? (completedMilestones / totalMilestones * 100).round()
            : 0;

        final isGoalCompleted = progress == 100;

        // Update the goal
        await goalDoc.reference.update({
          'milestones': milestones,
          'progress': progress,
          'status': isGoalCompleted ? 'completed' : 'inProgress',
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Update user's total points
        await _firestore.collection('users').doc(userId).update({
          'totalPoints': FieldValue.increment(points),
        });

        // Create alert for milestone completion
        await AlertService.createMotivationalAlert(
          userId: userId,
          message: 'You completed a milestone and earned $points points!',
        );

        // If goal is completed, check if season should be completed
        if (isGoalCompleted) {
          await _checkSeasonCompletion(seasonId, userId);
        }

        developer.log(
          'Updated employee goal progress for milestone $milestoneId',
        );
      }
    } catch (e) {
      developer.log('Error updating employee goal progress: $e');
    }
  }

  // Check if season should be completed when a goal is finished
  static Future<void> _checkSeasonCompletion(
    String seasonId,
    String userId,
  ) async {
    try {
      final season = await getSeason(seasonId);
      if (season == null) return;

      // Get all season goals for this user
      final userGoalsQuery = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: userId)
          .where('seasonId', isEqualTo: seasonId)
          .where('isSeasonGoal', isEqualTo: true)
          .get();

      final userGoals = userGoalsQuery.docs;
      final completedGoals = userGoals
          .where((doc) => doc.data()['status'] == 'completed')
          .length;
      final totalGoals = userGoals.length;

      // If user completed all their season goals, award completion badge
      if (completedGoals == totalGoals && totalGoals > 0) {
        await _awardSeasonCompletionBadge(season, userId, 'employee');
      }

      // Check if all participants have completed their goals
      final allParticipants = season.participantIds;
      bool allParticipantsCompleted = true;

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

        if (participantCompletedGoals != participantTotalGoals ||
            participantTotalGoals == 0) {
          allParticipantsCompleted = false;
          break;
        }
      }

      // If all participants completed their goals, complete the season
      if (allParticipantsCompleted) {
        await _completeSeason(season);
      }
    } catch (e) {
      developer.log('Error checking season completion: $e');
    }
  }

  // Complete a season and award final rewards
  static Future<void> _completeSeason(Season season) async {
    try {
      // Update season status
      await updateSeasonStatus(season.id, SeasonStatus.completed);

      // Award completion badges to all participants
      for (final participantId in season.participantIds) {
        await _awardSeasonCompletionBadge(season, participantId, 'employee');
      }

      // Award manager completion badge
      final seasonDoc = await _firestore
          .collection('seasons')
          .doc(season.id)
          .get();
      if (seasonDoc.exists) {
        final seasonData = seasonDoc.data()!;
        final managerId = seasonData['createdBy'];
        if (managerId != null) {
          await _awardSeasonCompletionBadge(season, managerId, 'manager');
        }
      }

      // Create celebration data
      await _createSeasonCelebration(season.id);

      developer.log('Season ${season.id} completed successfully');
    } catch (e) {
      developer.log('Error completing season: $e');
    }
  }

  // Award season completion badge based on role
  static Future<void> _awardSeasonCompletionBadge(
    Season season,
    String userId,
    String role,
  ) async {
    try {
      final badge = role == 'manager'
          ? SeasonBadge(
              id: 'season_manager_champion',
              name: 'Season Manager Champion',
              description:
                  'Successfully led and completed the "${season.title}" season',
              icon: '👑',
              color: '#FFD700',
              points: 200,
              criteria: {'role': 'manager'},
            )
          : SeasonBadge(
              id: 'season_completion_champion',
              name: 'Season Completion Champion',
              description:
                  'Completed all challenges in the "${season.title}" season',
              icon: '🏆',
              color: '#C0C0C0',
              points: 150,
              criteria: {'role': 'employee'},
            );

      // Add badge to season participation (for employees)
      if (role == 'employee') {
        await _firestore.collection('seasons').doc(season.id).update({
          'participations.$userId.badgesEarned': FieldValue.arrayUnion([
            badge.id,
          ]),
          'participations.$userId.totalPoints': FieldValue.increment(
            badge.points,
          ),
        });
      }

      // Sync badge with employee's main badge system
      await _syncBadgeWithEmployeeSystem(userId, badge, season);

      // Create celebration alert
      await AlertService.createMotivationalAlert(
        userId: userId,
        message:
            'Congratulations! You earned the "${badge.name}" badge for completing "${season.title}"!',
      );

      developer.log('Awarded $role completion badge to user $userId');
    } catch (e) {
      developer.log('Error awarding season completion badge: $e');
    }
  }

  // Sync season badge with employee's main badge system
  static Future<void> _syncBadgeWithEmployeeSystem(
    String userId,
    SeasonBadge seasonBadge,
    Season season,
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

      // Update user's total points
      await _firestore.collection('users').doc(userId).update({
        'totalPoints': FieldValue.increment(seasonBadge.points),
        'totalBadges': FieldValue.increment(1),
      });

      // Create a general badge alert (not just season-specific)
      await AlertService.createBadgeAlert(
        userId: userId,
        badgeName: seasonBadge.name,
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

      final seasonId = goalData['seasonId'];
      final challengeId = goalData['challengeId'];
      final points = goalData['points'] ?? 0;

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
      }

      // Check if season should be completed
      if (seasonId != null) {
        await _checkSeasonCompletion(seasonId, userId);
      }

      // Create alert for goal completion
      await AlertService.createMotivationalAlert(
        userId: userId,
        message:
            'Congratulations! You completed "${goalData['title']}" and earned $points points!',
      );

      // Notify manager about employee goal completion
      if (seasonId != null) {
        await _notifyManagerAboutGoalCompletion(
          seasonId,
          userId,
          goalData['title'],
        );
      }

      developer.log('Employee $userId completed season goal $goalId');
    } catch (e) {
      developer.log('Error completing season goal: $e');
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

      // Get employee details
      final employeeDoc = await _firestore
          .collection('users')
          .doc(employeeId)
          .get();
      final employeeName = employeeDoc.exists
          ? (employeeDoc.data()?['displayName'] ?? 'Employee')
          : 'Employee';

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
        'type': 'season_progress_update',
        'priority': allParticipantsCompleted ? 'high' : 'medium',
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
                criteria: {'action': 'start_learning'},
              ),
              SeasonMilestone(
                id: 'milestone_2',
                title: 'Halfway Point',
                description: 'Complete 50% of the module',
                points: 20,
                criteria: {'progress': 50},
              ),
              SeasonMilestone(
                id: 'milestone_3',
                title: 'Module Complete',
                description: 'Complete the entire learning module',
                points: 20,
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
                criteria: {'action': 'skill_assessment'},
              ),
              SeasonMilestone(
                id: 'skill_milestone_2',
                title: 'Practice Sessions',
                description: 'Complete 5 practice sessions',
                points: 30,
                criteria: {'sessions': 5},
              ),
              SeasonMilestone(
                id: 'skill_milestone_3',
                title: 'Skill Demonstration',
                description: 'Demonstrate your improved skill',
                points: 30,
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
                criteria: {'action': 'project_start'},
              ),
              SeasonMilestone(
                id: 'collab_milestone_2',
                title: 'Team Meetings',
                description: 'Participate in 3 team meetings',
                points: 25,
                criteria: {'meetings': 3},
              ),
              SeasonMilestone(
                id: 'collab_milestone_3',
                title: 'Project Completion',
                description: 'Complete the collaborative project',
                points: 20,
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
                criteria: {'action': 'goal_set'},
              ),
              SeasonMilestone(
                id: 'general_milestone_2',
                title: 'Progress Update',
                description: 'Update your progress on the goal',
                points: 15,
                criteria: {'progress': 50},
              ),
              SeasonMilestone(
                id: 'general_milestone_3',
                title: 'Goal Achievement',
                description: 'Complete your personal development goal',
                points: 15,
                criteria: {'progress': 100},
              ),
            ],
            requirements: {'goal_type': 'personal'},
          ),
        ];
    }
  }
}
