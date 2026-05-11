import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';
import 'package:pdh/leaderboard_screen.dart';

/// Manager Leaderboard screen - now uses shared LeaderboardScreen with floating participants
class ManagerLeaderboardScreen extends StatefulWidget {
  final bool embedded;
  final bool compareManagers;
  const ManagerLeaderboardScreen({
    super.key,
    this.embedded = false,
    this.compareManagers = false,
  });

  @override
  State<ManagerLeaderboardScreen> createState() =>
      _ManagerLeaderboardScreenState();
}

class _ManagerLeaderboardScreenState extends State<ManagerLeaderboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: DashboardChrome.fg,
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const SizedBox.shrink(),
        centerTitle: false,
        actions: const [],
      ),
      body: DashboardThemedBackground(
        child: LeaderboardScreen(
          forAdminOversight: false,
          compareManagers: widget.compareManagers,
          embedded: widget.embedded,
        ),
      ),
    );
  }
}
