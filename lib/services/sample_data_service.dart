import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/backend_auth_service.dart';

class SampleDataService {
  static final BackendAuthService _backend = BackendAuthService.instance;

  static Future<void> createSampleActivitiesForEmployee(String employeeId) async {
    try {
      final now = DateTime.now();
      final activities = [
        {
          'userId': employeeId,
          'activityType': 'goal_progress',
          'description': 'Updated progress on "Complete Q4 Productivity Goals"',
          'metadata': {'goalId': 'sample_goal_1', 'progressAdded': 25},
          'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'activityType': 'goal_created',
          'description': 'Created new goal "Learn React Native Development"',
          'metadata': {
            'goalId': 'sample_goal_2',
            'targetDate': now.add(const Duration(days: 15)).toIso8601String(),
          },
          'timestamp': now.subtract(const Duration(days: 1)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'activityType': 'goal_completed',
          'description': 'Completed goal "Complete Code Refactoring"',
          'metadata': {'goalId': 'sample_goal_3', 'pointsEarned': 50},
          'timestamp': now.subtract(const Duration(days: 2)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'activityType': 'login',
          'description': 'Logged into the application',
          'metadata': {},
          'timestamp': now.subtract(const Duration(days: 3)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'activityType': 'goal_progress',
          'description': 'Updated progress on "Complete Project Documentation"',
          'metadata': {'goalId': 'sample_goal_4', 'progressAdded': 30},
          'timestamp': now.subtract(const Duration(days: 4)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'activityType': 'nudge_received',
          'description': 'Received a motivational nudge from manager',
          'metadata': {
            'managerName': 'John Manager',
            'message': 'Keep up the great work!',
          },
          'timestamp': now.subtract(const Duration(days: 5)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'activityType': 'goal_created',
          'description': 'Created new goal "Complete Team Collaboration Skills"',
          'metadata': {
            'goalId': 'sample_goal_5',
            'targetDate': now.add(const Duration(days: 20)).toIso8601String(),
          },
          'timestamp': now.subtract(const Duration(days: 6)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'activityType': 'goal_progress',
          'description': 'Updated progress on "Learn Agile Methodologies"',
          'metadata': {'goalId': 'sample_goal_6', 'progressAdded': 60},
          'timestamp': now.subtract(const Duration(days: 7)).toIso8601String(),
        },
      ];

      for (final activity in activities) {
        await _backend.createActivity(employeeId, activity);
      }

      developer.log(
        'Created ${activities.length} sample activities for employee $employeeId',
      );
    } catch (e) {
      developer.log('Error creating sample activities: $e');
      rethrow;
    }
  }

  static Future<void> createSampleGoalsForEmployee(String employeeId) async {
    try {
      final now = DateTime.now();
      final goals = [
        {
          'userId': employeeId,
          'title': 'Complete Q4 Productivity Goals',
          'description':
              'Focus on improving productivity and meeting quarter-end targets',
          'category': 'work',
          'priority': 'high',
          'status': 'inProgress',
          'progress': 75,
          'points': 30,
          'createdAt': now.subtract(const Duration(days: 10)).toIso8601String(),
          'targetDate': now.add(const Duration(days: 5)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'title': 'Learn React Native Development',
          'description':
              'Master the fundamentals of React Native for mobile development',
          'category': 'learning',
          'priority': 'medium',
          'status': 'inProgress',
          'progress': 40,
          'points': 25,
          'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
          'targetDate': now.add(const Duration(days: 12)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'title': 'Complete Project Documentation',
          'description': 'Create comprehensive documentation for the current project',
          'category': 'work',
          'priority': 'medium',
          'status': 'inProgress',
          'progress': 65,
          'points': 20,
          'createdAt': now.subtract(const Duration(days: 8)).toIso8601String(),
          'targetDate': now.add(const Duration(days: 3)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'title': 'Team Collaboration Skills',
          'description': 'Improve communication and teamwork abilities',
          'category': 'personal',
          'priority': 'low',
          'status': 'notStarted',
          'progress': 0,
          'points': 15,
          'createdAt': now.subtract(const Duration(days: 5)).toIso8601String(),
          'targetDate': now.add(const Duration(days: 15)).toIso8601String(),
        },
        {
          'userId': employeeId,
          'title': 'Learn Agile Methodologies',
          'description': 'Complete online course on Agile project management',
          'category': 'learning',
          'priority': 'high',
          'status': 'inProgress',
          'progress': 60,
          'points': 35,
          'createdAt': now.subtract(const Duration(days: 15)).toIso8601String(),
          'targetDate': now.add(const Duration(days: 8)).toIso8601String(),
        },
      ];

      for (final goal in goals) {
        await _backend.createGoal(goal);
      }

      developer.log('Created ${goals.length} sample goals for employee $employeeId');
    } catch (e) {
      developer.log('Error creating sample goals: $e');
      rethrow;
    }
  }

  static Future<void> populateManagerDashboardWithSampleData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final managerData = await _backend.getUser(currentUser.uid);
      final managerDepartment =
          managerData['department']?.toString() ?? 'Engineering';

      final employees = await _backend.listUsers(
        role: 'employee',
        department: managerDepartment,
        limit: 10,
      );

      developer.log(
        'Found ${employees.length} employees in $managerDepartment department',
      );

      for (final employee in employees) {
        final employeeId = (employee['id'] ?? employee['userId'] ?? '').toString();
        if (employeeId.isEmpty) continue;

        final existingActivities = await _backend.getActivities(employeeId, limit: 1);
        if (existingActivities.isEmpty) {
          await createSampleActivitiesForEmployee(employeeId);
          await createSampleGoalsForEmployee(employeeId);
          developer.log(
            'Created sample data for employee: ${employee['displayName'] ?? employeeId}',
          );
        }
      }

      developer.log('Finished populating sample data for manager dashboard');
    } catch (e) {
      developer.log('Error populating manager dashboard with sample data: $e');
      rethrow;
    }
  }

  static Future<void> clearSampleData() async {
    developer.log(
      'clearSampleData skipped: bulk delete is not supported via backend API',
    );
  }
}
