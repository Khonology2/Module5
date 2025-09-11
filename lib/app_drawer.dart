import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added import for firebase_auth
import 'package:pdh/sign_in_screen.dart'; // Corrected import for LoginScreen

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Widget _buildDrawerItem({
    required BuildContext context, // Add BuildContext to parameters
    required IconData icon,
    required String text,
    required String route, // Use route for navigation
    Color? color,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: isSelected
          ? BoxDecoration(
              color: const Color(0xFF81D4FA), // Light blue for selected item
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.blueGrey[800]), // Darker icons for light background
        title: Text(
          text,
          style: TextStyle(
            color: color ?? Colors.blueGrey[900], // Darker text for light background
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () async {
          Navigator.pop(context); // Close the drawer
          if (!context.mounted) return; // Check if the context is still mounted

          if (route == '/sign_in') { // Logout route
            await FirebaseAuth.instance.signOut(); // Sign out from Firebase
            // Navigate to login screen and remove all previous routes
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false, // Remove all routes
            );
          } else { // All other authenticated routes
            final currentRouteName = ModalRoute.of(context)?.settings.name;
            if (currentRouteName != route) {
              // Navigate to the new route, and remove all routes until dashboard.
              // This ensures that pressing the back button from the new route will lead to the dashboard.
              Navigator.pushNamedAndRemoveUntil(
                context,
                route,
                (Route<dynamic> route) => route.settings.name == '/dashboard' || route.isFirst, // Keep dashboard or first route
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine the current route to highlight the selected item
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: const Color(0xFFE0F2F7), // Light blue background for the drawer
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFFB3E0F2), // Light blue background for the header
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.blueGrey[900], // Darker text for light background
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Employee Portal',
                  style: TextStyle(
                    color: Colors.blueGrey[700], // Darker text for light background
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.dashboard,
            text: 'Dashboard',
            route: '/dashboard',
            isSelected: currentRoute == '/dashboard',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.person,
            text: 'My PDP',
            route: '/my_pdp',
            isSelected: currentRoute == '/my_pdp',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.bar_chart,
            text: 'Progress Visuals',
            route: '/progress_visuals',
            isSelected: currentRoute == '/progress_visuals',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.workspaces_filled,
            text: 'My Goal Workspace',
            route: '/my_goal_workspace',
            isSelected: currentRoute == '/my_goal_workspace',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.people,
            text: 'Manager Review / Team Dashboard',
            route: '/manager_review_team_dashboard',
            isSelected: currentRoute == '/manager_review_team_dashboard',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.card_giftcard, // or another appropriate icon
            text: 'Badges & Points',
            route: '/badges_points',
            isSelected: currentRoute == '/badges_points',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.leaderboard, // or another appropriate icon
            text: 'Leaderboard',
            route: '/leaderboard',
            isSelected: currentRoute == '/leaderboard',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.folder,
            text: 'Repository & Audit',
            route: '/repository_audit',
            isSelected: currentRoute == '/repository_audit',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.notifications,
            text: 'Alerts & Nudges',
            route: '/alerts_nudges',
            isSelected: currentRoute == '/alerts_nudges',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.calendar_today,
            text: 'Season Challenge',
            route: '/season_challenge',
            isSelected: currentRoute == '/season_challenge',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.settings,
            text: 'Settings',
            route: '/settings',
            isSelected: currentRoute == '/settings',
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.logout,
            text: 'Logout',
            route: '/sign_in',
            color: Colors.red, // Highlight Logout button
          ),
        ],
      ),
    );
  }
}
