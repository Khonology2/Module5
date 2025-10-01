import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
// Drawers removed in favor of persistent sidebar
import 'package:pdh/widgets/main_layout.dart';
import 'package:pdh/services/role_service.dart';
// Profile handled by MainLayout

class AlertsNudgesScreen extends StatelessWidget {
  const AlertsNudgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Alerts & Nudges',
      currentRouteName: '/alerts_nudges',
      body: StreamBuilder<String?>(
        stream: RoleService.instance.roleStream(),
        builder: (context, snapshot) {
          final role = snapshot.data;
          final isManager = role == 'manager';
          if (role == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _aiSmartAlertsCard(),
              const SizedBox(height: 16),
              if (isManager) _managerSummaryChips(),
              if (isManager) const SizedBox(height: 16),
              if (isManager)
                _managerAlerts(context)
              else
                _employeeAlerts(context),
            ],
          );
        },
      ),
    );
  }

  // Profile handled by MainLayout

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
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
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
          onPrimary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Nudge sent'))),
          onSecondary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Reassign flow'))),
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
          onPrimary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Reviewer assigned'))),
          onSecondary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Snoozed'))),
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
          onPrimary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Kudos sent'))),
          onSecondary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Shared'))),
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
          onPrimary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Opening notes'))),
          onSecondary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Remind later'))),
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
          onPrimary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Opening goal'))),
          onSecondary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Snoozed'))),
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
          onPrimary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Viewing points'))),
          onSecondary: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Dismissed'))),
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
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                    side: BorderSide(
                      color: Colors.white70.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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

// Drawer removed; persistent sidebar via MainLayout
