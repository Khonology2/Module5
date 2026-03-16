import 'package:flutter/material.dart';
import 'package:pdh/settings_screen.dart';
import 'package:pdh/widgets/sidebar.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/widgets/notifications_bell.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/sign_in_screen.dart';
import 'package:pdh/admin_profile_screen.dart';
import 'package:pdh/admin_dashboard_screen.dart';
import 'package:pdh/admin_manager_oversight_screen.dart';
import 'package:pdh/admin_inbox_screen.dart';
import 'package:pdh/admin_leaderboard_screen.dart';
import 'package:pdh/admin_repository_audit_screen.dart';
import 'package:pdh/admin_analytics_screen.dart';

class AdminPortalScreen extends StatefulWidget {
  const AdminPortalScreen({super.key});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen> {
  String _currentRoute = '/admin_dashboard';
  bool _didInitFromArgs = false;

  Widget _getBodyWidget() {
    if (_currentRoute == '/admin_dashboard') {
      return AdminDashboardScreen(embedded: true, onNavigate: _onNavigate);
    }
    if (_currentRoute == '/admin_profile') {
      return const AdminProfileScreen(embedded: true);
    }
    if (_currentRoute == '/manager_oversight') {
      return const AdminManagerOversightScreen(embedded: true);
    }
    if (_currentRoute == '/admin_inbox') {
      return const AdminInboxScreen(embedded: true);
    }
    if (_currentRoute == '/org_leaderboard') {
      return const AdminLeaderboardScreen(embedded: true);
    }
    if (_currentRoute == '/admin_repository_audit') {
      return const AdminRepositoryAuditScreen(embedded: true);
    }
    if (_currentRoute == '/admin_analytics') {
      return AdminAnalyticsScreen(embedded: true, onNavigate: _onNavigate);
    }
    if (_currentRoute == '/admin_settings') {
      return const SettingsScreen();
    }
    // Analytics, Team Challenge, etc. show placeholder until built
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
      }
      _didInitFromArgs = true;
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/khono_bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Color(0x880A0F1F), Color(0x88040610)],
                  stops: [0.0, 1.0],
                ),
              ),
              child: Row(
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
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NotificationsBell(onTap: () => _onNavigate('/admin_inbox')),
                const SizedBox(width: 8),
                _buildProfileButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'Admin';
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      userName = user.displayName!.split(' ').first;
    } else if (user?.email != null && user!.email!.isNotEmpty) {
      userName = user.email!.split('@').first;
    }
    return InkWell(
      onTap: () {
        _onNavigate('/admin_profile');
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.elevatedBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              userName,
              style: AppTypography.bodySmall.copyWith(color: Colors.white),
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
            color: Colors.white.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: AppTypography.heading2.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
