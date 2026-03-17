import 'package:flutter/material.dart';
import 'package:pdh/settings_screen.dart';

/// Admin-only Settings & Privacy screen. Uses the same UI as the shared settings.
/// Not shared with manager/employee as a route target.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}
