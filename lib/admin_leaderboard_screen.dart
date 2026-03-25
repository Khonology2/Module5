import 'package:flutter/material.dart';
import 'package:pdh/leaderboard_screen.dart';

/// Admin-only Leaderboard screen. Uses the same UI as the shared leaderboard.
/// Not shared with manager/employee as a route target.
class AdminLeaderboardScreen extends StatelessWidget {
  const AdminLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LeaderboardScreen(forAdminOversight: true);
  }
}
