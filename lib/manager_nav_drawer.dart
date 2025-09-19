import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/sign_in_screen.dart';

class ManagerNavDrawer extends StatelessWidget {
  const ManagerNavDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: Colors.red.shade50,
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
                'Manager Portal',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          _drawerItem(
            context: context,
            icon: Icons.dashboard,
            text: 'Dashboard',
            route: '/dashboard',
            isSelected: currentRoute == '/dashboard',
          ),
          _drawerItem(
            context: context,
            icon: Icons.groups,
            text: 'Manager Review',
            route: '/manager_review_team_dashboard',
            isSelected: currentRoute == '/manager_review_team_dashboard',
          ),
          _drawerItem(
            context: context,
            icon: Icons.bar_chart,
            text: 'Progress Visuals',
            route: '/progress_visuals',
            isSelected: currentRoute == '/progress_visuals',
          ),
          _drawerItem(
            context: context,
            icon: Icons.notifications,
            text: 'Alerts & Nudges',
            route: '/alerts_nudges',
            isSelected: currentRoute == '/alerts_nudges',
          ),
          _drawerItem(
            context: context,
            icon: Icons.leaderboard,
            text: 'Leaderboard',
            route: '/leaderboard',
            isSelected: currentRoute == '/leaderboard',
          ),
          _drawerItem(
            context: context,
            icon: Icons.folder_open,
            text: 'Repository & Audit',
            route: '/repository_audit',
            isSelected: currentRoute == '/repository_audit',
          ),
          _drawerItem(
            context: context,
            icon: Icons.settings,
            text: 'Settings & Privacy',
            route: '/settings',
            isSelected: currentRoute == '/settings',
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
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

  Widget _drawerItem({
    required BuildContext context,
    required IconData icon,
    required String text,
    required String route,
    bool isSelected = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        gradient: const LinearGradient(
          colors: [Color(0xFFC10D00), Color(0xFFC10D00)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Color(0xFFC10D00).withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        leading: null,
        title: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        onTap: () async {
          Navigator.pop(context);
          final currentRouteName = ModalRoute.of(context)?.settings.name;
          if (currentRouteName != route) {
            // Guard: prevent navigating to employee-only screens
            final blocked = {
              '/employee_portal',
            };
            if (blocked.contains(route)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Access restricted to employees')),
              );
              return;
            }
            Navigator.pushNamed(context, route, arguments: const {'origin': 'manager'});
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
    );
  }
}


