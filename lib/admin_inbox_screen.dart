import 'package:flutter/material.dart';
import 'package:pdh/manager_inbox_screen.dart';

/// Admin-only inbox. Delegates to [ManagerInboxScreen];
/// alerts and approvals are loaded from PostgreSQL via [BackendAuthService].
class AdminInboxScreen extends StatelessWidget {
  const AdminInboxScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return const ManagerInboxScreen(
      embedded: true,
      forAdminOversight: true,
    );
  }
}
