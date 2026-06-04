import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdh/services/backend_auth_service.dart';

class UserSettings {
  final String userId;
  final String displayName;
  final String email;
  final String? photoURL;
  final String? department;
  final String? jobTitle;
  final bool privateGoals;
  final bool managerOnly;
  final bool teamShare;
  final bool leaderboardParticipation;
  final bool profileVisible;
  final bool pushNotifications;
  final bool emailNotifications;
  final bool soundAlerts;
  final bool goalReminders;
  final bool weeklyReports;
  final bool darkMode;
  final bool speechRecognitionEnabled;
  final bool celebrationFeed;
  final bool autoSync;
  final String language;
  final String timeZone;
  final bool tutorialEnabled;
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
    this.leaderboardParticipation = false,
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
    this.tutorialEnabled = false,
    this.twoFactorAuth = false,
    this.sessionTimeout = false,
    this.sessionTimeoutMinutes = 30,
    this.biometricAuth = false,
  });

  factory UserSettings.fromJson(Map<String, dynamic> data) {
    return UserSettings(
      userId: (data['userId'] ?? data['user_id'] ?? '').toString(),
      displayName: (data['displayName'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      photoURL: data['photoURL']?.toString(),
      department: data['department']?.toString(),
      jobTitle: data['jobTitle']?.toString(),
      privateGoals: data['privateGoals'] == true,
      managerOnly: data['managerOnly'] == true,
      teamShare: data['teamShare'] != false,
      leaderboardParticipation: data['leaderboardParticipation'] == true,
      profileVisible: data['profileVisible'] != false,
      pushNotifications: data['pushNotifications'] != false,
      emailNotifications: data['emailNotifications'] != false,
      soundAlerts: data['soundAlerts'] != false,
      goalReminders: data['goalReminders'] != false,
      weeklyReports: data['weeklyReports'] == true,
      darkMode: data['darkMode'] != false,
      speechRecognitionEnabled: data['speechRecognitionEnabled'] == true,
      celebrationFeed: data['celebrationFeed'] != false,
      autoSync: data['autoSync'] != false,
      language: (data['language'] ?? 'en').toString(),
      timeZone: (data['timeZone'] ?? 'UTC').toString(),
      tutorialEnabled: data['tutorialEnabled'] == true,
      twoFactorAuth: data['twoFactorAuth'] == true,
      sessionTimeout: data['sessionTimeout'] == true,
      sessionTimeoutMinutes:
          int.tryParse((data['sessionTimeoutMinutes'] ?? 30).toString()) ?? 30,
      biometricAuth: data['biometricAuth'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'photoURL': photoURL,
      'department': department,
      'jobTitle': jobTitle,
      'privateGoals': privateGoals,
      'managerOnly': managerOnly,
      'teamShare': teamShare,
      'leaderboardParticipation': leaderboardParticipation,
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
      'tutorialEnabled': tutorialEnabled,
      'twoFactorAuth': twoFactorAuth,
      'sessionTimeout': sessionTimeout,
      'sessionTimeoutMinutes': sessionTimeoutMinutes,
      'biometricAuth': biometricAuth,
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
    bool? tutorialEnabled,
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
      leaderboardParticipation:
          leaderboardParticipation ?? this.leaderboardParticipation,
      profileVisible: profileVisible ?? this.profileVisible,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      soundAlerts: soundAlerts ?? this.soundAlerts,
      goalReminders: goalReminders ?? this.goalReminders,
      weeklyReports: weeklyReports ?? this.weeklyReports,
      darkMode: darkMode ?? this.darkMode,
      speechRecognitionEnabled:
          speechRecognitionEnabled ?? this.speechRecognitionEnabled,
      celebrationFeed: celebrationFeed ?? this.celebrationFeed,
      autoSync: autoSync ?? this.autoSync,
      language: language ?? this.language,
      timeZone: timeZone ?? this.timeZone,
      tutorialEnabled: tutorialEnabled ?? this.tutorialEnabled,
      twoFactorAuth: twoFactorAuth ?? this.twoFactorAuth,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
      biometricAuth: biometricAuth ?? this.biometricAuth,
    );
  }
}

class SettingsService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static String? _cachedUserId;
  static final Map<String, Future<void>> _initInFlightByUserId = {};

  static void clearCache() {
    _cachedUserId = null;
  }

  static Future<void> _ensureUserSettingsDocInitialized(
    String uid,
    UserSettings defaultSettings,
  ) {
    final existing = _initInFlightByUserId[uid];
    if (existing != null) return existing;

    final fut = BackendAuthService.instance
        .updateUserSettings(uid, defaultSettings.toJson())
        .catchError((e) {
          developer.log('Error initializing user settings: $e');
          throw e;
        })
        .whenComplete(() {
          _initInFlightByUserId.remove(uid);
        });
    _initInFlightByUserId[uid] = fut;
    return fut;
  }

  static UserSettings getDefaultSettings(User user) {
    return UserSettings(
      userId: user.uid,
      displayName: user.displayName ?? '',
      email: user.email ?? '',
      photoURL: user.photoURL,
    );
  }

  static Stream<UserSettings?> getUserSettingsStream() async* {
    final user = _auth.currentUser;
    if (user == null) {
      clearCache();
      yield null;
      return;
    }

    if (_cachedUserId != user.uid) {
      clearCache();
      _cachedUserId = user.uid;
    }

    while (true) {
      yield await getUserSettings();
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  static Future<UserSettings?> getUserSettings() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final json = await BackendAuthService.instance.getUserSettings(user.uid);
      if (json.isEmpty) {
        final defaults = getDefaultSettings(user);
        try {
          await _ensureUserSettingsDocInitialized(user.uid, defaults);
        } catch (_) {}
        return defaults;
      }
      return UserSettings.fromJson(json);
    } catch (e) {
      developer.log('Error getting user settings: $e');
      final defaults = getDefaultSettings(user);
      try {
        await _ensureUserSettingsDocInitialized(user.uid, defaults);
      } catch (_) {}
      return defaults;
    }
  }

  static Future<void> updateUserSettings(UserSettings settings) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    try {
      await BackendAuthService.instance.updateUserSettings(
        user.uid,
        settings.toJson(),
      );
      await _saveLocalSettings(settings);
    } catch (e) {
      developer.log('Error updating user settings: $e');
      rethrow;
    }
  }

  static Future<void> updateSetting(String key, dynamic value) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    try {
      final payload = <String, dynamic>{key: value};
      if (key == 'leaderboardParticipation') {
        payload['leaderboardOptin'] = value;
      }
      await BackendAuthService.instance.updateUserSettings(user.uid, payload);
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

  static Future<void> _saveLocalSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', settings.darkMode);
    await prefs.setBool('speechRecognitionEnabled', settings.speechRecognitionEnabled);
    await prefs.setBool('pushNotifications', settings.pushNotifications);
    await prefs.setBool('autoSync', settings.autoSync);
    await prefs.setString('language', settings.language);
  }

  static Future<Map<String, dynamic>> getLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'darkMode': prefs.getBool('darkMode') ?? true,
      'speechRecognitionEnabled':
          prefs.getBool('speechRecognitionEnabled') ?? false,
      'pushNotifications': prefs.getBool('pushNotifications') ?? true,
      'autoSync': prefs.getBool('autoSync') ?? true,
      'language': prefs.getString('language') ?? 'en',
    };
  }

  static Future<void> updateProfile({
    required String displayName,
    String? photoURL,
    String? department,
    String? jobTitle,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    try {
      await user.updateDisplayName(displayName);
      if (photoURL != null && photoURL.isNotEmpty) {
        await user.updatePhotoURL(photoURL);
      }
      final payload = <String, dynamic>{'displayName': displayName};
      if (photoURL != null) payload['photoURL'] = photoURL;
      if (department != null) payload['department'] = department;
      if (jobTitle != null) payload['jobTitle'] = jobTitle;
      await BackendAuthService.instance.updateUserProfile(user.uid, payload);
    } catch (e) {
      developer.log('Error updating profile: $e');
      rethrow;
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      developer.log('Error sending password reset email: $e');
      rethrow;
    }
  }

  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await user.delete();
    } catch (e) {
      developer.log('Error deleting account: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> exportUserData() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final profile = await BackendAuthService.instance.getUser(user.uid);
    final settings = await getUserSettings();
    return {
      'profile': profile,
      'settings': settings?.toJson() ?? <String, dynamic>{},
      'goals': const [],
      'activities': const [],
      'badges': const [],
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

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

  static Future<void> initializeUserSettings(User user) async {
    try {
      final defaultSettings = getDefaultSettings(user);
      await _ensureUserSettingsDocInitialized(user.uid, defaultSettings);
    } catch (e) {
      developer.log('Error initializing user settings: $e');
      rethrow;
    }
  }
}

