import 'package:flutter/material.dart';
import 'package:pdh/leaderboard_screen.dart';

/// Manager Leaderboard screen - uses the same shared LeaderboardScreen as admin
class ManagerLeaderboardScreen extends StatelessWidget {
  final bool embedded;
  final bool compareManagers;
  const ManagerLeaderboardScreen({
    super.key,
    this.embedded = false,
    this.compareManagers = false,
  });

  @override
  Widget build(BuildContext context) {
    return LeaderboardScreen(
      forAdminOversight: compareManagers,
      compareManagers: compareManagers,
      embedded: embedded,
      suppressShellTitleBanner: true,
    );
  }
}
