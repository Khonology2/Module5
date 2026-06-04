import 'package:flutter/material.dart';
import 'package:pdh/settings_screen.dart';

/// Admin-only Settings. Delegates to [SettingsScreen];
/// preferences are stored in PostgreSQL via [BackendAuthService].
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}
