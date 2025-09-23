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
      role: data['role'] ?? 'employee', // Deserialize role
      jobTitle: data['jobTitle'] ?? '',
      department: data['department'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      profilePhotoUrl: data['profilePhotoUrl'],
      skills: List<String>.from(data['skills'] ?? const []),
      developmentAreas: List<String>.from(data['developmentAreas'] ?? const []),
      careerAspirations: data['careerAspirations'] ?? '',
      currentProjects: data['currentProjects'] ?? '',
      learningStyle: data['learningStyle'] ?? '',
      preferredDevActivities: List<String>.from(data['preferredDevActivities'] ?? const []),
      shortGoals: data['shortGoals'] ?? '',
      longGoals: data['longGoals'] ?? '',
      notificationFrequency: data['notificationFrequency'] ?? 'daily',
      goalVisibility: data['goalVisibility'] ?? 'private',
      leaderboardOptin: data['leaderboardOptin'] ?? false,
      badgeName: data['badgeName'] ?? '',
      celebrationConsent: data['celebrationConsent'] ?? 'private',
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

  static Future<void> initializeSubcollections(DocumentReference userDocRef) async {
    final subcollections = ['goals', 'streaks', 'badges', 'alerts', 'development_activities'];

    for (String sub in subcollections) {
      final subRef = userDocRef.collection(sub).doc('init');
      final subSnap = await subRef.get();
      if (!subSnap.exists) {
        await subRef.set({
          'placeholder': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  static Future<void> initializeUserData(String uid, String? displayName, String? email, {String role = 'employee'}) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final docSnapshot = await userDocRef.get();
    if (!docSnapshot.exists) {
      await userDocRef.set({
        'displayName': displayName ?? '', // Use displayName as full name, or an empty string
        'email': email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'role': role, // default role, only set on creation
        'totalPoints': 0,
        'level': 1,
        'badges': [],
        'jobTitle': '',
        'department': '',
        'phoneNumber': '',
        'profilePhotoUrl': null,
        'skills': [],
        'developmentAreas': [],
        'careerAspirations': '',
        'currentProjects': '',
        'learningStyle': '',
        'preferredDevActivities': [],
        'shortGoals': '',
        'longGoals': '',
        'notificationFrequency': 'daily',
        'goalVisibility': 'private',
        'leaderboardOptin': false,
        'badgeName': '',
        'celebrationConsent': 'private',
      });
    } else {
      // Only update fields that might change, excluding 'role'
      await userDocRef.update({
        'displayName': displayName ?? docSnapshot.data()?['displayName'] ?? '',
        'email': email ?? docSnapshot.data()?['email'] ?? '',
        // Other fields will be updated by a dedicated updateUserProfile method.
      });
    }

    await initializeSubcollections(userDocRef);
  }

  static Future<void> updateUserProfile(UserProfile userProfile) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(userProfile.uid);
    await userDocRef.update(userProfile.toFirestore());
  }

  static Future<Map<String, dynamic>> getDashboardData(String uid) async {
    final userDocRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final doc = await userDocRef.get();
    final goals = await userDocRef.collection('goals').get();
    final streaks = await userDocRef.collection('streaks').get();
    final badges = await userDocRef.collection('badges').get();
    final alerts = await userDocRef.collection('alerts').get();

    return {
      'profile': doc.data(),
      'goals': goals.docs.map((d) => d.data()).toList(),
      'streaks': streaks.docs.map((d) => d.data()).toList(),
      'badges': badges.docs.map((d) => d.data()).toList(),
      'alerts': alerts.docs.map((d) => d.data()).toList(),
    };
  }
}


