import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final int totalPoints;
  final int level;
  final List<String> badges;
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

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.totalPoints,
    required this.level,
    required this.badges,
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
  });

  // Factory constructor to create a UserProfile from a Firestore DocumentSnapshot
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return UserProfile(
      uid: doc.id,
      email: data?['email'] ?? '',
      displayName: data?['displayName'] ?? '',
      totalPoints: (data?['totalPoints'] ?? 0) as int,
      level: (data?['level'] ?? 1) as int,
      badges: List<String>.from(data?['badges'] ?? const []),
      role: data?['role'] ?? 'employee', // Deserialize role
      jobTitle: data?['jobTitle'] ?? '',
      department: data?['department'] ?? '',
      phoneNumber: data?['phoneNumber'] ?? '',
      profilePhotoUrl: data?['profilePhotoUrl'],
      skills: List<String>.from(data?['skills'] ?? const []),
      developmentAreas: List<String>.from(data?['developmentAreas'] ?? const []),
      careerAspirations: data?['careerAspirations'] ?? '',
      currentProjects: data?['currentProjects'] ?? '',
      learningStyle: data?['learningStyle'] ?? '',
      preferredDevActivities: List<String>.from(data?['preferredDevActivities'] ?? const []),
      shortGoals: data?['shortGoals'] ?? '',
      longGoals: data?['longGoals'] ?? '',
      notificationFrequency: data?['notificationFrequency'] ?? 'daily',
      goalVisibility: data?['goalVisibility'] ?? 'private',
      leaderboardOptin: data?['leaderboardOptin'] ?? false,
      badgeName: data?['badgeName'] ?? '',
      celebrationConsent: data?['celebrationConsent'] ?? 'private',
    );
  }

  // Method to convert UserProfile to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'totalPoints': totalPoints,
      'level': level,
      'badges': badges,
      'role': role, // Serialize role
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
      'badgeName': badgeName,
      'celebrationConsent': celebrationConsent,
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
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      totalPoints: totalPoints ?? this.totalPoints,
      level: level ?? this.level,
      badges: badges ?? this.badges,
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
      preferredDevActivities: preferredDevActivities ?? this.preferredDevActivities,
      shortGoals: shortGoals ?? this.shortGoals,
      longGoals: longGoals ?? this.longGoals,
      notificationFrequency: notificationFrequency ?? this.notificationFrequency,
      goalVisibility: goalVisibility ?? this.goalVisibility,
      leaderboardOptin: leaderboardOptin ?? this.leaderboardOptin,
      badgeName: badgeName ?? this.badgeName,
      celebrationConsent: celebrationConsent ?? this.celebrationConsent,
    );
  }
}


