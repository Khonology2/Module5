class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final int totalPoints;
  final int level;
  final List<String> badges;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.totalPoints,
    required this.level,
    required this.badges,
  });
}


