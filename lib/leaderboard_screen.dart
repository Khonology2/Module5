import 'package:flutter/material.dart';
// Drawers removed in favor of persistent sidebar
import 'package:pdh/services/role_service.dart';
// Profile handled by MainLayout

class LeaderboardScreen extends StatefulWidget {
  // Changed to StatefulWidget
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0), // Adjusted padding
      child: StreamBuilder<String?>(
        stream: RoleService.instance.roleStream(),
        builder: (context, snapshot) {
          final role = snapshot.data;
          if (role == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          }
          final isManager = role == 'manager';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leaderboard', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _filtersBar(isManager: isManager),
              const SizedBox(height: 16),
              _podium(),
              const SizedBox(height: 20),
              _leaderList(isManager: isManager),
            ],
          );
        },
      ),
    );
  }

  // Profile handled by MainLayout
}

// Drawer removed; persistent sidebar via MainLayout

Widget _filtersBar({required bool isManager}) {
  Widget chip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF2A3652),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12),
    ),
    child: Text(
      label,
      style: const TextStyle(color: Colors.white70, fontSize: 12),
    ),
  );
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF1F2840),
      borderRadius: BorderRadius.circular(10),
    ),
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
        IconButton(
          icon: const Icon(Icons.filter_list, color: Colors.white70),
          onPressed: () {},
        ),
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
      const Text(
        'Top performers',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      const SizedBox(height: 10),
      // Removed mock data for top performers
      const SizedBox(height: 16),
      const Text(
        'Full leaderboard',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      const SizedBox(height: 10),
      // Removed mock data for full leaderboard
    ],
  );
}
