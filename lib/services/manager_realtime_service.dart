import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:pdh/models/goal.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/one_on_one_meeting_service.dart';
import 'package:pdh/services/manager_badge_evaluator.dart';
import 'package:pdh/services/onboarding_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';

enum TimeFilter { today, week, month, quarter, year }

class EmployeeActivity {
  final String activityId;
  final String userId;
  final String activityType;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const EmployeeActivity({
    required this.activityId,
    required this.userId,
    required this.activityType,
    required this.description,
    required this.timestamp,
    required this.metadata,
  });

  static EmployeeActivity fromMap(Map<String, dynamic> map) {
    return EmployeeActivity(
      activityId: map['activityId'] ?? '',
      userId: map['userId'] ?? '',
      activityType: map['activityType'] ?? 'unknown',
      description: map['description'] ?? '',
      timestamp: map['timestamp'] is DateTime
          ? map['timestamp'] as DateTime
          : DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }
}

class EmployeeData {
  final UserProfile profile;
  final List<Goal> goals;
  final List<EmployeeActivity> recentActivities;
  final List<Alert> recentAlerts;
  final int completedGoalsCount;
  final int overdueGoalsCount;
  final int totalPoints;
  final DateTime lastActivity;
  final double avgProgress;
  final int streakDays;
  final EmployeeStatus status;
  final int weeklyActivityCount;
  final double engagementScore;
  final String motivationLevel;
  // When true, this item was emitted as a fast placeholder while full team data
  // (goals/activities/alerts) is still being fetched/enriched.
  final bool isPlaceholder;

  const EmployeeData({
    required this.profile,
    required this.goals,
    required this.recentActivities,
    required this.recentAlerts,
    required this.completedGoalsCount,
    required this.overdueGoalsCount,
    required this.totalPoints,
    required this.lastActivity,
    required this.avgProgress,
    required this.streakDays,
    required this.status,
    required this.weeklyActivityCount,
    required this.engagementScore,
    required this.motivationLevel,
    this.isPlaceholder = false,
  });

  static EmployeeData fromMap(Map<String, dynamic> map, {String? id}) {
    return EmployeeData(
      profile: map['profile'] is UserProfile
          ? map['profile']
          : UserProfile.fromMap(
              map['profile'] ?? {},
              id: map['profile']?['uid'] ?? id,
            ),
      goals: (map['goals'] as List<dynamic>? ?? [])
          .map((g) => g is Goal ? g : Goal.fromMap(g ?? {}))
          .toList(),
      recentActivities: (map['recentActivities'] as List<dynamic>? ?? [])
          .map(
            (a) =>
                a is EmployeeActivity ? a : EmployeeActivity.fromMap(a ?? {}),
          )
          .toList(),
      recentAlerts: (map['recentAlerts'] as List<dynamic>? ?? [])
          .map((a) => a is Alert ? a : Alert.fromMap(a ?? {}))
          .toList()
          .cast<Alert>(),
      completedGoalsCount: map['completedGoalsCount'] ?? 0,
      overdueGoalsCount: map['overdueGoalsCount'] ?? 0,
      totalPoints: map['totalPoints'] ?? 0,
      lastActivity: map['lastActivity'] is DateTime
          ? map['lastActivity']
          : ManagerRealtimeService._parseDate(map['lastActivity']) ??
                DateTime.now(),
      avgProgress: (map['avgProgress'] is num)
          ? (map['avgProgress'] as num).toDouble()
          : 0.0,
      streakDays: map['streakDays'] ?? 0,
      status: map['status'] is EmployeeStatus
          ? map['status']
          : EmployeeStatus.values.firstWhere(
              (e) => e.name == (map['status']?.toString() ?? ''),
              orElse: () => EmployeeStatus.onTrack,
            ),
      weeklyActivityCount: map['weeklyActivityCount'] ?? 0,
      engagementScore: (map['engagementScore'] is num)
          ? (map['engagementScore'] as num).toDouble()
          : 0.0,
      motivationLevel: map['motivationLevel'] ?? 'Unknown',
      isPlaceholder: map['isPlaceholder'] == true,
    );
  }
}

enum EmployeeStatus { onTrack, atRisk, overdue, inactive }

class TeamInsight {
  final String title;
  final String description;
  final String employeeName;
  final String actionRequired;
  final InsightPriority priority;
  final DateTime createdAt;

  const TeamInsight({
    required this.title,
    required this.description,
    required this.employeeName,
    required this.actionRequired,
    required this.priority,
    required this.createdAt,
  });

  static TeamInsight fromMap(Map<String, dynamic> map, {String? id}) {
    return TeamInsight(
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      employeeName: map['employeeName'] ?? '',
      actionRequired: map['actionRequired'] ?? '',
      priority: InsightPriority.values.firstWhere(
        (e) => e.name == (map['priority']?.toString().toLowerCase() ?? ''),
        orElse: () => InsightPriority.medium,
      ),
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt']
          : ManagerRealtimeService._parseDate(map['createdAt']) ??
                DateTime.now(),
    );
  }
}

enum InsightPriority { low, medium, high, urgent }

enum NudgeType { motivational, deadline, kudos, checkIn, support }

enum ManagementAction {
  sendNudge,
  scheduleMeeting,
  assignGoal,
  reassignGoal,
  giveRecognition,
  provideFeedback,
  escalateIssue,
  adjustWorkload,
  offerSupport,
}

class ManagerAction {
  final String actionId;
  final ManagementAction actionType;
  final String employeeId;
  final String employeeName;
  final String description;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final String status; // pending, completed, cancelled
  final DateTime? completedAt;

  const ManagerAction({
    required this.actionId,
    required this.actionType,
    required this.employeeId,
    required this.employeeName,
    required this.description,
    required this.details,
    required this.createdAt,
    required this.status,
    this.completedAt,
  });

  factory ManagerAction.fromMap(Map<String, dynamic> data, {String? id}) {
    return ManagerAction(
      actionId: id ?? (data['actionId'] ?? data['id'] ?? '').toString(),
      actionType: ManagementAction.values.firstWhere(
        (e) => e.name == (data['actionType'] ?? '').toString(),
        orElse: () => ManagementAction.sendNudge,
      ),
      employeeId: data['employeeId']?.toString() ?? '',
      employeeName: data['employeeName']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      details: Map<String, dynamic>.from(data['details'] ?? {}),
      createdAt:
          ManagerRealtimeService._parseDate(data['createdAt']) ??
          DateTime.now(),
      status: data['status']?.toString() ?? 'pending',
      completedAt: ManagerRealtimeService._parseDate(data['completedAt']),
    );
  }
}

class TeamMetrics {
  final int totalEmployees;
  final int activeEmployees;
  final int onTrackGoals;
  final int atRiskGoals;
  final int overdueGoals;
  final double avgTeamProgress;
  final double teamEngagement;
  final int totalPointsEarned;
  final int goalsCompleted;
  final DateTime lastUpdated;

  const TeamMetrics({
    required this.totalEmployees,
    required this.activeEmployees,
    required this.onTrackGoals,
    required this.atRiskGoals,
    required this.overdueGoals,
    required this.avgTeamProgress,
    required this.teamEngagement,
    required this.totalPointsEarned,
    required this.goalsCompleted,
    required this.lastUpdated,
  });
}

class DailyNudgeStat {
  final DateTime date;
  final int nudgesSent;
  final int followUpActions;

  const DailyNudgeStat({
    required this.date,
    required this.nudgesSent,
    required this.followUpActions,
  });
}

class EmployeeNudgeMetric {
  final String employeeId;
  final int unreadCount;
  final int urgentCount;
  final DateTime? lastNudgedAt;

  const EmployeeNudgeMetric({
    required this.employeeId,
    required this.unreadCount,
    required this.urgentCount,
    required this.lastNudgedAt,
  });
}

class NudgeAnalyticsSummary {
  final int totalNudges;
  final int nudgesLast7Days;
  final int uniqueRecipientsLast7Days;
  final int unreadNudges;
  final int readNudges;
  final int dismissedNudges;
  final List<DailyNudgeStat> trend;
  final Map<String, int> templateBreakdown;
  final List<EmployeeNudgeMetric> outstandingEmployees;
  final DateTime generatedAt;

  const NudgeAnalyticsSummary({
    required this.totalNudges,
    required this.nudgesLast7Days,
    required this.uniqueRecipientsLast7Days,
    required this.unreadNudges,
    required this.readNudges,
    required this.dismissedNudges,
    required this.trend,
    required this.templateBreakdown,
    required this.outstandingEmployees,
    required this.generatedAt,
  });

  factory NudgeAnalyticsSummary.empty() {
    return NudgeAnalyticsSummary(
      totalNudges: 0,
      nudgesLast7Days: 0,
      uniqueRecipientsLast7Days: 0,
      unreadNudges: 0,
      readNudges: 0,
      dismissedNudges: 0,
      trend: const [],
      templateBreakdown: const {},
      outstandingEmployees: const [],
      generatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _EmployeeNudgeAccumulator {
  int unread = 0;
  int urgent = 0;
  DateTime? lastNudgedAt;
}

class ManagerRealtimeService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final BackendAuthService _backend = BackendAuthService.instance;

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static Future<Map<String, List<Goal>>> _fetchGoalsByEmployees(
    List<String> employeeIds,
    DateTime startDate,
  ) async {
    final map = <String, List<Goal>>{};
    await Future.wait(
      employeeIds.map((id) async {
        try {
          final items = await _backend.getGoals(userId: id, limit: 500);
          map[id] = items
              .map((g) => Goal.fromMap(g))
              .where((g) {
                return g.createdAt.isAfter(startDate) ||
                    (g.status != GoalStatus.completed &&
                        g.status != GoalStatus.paused);
              })
              .toList();
        } catch (_) {
          map[id] = [];
        }
      }),
    );
    return map;
  }

  static Future<Map<String, List<EmployeeActivity>>> _fetchActivitiesByEmployees(
    List<String> employeeIds,
  ) async {
    final map = <String, List<EmployeeActivity>>{};
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    await Future.wait(
      employeeIds.map((id) async {
        try {
          final items = await _backend.getActivities(id, limit: 200);
          map[id] = items
              .map((a) => EmployeeActivity.fromMap(a))
              .where((a) => a.timestamp.isAfter(cutoff))
              .toList();
        } catch (_) {
          map[id] = [];
        }
      }),
    );
    return map;
  }

  static Future<Map<String, List<Alert>>> _fetchAlertsByEmployees(
    List<String> employeeIds,
  ) async {
    final map = <String, List<Alert>>{};
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    await Future.wait(
      employeeIds.map((id) async {
        try {
          final items = await _backend.getAlerts(id, limit: 200);
          map[id] = items
              .map((a) => Alert.fromMap(a))
              .where((a) {
                if (a.isDismissed) return false;
                final created = _parseDate(a.createdAt) ?? DateTime.now();
                return created.isAfter(cutoff);
              })
              .toList();
        } catch (_) {
          map[id] = [];
        }
      }),
    );
    return map;
  }

  /// Ensure the app has an authenticated user. Will attempt anonymous sign-in
  /// if no user exists. Make sure Anonymous Auth is enabled in the Firebase console
  /// if you want this to work.
  Future<void> _ensureSignedIn() async {
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
      if (kDebugMode) {
        debugPrint('Signed in anonymously: ${_auth.currentUser?.uid}');
      }
    } on FirebaseAuthException catch (e, st) {
      if (kDebugMode) debugPrint('Anonymous sign-in failed: $e\n$st');
      // Let callers handle lack of auth; do not rethrow here to allow UI to show helpful message.
    }
  }

  /// Fetch onboarding employees and convert to UserProfile objects
  static Future<List<UserProfile>> _fetchOnboardingEmployees(
    String? department,
  ) async {
    try {
      String norm(String? s) => (s ?? '').trim().toLowerCase();

      final items = await OnboardingService.listOnboardingRecords(limit: 500);

      final onboardingProfiles = items
          .where((data) {
            final moduleAccessRole = data['moduleAccessRole'] as String?;
            return OnboardingService.shouldIncludeUser(
              moduleAccessRole,
              'employee',
            );
          })
          .map((data) {
            final uid =
                (data['userId'] ?? data['id'] ?? data['uid'] ?? '').toString();
            final convertedData =
                OnboardingService.convertOnboardingUserToUserFormat(
                  data,
                  uid,
                );

            return UserProfile(
              uid: uid,
              email: convertedData['email'] ?? '',
              displayName: convertedData['displayName'] ?? 'Unknown User',
              totalPoints: (convertedData['totalPoints'] ?? 0) as int,
              level: (convertedData['level'] ?? 1) as int,
              badges: List<String>.from(convertedData['badges'] ?? const []),
              role: convertedData['role'] ?? 'employee',
              jobTitle: convertedData['jobTitle'] ?? '',
              department: convertedData['department'] ?? '',
              phoneNumber: convertedData['phoneNumber'] ?? '',
              profilePhotoUrl: convertedData['profilePhotoUrl'],
              skills: List<String>.from(convertedData['skills'] ?? const []),
              developmentAreas: List<String>.from(
                convertedData['developmentAreas'] ?? const [],
              ),
              careerAspirations: convertedData['careerAspirations'] ?? '',
              currentProjects: convertedData['currentProjects'] ?? '',
              learningStyle: convertedData['learningStyle'] ?? '',
              preferredDevActivities: List<String>.from(
                convertedData['preferredDevActivities'] ?? const [],
              ),
              shortGoals: convertedData['shortGoals'] ?? '',
              longGoals: convertedData['longGoals'] ?? '',
              notificationFrequency:
                  convertedData['notificationFrequency'] ?? 'daily',
              goalVisibility: convertedData['goalVisibility'] ?? 'private',
              leaderboardOptin: convertedData['leaderboardOptin'] ?? false,
              badgeName: convertedData['badgeName'] ?? '',
              celebrationConsent:
                  convertedData['celebrationConsent'] ?? 'private',
              lastLoginAt: _parseDate(convertedData['lastLoginAt']),
            );
          })
          .where((profile) => profile.uid.isNotEmpty)
          .toList();

      if (department != null && department.trim().isNotEmpty) {
        final target = norm(department);
        return onboardingProfiles
            .where((profile) => norm(profile.department) == target)
            .toList();
      }

      return onboardingProfiles;
    } catch (e) {
      developer.log('Error fetching onboarding employees: $e');
      return [];
    }
  }

  /// Fetches the set of user IDs that have been permanently deleted (in deleted_accounts).
  /// Used to exclude deleted employees from team review and all manager-side lists.
  static Future<Set<String>> getDeletedAccountUids() async {
    try {
      final ids = await _backend.getDeletedAccountIds();
      return ids.toSet();
    } catch (e) {
      developer.log('Error fetching deleted_accounts: $e');
      return {};
    }
  }

  Stream<List<EmployeeData>> employeesStream() {
    return getTeamDataStream();
  }

  Stream<TeamMetrics?> teamMetricsStream() async* {
    await _ensureSignedIn();
    yield* employeesStream().map((employees) {
      if (employees.isEmpty) return null;
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final totalEmployees = employees.length;
      final activeEmployees = employees
          .where((e) => e.lastActivity.isAfter(sevenDaysAgo))
          .length;
      final avgProgress = totalEmployees > 0
          ? employees.map((e) => e.avgProgress).fold(0.0, (a, b) => a + b) /
                totalEmployees
          : 0.0;
      final engagement = totalEmployees > 0
          ? (activeEmployees / totalEmployees) * 100.0
          : 0.0;
      return TeamMetrics(
        totalEmployees: totalEmployees,
        activeEmployees: activeEmployees,
        avgTeamProgress: avgProgress,
        teamEngagement: engagement,
        onTrackGoals: employees.fold<int>(0, (acc, e) {
          final onTrack = e.goals
              .where(
                (g) =>
                    g.status != GoalStatus.completed &&
                    g.targetDate.isAfter(DateTime.now()) &&
                    g.progress >= 30,
              )
              .length;
          return acc + onTrack;
        }),
        atRiskGoals: employees.fold<int>(0, (acc, e) {
          final atRisk = e.goals
              .where(
                (g) =>
                    g.status != GoalStatus.completed &&
                    g.targetDate.isAfter(DateTime.now()) &&
                    g.progress < 30,
              )
              .length;
          return acc + atRisk;
        }),
        overdueGoals: employees.fold<int>(
          0,
          (acc, e) => acc + (e.overdueGoalsCount),
        ),
        totalPointsEarned: employees.fold<int>(
          0,
          (acc, e) => acc + e.totalPoints,
        ),
        goalsCompleted: employees.fold<int>(
          0,
          (acc, e) => acc + e.completedGoalsCount,
        ),
        lastUpdated: DateTime.now(),
      );
    });
  }

  static Future<NudgeAnalyticsSummary> fetchManagerNudgeAnalytics({
    int lookbackDays = 30,
  }) async {
    final service = ManagerRealtimeService();
    await service._ensureSignedIn();

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return NudgeAnalyticsSummary.empty();
    }

    final now = DateTime.now();
    final since = now.subtract(Duration(days: lookbackDays));

    try {
      final allActions = await _backend.getManagerActions(
        currentUser.uid,
        limit: 1000,
      );
      final actionsQuery = allActions.where((data) {
        final createdAt = _parseDate(data['createdAt']);
        return createdAt != null && !createdAt.isBefore(since);
      }).toList();

      final allAlerts = await _backend.getCollectionItems('alerts', limit: 1000);
      final alertsQuery = allAlerts.where((data) {
        final type = (data['type'] ?? '').toString();
        if (type != AlertType.managerNudge.name) return false;
        final fromUserId = (data['fromUserId'] ?? '').toString();
        if (fromUserId != currentUser.uid) return false;
        final createdAt = _parseDate(data['createdAt']);
        return createdAt != null && !createdAt.isBefore(since);
      }).toList();

      final Map<DateTime, int> nudgesByDay = {};
      final Map<DateTime, int> followUpsByDay = {};
      final Map<String, int> templateBreakdown = {};
      final Set<String> recipientsLast7Days = {};

      int totalNudges = 0;
      int nudgesLast7Days = 0;

      for (final data in actionsQuery) {
        final actionType = (data['actionType'] ?? '').toString();
        final createdAt = _parseDate(data['createdAt']) ?? now;
        final dayKey = DateTime(createdAt.year, createdAt.month, createdAt.day);

        if (actionType == ManagementAction.sendNudge.name) {
          totalNudges++;
          nudgesByDay[dayKey] = (nudgesByDay[dayKey] ?? 0) + 1;
          if (createdAt.isAfter(now.subtract(const Duration(days: 7)))) {
            nudgesLast7Days++;
            final employeeId = (data['employeeId'] ?? '').toString();
            if (employeeId.isNotEmpty) {
              recipientsLast7Days.add(employeeId);
            }
          }

          final details = data['details'];
          final nudgeType = details is Map && details['nudgeType'] != null
              ? details['nudgeType'].toString()
              : 'custom';
          templateBreakdown[nudgeType] =
              (templateBreakdown[nudgeType] ?? 0) + 1;
        } else {
          followUpsByDay[dayKey] = (followUpsByDay[dayKey] ?? 0) + 1;
        }
      }

      int readNudges = 0;
      int dismissedNudges = 0;

      final Map<String, _EmployeeNudgeAccumulator> employeeAccum = {};

      for (final data in alertsQuery) {
        final userId = (data['userId'] ?? '').toString();
        final isRead = data['isRead'] == true;
        final isDismissed = data['isDismissed'] == true;
        final priority = (data['priority'] ?? '').toString();
        final createdAt = _parseDate(data['createdAt']) ?? now;

        if (isRead) {
          readNudges++;
        }
        if (isDismissed) {
          dismissedNudges++;
        }

        if (userId.isEmpty) continue;

        final accumulator = employeeAccum.putIfAbsent(
          userId,
          () => _EmployeeNudgeAccumulator(),
        );

        if (!isRead && !isDismissed) {
          accumulator.unread += 1;
        }
        if (priority == AlertPriority.urgent.name) {
          accumulator.urgent += 1;
        }
        if (accumulator.lastNudgedAt == null ||
            createdAt.isAfter(accumulator.lastNudgedAt!)) {
          accumulator.lastNudgedAt = createdAt;
        }
      }

      final unreadNudges = alertsQuery.length - readNudges - dismissedNudges;

      final List<EmployeeNudgeMetric> outstandingEmployees =
          employeeAccum.entries
              .map(
                (entry) => EmployeeNudgeMetric(
                  employeeId: entry.key,
                  unreadCount: entry.value.unread,
                  urgentCount: entry.value.urgent,
                  lastNudgedAt: entry.value.lastNudgedAt,
                ),
              )
              .where(
                (metric) => metric.unreadCount > 0 || metric.urgentCount > 0,
              )
              .toList()
            ..sort((a, b) {
              if (b.urgentCount != a.urgentCount) {
                return b.urgentCount.compareTo(a.urgentCount);
              }
              if (b.unreadCount != a.unreadCount) {
                return b.unreadCount.compareTo(a.unreadCount);
              }
              final aTime =
                  a.lastNudgedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  b.lastNudgedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

      final today = DateTime(now.year, now.month, now.day);
      final List<DailyNudgeStat> trend = List.generate(14, (index) {
        final day = today.subtract(Duration(days: 13 - index));
        return DailyNudgeStat(
          date: day,
          nudgesSent: nudgesByDay[day] ?? 0,
          followUpActions: followUpsByDay[day] ?? 0,
        );
      });

      return NudgeAnalyticsSummary(
        totalNudges: totalNudges,
        nudgesLast7Days: nudgesLast7Days,
        uniqueRecipientsLast7Days: recipientsLast7Days.length,
        unreadNudges: unreadNudges < 0 ? 0 : unreadNudges,
        readNudges: readNudges,
        dismissedNudges: dismissedNudges,
        trend: trend,
        templateBreakdown: templateBreakdown,
        outstandingEmployees: outstandingEmployees,
        generatedAt: DateTime.now(),
      );
    } catch (e, st) {
      developer.log('fetchManagerNudgeAnalytics error: $e', stackTrace: st);
      rethrow;
    }
  }

  Stream<List<TeamInsight>> teamInsightsStream() async* {
    await _ensureSignedIn();
    yield* getTeamInsightsStream();
  }

  /// Convenience single-read for an employee (optional).
  Future<EmployeeData?> getEmployeeById(String id) async {
    try {
      Map<String, dynamic>? data;
      try {
        data = await _backend.getUser(id);
      } catch (_) {}

      if (data == null || data.isEmpty) {
        final items = await _backend.getCollectionItems('employees', limit: 500);
        for (final item in items) {
          final itemId = (item['id'] ?? item['uid'] ?? '').toString();
          if (itemId == id) {
            data = item;
            break;
          }
        }
      }

      if (data == null || data.isEmpty) return null;
      return EmployeeData.fromMap(data, id: id);
    } catch (e, st) {
      if (kDebugMode) debugPrint('getEmployeeById error: $e\n$st');
      return null;
    }
  }

  // Stream real-time team data based on current manager
  static const int _initialEmployeeLimit =
      10000; // Show all employees for managers (avoid silently dropping users)

  /// One-time fetch equivalent of [getTeamDataStream] (no live listeners).
  ///
  /// Useful on Flutter Web to avoid listener churn during rebuilds/navigation.
  static Future<List<EmployeeData>> getTeamDataOnce({
    String? department,
    TimeFilter timeFilter = TimeFilter.month,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return <EmployeeData>[];

      // TEMP: allow managers to view all employees regardless of department unless explicitly filtered
      final String? explicitDepartment =
          (department != null && department.trim().isNotEmpty)
              ? department.trim()
              : null;

      String norm(String? s) => (s ?? '').trim().toLowerCase();

      bool includeEmployeeProfile(UserProfile p) {
        // Treat missing/blank role as employee (many parts of the app default this way)
        final role = norm(p.role).isEmpty ? 'employee' : norm(p.role);
        if (role != 'employee') return false;
        if (explicitDepartment == null) return true;
        return norm(p.department) == norm(explicitDepartment);
      }

      final users = await _backend.listUsers(limit: _initialEmployeeLimit);
      final deletedUids = await getDeletedAccountUids();
      final onboardingProfiles =
          await ManagerRealtimeService._fetchOnboardingEmployees(department);

      final regularEmployeeProfiles = users
          .where((data) {
            final uid =
                (data['userId'] ?? data['id'] ?? data['uid'] ?? '').toString();
            if (uid.isEmpty || deletedUids.contains(uid)) return false;
            final profile = UserProfile.fromMap(data, id: uid);
            return includeEmployeeProfile(profile);
          })
          .map((data) => UserProfile.fromMap(
                data,
                id: (data['userId'] ?? data['id'] ?? data['uid'] ?? '').toString(),
              ))
          .toList();

      // Exclude deleted accounts from onboarding list
      final activeOnboardingProfiles = onboardingProfiles
          .where((p) => !deletedUids.contains(p.uid))
          .toList();

      final regularEmployeeIds =
          regularEmployeeProfiles.map((p) => p.uid).toList();

      // Get onboarding employee IDs
      final onboardingEmployeeIds =
          activeOnboardingProfiles.map((profile) => profile.uid).toList();

      // Combine all employee IDs
      final allEmployeeIds = <String>[...regularEmployeeIds, ...onboardingEmployeeIds];

      if (allEmployeeIds.isEmpty) {
        return <EmployeeData>[];
      }

      final startDate = _getStartDateForFilter(timeFilter);
      final goalsByEmployee =
          await _fetchGoalsByEmployees(allEmployeeIds, startDate);
      final activitiesByEmployee =
          await _fetchActivitiesByEmployees(allEmployeeIds);
      final alertsByEmployee = await _fetchAlertsByEmployees(allEmployeeIds);

      final now = DateTime.now();
      final employeeDataList = <EmployeeData>[];

      for (final userProfile in regularEmployeeProfiles) {
        final rawAlerts = alertsByEmployee[userProfile.uid] ?? [];
        final activeAlerts = rawAlerts.where((a) {
          if (a.isDismissed) return false;
          if (a.expiresAt != null && a.expiresAt!.isBefore(now)) return false;
          return true;
        }).toList();
        final employeeData = await _buildEmployeeData(
          userProfile,
          timeFilter,
          goalsByEmployee[userProfile.uid] ?? [],
          activitiesByEmployee[userProfile.uid] ?? [],
          activeAlerts,
        );
        employeeDataList.add(employeeData);
      }

      for (final userProfile in activeOnboardingProfiles) {
        final rawAlerts = alertsByEmployee[userProfile.uid] ?? [];
        final activeAlerts = rawAlerts.where((a) {
          if (a.isDismissed) return false;
          if (a.expiresAt != null && a.expiresAt!.isBefore(now)) return false;
          return true;
        }).toList();
        final employeeData = await _buildEmployeeData(
          userProfile,
          timeFilter,
          goalsByEmployee[userProfile.uid] ?? [],
          activitiesByEmployee[userProfile.uid] ?? [],
          activeAlerts,
        );
        employeeDataList.add(employeeData);
      }

      employeeDataList.sort((a, b) {
        final aRisk = _getRiskScore(a);
        final bRisk = _getRiskScore(b);
        if (aRisk != bRisk) return bRisk.compareTo(aRisk);
        return b.totalPoints.compareTo(a.totalPoints);
      });

      return employeeDataList;
    } catch (e) {
      developer.log('getTeamDataOnce error: $e');
      return <EmployeeData>[];
    }
  }

  static Stream<List<EmployeeData>> getTeamDataStream({
    String? department,
    TimeFilter timeFilter = TimeFilter.month,
  }) {
    return createManagedPollingStream<List<EmployeeData>>(
      fetch: () => getTeamDataOnce(
        department: department,
        timeFilter: timeFilter,
      ),
      initialValue: const [],
    );
  }

  // Get real-time team metrics
  static Stream<TeamMetrics> getTeamMetricsStream({
    String? department,
    TimeFilter timeFilter = TimeFilter.month,
  }) {
    return getTeamDataStream(
      department: department,
      timeFilter: timeFilter,
    ).map((employees) {
      final now = DateTime.now();
      final activeThreshold = now.subtract(const Duration(days: 7));

      int activeCount = 0;
      int onTrackCount = 0;
      int atRiskCount = 0;
      int overdueCount = 0;
      int totalPoints = 0;
      int totalGoalsCompleted = 0;
      double totalProgress = 0;

      for (final employee in employees) {
        if (employee.lastActivity.isAfter(activeThreshold)) {
          activeCount++;
        }

        switch (employee.status) {
          case EmployeeStatus.onTrack:
            onTrackCount++;
            break;
          case EmployeeStatus.atRisk:
            atRiskCount++;
            break;
          case EmployeeStatus.overdue:
            overdueCount++;
            break;
          case EmployeeStatus.inactive:
            // Don't count towards any status
            break;
        }

        totalPoints += employee.totalPoints;
        totalGoalsCompleted += employee.completedGoalsCount;
        totalProgress += employee.avgProgress;
      }

      final avgProgress = employees.isNotEmpty
          ? totalProgress / employees.length
          : 0.0;
      final engagement = employees.isNotEmpty
          ? (activeCount / employees.length) * 100
          : 0.0;

      return TeamMetrics(
        totalEmployees: employees.length,
        activeEmployees: activeCount,
        onTrackGoals: onTrackCount,
        atRiskGoals: atRiskCount,
        overdueGoals: overdueCount,
        avgTeamProgress: avgProgress,
        teamEngagement: engagement,
        totalPointsEarned: totalPoints,
        goalsCompleted: totalGoalsCompleted,
        lastUpdated: DateTime.now(),
      );
    });
  }

  /// One-time fetch equivalent of [getManagersDataStream].
  static Future<List<EmployeeData>> getManagersDataOnce({
    TimeFilter timeFilter = TimeFilter.month,
  }) async {
    try {
      final deletedUids = await getDeletedAccountUids();
      final users = await _backend.listUsers(role: 'manager', limit: 200);

      final managerProfiles = users
          .where((data) {
            final uid =
                (data['userId'] ?? data['id'] ?? data['uid'] ?? '').toString();
            if (uid.isEmpty || deletedUids.contains(uid)) return false;
            final profile = UserProfile.fromMap(data, id: uid);
            return profile.role.trim().toLowerCase() == 'manager';
          })
          .map(
            (data) => UserProfile.fromMap(
              data,
              id: (data['userId'] ?? data['id'] ?? data['uid'] ?? '')
                  .toString(),
            ),
          )
          .toList();

      if (managerProfiles.isEmpty) {
        return <EmployeeData>[];
      }

      final managerIds = managerProfiles.map((p) => p.uid).toList();
      final startDate = _getStartDateForFilter(timeFilter);
      final goalsByEmployee =
          await _fetchGoalsByEmployees(managerIds, startDate);
      final activitiesByEmployee =
          await _fetchActivitiesByEmployees(managerIds);
      final alertsByEmployee = await _fetchAlertsByEmployees(managerIds);

      final now = DateTime.now();
      final dataList = <EmployeeData>[];

      for (final userProfile in managerProfiles) {
        final rawAlerts = alertsByEmployee[userProfile.uid] ?? [];
        final activeAlerts = rawAlerts.where((a) {
          if (a.isDismissed) return false;
          if (a.expiresAt != null && a.expiresAt!.isBefore(now)) return false;
          return true;
        }).toList();
        final employeeData = await _buildEmployeeData(
          userProfile,
          timeFilter,
          goalsByEmployee[userProfile.uid] ?? [],
          activitiesByEmployee[userProfile.uid] ?? [],
          activeAlerts,
        );
        dataList.add(employeeData);
      }

      dataList.sort((a, b) {
        final aRisk = _getRiskScore(a);
        final bRisk = _getRiskScore(b);
        if (aRisk != bRisk) return bRisk.compareTo(aRisk);
        return b.totalPoints.compareTo(a.totalPoints);
      });

      return dataList;
    } catch (e) {
      developer.log('getManagersDataOnce error: $e');
      return <EmployeeData>[];
    }
  }

  /// Stream of all users with role == 'manager', as [EmployeeData].
  /// Used by the admin dashboard to show manager KPIs and comparisons.
  static Stream<List<EmployeeData>> getManagersDataStream({
    TimeFilter timeFilter = TimeFilter.month,
  }) {
    return createManagedPollingStream<List<EmployeeData>>(
      fetch: () => getManagersDataOnce(timeFilter: timeFilter),
      initialValue: const [],
    );
  }

  /// For admin oversight: stream of managers only. If [selectedManagerId] is
  /// set, returns a stream of at most one manager (for drill-down). No employees.
  static Stream<List<EmployeeData>> getManagersDataStreamForAdmin({
    TimeFilter timeFilter = TimeFilter.month,
    String? selectedManagerId,
  }) {
    final stream = getManagersDataStream(timeFilter: timeFilter);
    if (selectedManagerId == null || selectedManagerId.isEmpty) {
      return stream;
    }
    return stream.map((list) =>
        list.where((e) => e.profile.uid == selectedManagerId).toList());
  }

  // Get AI-generated insights for the team
  static Stream<List<TeamInsight>> getTeamInsightsStream({
    String? department,
    TimeFilter timeFilter = TimeFilter.month,
  }) {
    return getTeamDataStream(
      department: department,
      timeFilter: timeFilter,
    ).map((employees) {
      final insights = <TeamInsight>[];
      final now = DateTime.now();

      for (final employee in employees) {
        // Check for overdue goals
        if (employee.overdueGoalsCount > 0) {
          insights.add(
            TeamInsight(
              title: 'Overdue Goals Detected',
              description:
                  '${employee.profile.displayName} has ${employee.overdueGoalsCount} overdue goal${employee.overdueGoalsCount > 1 ? 's' : ''}.',
              employeeName: employee.profile.displayName,
              actionRequired:
                  'Schedule 1:1 meeting to discuss blockers and provide support',
              priority: InsightPriority.urgent,
              createdAt: now,
            ),
          );
        }

        // Check for low progress
        if (employee.avgProgress < 30 && employee.goals.isNotEmpty) {
          insights.add(
            TeamInsight(
              title: 'Low Progress Alert',
              description:
                  '${employee.profile.displayName} has average goal progress of ${employee.avgProgress.toStringAsFixed(1)}%.',
              employeeName: employee.profile.displayName,
              actionRequired:
                  'Send motivational nudge or offer additional resources',
              priority: InsightPriority.high,
              createdAt: now,
            ),
          );
        }

        // Check for inactivity
        final daysSinceActivity = now.difference(employee.lastActivity).inDays;
        if (daysSinceActivity > 7) {
          insights.add(
            TeamInsight(
              title: 'Employee Inactive',
              description:
                  '${employee.profile.displayName} has been inactive for $daysSinceActivity days.',
              employeeName: employee.profile.displayName,
              actionRequired: 'Reach out to check on engagement and well-being',
              priority: InsightPriority.medium,
              createdAt: now,
            ),
          );
        }

        // Check for high performance
        if (employee.avgProgress > 80 && employee.completedGoalsCount > 2) {
          insights.add(
            TeamInsight(
              title: 'High Performer',
              description:
                  '${employee.profile.displayName} is excelling with ${employee.avgProgress.toStringAsFixed(1)}% average progress.',
              employeeName: employee.profile.displayName,
              actionRequired: 'Consider offering stretch goals or recognition',
              priority: InsightPriority.low,
              createdAt: now,
            ),
          );
        }
      }

      // Sort by priority
      insights.sort((a, b) {
        final priorityOrder = {
          InsightPriority.urgent: 0,
          InsightPriority.high: 1,
          InsightPriority.medium: 2,
          InsightPriority.low: 3,
        };
        return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
      });

      return insights.take(10).toList(); // Limit to top 10 insights
    });
  }

  // Build comprehensive employee data
  static Future<EmployeeData> _buildEmployeeData(
    UserProfile profile,
    TimeFilter timeFilter,
    List<Goal> allEmployeeGoals,
    List<EmployeeActivity> allEmployeeActivities,
    List<Alert> allEmployeeAlerts,
  ) async {
    try {
      final meaningfulGoals =
          allEmployeeGoals.where((g) => g.isDisplayableGoal).toList();
      final startDate = _getStartDateForFilter(timeFilter);

      final goals = meaningfulGoals.where((g) {
        final createdRecently = g.createdAt.isAfter(startDate);
        final isActive =
            !_isGoalCompleted(g) && g.status != GoalStatus.paused;
        return createdRecently || isActive;
      }).toList();

      final completedGoals = meaningfulGoals
          .where((g) => _isGoalCompleted(g))
          .length;
      final overdueGoals = meaningfulGoals
          .where(
            (g) =>
                !_isGoalCompleted(g) && g.targetDate.isBefore(DateTime.now()),
          )
          .length;

      final avgProgress = meaningfulGoals.isNotEmpty
          ? meaningfulGoals.map((g) => g.progress).fold(0.0, (a, b) => a + b) /
                meaningfulGoals.length
          : 0.0;

      allEmployeeActivities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final now = DateTime.now();
      bool isValidActivityTimestamp(DateTime ts) {
        // Guard against bad/missing timestamps becoming "now" and incorrectly
        // marking an employee as active.
        if (ts.year < 2000) return false;
        // Allow small clock skew between server and device.
        if (ts.isAfter(now.add(const Duration(minutes: 10)))) return false;
        return true;
      }

      // "Last active" should come from the most recent of:
      // - the newest activity record we have
      // - users.lastActivityAt (updated by recordEmployeeActivity and other actions)
      // - users.lastLoginAt
      DateTime? mostRecent;
      if (allEmployeeActivities.isNotEmpty) {
        for (final act in allEmployeeActivities) {
          if (isValidActivityTimestamp(act.timestamp)) {
            mostRecent = act.timestamp;
            break;
          }
        }
      }
      final profileLastActivityAt = profile.lastActivityAt;
      if (profileLastActivityAt != null &&
          (mostRecent == null || profileLastActivityAt.isAfter(mostRecent))) {
        mostRecent = profileLastActivityAt;
      }
      final profileLastLoginAt = profile.lastLoginAt;
      if (profileLastLoginAt != null &&
          (mostRecent == null || profileLastLoginAt.isAfter(mostRecent))) {
        mostRecent = profileLastLoginAt;
      }

      final lastActivity =
          mostRecent ?? now.subtract(const Duration(days: 30));

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final recentDocs = allEmployeeActivities
          .where(
            (act) =>
                act.timestamp.isAfter(thirtyDaysAgo) &&
                isValidActivityTimestamp(act.timestamp),
          )
          .toList();

      final streakDays = _calculateStreakDaysFromActivities(recentDocs);
      final recentActivities = recentDocs.take(10).toList();

      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final weeklyActivityCount = allEmployeeActivities
          .where(
            (act) =>
                act.timestamp.isAfter(sevenDaysAgo) &&
                isValidActivityTimestamp(act.timestamp),
          )
          .length;

      final engagementScore = (weeklyActivityCount / 7) * 100.0;

      final status = _determineEmployeeStatus(meaningfulGoals, lastActivity);

      return EmployeeData(
        profile: profile,
        goals: goals,
        recentActivities: recentActivities,
        recentAlerts: allEmployeeAlerts,
        completedGoalsCount: completedGoals,
        overdueGoalsCount: overdueGoals,
        totalPoints: profile.totalPoints,
        lastActivity: lastActivity,
        avgProgress: avgProgress,
        streakDays: streakDays,
        status: status,
        weeklyActivityCount: weeklyActivityCount,
        engagementScore: engagementScore,
        motivationLevel: 'N/A', // This can be enhanced later
      );
    } catch (e) {
      developer.log('Error building employee data for ${profile.uid}: $e');
      // Return default data if error occurs
      return EmployeeData(
        profile: profile,
        goals: [],
        recentActivities: const [],
        recentAlerts: const [],
        completedGoalsCount: 0,
        overdueGoalsCount: 0,
        totalPoints: profile.totalPoints,
        lastActivity: DateTime.now().subtract(const Duration(days: 30)),
        avgProgress: 0.0,
        streakDays: 0,
        status: EmployeeStatus.inactive,
        weeklyActivityCount: 0,
        engagementScore: 0.0,
        motivationLevel: 'Unknown',
      );
    }
  }

  // Determine employee status based on goals and activity
  static EmployeeStatus _determineEmployeeStatus(
    List<Goal> goals,
    DateTime lastActivity,
  ) {
    final now = DateTime.now();
    final inactiveThreshold = now.subtract(const Duration(days: 14));

    if (lastActivity.isBefore(inactiveThreshold)) {
      return EmployeeStatus.inactive;
    }

    final activeGoals = goals.where((g) => !_isGoalCompleted(g)).toList();

    if (activeGoals.isEmpty) {
      return EmployeeStatus.onTrack;
    }

    final overdueGoals = activeGoals
        .where((g) => g.targetDate.isBefore(now))
        .length;
    final dueSoonGoals = activeGoals
        .where(
          (g) =>
              g.targetDate.isAfter(now) &&
              g.targetDate.isBefore(now.add(const Duration(days: 3))),
        )
        .length;

    if (overdueGoals > 0) {
      return EmployeeStatus.overdue;
    } else if (dueSoonGoals > 0 || activeGoals.any((g) => g.progress < 30)) {
      return EmployeeStatus.atRisk;
    } else {
      return EmployeeStatus.onTrack;
    }
  }

  static bool _isGoalCompleted(Goal goal) {
    return goal.status == GoalStatus.completed ||
        goal.status == GoalStatus.acknowledged ||
        goal.progress >= 100;
  }

  // Calculate streak days from activity documents
  static int _calculateStreakDaysFromActivities(
    List<EmployeeActivity> activities,
  ) {
    if (activities.isEmpty) return 0;

    final now = DateTime.now();
    final activityDates = activities
        .map((a) {
          final ts = a.timestamp;
          return '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
        })
        .toSet()
        .toList();

    activityDates.sort((a, b) => b.compareTo(a));

    final today = DateTime(now.year, now.month, now.day);
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (!activityDates.contains(todayString)) {
      return 0;
    }

    int streakDays = 0;
    for (int i = 0; i < activityDates.length; i++) {
      final expectedDate = today.subtract(Duration(days: i));
      final expectedString =
          '${expectedDate.year}-${expectedDate.month.toString().padLeft(2, '0')}-${expectedDate.day.toString().padLeft(2, '0')}';

      if (activityDates.contains(expectedString)) {
        streakDays++;
      } else {
        break;
      }
    }

    return streakDays;
  }

  // Get risk score for sorting
  static int _getRiskScore(EmployeeData employee) {
    switch (employee.status) {
      case EmployeeStatus.overdue:
        return 4;
      case EmployeeStatus.atRisk:
        return 3;
      case EmployeeStatus.inactive:
        return 2;
      case EmployeeStatus.onTrack:
        return 1;
    }
  }

  // Helper method to determine if employee is currently active
  static bool isEmployeeActive(EmployeeData employee, {Duration? threshold}) {
    final now = DateTime.now();
    final activeThreshold = threshold ?? const Duration(days: 7);
    final cutoffTime = now.subtract(activeThreshold);

    return employee.lastActivity.isAfter(cutoffTime);
  }

  // Helper method to get active status text
  static String getActiveStatusText(EmployeeData employee) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    if (employee.lastActivity.isAfter(today)) {
      return 'Active Today';
    } else if (employee.lastActivity.isAfter(sevenDaysAgo)) {
      return 'Active This Week';
    } else {
      return 'Inactive';
    }
  }

  // Get start date based on time filter
  static DateTime _getStartDateForFilter(TimeFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case TimeFilter.today:
        return DateTime(now.year, now.month, now.day);
      case TimeFilter.week:
        // Align with progress visuals: rolling last 7 calendar days through today
        // (start at midnight, 6 days before today).
        final todayStart = DateTime(now.year, now.month, now.day);
        return todayStart.subtract(const Duration(days: 6));
      case TimeFilter.month:
        return DateTime(now.year, now.month, 1);
      case TimeFilter.quarter:
        final quarter = ((now.month - 1) ~/ 3) + 1;
        return DateTime(now.year, (quarter - 1) * 3 + 1, 1);
      case TimeFilter.year:
        return DateTime(now.year, 1, 1);
    }
  }

  // Record employee activity
  static Future<void> recordEmployeeActivity({
    required String employeeId,
    required String activityType,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final now = DateTime.now();

      await _backend.createActivity(employeeId, {
        'userId': employeeId,
        'activityType': activityType,
        'description': description,
        'metadata': metadata ?? {},
        'timestamp': now.toIso8601String(),
      });

      if (currentUser.uid == employeeId) {
        try {
          await _backend.updateUserProfile(employeeId, {
            'lastActivityAt': now.toIso8601String(),
            'lastLoginAt': now.toIso8601String(),
          });
        } catch (e) {
          developer.log('Skipped self timestamp sync for $employeeId: $e');
        }
      }

      developer.log(
        'Recorded activity for employee $employeeId: $activityType',
      );
    } catch (e) {
      developer.log('Error recording activity: $e');
      rethrow;
    }
  }

  /// Stream nudge reactions/responses (reaction/response types only).
  /// Caller should filter by manager locally (using metadata.managerId/managerName).
  static Stream<List<Map<String, dynamic>>> getNudgeFeedbackStream({
    required String managerId,
    String? managerName,
    int limit = 300,
  }) {
    return createManagedPollingStream<List<Map<String, dynamic>>>(
      initialValue: const [],
      fetch: () async {
        final items = await _backend.getCollectionItems(
          'activities',
          limit: limit,
        );
        final feedback = items
            .where((data) {
              final type = (data['activityType'] ?? '').toString();
              return type == 'nudge_response' || type == 'nudge_reaction';
            })
            .map((data) {
              final metadata = data['metadata'];
              return <String, dynamic>{
                'id': data['id']?.toString() ?? '',
                'employeeId': data['userId'],
                'activityType': data['activityType'],
                'description': data['description'],
                'metadata': metadata is Map
                    ? Map<String, dynamic>.from(metadata)
                    : <String, dynamic>{},
                'timestamp': _parseDate(data['timestamp']),
              };
            })
            .toList();
        feedback.sort((a, b) {
          final aTime =
              a['timestamp'] as DateTime? ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              b['timestamp'] as DateTime? ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
        return feedback;
      },
    );
  }

  static Stream<List<EmployeeActivity>> getEmployeeActivitiesStream({
    required String employeeId,
    int limit = 20,
  }) {
    return createManagedPollingStream<List<EmployeeActivity>>(
      initialValue: const [],
      fetch: () async {
        final items = await _backend.getActivities(employeeId, limit: limit);
        final list = items.map((a) => EmployeeActivity.fromMap(a)).toList();
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return list;
      },
    );
  }

  // Send comprehensive nudge to employee
  static Future<void> sendNudgeToEmployee({
    required String employeeId,
    required String goalId,
    required String message,
    NudgeType nudgeType = NudgeType.motivational,
    String? recipientActionRoute,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final managerData = await _backend.getUser(currentUser.uid);
      final managerName = managerData['displayName'] ?? 'Your Manager';

      String goalTitle = 'Goal';
      try {
        final goals = await _backend.getGoals(goalId: goalId, limit: 1);
        if (goals.isNotEmpty) {
          goalTitle = goals.first['title']?.toString() ?? 'Goal';
        }
      } catch (e) {
        developer.log('Could not fetch goal title: $e');
      }

      // Create enhanced manager nudge alert using AlertService
      await AlertService.createManagerNudgeAlertEnhanced(
        userId: employeeId,
        goalId: goalId,
        managerId: currentUser.uid,
        managerName: managerName,
        goalTitle: goalTitle,
        nudgeMessage: message,
        actionRouteOverride: recipientActionRoute,
      );

      // Record manager action
      await recordManagerAction(
        actionType: ManagementAction.sendNudge,
        employeeId: employeeId,
        description: 'Sent nudge about "$goalTitle": $message',
        details: {
          'goalId': goalId,
          'message': message,
          'nudgeType': nudgeType.name,
        },
      );

      // Best-effort: refresh manager badges after a nudge is sent
      try {
        await ManagerBadgeEvaluator.evaluate(currentUser.uid);
      } catch (_) {}

      developer.log(
        'Enhanced nudge sent to employee $employeeId for goal $goalId',
      );
    } catch (e) {
      developer.log('Error sending nudge: $e');
      rethrow;
    }
  }

  // Reassign goal to different employee
  static Future<void> reassignGoal({
    required String goalId,
    required String fromEmployeeId,
    required String toEmployeeId,
  }) async {
    try {
      await _backend.patchGoal(goalId, {
        'userId': toEmployeeId,
        'reassignedAt': DateTime.now().toIso8601String(),
        'reassignedFrom': fromEmployeeId,
      });

      await _backend.createAlert(toEmployeeId, {
        'userId': toEmployeeId,
        'type': 'goalReassigned',
        'priority': 'high',
        'title': 'Goal Assigned to You',
        'message': 'A goal has been reassigned to you by your manager.',
        'actionText': 'View Goal',
        'actionRoute': '/my_goal_workspace',
        'createdAt': DateTime.now().toIso8601String(),
        'relatedGoalId': goalId,
        'isRead': false,
        'isDismissed': false,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 14))
            .toIso8601String(),
      });

      developer.log(
        'Goal $goalId reassigned from $fromEmployeeId to $toEmployeeId',
      );

      await recordManagerAction(
        actionType: ManagementAction.reassignGoal,
        employeeId: toEmployeeId,
        description: 'Goal reassigned',
        details: {'goalId': goalId, 'previousOwner': fromEmployeeId},
      );
    } catch (e) {
      developer.log('Error reassigning goal: $e');
      rethrow;
    }
  }

  // Record manager action for tracking
  static Future<void> recordManagerAction({
    required ManagementAction actionType,
    required String employeeId,
    required String description,
    Map<String, dynamic>? details,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      Map<String, dynamic> employeeData = {};
      try {
        employeeData = await _backend.getUser(employeeId);
      } catch (_) {}
      final employeeName =
          employeeData['displayName']?.toString() ?? 'Unknown Employee';

      final now = DateTime.now().toIso8601String();
      await _backend.createManagerAction(currentUser.uid, {
        'actionType': actionType.name,
        'managerId': currentUser.uid,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'description': description,
        'details': details ?? {},
        'status': 'completed',
        'createdAt': now,
        'completedAt': now,
      });

      developer.log(
        'Recorded manager action: ${actionType.name} for $employeeName',
      );
    } catch (e) {
      developer.log('Error recording manager action: $e');
      rethrow;
    }
  }

  // Give recognition/kudos to employee
  static Future<void> giveRecognition({
    required String employeeId,
    required String reason,
    required int points,
    String? badgeName,
    String? recipientActionRoute,
  }) async {
    // Two-phase behavior:
    // - Phase 1 (must succeed): points increment + alert creation
    // - Phase 2 (best-effort): activity/audit logging (must NOT surface as "failed"
    //   when Phase 1 already succeeded)
    try {
      Map<String, dynamic> employeeData = {};
      try {
        employeeData = await _backend.getUser(employeeId);
      } catch (_) {}
      final currentPoints = employeeData['totalPoints'] is num
          ? (employeeData['totalPoints'] as num).toInt()
          : 0;

      await _backend.updateUserProfile(employeeId, {
        'totalPoints': currentPoints + points,
      });

      await _backend.createAlert(employeeId, {
        'userId': employeeId,
        'type': 'recognition',
        'priority': 'high',
        'title': 'Recognition Received! 🏆',
        'message': 'Your manager recognized you: $reason'
            '${badgeName != null && badgeName.trim().isNotEmpty ? ' (Badge: ${badgeName.trim()})' : ''}'
            ' (+$points pts)',
        'actionText': 'View Achievement',
        'actionRoute': recipientActionRoute ?? '/badges_points',
        'createdAt': DateTime.now().toIso8601String(),
        'isRead': false,
        'isDismissed': false,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
      });

      try {
        await _backend.createPointEvent({
          'userId': employeeId,
          'amount': points,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      // Best-effort logging (do not fail the UX if rules block these writes)
      try {
        await recordEmployeeActivity(
          employeeId: employeeId,
          activityType: 'recognition_received',
          description: 'Received recognition: $reason',
          metadata: {'points': points, 'badge': badgeName},
        );
      } catch (e) {
        developer.log('Recognition activity logging skipped: $e');
      }

      try {
        await recordManagerAction(
          actionType: ManagementAction.giveRecognition,
          employeeId: employeeId,
          description: 'Gave recognition: $reason',
          details: {'points': points, 'badge': badgeName},
        );
      } catch (e) {
        developer.log('Recognition manager-action logging skipped: $e');
      }

      developer.log('Recognition given to employee $employeeId');
    } catch (e) {
      developer.log('Error giving recognition: $e');
      rethrow;
    }
  }

  /// Request a 1:1 (intent only; no time yet).
  static Future<String> requestOneOnOne({
    required String employeeId,
    String? agenda,
    String? recipientActionRoute,
  }) async {
    try {
      final managerId = FirebaseAuth.instance.currentUser!.uid;
      final meetingId = await OneOnOneMeetingService.requestOneOnOne(
        managerId: managerId,
        employeeId: employeeId,
        agenda: agenda,
      );

      await Future.wait([
        _backend.createManagerAction(managerId, {
          'actionType': 'requestMeeting',
          'managerId': managerId,
          'employeeId': employeeId,
          'employeeName': '',
          'description': 'Requested a 1:1 meeting',
          'details': {
            'meetingId': meetingId,
            'agenda': (agenda ?? '').trim(),
          },
          'status': 'requested',
          'createdAt': DateTime.now().toIso8601String(),
        }),
        AlertService.createOneOnOneRequestedAlert(
          employeeId: employeeId,
          managerId: managerId,
          meetingId: meetingId,
          agenda: agenda,
          actionRouteOverride: recipientActionRoute,
        ),
      ]);
      return meetingId;
    } catch (e) {
      developer.log('Error requesting 1:1 meeting: $e');
      rethrow;
    }
  }

  // Schedule 1:1 meeting
  static Future<String> scheduleMeeting({
    required String employeeId,
    required DateTime scheduledStartTime,
    required DateTime scheduledEndTime,
    required String purpose,
    String? notes,
    String? recipientActionRoute,
  }) async {
    try {
      final managerId = FirebaseAuth.instance.currentUser!.uid;

      // New trust-first behavior: this is a proposal, not a scheduled meeting,
      // until the employee accepts.
      final meetingId = await OneOnOneMeetingService.proposeTime(
        managerId: managerId,
        employeeId: employeeId,
        proposedStartDateTime: scheduledStartTime,
        proposedEndDateTime: scheduledEndTime,
        agenda: purpose,
      );

      await Future.wait([
        _backend.createManagerAction(managerId, {
          'actionType': 'scheduleMeeting',
          'managerId': managerId,
          'employeeId': employeeId,
          'employeeName': '',
          'description': 'Proposed 1:1 meeting time',
          'details': {
            'meetingId': meetingId,
            'proposedStartDateTime': scheduledStartTime.toIso8601String(),
            'proposedEndDateTime': scheduledEndTime.toIso8601String(),
            'proposedDateTime': scheduledStartTime.toIso8601String(),
            'purpose': purpose,
            'notes': notes ?? '',
          },
          'status': 'proposed',
          'createdAt': DateTime.now().toIso8601String(),
          'scheduledFor': scheduledStartTime.toIso8601String(),
        }),
        AlertService.createOneOnOneProposedAlert(
          employeeId: employeeId,
          managerId: managerId,
          meetingId: meetingId,
          proposedStartDateTime: scheduledStartTime,
          proposedEndDateTime: scheduledEndTime,
          agenda: purpose,
          actionRouteOverride: recipientActionRoute,
        ),
      ]);

      developer.log('1:1 proposed for employee $employeeId');
      return meetingId;
    } catch (e) {
      developer.log('Error scheduling meeting: $e');
      rethrow;
    }
  }

  // Get manager's action history
  static Stream<List<ManagerAction>> getManagerActionsStream({
    String? employeeId,
    int limit = 50,
  }) {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return const Stream.empty();

      return createManagedPollingStream<List<ManagerAction>>(
        initialValue: const [],
        fetch: () async {
          final items = await _backend.getManagerActions(
            currentUser.uid,
            limit: limit * 2,
          );
          final actions = items
              .where((data) {
                if (employeeId == null) return true;
                return (data['employeeId'] ?? '').toString() == employeeId;
              })
              .map((data) => ManagerAction.fromMap(data))
              .toList();
          actions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return actions.take(limit).toList();
        },
      );
    } catch (e) {
      developer.log('Error getting manager actions: $e');
      return const Stream.empty();
    }
  }

  // Create stretch goal for high performers
  static Future<void> createStretchGoal({
    required String employeeId,
    required String title,
    required String description,
    required DateTime targetDate,
    required int points,
  }) async {
    try {
      await _backend.createGoal({
        'userId': employeeId,
        'title': title,
        'description': description,
        'category': GoalCategory.work.name,
        'priority': GoalPriority.high.name,
        'status': GoalStatus.notStarted.name,
        'progress': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'targetDate': targetDate.toIso8601String(),
        'points': points,
        'isStretchGoal': true,
        'createdByManager': true,
      });

      await _backend.createAlert(employeeId, {
        'userId': employeeId,
        'type': 'stretchGoalAssigned',
        'priority': 'medium',
        'title': 'Stretch Goal Assigned! 🎯',
        'message': 'Your manager has assigned you a stretch goal: $title',
        'actionText': 'View Goal',
        'actionRoute': '/my_goal_workspace',
        'createdAt': DateTime.now().toIso8601String(),
        'isRead': false,
        'isDismissed': false,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      });

      developer.log('Stretch goal created for employee $employeeId');
    } catch (e) {
      developer.log('Error creating stretch goal: $e');
      rethrow;
    }
  }
}
