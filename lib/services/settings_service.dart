import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSettings {
  final String userId;
  final String displayName;
  final String email;
  final String? photoURL;
  final String? department;
  final String? jobTitle;
  
  // Privacy Settings
  final bool privateGoals;
  final bool managerOnly;
  final bool teamShare;
  final bool leaderboardParticipation;
  final bool profileVisible;
  
  // Notification Settings
  final bool pushNotifications;
  final bool emailNotifications;
  final bool soundAlerts;
  final bool goalReminders;
  final bool weeklyReports;
  
  // App Settings
  final bool darkMode;
  final bool speechRecognitionEnabled;
  final bool celebrationFeed;
  final bool autoSync;
  final String language;
  final String timeZone;
  
  // Security Settings
  final bool twoFactorAuth;
  final bool sessionTimeout;
  final int sessionTimeoutMinutes;
  final bool biometricAuth;

  UserSettings({
    required this.userId,
    required this.displayName,
    required this.email,
    this.photoURL,
    this.department,
    this.jobTitle,
    this.privateGoals = false,
    this.managerOnly = false,
    this.teamShare = true,
    this.leaderboardParticipation = false, // Default to false, require opt-in
    this.profileVisible = true,
    this.pushNotifications = true,
    this.emailNotifications = true,
    this.soundAlerts = true,
    this.goalReminders = true,
    this.weeklyReports = false,
    this.darkMode = true,
    this.speechRecognitionEnabled = false,
    this.celebrationFeed = true,
    this.autoSync = true,
    this.language = 'en',
    this.timeZone = 'UTC',
    this.twoFactorAuth = false,
    this.sessionTimeout = false,
    this.sessionTimeoutMinutes = 30,
    this.biometricAuth = false,
  });

  factory UserSettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserSettings(
      userId: doc.id,
      displayName: data['displayName']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      photoURL: data['photoURL']?.toString(),
      department: data['department']?.toString(),
      jobTitle: data['jobTitle']?.toString(),
      privateGoals: data['privateGoals'] ?? false,
      managerOnly: data['managerOnly'] ?? false,
      teamShare: data['teamShare'] ?? true,
      leaderboardParticipation: data['leaderboardParticipation'] ?? false,
      profileVisible: data['profileVisible'] ?? true,
      pushNotifications: data['pushNotifications'] ?? true,
      emailNotifications: data['emailNotifications'] ?? true,
      soundAlerts: data['soundAlerts'] ?? true,
      goalReminders: data['goalReminders'] ?? true,
      weeklyReports: data['weeklyReports'] ?? false,
      darkMode: data['darkMode'] ?? true,
      speechRecognitionEnabled: data['speechRecognitionEnabled'] ?? false,
      celebrationFeed: data['celebrationFeed'] ?? true,
      autoSync: data['autoSync'] ?? true,
      language: data['language'] ?? 'en',
      timeZone: data['timeZone'] ?? 'UTC',
      twoFactorAuth: data['twoFactorAuth'] ?? false,
      sessionTimeout: data['sessionTimeout'] ?? false,
      sessionTimeoutMinutes: data['sessionTimeoutMinutes'] ?? 30,
      biometricAuth: data['biometricAuth'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'department': department,
      'jobTitle': jobTitle,
      'privateGoals': privateGoals,
      'managerOnly': managerOnly,
      'teamShare': teamShare,
      'leaderboardParticipation': leaderboardParticipation,
      'leaderboardOptin': leaderboardParticipation, // Sync both fields for compatibility
      'profileVisible': profileVisible,
      'pushNotifications': pushNotifications,
      'emailNotifications': emailNotifications,
      'soundAlerts': soundAlerts,
      'goalReminders': goalReminders,
      'weeklyReports': weeklyReports,
      'darkMode': darkMode,
      'speechRecognitionEnabled': speechRecognitionEnabled,
      'celebrationFeed': celebrationFeed,
      'autoSync': autoSync,
      'language': language,
      'timeZone': timeZone,
      'twoFactorAuth': twoFactorAuth,
      'sessionTimeout': sessionTimeout,
      'sessionTimeoutMinutes': sessionTimeoutMinutes,
      'biometricAuth': biometricAuth,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  UserSettings copyWith({
    String? displayName,
    String? email,
    String? photoURL,
    String? department,
    String? jobTitle,
    bool? privateGoals,
    bool? managerOnly,
    bool? teamShare,
    bool? leaderboardParticipation,
    bool? profileVisible,
    bool? pushNotifications,
    bool? emailNotifications,
    bool? soundAlerts,
    bool? goalReminders,
    bool? weeklyReports,
    bool? darkMode,
    bool? speechRecognitionEnabled,
    bool? celebrationFeed,
    bool? autoSync,
    String? language,
    String? timeZone,
    bool? twoFactorAuth,
    bool? sessionTimeout,
    int? sessionTimeoutMinutes,
    bool? biometricAuth,
  }) {
    return UserSettings(
      userId: userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoURL: photoURL ?? this.photoURL,
      department: department ?? this.department,
      jobTitle: jobTitle ?? this.jobTitle,
      privateGoals: privateGoals ?? this.privateGoals,
      managerOnly: managerOnly ?? this.managerOnly,
      teamShare: teamShare ?? this.teamShare,
      leaderboardParticipation: leaderboardParticipation ?? this.leaderboardParticipation,
      profileVisible: profileVisible ?? this.profileVisible,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      soundAlerts: soundAlerts ?? this.soundAlerts,
      goalReminders: goalReminders ?? this.goalReminders,
      weeklyReports: weeklyReports ?? this.weeklyReports,
      darkMode: darkMode ?? this.darkMode,
      speechRecognitionEnabled: speechRecognitionEnabled ?? this.speechRecognitionEnabled,
      celebrationFeed: celebrationFeed ?? this.celebrationFeed,
      autoSync: autoSync ?? this.autoSync,
      language: language ?? this.language,
      timeZone: timeZone ?? this.timeZone,
      twoFactorAuth: twoFactorAuth ?? this.twoFactorAuth,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
      sessionTimeoutMinutes: sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      biometricAuth: biometricAuth ?? this.biometricAuth,
    );
  }
}

class SettingsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user settings stream
  static Stream<UserSettings?> getUserSettingsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) {
        // Initialize default settings for new users
        final defaultSettings = getDefaultSettings(user);
        // Save to Firestore asynchronously
        _firestore.collection('users').doc(user.uid).set(defaultSettings.toFirestore());
        return defaultSettings;
      }
      return UserSettings.fromFirestore(snapshot);
    }).handleError((error) {
      developer.log('Error in user settings stream: $error');
      // Return default settings if there's an error
      return getDefaultSettings(user);
    });
  }

  // Get user settings once
  static Future<UserSettings?> getUserSettings() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      if (!snapshot.exists) return null;
      return UserSettings.fromFirestore(snapshot);
    } catch (e) {
      developer.log('Error getting user settings: $e');
      return null;
    }
  }

  // Update user settings
  static Future<void> updateUserSettings(UserSettings settings) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update(settings.toFirestore());
      
      // Also save certain settings locally
      await _saveLocalSettings(settings);
    } catch (e) {
      developer.log('Error updating user settings: $e');
      rethrow;
    }
  }

  // Update specific setting
  static Future<void> updateSetting(String key, dynamic value) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      Map<String, dynamic> updateData = {
        key: value,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      // Sync leaderboardParticipation with leaderboardOptin for compatibility
      if (key == 'leaderboardParticipation') {
        updateData['leaderboardOptin'] = value;
      }

      // Use set with merge to handle both create and update cases
      // This ensures the document exists even if it wasn't created yet
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      // Save locally if it's a critical setting
      if (_criticalSettings.contains(key)) {
        final prefs = await SharedPreferences.getInstance();
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        }
      }
    } catch (e) {
      developer.log('Error updating setting $key: $e');
      rethrow;
    }
  }

  // Save critical settings locally
  static Future<void> _saveLocalSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', settings.darkMode);
    await prefs.setBool('speechRecognitionEnabled', settings.speechRecognitionEnabled);
    await prefs.setBool('pushNotifications', settings.pushNotifications);
    await prefs.setBool('autoSync', settings.autoSync);
    await prefs.setString('language', settings.language);
  }

  // Load local settings
  static Future<Map<String, dynamic>> getLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'darkMode': prefs.getBool('darkMode') ?? true,
      'speechRecognitionEnabled': prefs.getBool('speechRecognitionEnabled') ?? false,
      'pushNotifications': prefs.getBool('pushNotifications') ?? true,
      'autoSync': prefs.getBool('autoSync') ?? true,
      'language': prefs.getString('language') ?? 'en',
    };
  }

  // Update profile information
  static Future<void> updateProfile({
    required String displayName,
    String? photoURL,
    String? department,
    String? jobTitle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Update Firebase Auth profile
      await user.updateDisplayName(displayName);
      if (photoURL != null && photoURL.isNotEmpty) {
        await user.updatePhotoURL(photoURL);
      }

      // Update Firestore document
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        if (department != null) 'department': department,
        if (jobTitle != null) 'jobTitle': jobTitle,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      developer.log('Error updating profile: $e');
      rethrow;
    }
  }

  // Reset password
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      developer.log('Error sending password reset email: $e');
      rethrow;
    }
  }

  // Delete account
  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final uid = user.uid;
      final emailLower = (user.email ?? '').toLowerCase();

      // Record blocklist entry first (prevents future login/registration by email)
      if (emailLower.isNotEmpty) {
        try {
          await _firestore.collection('deleted_accounts').doc(uid).set({
            'uid': uid,
            'emailLower': emailLower,
            'deletedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          developer.log('Warning: could not write deleted_accounts for $uid: $e');
        }
      }

      // Delete top-level documents referencing this user
      Future<void> deleteWhere(String collection, String field) async {
        final snap = await _firestore
            .collection(collection)
            .where(field, isEqualTo: uid)
            .get();
        final batch = _firestore.batch();
        for (final d in snap.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }

      try { await deleteWhere('goals', 'userId'); } catch (e) { developer.log('delete goals failed: $e'); }
      try { await deleteWhere('alerts', 'userId'); } catch (e) { developer.log('delete alerts failed: $e'); }
      try { await deleteWhere('activities', 'userId'); } catch (e) { developer.log('delete activities failed: $e'); }
      try { await deleteWhere('goal_daily_progress', 'userId'); } catch (e) { developer.log('delete goal_daily_progress failed: $e'); }

      // Delete any subcollections under users/{uid}
      final subcollections = [
        'goals',
        'streaks',
        'badges',
        'alerts',
        'development_activities',
        'daily_activities',
      ];
      for (final sub in subcollections) {
        try {
          final subSnap = await _firestore
              .collection('users')
              .doc(uid)
              .collection(sub)
              .get();
          final batch = _firestore.batch();
          for (final d in subSnap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
        } catch (e) {
          developer.log('Error deleting subcollection $sub for $uid: $e');
        }
      }

      // Delete the user profile document last
      try {
        await _firestore.collection('users').doc(uid).delete();
      } catch (e) {
        developer.log('Error deleting users/$uid: $e');
      }

      // Delete evidence files metadata for this user (best-effort)
      try {
        await deleteWhere('evidence_files', 'userId');
      } catch (e) {
        developer.log('Error deleting evidence_files for $uid: $e');
      }

      // Clear local settings
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Finally, delete Firebase Auth account
      await user.delete();
    } catch (e) {
      developer.log('Error deleting account: $e');
      rethrow;
    }
  }

  // Export user data
  static Future<Map<String, dynamic>> exportUserData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final userData = await _firestore.collection('users').doc(user.uid).get();
      final goalsQuery = await _firestore
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .get();

      return {
        'profile': userData.data(),
        'goals': goalsQuery.docs.map((doc) => doc.data()).toList(),
        'exportDate': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      developer.log('Error exporting user data: $e');
      rethrow;
    }
  }

  // Critical settings that should be saved locally
  static const List<String> _criticalSettings = [
    'darkMode',
    'speechRecognitionEnabled',
    'pushNotifications',
    'autoSync',
    'language',
    'leaderboardParticipation',
    'privateGoals',
    'managerOnly',
    'soundAlerts',
    'emailNotifications',
    'twoFactorAuth',
    'sessionTimeout',
    'celebrationFeed',
  ];

  // Get default settings for new users
  static UserSettings getDefaultSettings(User user) {
    return UserSettings(
      userId: user.uid,
      displayName: user.displayName ?? '',
      email: user.email ?? '',
      photoURL: user.photoURL,
    );
  }

  // Initialize settings for new user
  static Future<void> initializeUserSettings(User user) async {
    try {
      final defaultSettings = getDefaultSettings(user);
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(defaultSettings.toFirestore());
    } catch (e) {
      developer.log('Error initializing user settings: $e');
      rethrow;
    }
  }
}
