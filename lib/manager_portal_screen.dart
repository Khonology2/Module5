import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:firebase_auth/firebase_auth.dart'; // Import for Firebase Auth
import 'package:pdh/sign_in_screen.dart'; // Import for LoginScreen

class ManagerPortalScreen extends StatelessWidget {
  const ManagerPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const _ManagerDrawer(),
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Manager Portal',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6B4EE8), Color(0xFF48A6ED)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/hillyxyz_Generate_a_background_image_for_a_personal_development_app._Theme_7058e6a9-bc4e-49a4-836d-7344ed124d1f.png',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay for gradient effect and content
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F), // More opaque semi-transparent overlay
                      Color(0x88040610), // More opaque semi-transparent overlay
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      const SizedBox(height: 40),
                            const Text(
                              'Welcome to Manager Portal',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFC7E3FF),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Access all management tools and team oversight features from the sidebar menu.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8B9FB7),
                                height: 1.5,
                              ),
                            ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _ManagerDrawer extends StatelessWidget {
  const _ManagerDrawer();

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Drawer(
      backgroundColor: const Color(0xFFE0F2F7),
      child: ListView(
        padding: EdgeInsets.zero,
                                children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6B4EE8), Color(0xFF48A6ED)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Manager Portal',
                style: TextStyle(color: Colors.blueGrey[50], fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _drawerItem(
              context: context,
              icon: Icons.dashboard,
              text: 'Dashboard',
              route: '/manager_portal',
              isSelected: currentRoute == '/manager_portal',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _drawerItem(
              context: context,
              icon: Icons.groups,
              text: 'Manager Review',
              route: '/manager_review_team_dashboard',
              isSelected: currentRoute == '/manager_review_team_dashboard',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _drawerItem(
              context: context,
              icon: Icons.bar_chart,
              text: 'Progress Visuals',
              route: '/progress_visuals',
              isSelected: currentRoute == '/progress_visuals',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _drawerItem(
              context: context,
              icon: Icons.notifications,
              text: 'Alerts & Nudges',
              route: '/alerts_nudges',
              isSelected: currentRoute == '/alerts_nudges',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _drawerItem(
              context: context,
              icon: Icons.leaderboard,
              text: 'Leaderboard',
              route: '/leaderboard',
              isSelected: currentRoute == '/leaderboard',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _drawerItem(
              context: context,
              icon: Icons.folder_open,
              text: 'Repository & Audit',
              route: '/repository_audit',
              isSelected: currentRoute == '/repository_audit',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _drawerItem(
              context: context,
              icon: Icons.settings,
              text: 'Settings & Privacy',
              route: '/settings',
              isSelected: currentRoute == '/settings',
            ),
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
            colors: [Color(0xFF6B4EE8), Color(0xFF48A6ED)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF48A6ED).withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
        child: ListTile(
        leading: const Icon(Icons.chevron_right, color: Colors.white),
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
        onTap: () {
          Navigator.pop(context);
          final currentRouteName = ModalRoute.of(context)?.settings.name;
          if (currentRouteName != route) {
            Navigator.pushNamed(context, route);
          }
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      ),
    );
  }
}
