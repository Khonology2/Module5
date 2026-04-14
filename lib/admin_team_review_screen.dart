import 'package:flutter/material.dart';
import 'package:pdh/manager_review_team_dashboard_screen.dart';

/// Admin-only Team Review screen. Shows managers only (no employees).
class AdminTeamReviewScreen extends StatelessWidget {
  const AdminTeamReviewScreen({
    super.key,
    this.selectedManagerId,
    this.initialEmployeeId,
    this.initialMeetingId,
  });

  final String? selectedManagerId;
  final String? initialEmployeeId;
  final String? initialMeetingId;

  @override
  Widget build(BuildContext context) {
    return ManagerReviewTeamDashboardScreen(
      forAdminOversight: true,
      selectedManagerId: selectedManagerId,
      initialEmployeeId: initialEmployeeId,
      initialMeetingId: initialMeetingId,
    );
  }
}
