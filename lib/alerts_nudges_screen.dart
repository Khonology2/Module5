import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:pdh/employee_drawer.dart'; // Import the EmployeeDrawer
import 'package:pdh/manager_nav_drawer.dart';
import 'package:pdh/services/role_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:pdh/employee_profile_screen.dart'; // Import EmployeeProfileScreen

class AlertsNudgesScreen extends StatelessWidget {
  const AlertsNudgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        title: const Text('Alerts & Nudges', style: TextStyle(color: Colors.white)), // Ensure title is visible
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
        actions: [
          _buildProfileButton(context), // Use the new profile button widget
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
                    final isManager = role == 'manager';
                    if (role == null) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white70));
                    }
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _aiSmartAlertsCard(),
                          const SizedBox(height: 16),
                          if (isManager) _managerSummaryChips(),
                          if (isManager) const SizedBox(height: 16),
                          if (isManager) _managerAlerts(context) else _employeeAlerts(context),
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

  Widget _buildProfileButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Profile';
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()));
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

  Widget _aiSmartAlertsCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'AI Smart Alerts',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.psychology, color: Color(0xFFC10D00), size: 22),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Personalized nudges based on habits and goals',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _managerSummaryChips() {
    Widget chip(Color color, String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
          child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(Colors.redAccent, '3 Overdue'),
        chip(Colors.orangeAccent, '5 At Risk'),
        chip(Color(0xFFC10D00), '7 Due Soon'),
        chip(Colors.greenAccent, '4 Kudos'),
      ],
    );
  }

  Widget _managerAlerts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _alertCard(
          context,
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.redAccent,
          title: 'Overdue: Launch new product campaign',
          subtitle: 'Michael Chen • Due 2 days ago',
          primaryText: 'Nudge',
          secondaryText: 'Reassign',
          onPrimary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nudge sent'))),
          onSecondary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reassign flow'))),
        ),
        const SizedBox(height: 12),
        _alertCard(
          context,
          icon: Icons.schedule,
          iconColor: Colors.orangeAccent,
          title: 'Due soon: Quarterly roadmap draft',
          subtitle: 'Sarah Johnson • Due in 5 days',
          primaryText: 'Assign Reviewer',
          secondaryText: 'Snooze',
          onPrimary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reviewer assigned'))),
          onSecondary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Snoozed'))),
        ),
        const SizedBox(height: 12),
        _alertCard(
          context,
          icon: Icons.emoji_events,
          iconColor: Colors.greenAccent,
          title: 'Kudos: Retention win‑back workflow',
          subtitle: 'Emily Rodriguez • Completed 2d ago',
          primaryText: 'Give Kudos',
          secondaryText: 'Share',
          onPrimary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kudos sent'))),
          onSecondary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared'))),
        ),
      ],
    );
  }

  Widget _employeeAlerts(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _alertCard(
          context,
          icon: Icons.lightbulb_outline,
          iconColor: Colors.orange,
          title: 'Tip: Share your progress notes before Friday',
          subtitle: 'Keeps your streak and helps your manager review',
          primaryText: 'Add Notes',
          secondaryText: 'Later',
          onPrimary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening notes'))),
          onSecondary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remind later'))),
        ),
        const SizedBox(height: 12),
        _alertCard(
          context,
          icon: Icons.event,
          iconColor: Color(0xFFC10D00),
          title: 'Due soon: Fitness Challenge goal',
          subtitle: 'Due in 3 days',
          primaryText: 'Open Goal',
          secondaryText: 'Snooze',
          onPrimary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening goal'))),
          onSecondary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Snoozed'))),
        ),
        const SizedBox(height: 12),
        _alertCard(
          context,
          icon: Icons.emoji_events,
          iconColor: Colors.green,
          title: 'Nice work! You earned +20 points yesterday',
          subtitle: 'Keep your streak to unlock a badge',
          primaryText: 'View Points',
          secondaryText: 'Dismiss',
          onPrimary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Viewing points'))),
          onSecondary: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dismissed'))),
        ),
      ],
    );
  }

  Widget _alertCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required String primaryText,
    required String secondaryText,
    required VoidCallback onPrimary,
    required VoidCallback onSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onPrimary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(primaryText),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white70.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(secondaryText),
                ),
              ),
            ],
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
