import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/sign_in_screen.dart';
import 'package:pdh/l10n/generated/app_localizations.dart';

class EmployeeDrawer extends StatelessWidget {
  const EmployeeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: const Color(0xFF1F2840),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFC10D00), Color(0xFFC10D00)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                localizations.employee_portal_title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.dashboard,
            text: localizations.nav_dashboard,
            route: '/employee_dashboard',
            isSelected: currentRoute == '/employee_dashboard',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.person_outline,
            text: localizations.nav_goal_workspace,
            route: '/my_pdp',
            isSelected: currentRoute == '/my_pdp',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.track_changes,
            text: localizations.nav_my_pdp,
            route: '/my_goal_workspace',
            isSelected: currentRoute == '/my_goal_workspace',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.bar_chart,
            text: localizations.nav_progress_visuals,
            route: '/progress_visuals',
            isSelected: currentRoute == '/progress_visuals',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.notifications_none,
            text: localizations.nav_alerts_nudges,
            route: '/alerts_nudges',
            isSelected: currentRoute == '/alerts_nudges',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.workspace_premium,
            text: localizations.nav_badges_points,
            route: '/badges_points',
            isSelected: currentRoute == '/badges_points',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.emoji_events,
            text: localizations.nav_season_challenges,
            route: '/season_challenges',
            isSelected: currentRoute == '/season_challenges',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.leaderboard,
            text: localizations.nav_leaderboard,
            route: '/leaderboard',
            isSelected: currentRoute == '/leaderboard',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.folder_open,
            text: localizations.nav_repository_audit,
            route: '/repository_audit',
            isSelected: currentRoute == '/repository_audit',
          ),
          // Goal Evidence Submission removed
          _buildDrawerItem(
            context: context,
            icon: Icons.settings_outlined,
            text: localizations.nav_settings_privacy,
            route: '/settings',
            isSelected: currentRoute == '/settings',
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: Text(
              localizations.employee_drawer_exit,
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String text,
    required String route,
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Container(
        height: 60,
        decoration: ShapeDecoration(
          shape: const StadiumBorder(), // Changed to StadiumBorder
          gradient: const LinearGradient(
            colors: [Color(0xFFC10D00), Color(0xFFC10D00)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          shadows: isSelected
              ? [
                  BoxShadow(
                    color: Color(0xFFC10D00).withValues(alpha: 89),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
            final currentRouteName = ModalRoute.of(context)?.settings.name;
            if (currentRouteName != route) {
              // Guard: prevent navigating to manager-only screens
              final blocked = {
                '/manager_portal',
                '/dashboard',
                '/manager_review_team_dashboard',
              };
              if (blocked.contains(route)) {
                _showCenterNotice(context, 'Access restricted to managers');
                return;
              }
              Navigator.pushNamed(context, route);
            }
          },
          icon: Icon(icon, color: Colors.white, size: 24),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showCenterNotice(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline, color: Color(0xFFC10D00)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFC10D00)),
              ),
            ),
          ],
        );
      },
    );
  }
}
