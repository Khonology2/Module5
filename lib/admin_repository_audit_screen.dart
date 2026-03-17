import 'package:flutter/material.dart';
import 'package:pdh/repository_audit_screen.dart';

/// Admin-only Repository & Audit screen. Uses the same UI as the shared screen.
/// Not shared with manager/employee as a route target.
class AdminRepositoryAuditScreen extends StatelessWidget {
  const AdminRepositoryAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepositoryAuditScreen(forAdminOversight: true);
  }
}
