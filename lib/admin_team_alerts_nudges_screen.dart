import 'package:flutter/material.dart';
import 'package:pdh/manager_alerts_nudges_screen.dart';

/// Admin-only Team Alerts & Nudges screen. Shows managers only (no employees).
class AdminTeamAlertsNudgesScreen extends StatelessWidget {
  const AdminTeamAlertsNudgesScreen({
    super.key,
    this.embedded = false,
    this.selectedManagerId,
  });

  final bool embedded;
  final String? selectedManagerId;

  @override
  Widget build(BuildContext context) {
    return ManagerAlertsNudgesScreen(
      embedded: true,
      forAdminOversight: true,
      selectedManagerId: selectedManagerId,
    );
  }
}
