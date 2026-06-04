import 'package:flutter/material.dart';
import 'package:pdh/manager_dashboard_screen.dart';

/// Admin-only dashboard. Delegates to [ManagerDashboardScreen];
/// team/manager data is loaded from PostgreSQL via [ManagerRealtimeService].
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
