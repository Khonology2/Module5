import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/user_profile.dart';

class DatabaseService {
  static Future<UserProfile> getUserProfile(String uid) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    return UserProfile(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? data['fullName'] ?? '',
      totalPoints: (data['totalPoints'] ?? 0) as int,
      level: (data['level'] ?? 1) as int,
      badges: List<String>.from(data['badges'] ?? const []),
    );
  }

  static Future<List<Goal>> getUserGoals(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return Goal(
        id: doc.id,
        userId: data['userId'] ?? uid,
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        category: GoalCategory.values.firstWhere(
          (e) => e.name == (data['category'] ?? 'personal'),
          orElse: () => GoalCategory.personal,
        ),
        priority: GoalPriority.values.firstWhere(
          (e) => e.name == (data['priority'] ?? 'medium'),
          orElse: () => GoalPriority.medium,
        ),
        status: GoalStatus.values.firstWhere(
          (e) => e.name == (data['status'] ?? 'notStarted'),
          orElse: () => GoalStatus.notStarted,
        ),
        progress: (data['progress'] ?? 0) as int,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        targetDate: (data['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        points: (data['points'] ?? 0) as int,
      );
    }).toList();
  }

  static Future<String> createGoal(Goal goal) async {
    final doc = await FirebaseFirestore.instance.collection('goals').add({
      'userId': goal.userId,
      'title': goal.title,
      'description': goal.description,
      'category': goal.category.name,
      'priority': goal.priority.name,
      'status': goal.status.name,
      'progress': goal.progress,
      'createdAt': Timestamp.fromDate(goal.createdAt),
      'targetDate': Timestamp.fromDate(goal.targetDate),
      'points': goal.points,
    });
    return doc.id;
  }
}


