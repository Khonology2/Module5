import 'package:flutter/material.dart';
import 'package:pdh/team_challenges_seasons_screen.dart';

/// Admin-only Team Challenges screen. Uses the same UI as the manager screen.
/// Not shared with manager/employee.
class AdminTeamChallengesScreen extends StatelessWidget {
  const AdminTeamChallengesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeamChallengesSeasonsScreen(forAdminOversight: true);
  }
}
