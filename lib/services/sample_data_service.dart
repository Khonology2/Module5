import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SampleDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create sample activities for employees to populate manager data
  static Future<void> createSampleActivitiesForEmployee(String employeeId) async {
    try {
      final now = DateTime.now();
      final activities = [
        {
          'userId': employeeId,
          'activityType': 'goal_progress',
          'description': 'Updated progress on "Complete Q4 Productivity Goals"',
          'metadata': {'goalId': 'sample_goal_1', 'progressAdded': 25},
          'timestamp': now.subtract(const Duration(hours: 2)),
        },
        {
          'userId': employeeId,
          'activityType': 'goal_created',
          'description': 'Created new goal "Learn React Native Development"',
          'metadata': {'goalId': 'sample_goal_2', 'targetDate': now.add(const Duration(days: 15))},
          'timestamp': now.subtract(const Duration(days: 1)),
        },
        {
          'userId': employeeId,
          'activityType': 'goal_completed',
          'description': 'Completed goal "Complete Code Refactoring"',
          'metadata': {'goalId': 'sample_goal_3', 'pointsEarned': 50},
          'timestamp': now.subtract(const Duration(days: 2)),
        },
        {
          'userId': employeeId,
          'activityType': 'login',
          'description': 'Logged into the application',
          'metadata': {},
          'timestamp': now.subtract(const Duration(days: 3)),
        },
        {
          'userId': employeeId,
          'activityType': 'goal_progress',
          'description': 'Updated progress on "Complete Project Documentation"',
          'metadata': {'goalId': 'sample_goal_4', 'progressAdded': 30},
          'timestamp': now.subtract(const Duration(days: 4)),
        },
        {
          'userId': employeeId,
          'activityType': 'nudge_received',
          'description': 'Received a motivational nudge from manager',
          'metadata': {'managerName': 'John Manager', 'message': 'Keep up the great work!'},
          'timestamp': now.subtract(const Duration(days: 5)),
        },
        {
          'userId': employeeId,
          'activityType': 'goal_created',
          'description': 'Created new goal "Complete Team Collaboration Skills"',
          'metadata': {'goalId': 'sample_goal_5', 'targetDate': now.add(const Duration(days: 20))},
          'timestamp': now.subtract(const Duration(days: 6)),
        },
        {
          'userId': employeeId,
          'activityType': 'goal_progress',
          'description': 'Updated progress on "Learn Agile Methodologies"',
          'metadata': {'goalId': 'sample_goal_6', 'progressAdded': 60},
          'timestamp': now.subtract(const Duration(days: 7)),
        },
      ];

      // Add each activity to Firestore
      for (final activity in activities) {
        await _firestore.collection('activities').add({
          ...activity,
          'timestamp': Timestamp.fromDate(activity['timestamp'] as DateTime),
        });
      }

      developer.log('Created ${activities.length} sample activities for employee $employeeId');
    } catch (e) {
      developer.log('Error creating sample activities: $e');
      rethrow;
    }
  }

  // Create sample goals for employees
  static Future<void> createSampleGoalsForEmployee(String employeeId) async {
    try {
      final now = DateTime.now();
      final goals = [
        {
          'userId': employeeId,
          'title': 'Complete Q4 Productivity Goals',
          'description': 'Focus on improving productivity and meeting quarter-end targets',
          'category': 'work',
          'priority': 'high',
          'status': 'inProgress',
          'progress': 75,
          'points': 30,
          'createdAt': now.subtract(const Duration(days: 10)),
          'targetDate': now.add(const Duration(days: 5)),
        },
        {
          'userId': employeeId,
          'title': 'Learn React Native Development',
          'description': 'Master the fundamentals of React Native for mobile development',
          'category': 'learning',
          'priority': 'medium',
          'status': 'inProgress',
          'progress': 40,
          'points': 25,
          'createdAt': now.subtract(const Duration(days: 3)),
          'targetDate': now.add(const Duration(days: 12)),
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
          'createdAt': now.subtract(const Duration(days: 8)),
          'targetDate': now.add(const Duration(days: 3)),
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
          'createdAt': now.subtract(const Duration(days: 5)),
          'targetDate': now.add(const Duration(days: 15)),
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
          'createdAt': now.subtract(const Duration(days: 15)),
          'targetDate': now.add(const Duration(days: 8)),
        },
      ];

      // Add each goal to Firestore
      for (final goal in goals) {
        await _firestore.collection('goals').add({
          ...goal,
          'createdAt': Timestamp.fromDate(goal['createdAt'] as DateTime),
          'targetDate': Timestamp.fromDate(goal['targetDate'] as DateTime),
        });
      }

      developer.log('Created ${goals.length} sample goals for employee $employeeId');
    } catch (e) {
      developer.log('Error creating sample goals: $e');
      rethrow;
    }
  }

  // Populate manager dashboard with sample data for all employees in department
  static Future<void> populateManagerDashboardWithSampleData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get manager's department
      final managerDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final managerDepartment = managerDoc.data()?['department'] as String? ?? 'Engineering';

      // Get all employees in the same department
      final employeesQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('department', isEqualTo: managerDepartment)
          .limit(10) // Limit to avoid overwhelming the system
          .get();

      developer.log('Found ${employeesQuery.docs.length} employees in $managerDepartment department');

      // Create sample data for each employee
      for (final employeeDoc in employeesQuery.docs) {
        final employeeId = employeeDoc.id;
        
        // Skip if this employee already has sample data
        final existingActivities = await _firestore
            .collection('activities')
            .where('userId', isEqualTo: employeeId)
            .limit(1)
            .get();

        if (existingActivities.docs.isEmpty) {
          await createSampleActivitiesForEmployee(employeeId);
          await createSampleGoalsForEmployee(employeeId);
          developer.log('Created sample data for employee: ${employeeDoc.data()['displayName']}');
        }
      }

      developer.log('Finished populating sample data for manager dashboard');
    } catch (e) {
      developer.log('Error populating manager dashboard with sample data: $e');
      rethrow;
    }
  }

  // Clear all sample data (for testing purposes)
  static Future<void> clearSampleData() async {
    try {
      // Delete all activities (be careful with this in production!)
      final activitiesQuery = await _firestore
          .collection('activities')
          .limit(1000)
          .get();

      for (final doc in activitiesQuery.docs) {
        await doc.reference.delete();
      }

      // Delete sample goals (ones without proper goal structure)
      final goalsQuery = await _firestore
          .collection('goals')
          .limit(1000)
          .get();

      for (final doc in goalsQuery.docs) {
        await doc.reference.delete();
      }

      developer.log('Cleared sample data');
    } catch (e) {
      developer.log('Error clearing sample data: $e');
      rethrow;
    }
  }
}
