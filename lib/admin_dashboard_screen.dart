import 'package:flutter/material.dart';
import 'package:pdh/manager_dashboard_screen.dart';

/// Admin-only dashboard screen. Uses the same UI as the manager dashboard
/// with admin oversight (managers as "team"). Not shared with manager/employee.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    this.embedded = false,
    this.selectedManagerId,
  });

  final bool embedded;
  final String? selectedManagerId;

  @override
  Widget build(BuildContext context) {
    return ManagerDashboardScreen(
      embedded: true,
      forAdminOversight: true,
      selectedManagerId: selectedManagerId,
    );
  }
}
