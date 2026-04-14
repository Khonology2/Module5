import 'package:flutter/material.dart';
import 'package:pdh/manager_inbox_screen.dart';

/// Admin-only inbox screen (Manager IBox). Uses the same UI as the manager inbox.
/// Not shared with manager/employee.
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
