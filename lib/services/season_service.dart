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
        status: SeasonStatus.planning,
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
      final seasonDoc = await seasonRef.get();
      if (seasonDoc.exists) {
        final season = Season.fromFirestore(seasonDoc);
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
      }

      await batch.commit();

      // Record activity
      await ManagerRealtimeService.recordEmployeeActivity(
        employeeId: userId,
        activityType: 'season_joined',
        description: 'Joined season: $seasonId',
        metadata: {'seasonId': seasonId},
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
        if (!participation.badgesEarned.contains(badge.id)) {
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
