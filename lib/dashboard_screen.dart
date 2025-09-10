import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1B1B1B), // Dark background for the drawer
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xFF1B1B1B), // Dark background for the header
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Employee Portal',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            _buildDrawerItem(
              icon: Icons.dashboard,
              text: 'Dashboard',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                // No navigation needed as Dashboard is the current screen
              },
              isSelected: true, // Assuming Dashboard is the current screen
            ),
            _buildDrawerItem(
              icon: Icons.person,
              text: 'My PDP',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/my_pdp');
              },
            ),
            _buildDrawerItem(
              icon: Icons.bar_chart,
              text: 'Progress Visuals',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/progress_visuals');
              },
            ),
            _buildDrawerItem(
              icon: Icons.workspaces_filled,
              text: 'my Goal Workspace',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/my_goal_workspace');
              },
            ),
            _buildDrawerItem(
              icon: Icons.gamepad,
              text: 'Gamification',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/gamification');
              },
            ),
            _buildDrawerItem(
              icon: Icons.folder,
              text: 'Repository & Audit',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/repository_audit');
              },
            ),
            _buildDrawerItem(
              icon: Icons.notifications,
              text: 'Alerts & Nudges',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/alerts_nudges');
              },
            ),
            _buildDrawerItem(
              icon: Icons.calendar_today,
              text: 'Season Challenge',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/season_challenge');
              },
            ),
            _buildDrawerItem(
              icon: Icons.settings,
              text: 'Settings',
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushNamed(context, '/settings');
              },
            ),
            _buildDrawerItem(
              icon: Icons.logout,
              text: 'Logout',
              color: Colors.red, // Highlight Logout button
              onTap: () {
                Navigator.pop(context); // Close the drawer
                Navigator.pushReplacementNamed(context, '/'); // Navigate to the landing screen and remove all previous routes
              },
            ),
          ],
        ),
      ),
      body: Center(
        child: Text(
          'Welcome to your Dashboard!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
    Color? color,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: isSelected
          ? BoxDecoration(
              color: const Color(0xFF6B4EE8),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.white70),
        title: Text(
          text,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
