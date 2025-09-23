import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:pdh/employee_drawer.dart'; // Import the EmployeeDrawer
import 'package:pdh/manager_nav_drawer.dart';
// import 'package:pdh/bottom_nav_bar.dart'; // Bottom nav removed on leaderboard
import 'package:pdh/services/role_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:pdh/employee_profile_screen.dart'; // Import EmployeeProfileScreen
import 'package:pdh/manager_profile_screen.dart'; // Import ManagerProfileScreen

class LeaderboardScreen extends StatefulWidget { // Changed to StatefulWidget
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Role-aware drawer/content
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        title: const Text('Leaderboard', style: TextStyle(color: Colors.white)), // Ensure title is visible
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
        actions: [
          StreamBuilder<String?>(
            stream: RoleService.instance.roleStream(),
            builder: (context, snapshot) {
              final role = snapshot.data;
              final isManager = role == 'manager';
              return _buildProfileButton(context, isManager: isManager);
            },
          ), // Use the new profile button widget
        ],
      ),
      drawer: const _RoleAwareDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Apply stronger blur effect
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F), // More opaque semi-transparent overlay (alpha 0x88)
                      Color(0x88040610), // More opaque semi-transparent overlay (alpha 0x88)
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: StreamBuilder<String?>(
                  stream: RoleService.instance.roleStream(),
                  builder: (context, snapshot) {
                    final role = snapshot.data;
                    if (role == null) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white70));
                    }
                    final isManager = role == 'manager';
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _filtersBar(isManager: isManager),
                          const SizedBox(height: 16),
                          _podium(),
                          const SizedBox(height: 20),
                          _leaderList(isManager: isManager),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context, {required bool isManager}) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Profile';
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: InkWell(
        onTap: () {
          if (isManager) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerProfileScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()));
          }
        },
        child: Row(
          children: [
            const Icon(Icons.person, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              userName,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleAwareDrawer extends StatelessWidget {
  const _RoleAwareDrawer();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, snapshot) {
        final isManager = snapshot.data == 'manager';
        return isManager ? const ManagerNavDrawer() : const EmployeeDrawer();
      },
    );
  }
}

Widget _filtersBar({required bool isManager}) {
  Widget chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A3652),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF1F2840), borderRadius: BorderRadius.circular(10)),
    child: Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('This month'),
              chip('Points'),
              chip('Streaks'),
              if (isManager) chip('My team'),
              if (isManager) chip('Org'),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.filter_list, color: Colors.white70), onPressed: () {}),
      ],
    ),
  );
}

Widget _podium() {
  // Removed mock data for podium
  return Row(
    children: [
      // Removed mock data for podium
    ],
  );
}

Widget _leaderList({required bool isManager}) {
  // Removed mock data

  // Removed mock data for top performers

  // Removed mock data for full leaderboard

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Top performers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      // Removed mock data for top performers
      const SizedBox(height: 16),
      const Text('Full leaderboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      // Removed mock data for full leaderboard
    ],
  );
}
