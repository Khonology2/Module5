import 'package:flutter/material.dart';
import 'package:pdh/repository_audit_screen.dart';

/// Admin-only Repository & Audit. Delegates to [RepositoryAuditScreen];
/// audit data is loaded from PostgreSQL via [BackendAuthService].
class AdminRepositoryAuditScreen extends StatelessWidget {
  const AdminRepositoryAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepositoryAuditScreen(forAdminOversight: true);
  }
}
