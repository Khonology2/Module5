import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:pdh/employee_drawer.dart'; // Import the EmployeeDrawer
import 'package:pdh/manager_nav_drawer.dart';
// import 'package:pdh/bottom_nav_bar.dart'; // Bottom nav removed on leaderboard
import 'package:pdh/services/role_service.dart';

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
      ),
      drawer: const _RoleAwareDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/hillyxyz_Generate_a_background_image_for_a_personal_development_app._Theme_7058e6a9-bc4e-49a4-836d-7344ed124d1f.png'),
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
  Widget medal(Color color, String rank, String name, String points) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2840),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Text(rank, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const CircleAvatar(radius: 18, backgroundColor: Colors.white24),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(points, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  return Row(
    children: [
      medal(Colors.amber, '1', 'Emily', '320 pts'),
      const SizedBox(width: 10),
      medal(Colors.grey, '2', 'Sarah', '295 pts'),
      const SizedBox(width: 10),
      medal(Colors.brown, '3', 'Michael', '270 pts'),
    ],
  );
}

Widget _leaderList({required bool isManager}) {
  List<Map<String, dynamic>> data = [
    {'rank': 1, 'name': 'Emily Rodriguez', 'points': 320, 'streak': 12, 'team': 'Design'},
    {'rank': 2, 'name': 'Sarah Johnson', 'points': 295, 'streak': 9, 'team': 'Marketing'},
    {'rank': 3, 'name': 'Michael Chen', 'points': 270, 'streak': 4, 'team': 'Growth'},
    {'rank': 4, 'name': 'You', 'points': 250, 'streak': 7, 'team': 'Engineering'},
    {'rank': 5, 'name': 'Alex Kim', 'points': 230, 'streak': 3, 'team': 'Sales'},
  ];

  Widget row(Map<String, dynamic> x, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
        border: highlight ? Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text('#${x['rank']}', style: const TextStyle(color: Colors.white70))),
          const SizedBox(width: 10),
          const CircleAvatar(radius: 14, backgroundColor: Colors.white24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(x['name'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${x['points']} pts • 🔥 ${x['streak']} days${isManager ? ' • ${x['team']}' : ''}', style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (isManager)
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
              child: const Text('Nudge'),
            ),
        ],
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Top performers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      ...data.take(3).map((x) => row(x)),
      const SizedBox(height: 16),
      const Text('Full leaderboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 10),
      ...data.asMap().entries.map((e) => row(e.value, highlight: e.value['name'] == 'You')),
    ],
  );
}
