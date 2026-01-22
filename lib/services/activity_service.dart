import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for recording and managing user activities
class ActivityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Record a user activity
  static Future<void> recordActivity({
    required String activityType,
    required String description,
    Map<String, dynamic>? metadata,
    String? userId,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final targetUserId = userId ?? currentUser?.uid;

      if (targetUserId == null) {
        developer.log('Error: No user ID available to record activity');
        return;
      }

      await _firestore.collection('activities').add({
        'userId': targetUserId,
        'activityType': activityType,
        'description': description,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      developer.log('Recorded activity: $activityType for user $targetUserId');
    } catch (e) {
      developer.log('Error recording activity: $e');
      rethrow;
    }
  }

  /// Record goal-related activities
  static Future<void> recordGoalActivity({
    required String goalId,
    required String goalTitle,
    required String activityType,
    required String description,
    Map<String, dynamic>? metadata,
    String? userId,
  }) async {
    final enhancedMetadata = {
      'goalId': goalId,
      'goalTitle': goalTitle,
      ...metadata ?? {},
    };

    await recordActivity(
      activityType: activityType,
      description: description,
      metadata: enhancedMetadata,
      userId: userId,
    );
  }

  /// Record engagement activities (logs, progress updates, etc.)
  static Future<void> recordEngagementActivity({
    required String activityType,
    required String description,
    Map<String, dynamic>? metadata,
    String? userId,
  }) async {
    await recordActivity(
      activityType: activityType,
      description: description,
      metadata: metadata,
      userId: userId,
    );
  }

  /// Get user activities stream
  static Stream<List<ActivityRecord>> getUserActivitiesStream({
    required String userId,
    int limit = 20,
  }) {
    return _firestore
        .collection('activities')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ActivityRecord.fromFirestore(doc))
              .toList();
        });
  }

  /// Create sample activities for demo/development
  static Future<void> createSampleActivities(String userId) async {
    final activities = [
      {
        'activityType': 'goal_created',
        'description': 'Created new goal: "Complete React Certification"',
        'metadata': {
          'goalTitle': 'Complete React Certification',
          'priority': 'high',
        },
      },
      {
        'activityType': 'goal_progress',
        'description':
            'Updated progress on "Complete React Certification" to 45%',
        'metadata': {'progress': 45, 'previousProgress': 30},
      },
      {
        'activityType': 'nudge_received',
        'description': 'Received manager nudge about goal progress',
        'metadata': {'fromManager': 'Manager Name'},
      },
      {
        'activityType': 'goal_completed',
        'description': 'Completed goal: "Learn TypeScript Basics"',
        'metadata': {'pointsEarned': 50},
      },
      {
        'activityType': 'log_created',
        'description': 'Created development log entry',
        'metadata': {'category': 'learning'},
      },
    ];

    for (final activity in activities) {
      await recordActivity(
        activityType: activity['activityType'] as String,
        description: activity['description'] as String,
        metadata: activity['metadata'] as Map<String, dynamic>?,
        userId: userId,
      );
    }

    developer.log(
      'Created ${activities.length} sample activities for user $userId',
    );
  }
}

/// Activity record data model
class ActivityRecord {
  final String id;
  final String userId;
  final String activityType;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const ActivityRecord({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.description,
    required this.timestamp,
    required this.metadata,
    required this.createdAt,
  });

  factory ActivityRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ActivityRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      activityType: data['activityType'] ?? 'unknown',
      description: data['description'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
