import 'package:flutter/material.dart';
import 'package:pdh/manager_badges_points_screen.dart';

/// Admin-only Badges & Points. Delegates to [ManagerBadgesPointsScreen];
/// data is loaded from PostgreSQL via [BackendAuthService].
class AdminBadgesPointsScreen extends StatelessWidget {
  const AdminBadgesPointsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ManagerBadgesPointsScreen(
      embedded: embedded,
      forAdminSelf: true,
    );
  }
}
