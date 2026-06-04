import 'package:pdh/utils/date_parse.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final int totalPoints;
  final int level;
  final List<String> badges;
  final List<String> badgesV2;
  final String role; // Added for user roles (e.g., 'employee', 'manager')

  // New fields from EmployeeProfileScreen
  final String jobTitle;
  final String department;
  final String phoneNumber;
  final String? profilePhotoUrl; // Nullable as it might not always be set
  final List<String> skills;
  final List<String> developmentAreas;
  final String careerAspirations;
  final String currentProjects;
  final String learningStyle;
  final List<String> preferredDevActivities;
  final String shortGoals;
  final String longGoals;
  final String notificationFrequency;
  final String goalVisibility;
  final bool leaderboardOptin;
  final String badgeName;
  final String celebrationConsent;
  final DateTime? lastLoginAt;
  final DateTime? lastActivityAt;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.totalPoints,
    required this.level,
    required this.badges,
    this.badgesV2 = const [],
    this.role = 'employee', // Default role
    // Initialize new fields
    this.jobTitle = '',
    this.department = '',
    this.phoneNumber = '',
    this.profilePhotoUrl,
    this.skills = const [],
    this.developmentAreas = const [],
    this.careerAspirations = '',
    this.currentProjects = '',
    this.learningStyle = '',
    this.preferredDevActivities = const [],
    this.shortGoals = '',
    this.longGoals = '',
    this.notificationFrequency = 'daily',
    this.goalVisibility = 'private',
    this.leaderboardOptin = false,
    this.badgeName = '',
    this.celebrationConsent = 'private',
    this.lastLoginAt,
    this.lastActivityAt,
  });

  factory UserProfile.fromBackendMap(
    Map<String, dynamic> data, {
    String? fallbackId,
  }) {
    DateTime? readDate(dynamic v) => parseNullableDate(v);

    final dn = (data['displayName']?.toString() ?? '').trim();
    final fn = (data['fullName']?.toString() ?? '').trim();

    return UserProfile(
      uid: (data['userId'] ?? data['id'] ?? fallbackId ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      displayName: dn.isNotEmpty ? dn : fn,
      totalPoints: (data['totalPoints'] ?? 0) is num
          ? (data['totalPoints'] as num).toInt()
          : int.tryParse(data['totalPoints']?.toString() ?? '0') ?? 0,
      level: (data['level'] ?? 1) is num
          ? (data['level'] as num).toInt()
          : int.tryParse(data['level']?.toString() ?? '1') ?? 1,
      badges: List<String>.from(data['badges'] ?? const []),
      badgesV2: List<String>.from(data['badgesV2'] ?? const []),
      role: (data['role'] ?? 'employee').toString(),
      jobTitle: (data['jobTitle'] ?? '').toString(),
      department: (data['department'] ?? '').toString(),
      phoneNumber: (data['phoneNumber'] ?? '').toString(),
      profilePhotoUrl: data['profilePhotoUrl']?.toString(),
      skills: List<String>.from(data['skills'] ?? const []),
      developmentAreas: List<String>.from(data['developmentAreas'] ?? const []),
      careerAspirations: (data['careerAspirations'] ?? '').toString(),
      currentProjects: (data['currentProjects'] ?? '').toString(),
      learningStyle: (data['learningStyle'] ?? '').toString(),
      preferredDevActivities: List<String>.from(
        data['preferredDevActivities'] ?? const [],
      ),
      shortGoals: (data['shortGoals'] ?? '').toString(),
      longGoals: (data['longGoals'] ?? '').toString(),
      notificationFrequency: (data['notificationFrequency'] ?? 'daily').toString(),
      goalVisibility: (data['goalVisibility'] ?? 'private').toString(),
      leaderboardOptin: data['leaderboardOptin'] == true ||
          data['leaderboardParticipation'] == true,
      badgeName: (data['badgeName'] ?? '').toString(),
      celebrationConsent: (data['celebrationConsent'] ?? 'private').toString(),
      lastLoginAt: readDate(data['lastLoginAt']),
      lastActivityAt: readDate(data['lastActivityAt']),
    );
  }

  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId) 'userId': uid,
      'email': email,
      'displayName': displayName,
      'totalPoints': totalPoints,
      'level': level,
      'badges': badges,
      'badgesV2': badgesV2,
      'role': role,
      'jobTitle': jobTitle,
      'department': department,
      'phoneNumber': phoneNumber,
      'profilePhotoUrl': profilePhotoUrl,
      'skills': skills,
      'developmentAreas': developmentAreas,
      'careerAspirations': careerAspirations,
      'currentProjects': currentProjects,
      'learningStyle': learningStyle,
      'preferredDevActivities': preferredDevActivities,
      'shortGoals': shortGoals,
      'longGoals': longGoals,
      'notificationFrequency': notificationFrequency,
      'goalVisibility': goalVisibility,
      'leaderboardOptin': leaderboardOptin,
      'leaderboardParticipation': leaderboardOptin,
      'badgeName': badgeName,
      'celebrationConsent': celebrationConsent,
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'lastActivityAt': lastActivityAt?.toIso8601String(),
    };
  }

  // copyWith method for immutability
  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    int? totalPoints,
    int? level,
    List<String>? badges,
    List<String>? badgesV2,
    String? role, // Add role to copyWith
    String? jobTitle,
    String? department,
    String? phoneNumber,
    String? profilePhotoUrl,
    List<String>? skills,
    List<String>? developmentAreas,
    String? careerAspirations,
    String? currentProjects,
    String? learningStyle,
    List<String>? preferredDevActivities,
    String? shortGoals,
    String? longGoals,
    String? notificationFrequency,
    String? goalVisibility,
    bool? leaderboardOptin,
    String? badgeName,
    String? celebrationConsent,
    DateTime? lastLoginAt,
    DateTime? lastActivityAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      totalPoints: totalPoints ?? this.totalPoints,
      level: level ?? this.level,
      badges: badges ?? this.badges,
      badgesV2: badgesV2 ?? this.badgesV2,
      role: role ?? this.role, // Update role in copyWith
      jobTitle: jobTitle ?? this.jobTitle,
      department: department ?? this.department,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      skills: skills ?? this.skills,
      developmentAreas: developmentAreas ?? this.developmentAreas,
      careerAspirations: careerAspirations ?? this.careerAspirations,
      currentProjects: currentProjects ?? this.currentProjects,
      learningStyle: learningStyle ?? this.learningStyle,
      preferredDevActivities:
          preferredDevActivities ?? this.preferredDevActivities,
      shortGoals: shortGoals ?? this.shortGoals,
      longGoals: longGoals ?? this.longGoals,
      notificationFrequency:
          notificationFrequency ?? this.notificationFrequency,
      goalVisibility: goalVisibility ?? this.goalVisibility,
      leaderboardOptin: leaderboardOptin ?? this.leaderboardOptin,
      badgeName: badgeName ?? this.badgeName,
      celebrationConsent: celebrationConsent ?? this.celebrationConsent,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    );
  }

  static UserProfile fromMap(Map<String, dynamic> map, {String? id}) {
    return UserProfile.fromBackendMap(
      map,
      fallbackId: id ?? map['uid']?.toString() ?? map['userId']?.toString(),
    );
  }
}
