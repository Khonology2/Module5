import 'package:flutter/material.dart';
import 'package:pdh/leaderboard_screen.dart';

/// Admin-only leaderboard. Delegates to [LeaderboardScreen];
/// rankings are loaded from PostgreSQL via [BackendAuthService].
class AdminLeaderboardScreen extends StatelessWidget {
  const AdminLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LeaderboardScreen(forAdminOversight: true);
  }
}
