import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
<<<<<<< HEAD
=======
import 'package:flutter/foundation.dart';

>>>>>>> origin/lihle-manager
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/alert_service.dart';

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

  factory EmployeeActivity.fromFirestore(DocumentSnapshot doc) {
<<<<<<< HEAD
    final data = doc.data() as Map<String, dynamic>;
    return EmployeeActivity(
      activityId: doc.id,
      userId: data['userId'] ?? '',
      activityType: data['activityType'] ?? 'unknown',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
=======
    final data = doc.data() as Map<String, dynamic>?;
    return EmployeeActivity(
      activityId: doc.id,
      userId: (data != null ? data['userId'] : '') ?? '',
      activityType:
          (data != null ? data['activityType'] : 'unknown') ?? 'unknown',
      description: (data != null ? data['description'] : '') ?? '',
      timestamp: (data != null && data['timestamp'] is Timestamp)
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      metadata: Map<String, dynamic>.from(
        (data != null ? data['metadata'] : {}) ?? {},
      ),
    );
  }

  static EmployeeActivity fromMap(Map<String, dynamic> map) {
    return EmployeeActivity(
      activityId: map['activityId'] ?? '',
      userId: map['userId'] ?? '',
      activityType: map['activityType'] ?? 'unknown',
      description: map['description'] ?? '',
      timestamp: map['timestamp'] is DateTime
          ? map['timestamp']
          : (map['timestamp'] is Timestamp
                ? (map['timestamp'] as Timestamp).toDate()
                : DateTime.tryParse(map['timestamp']?.toString() ?? '') ??
                      DateTime.now()),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
>>>>>>> origin/lihle-manager
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
  });
<<<<<<< HEAD
=======

  static EmployeeData fromMap(Map<String, dynamic> map, {String? id}) {
    return EmployeeData(
      profile: map['profile'] is UserProfile
          ? map['profile']
          : UserProfile.fromMap(
              map['profile'] ?? {},
              id: map['profile']?['uid'] ?? id,
            ),
      goals:
          ((map['goals'] as List<dynamic>? ?? [])
                  .map((g) => g is Goal ? g : Goal.fromMap(g ?? {}))
                  .toList()
              as List<Goal>),
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
          : (map['lastActivity'] is Timestamp
                ? (map['lastActivity'] as Timestamp).toDate()
                : DateTime.tryParse(map['lastActivity']?.toString() ?? '') ??
                      DateTime.now()),
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
    );
  }
>>>>>>> origin/lihle-manager
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
<<<<<<< HEAD
=======

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
          : (map['createdAt'] is Timestamp
                ? (map['createdAt'] as Timestamp).toDate()
                : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
                      DateTime.now()),
    );
  }
>>>>>>> origin/lihle-manager
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

  factory ManagerAction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ManagerAction(
      actionId: doc.id,
      actionType: ManagementAction.values.firstWhere(
        (e) => e.name == (data['actionType']),
        orElse: () => ManagementAction.sendNudge,
      ),
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      description: data['description'] ?? '',
      details: Map<String, dynamic>.from(data['details'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
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

class ManagerRealtimeService {
<<<<<<< HEAD
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

=======
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Stream<List<EmployeeData>> employeesStream() async* {
    await _ensureSignedIn();
    try {
      yield* _db.collection('employees').snapshots().map((snap) {
        return snap.docs.map((doc) {
          final data = doc.data();
          return EmployeeData.fromMap(
            data,
            id: doc.id,
          ); // adjust factory if needed
        }).toList();
      });
    } on FirebaseException catch (e, st) {
      if (kDebugMode) debugPrint('employeesStream FirebaseException: $e\n$st');
      // Propagate a clearer error so the UI can show actionable text
      throw FirebaseException(
        plugin: e.plugin,
        code: e.code,
        message:
            'Firestore error (${e.code}). Verify Firestore rules and authentication. ${e.message ?? ''}',
      );
    } catch (e, st) {
      if (kDebugMode) debugPrint('employeesStream unknown error: $e\n$st');
      rethrow;
    }
  }

  Stream<TeamMetrics?> teamMetricsStream() async* {
    // reuse employeesStream to compute aggregated metrics
    await _ensureSignedIn();
    try {
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
            // Count goals that are on track for each employee
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
            // Count goals that are at risk for each employee
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
    } on FirebaseException catch (e, st) {
      if (kDebugMode) {
        debugPrint('teamMetricsStream FirebaseException: $e\n$st');
      }
      throw FirebaseException(
        plugin: e.plugin,
        code: e.code,
        message:
            'Firestore error (${e.code}). Check rules/auth: ${e.message ?? ''}',
      );
    }
  }

  Stream<List<TeamInsight>> teamInsightsStream() async* {
    await _ensureSignedIn();
    try {
      yield* _db.collection('team_insights').snapshots().map((snap) {
        return snap.docs.map((doc) {
          final data = doc.data();
          return TeamInsight.fromMap(
            data,
            id: doc.id,
          ); // adjust factory if needed
        }).toList();
      });
    } on FirebaseException catch (e, st) {
      if (kDebugMode) {
        debugPrint('teamInsightsStream FirebaseException: $e\n$st');
      }
      throw FirebaseException(
        plugin: e.plugin,
        code: e.code,
        message: 'Firestore error (${e.code}). Ensure rules/auth are correct.',
      );
    }
  }

  /// Convenience single-read for an employee (optional).
  Future<EmployeeData?> getEmployeeById(String id) async {
    try {
      final doc = await _db.collection('employees').doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>;
      return EmployeeData.fromMap(data, id: doc.id);
    } catch (e, st) {
      if (kDebugMode) debugPrint('getEmployeeById error: $e\n$st');
      return null;
    }
  }

>>>>>>> origin/lihle-manager
  // Stream real-time team data based on current manager
  static Stream<List<EmployeeData>> getTeamDataStream({
    String? department,
    TimeFilter timeFilter = TimeFilter.month,
  }) {
    return Stream<List<EmployeeData>>.multi((controller) async {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          controller.addError('No authenticated user');
          return;
        }

        // Get the manager's department if not specified
        String? targetDepartment = department;
        if (targetDepartment == null) {
          final managerDoc = await _firestore
              .collection('users')
              .doc(currentUser.uid)
              .get();
          targetDepartment = managerDoc.data()?['department'] as String?;
        }

<<<<<<< HEAD
=======
        // For now, get all employees regardless of department
        // This allows managers to see all employees in the system
        // The Firestore rules will handle security
>>>>>>> origin/lihle-manager
        Query query = _firestore
            .collection('users')
            .where('role', isEqualTo: 'employee');

<<<<<<< HEAD
        if (targetDepartment != null && targetDepartment.isNotEmpty) {
          query = query.where('department', isEqualTo: targetDepartment);
        } else if (targetDepartment != null && targetDepartment.isEmpty) {
          // If targetDepartment is an empty string, specifically query for employees with empty department
          query = query.where('department', isEqualTo: '');
        }

        developer.log('Manager Realtime Service: Setting up stream');
        developer.log('Manager UID: $currentUser.uid');
        developer.log('Target Department: $targetDepartment');

        final subscription = query.snapshots().listen(
          (snapshot) async {
            developer.log(
              'Manager Realtime Service: Received snapshot with ${snapshot.docs.length} employees',
            );
            final List<EmployeeData> employeeDataList = [];

            for (final userDoc in snapshot.docs) {
              try {
                developer.log('Processing employee: ${userDoc.id}');
                final userProfile = UserProfile.fromFirestore(userDoc);
                final employeeData = await _buildEmployeeData(
                  userProfile,
                  timeFilter,
                );
                employeeDataList.add(employeeData);
                developer.log(
                  'Successfully processed employee: ${userProfile.displayName}',
                );
              } catch (e) {
                developer.log('Error processing employee ${userDoc.id}: $e');
              }
            }

            developer.log(
              'Manager Realtime Service: Built ${employeeDataList.length} employee data objects',
            );

            // Sort by risk level (at risk and overdue first)
            employeeDataList.sort((a, b) {
              final aRisk = _getRiskScore(a);
              final bRisk = _getRiskScore(b);
              if (aRisk != bRisk) return bRisk.compareTo(aRisk);
              return b.totalPoints.compareTo(a.totalPoints);
            });

            controller.add(employeeDataList);
=======
        developer.log('Manager Realtime Service: Setting up stream');
        developer.log('Manager UID: $currentUser.uid');
        developer.log('Getting all employees (department filtering disabled)');

        // Get all activities and filter in memory to avoid composite index
        Query activitiesQuery = _firestore.collection('activities');

        QuerySnapshot? lastUsersSnapshot;

        Future<void> rebuildAndEmit(QuerySnapshot usersSnapshot) async {
          developer.log(
            'Manager Realtime Service: Received snapshot with ${usersSnapshot.docs.length} employees',
          );
          final List<EmployeeData> employeeDataList = [];

          for (final userDoc in usersSnapshot.docs) {
            try {
              developer.log('Processing employee: ${userDoc.id}');
              final userProfile = UserProfile.fromFirestore(userDoc);
              final employeeData = await _buildEmployeeData(
                userProfile,
                timeFilter,
              );
              employeeDataList.add(employeeData);
              developer.log(
                'Successfully processed employee: ${userProfile.displayName}',
              );
            } catch (e) {
              developer.log('Error processing employee ${userDoc.id}: $e');
            }
          }

          developer.log(
            'Manager Realtime Service: Built ${employeeDataList.length} employee data objects',
          );

          // Sort by risk level (at risk and overdue first)
          employeeDataList.sort((a, b) {
            final aRisk = _getRiskScore(a);
            final bRisk = _getRiskScore(b);
            if (aRisk != bRisk) return bRisk.compareTo(aRisk);
            return b.totalPoints.compareTo(a.totalPoints);
          });

          controller.add(employeeDataList);
        }

        final usersSub = query.snapshots().listen(
          (snapshot) async {
            lastUsersSnapshot = snapshot;
            await rebuildAndEmit(snapshot);
>>>>>>> origin/lihle-manager
          },
          onError: (error) {
            developer.log('Error in team data stream: $error');
            controller.addError(error);
          },
        );

<<<<<<< HEAD
        controller.onCancel = () {
          subscription.cancel();
=======
        final activitiesSub = activitiesQuery.snapshots().listen(
          (_) async {
            if (lastUsersSnapshot != null) {
              await rebuildAndEmit(lastUsersSnapshot!);
            }
          },
          onError: (error) {
            developer.log('Error in activities stream: $error');
          },
        );

        controller.onCancel = () {
          usersSub.cancel();
          activitiesSub.cancel();
>>>>>>> origin/lihle-manager
        };
      } catch (e) {
        developer.log('Error setting up team data stream: $e');
        controller.addError(e);
      }
    });
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
  ) async {
    try {
      final startDate = _getStartDateForFilter(timeFilter);

      // Get employee's goals within time filter (supports top-level and nested under user)
      final goalsTopLevel = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: profile.uid)
<<<<<<< HEAD
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
=======
>>>>>>> origin/lihle-manager
          .get();

      List<Goal> goals = goalsTopLevel.docs
          .map((doc) => Goal.fromFirestore(doc))
<<<<<<< HEAD
=======
          .where((goal) => goal.createdAt.isAfter(startDate))
>>>>>>> origin/lihle-manager
          .toList();

      if (goals.isEmpty) {
        final goalsNested = await _firestore
            .collection('users')
            .doc(profile.uid)
            .collection('goals')
<<<<<<< HEAD
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .get();
        goals = goalsNested.docs.map((doc) => Goal.fromFirestore(doc)).toList();
=======
            .get();
        goals = goalsNested.docs
            .map((doc) => Goal.fromFirestore(doc))
            .where((goal) => goal.createdAt.isAfter(startDate))
            .toList();
>>>>>>> origin/lihle-manager
      }

      // Get all goals for status calculation (top-level first, fallback to nested)
      final allTopLevel = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: profile.uid)
          .get();

      List<Goal> allGoals = allTopLevel.docs
          .map((doc) => Goal.fromFirestore(doc))
          .toList();

      if (allGoals.isEmpty) {
        final allNested = await _firestore
            .collection('users')
            .doc(profile.uid)
            .collection('goals')
            .get();
        allGoals = allNested.docs
            .map((doc) => Goal.fromFirestore(doc))
            .toList();
      }

      // Calculate metrics
      final completedGoals = allGoals
          .where((g) => g.status == GoalStatus.completed)
          .length;
      final overdueGoals = allGoals
          .where(
            (g) =>
                g.status != GoalStatus.completed &&
                g.targetDate.isBefore(DateTime.now()),
          )
          .length;

      final avgProgress = allGoals.isNotEmpty
          ? allGoals.map((g) => g.progress).reduce((a, b) => a + b) /
                allGoals.length
          : 0.0;

      // Get real recent activity from activities collection
      DateTime lastActivity = DateTime.now().subtract(
        const Duration(days: 30),
      ); // Default to inactive
      int streakDays = 0;
      double engagementScore = 0.0;
      String motivationLevel = 'Unknown';
      List<QueryDocumentSnapshot> activityDocs = [];
      List<EmployeeActivity> recentActivities = const [];

      try {
<<<<<<< HEAD
        // Pull lastLoginAt from user profile
=======
        // Pull lastLoginAt and lastActivityAt from user profile
>>>>>>> origin/lihle-manager
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(profile.uid)
              .get();
          final data = userDoc.data();
          // Prefer stored values when available
          final storedStreak = data?['currentStreak'];
          if (storedStreak != null) {
            streakDays = (storedStreak is int)
                ? storedStreak
                : int.tryParse(storedStreak.toString()) ?? 0;
          }
          final storedEngagement = data?['engagementScore'];
          if (storedEngagement != null) {
            engagementScore = (storedEngagement is num)
                ? storedEngagement.toDouble()
                : double.tryParse(storedEngagement.toString()) ?? 0.0;
          }
          final storedMotivation = data?['motivationLevel'];
          if (storedMotivation is String && storedMotivation.isNotEmpty) {
            motivationLevel = storedMotivation;
          }
<<<<<<< HEAD
          final lastLoginTs = data?['lastLoginAt'] as Timestamp?;
          if (lastLoginTs != null) {
            final lastLogin = lastLoginTs.toDate();
=======

          // Check for lastActivityAt timestamp (from goal updates)
          final lastActivityTs = data?['lastActivityAt'] as Timestamp?;
          if (lastActivityTs != null) {
            lastActivity = lastActivityTs.toDate();
          }

          // If lastLoginAt is more recent, use that instead
          final lastLoginTs = data?['lastLoginAt'] as Timestamp?;
          if (lastLoginTs != null) {
            final lastLogin = lastLoginTs.toDate();
            if (lastLogin.isAfter(lastActivity)) {
              lastActivity = lastLogin;
            }
>>>>>>> origin/lihle-manager
            // If no login today, enforce streak = 0 later by passing empty docs
            final now = DateTime.now();
            final todayOnly = DateTime(now.year, now.month, now.day);
            final lastLoginOnly = DateTime(
              lastLogin.year,
              lastLogin.month,
              lastLogin.day,
            );
            final hasLoggedInToday = lastLoginOnly.isAtSameMomentAs(todayOnly);
            if (!hasLoggedInToday) {
              // Skip activity-based streak; ensure streakDays becomes 0
              streakDays = 0;
            }
          }
        } catch (_) {}

        final activityQuery = await _firestore
            .collection('activities')
            .where('userId', isEqualTo: profile.uid)
<<<<<<< HEAD
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (activityQuery.docs.isNotEmpty) {
          lastActivity =
              (activityQuery.docs.first.data()['timestamp'] as Timestamp?)
=======
            .get();

        if (activityQuery.docs.isNotEmpty) {
          // Sort activities by timestamp to get the most recent
          final sortedActivities = activityQuery.docs.toList()
            ..sort((a, b) {
              final aTime =
                  (a.data()['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final bTime =
                  (b.data()['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return bTime.compareTo(aTime);
            });

          lastActivity =
              (sortedActivities.first.data()['timestamp'] as Timestamp?)
>>>>>>> origin/lihle-manager
                  ?.toDate() ??
              DateTime.now().subtract(const Duration(days: 30));
        }

        // Calculate streak days from recent activities
        final streakQuerySnapshot = await _firestore
            .collection('activities')
            .where('userId', isEqualTo: profile.uid)
<<<<<<< HEAD
            .orderBy('timestamp', descending: true)
            .limit(30) // Check last 30 days
            .get();

=======
            .get();

        // Sort activities by timestamp and limit to last 30 days
        final sortedStreakDocs = streakQuerySnapshot.docs.toList()
          ..sort((a, b) {
            final aTime =
                (a.data()['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                (b.data()['timestamp'] as Timestamp?)?.toDate() ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

        // Filter to last 30 days
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        final recentDocs = sortedStreakDocs.where((doc) {
          final timestamp = (doc.data()['timestamp'] as Timestamp?)?.toDate();
          return timestamp != null && timestamp.isAfter(thirtyDaysAgo);
        }).toList();

>>>>>>> origin/lihle-manager
        // If we have stored streak (>0), keep it; otherwise compute based on activity
        if (streakDays > 0) {
          // keep stored value
        } else {
<<<<<<< HEAD
          streakDays = _calculateStreakDays(streakQuerySnapshot.docs);
        }
        activityDocs = streakQuerySnapshot.docs;

        // Build recent activities list (limit 10)
        recentActivities = streakQuerySnapshot.docs
=======
          streakDays = _calculateStreakDays(recentDocs);
        }
        activityDocs = recentDocs;

        // Build recent activities list (limit 10)
        recentActivities = recentDocs
>>>>>>> origin/lihle-manager
            .take(10)
            .map((doc) => EmployeeActivity.fromFirestore(doc))
            .toList();

        // If engagementScore not stored, compute simple engagement as active days in last 7 days
        if (engagementScore == 0.0) {
          final now = DateTime.now();
          final sevenDaysAgo = now.subtract(const Duration(days: 7));
          final activeDays = activityDocs
              .map(
                (doc) =>
                    (doc.data() as Map<String, dynamic>?)?['timestamp']
                        as Timestamp?,
              )
              .where((ts) => ts != null && ts.toDate().isAfter(sevenDaysAgo))
              .map((ts) {
                final d = ts!.toDate();
                return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              })
              .toSet()
              .length;
          engagementScore = (activeDays / 7) * 100.0;
        }
      } catch (e) {
        developer.log('Error getting activity data for ${profile.uid}: $e');
        // Keep default values
      }

      // Determine status
      final status = _determineEmployeeStatus(allGoals, lastActivity);

<<<<<<< HEAD
=======
      developer.log(
        'Manager Realtime Service: Built employee data for ${profile.displayName}',
      );
      developer.log(
        '  - Goals: ${goals.length} (completed: $completedGoals, overdue: $overdueGoals)',
      );
      developer.log('  - Status: $status');
      developer.log('  - Last activity: $lastActivity');

>>>>>>> origin/lihle-manager
      return EmployeeData(
        profile: profile,
        goals: goals,
        recentActivities: recentActivities,
        recentAlerts: const [], // Not implemented yet
        completedGoalsCount: completedGoals,
        overdueGoalsCount: overdueGoals,
        totalPoints: profile.totalPoints,
        lastActivity: lastActivity,
        avgProgress: avgProgress,
        streakDays: streakDays,
        status: status,
        weeklyActivityCount: _calculateWeeklyActivityCount(activityDocs),
        engagementScore: engagementScore == 0.0 ? avgProgress : engagementScore,
        motivationLevel: motivationLevel == 'Unknown'
            ? (avgProgress > 70
                  ? 'High'
                  : avgProgress > 40
                  ? 'Medium'
                  : 'Low')
            : motivationLevel,
      );
    } catch (e) {
      developer.log('Error building employee data for ${profile.uid}: $e');
      // Return default data if error occurs
      return EmployeeData(
        profile: profile,
        goals: [],
        recentActivities: const [], // Keep empty for now
        recentAlerts: const [], // Keep empty for now
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

    final activeGoals = goals
        .where((g) => g.status != GoalStatus.completed)
        .toList();

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

  // Calculate streak days from activity documents
  static int _calculateStreakDays(List<QueryDocumentSnapshot> activityDocs) {
    if (activityDocs.isEmpty) return 0;

    final now = DateTime.now();
    int streakDays = 0;
    final activityDates = <String>[];

    // Extract unique dates from activities
    for (final doc in activityDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      final timestamp = (data?['timestamp'] as Timestamp?)?.toDate();
      if (timestamp != null) {
        final dateString =
            '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
        if (!activityDates.contains(dateString)) {
          activityDates.add(dateString);
        }
      }
    }

    if (activityDates.isEmpty) return 0;

    // Sort dates descending
    activityDates.sort((a, b) => b.compareTo(a));

    // Count consecutive days starting strictly from today
    final today = DateTime(now.year, now.month, now.day);
    final todayString =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Require activity today to maintain any streak
    if (!activityDates.contains(todayString)) {
      return 0;
    }

    // Count consecutive days
    for (int i = 0; i < activityDates.length; i++) {
      final expectedDate = today.subtract(Duration(days: i));
      final expectedString =
          '${expectedDate.year}-${expectedDate.month.toString().padLeft(2, '0')}-${expectedDate.day.toString().padLeft(2, '0')}';

      if (activityDates.contains(expectedString)) {
        streakDays++;
      } else {
        break; // Gap found, end streak
      }
    }

    return streakDays;
  }

  // Calculate weekly activity count within last 7 days
  static int _calculateWeeklyActivityCount(
    List<QueryDocumentSnapshot> activityDocs,
  ) {
    if (activityDocs.isEmpty) return 0;

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final activityDates = <String>{};

    for (final doc in activityDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      final timestamp = (data?['timestamp'] as Timestamp?)?.toDate();
      if (timestamp != null && timestamp.isAfter(sevenDaysAgo)) {
        final dateString =
            '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
        activityDates.add(dateString);
      }
    }

    return activityDates.length;
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

<<<<<<< HEAD
=======
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

>>>>>>> origin/lihle-manager
  // Get start date based on time filter
  static DateTime _getStartDateForFilter(TimeFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case TimeFilter.today:
        return DateTime(now.year, now.month, now.day);
      case TimeFilter.week:
        return now.subtract(const Duration(days: 7));
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
<<<<<<< HEAD
      await _firestore.collection('activities').add({
=======
      final batch = _firestore.batch();

      // Add activity record
      final activityRef = _firestore.collection('activities').doc();
      batch.set(activityRef, {
>>>>>>> origin/lihle-manager
        'userId': employeeId,
        'activityType': activityType,
        'description': description,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });

<<<<<<< HEAD
=======
      // Update user's last activity timestamp
      final userRef = _firestore.collection('users').doc(employeeId);
      batch.update(userRef, {
        'lastActivityAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(), // Also update login time
      });

      await batch.commit();

>>>>>>> origin/lihle-manager
      developer.log(
        'Recorded activity for employee $employeeId: $activityType',
      );
    } catch (e) {
      developer.log('Error recording activity: $e');
      rethrow;
    }
  }

  // Get employee activities for monitoring
  static Stream<List<EmployeeActivity>> getEmployeeActivitiesStream({
    required String employeeId,
    int limit = 20,
  }) {
    return _firestore
        .collection('activities')
        .where('userId', isEqualTo: employeeId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => EmployeeActivity.fromFirestore(doc))
              .toList();
        });
  }

  // Send comprehensive nudge to employee
  static Future<void> sendNudgeToEmployee({
    required String employeeId,
    required String goalId,
    required String message,
    NudgeType nudgeType = NudgeType.motivational,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final managerDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final managerName = managerDoc.data()?['displayName'] ?? 'Your Manager';

      // Get goal title
      String goalTitle = 'Goal';
      try {
        final goalDoc = await _firestore.collection('goals').doc(goalId).get();
        goalTitle = goalDoc.data()?['title'] ?? 'Goal';
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
      final batch = _firestore.batch();

      // Update goal with new userId
      final goalRef = _firestore.collection('goals').doc(goalId);
      batch.update(goalRef, {
        'userId': toEmployeeId,
        'reassignedAt': FieldValue.serverTimestamp(),
        'reassignedFrom': fromEmployeeId,
      });

      // Create alert for new assignee
      final newAssigneeAlertRef = _firestore.collection('alerts').doc();
      batch.set(newAssigneeAlertRef, {
        'userId': toEmployeeId,
        'type': 'goalReassigned',
        'priority': 'high',
        'title': 'Goal Assigned to You',
        'message': 'A goal has been reassigned to you by your manager.',
        'actionText': 'View Goal',
        'actionRoute': '/my_goal_workspace',
        'createdAt': FieldValue.serverTimestamp(),
        'relatedGoalId': goalId,
        'isRead': false,
        'isDismissed': false,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 14)),
        ),
      });

      await batch.commit();
      developer.log(
        'Goal $goalId reassigned from $fromEmployeeId to $toEmployeeId',
      );

      // Record management action
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

      final employeeDoc = await _firestore
          .collection('users')
          .doc(employeeId)
          .get();
      final employeeName =
          employeeDoc.data()?['displayName'] ?? 'Unknown Employee';

      await _firestore.collection('manager_actions').add({
        'actionType': actionType.name,
        'managerId': currentUser.uid,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'description': description,
        'details': details ?? {},
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
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
  }) async {
    try {
      final batch = _firestore.batch();

      // Update employee points
      final userRef = _firestore.collection('users').doc(employeeId);
      batch.update(userRef, {'totalPoints': FieldValue.increment(points)});

      // Add to achievements if badge provided
      if (badgeName != null) {
        batch.update(userRef, {
          'badges': FieldValue.arrayUnion([badgeName]),
        });
      }

      // Create alert for employee
      final alertRef = _firestore.collection('alerts').doc();
      batch.set(alertRef, {
        'userId': employeeId,
        'type': 'recognition',
        'priority': 'high',
        'title': 'Recognition Received! 🏆',
        'message': 'Your manager recognized you: $reason',
        'actionText': 'View Achievement',
        'actionRoute': '/badges_points',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDismissed': false,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
      });

      await batch.commit();

      // Record activity
      await recordEmployeeActivity(
        employeeId: employeeId,
        activityType: 'recognition_received',
        description: 'Received recognition: $reason',
        metadata: {'points': points, 'badge': badgeName},
      );

      // Record manager action
      await recordManagerAction(
        actionType: ManagementAction.giveRecognition,
        employeeId: employeeId,
        description: 'Gave recognition: $reason',
        details: {'points': points, 'badge': badgeName},
      );

      developer.log('Recognition given to employee $employeeId');
    } catch (e) {
      developer.log('Error giving recognition: $e');
      rethrow;
    }
  }

  // Schedule 1:1 meeting
  static Future<void> scheduleMeeting({
    required String employeeId,
    required DateTime scheduledTime,
    required String purpose,
    String? notes,
  }) async {
    try {
      await _firestore.collection('manager_actions').add({
        'actionType': 'scheduleMeeting',
        'managerId': FirebaseAuth.instance.currentUser!.uid,
        'employeeId': employeeId,
        'employeeName': '', // Will be filled by recordManagerAction
        'description': 'Scheduled 1:1 meeting',
        'details': {
          'scheduledTime': Timestamp.fromDate(scheduledTime),
          'purpose': purpose,
          'notes': notes ?? '',
        },
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
        'scheduledFor': Timestamp.fromDate(scheduledTime),
      });

      // Create alert for employee
      await _firestore.collection('alerts').add({
        'userId': employeeId,
        'type': 'meeting_scheduled',
        'priority': 'medium',
        'title': '1:1 Meeting Scheduled 📅',
        'message': 'Your manager scheduled a 1:1 meeting: $purpose',
        'actionText': 'View Details',
        'actionRoute': '/schedule',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDismissed': false,
        'expiresAt': Timestamp.fromDate(
          scheduledTime.add(const Duration(hours: 1)),
        ),
      });

      developer.log('Meeting scheduled with employee $employeeId');
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

      Query query = _firestore
          .collection('manager_actions')
<<<<<<< HEAD
          .where('managerId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit);
=======
          .where('managerId', isEqualTo: currentUser.uid);
>>>>>>> origin/lihle-manager

      if (employeeId != null) {
        query = query.where('employeeId', isEqualTo: employeeId);
      }

      return query.snapshots().map((snapshot) {
<<<<<<< HEAD
        return snapshot.docs
            .map((doc) => ManagerAction.fromFirestore(doc))
            .toList();
=======
        final actions = snapshot.docs
            .map((doc) => ManagerAction.fromFirestore(doc))
            .toList();
        // Sort in memory to avoid composite index requirement
        actions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return actions.take(limit).toList();
>>>>>>> origin/lihle-manager
      });
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
      await _firestore.collection('goals').add({
        'userId': employeeId,
        'title': title,
        'description': description,
        'category': GoalCategory.work.name,
        'priority': GoalPriority.high.name,
        'status': GoalStatus.notStarted.name,
        'progress': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'targetDate': Timestamp.fromDate(targetDate),
        'points': points,
        'isStretchGoal': true,
        'createdByManager': true,
      });

      // Create alert for employee
      await _firestore.collection('alerts').add({
        'userId': employeeId,
        'type': 'stretchGoalAssigned',
        'priority': 'medium',
        'title': 'Stretch Goal Assigned! 🎯',
        'message': 'Your manager has assigned you a stretch goal: $title',
        'actionText': 'View Goal',
        'actionRoute': '/my_goal_workspace',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'isDismissed': false,
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      });

      developer.log('Stretch goal created for employee $employeeId');
    } catch (e) {
      developer.log('Error creating stretch goal: $e');
      rethrow;
    }
  }
}
