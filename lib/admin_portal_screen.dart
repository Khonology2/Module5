import 'package:flutter/material.dart';
import 'package:pdh/widgets/sidebar.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/widgets/notifications_bell.dart';
import 'package:pdh/widgets/messages_icon.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/sign_in_screen.dart';
import 'package:pdh/admin_profile_screen.dart';
import 'package:pdh/admin_dashboard_screen.dart';
import 'package:pdh/admin_inbox_screen.dart';
import 'package:pdh/admin_team_alerts_nudges_screen.dart';
import 'package:pdh/admin_team_challenges_screen.dart';
import 'package:pdh/admin_team_review_screen.dart';
import 'package:pdh/admin_progress_visuals_screen.dart';
import 'package:pdh/admin_leaderboard_screen.dart';
import 'package:pdh/admin_badges_points_screen.dart';
import 'package:pdh/admin_repository_audit_screen.dart';
import 'package:pdh/admin_settings_screen.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';
import 'package:pdh/services/one_on_one_meeting_service.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  String _currentRoute = '/admin_dashboard';
  bool _didInitFromArgs = false;
  /// When set, admin oversight screens show data for this manager (Manager Workspace Oversight).
  String? _selectedManagerId;
  String? _initialReviewEmployeeId;
  String? _initialReviewMeetingId;
  bool _startedMeetingManagerResolution = false;

  Widget _getBodyWidget() {
    if (_currentRoute == '/admin_dashboard') {
      return AdminDashboardScreen(
        embedded: true,
        selectedManagerId: _selectedManagerId,
      );
    }
    if (_currentRoute == '/admin_profile') {
      return const AdminProfileScreen(embedded: true);
    }
    if (_currentRoute == '/admin_inbox') {
      return const AdminInboxScreen(embedded: true);
    }
    if (_currentRoute == '/admin_team_alerts_nudges') {
      return AdminTeamAlertsNudgesScreen(
        embedded: true,
        selectedManagerId: _selectedManagerId,
      );
    }
    if (_currentRoute == '/admin_team_challenges') {
      return const AdminTeamChallengesScreen();
    }
    if (_currentRoute == '/admin_team_review') {
      return AdminTeamReviewScreen(
        selectedManagerId: _selectedManagerId,
        initialEmployeeId: _initialReviewEmployeeId,
        initialMeetingId: _initialReviewMeetingId,
      );
    }
    if (_currentRoute == '/admin_progress_visuals') {
      return AdminProgressVisualsScreen(
        embedded: true,
        selectedManagerId: _selectedManagerId,
      );
    }
    if (_currentRoute == '/org_leaderboard') {
      return const AdminLeaderboardScreen();
    }
    if (_currentRoute == '/admin_badges_points') {
      return const AdminBadgesPointsScreen(embedded: true);
    }
    if (_currentRoute == '/admin_repository_audit') {
      return const AdminRepositoryAuditScreen();
    }
    if (_currentRoute == '/admin_settings') {
      return const AdminSettingsScreen();
    }
    final matching = SidebarConfig.adminItems.where(
      (e) => e.route == _currentRoute,
    );
    final label = matching.isEmpty ? _currentRoute : matching.first.label;
    return _AdminPlaceholder(route: _currentRoute, label: label);
  }

  void _onNavigate(String route) {
    setState(() {
      _currentRoute = route;
    });
  }

  Future<void> _onLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_didInitFromArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final initial = args['initialRoute'] as String?;
        if (initial != null && initial.isNotEmpty) {
          _currentRoute = initial;
        }
        final selectedManagerRaw =
            args['selectedManagerId'] ?? args['lineManagerId'];
        final selectedManager = selectedManagerRaw?.toString().trim();
        if (selectedManager != null && selectedManager.isNotEmpty) {
          _selectedManagerId = selectedManager;
        }
        final meetingId = args['meetingId']?.toString().trim();
        if (meetingId != null && meetingId.isNotEmpty) {
          _initialReviewMeetingId = meetingId;
        }
        final employeeId = args['employeeId']?.toString().trim();
        if (employeeId != null && employeeId.isNotEmpty) {
          _initialReviewEmployeeId = employeeId;
        }
      }
      if (_currentRoute == '/admin_dashboard') {
        final routeName = ModalRoute.of(context)?.settings.name;
        if (routeName != null &&
            (routeName == '/admin_inbox' ||
                routeName == '/org_leaderboard' ||
                routeName == '/manager_oversight')) {
          _currentRoute = routeName;
        }
      }
      _didInitFromArgs = true;
    }

    if (_didInitFromArgs &&
        !_startedMeetingManagerResolution &&
        _initialReviewMeetingId != null &&
        _initialReviewMeetingId!.trim().isNotEmpty &&
        (_selectedManagerId == null || _selectedManagerId!.trim().isEmpty)) {
      _startedMeetingManagerResolution = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final mid = _initialReviewMeetingId?.trim();
        if (mid == null || mid.isEmpty) return;
        final m = await OneOnOneMeetingService.getMeeting(mid);
        if (!mounted || m == null) return;
        setState(() {
          _selectedManagerId = m.managerId;
          if (_initialReviewEmployeeId == null ||
              _initialReviewEmployeeId!.trim().isEmpty) {
            _initialReviewEmployeeId = m.employeeId;
          }
        });
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: DashboardThemedBackground(
        child: Stack(
          children: [
            Row(
              children: [
                ResponsiveSidebar(
                  items: SidebarConfig.adminItems,
                  onNavigate: _onNavigate,
                  currentRouteName: _currentRoute,
                  onLogout: _onLogout,
                ),
                Expanded(child: _getBodyWidget()),
              ],
            ),
            if (_currentRoute != '/admin_dashboard')
              Positioned(
                top: 24,
                right: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MessagesIcon(),
                    const SizedBox(width: 8),
                    NotificationsBell(onTap: () => _onNavigate('/admin_inbox')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

}

class _AdminPlaceholder extends StatelessWidget {
  const _AdminPlaceholder({required this.route, required this.label});

  final String route;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_outlined,
            size: 64,
            color: DashboardChrome.fg.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: AppTypography.heading2.copyWith(color: DashboardChrome.fg),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
          ),
        ],
      ),
    );
  }
}
