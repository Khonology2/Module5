import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:pdh/manager_nav_drawer.dart';
import 'dart:ui'; // Added for ImageFilter
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:pdh/manager_profile_screen.dart'; // Import ManagerProfileScreen

class ManagerReviewTeamDashboardScreen extends StatelessWidget {
  const ManagerReviewTeamDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
        title: const Text(
          'Manager Review',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          _buildProfileButton(context), // Use the new profile button widget
        ],
      ),
      drawer: const ManagerNavDrawer(),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding = constraints.maxWidth < 400
                        ? 12.0
                        : constraints.maxWidth < 700
                            ? 16.0
                            : 24.0;
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(horizontalPadding, MediaQuery.of(context).padding.top + kToolbarHeight + 16.0, horizontalPadding, 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildKpiRow(),
                          const SizedBox(height: 20),
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildAtRiskSection(),
                          const SizedBox(height: 20),
                          _buildGoalCard(
                            context,
                            name: 'Sarah Johnson',
                            goal: 'Increase social media engagement by 25%',
                            dueDate: 'Due in 5 days',
                            progress: 0.75,
                            status: 'On Track',
                            statusColor: Colors.green,
                          ),
                          const SizedBox(height: 20),
                          _buildGoalCard(
                            context,
                            name: 'Michael Chen',
                            goal: 'Launch new product campaign',
                            dueDate: 'Overdue 2 days',
                            progress: 0.20,
                            status: 'At Risk',
                            statusColor: Colors.redAccent,
                          ),
                          const SizedBox(height: 20),
                          _buildGoalCard(
                            context,
                            name: 'Emily Rodriguez',
                            goal: 'Improve customer retention rate',
                            dueDate: 'Due in 12 days',
                            progress: 0.90,
                            status: 'Ahead',
                            statusColor: const Color(0xFFC10D00),
                          ),
                          const SizedBox(height: 20),
                          _buildAIManagerInsights(),
                          const SizedBox(height: 20),
                          _buildUpcomingSection(),
                          const SizedBox(height: 20),
                          _buildRecentlyCompletedSection(),
                          const SizedBox(height: 24),
                          _buildQuickActions(),
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
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerProfileScreen()));
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

  Widget _buildKpiRow() {
    Widget tile(String label, String value, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2840),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
    return Row(
      children: [
        tile('On Track', '12', Colors.greenAccent),
        const SizedBox(width: 12),
        tile('At Risk', '3', Colors.orangeAccent),
        const SizedBox(width: 12),
        tile('Overdue', '1', Colors.redAccent),
      ],
    );
  }

  Widget _buildAtRiskSection() {
    Widget item(String name, String title, String due) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2840),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withAlpha(0x66), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(due, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                ],
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(backgroundColor: const Color(0xFFC10D00)),
              child: const Text('Nudge', style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)),
              child: const Text('Reassign', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('At Risk', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        item('Michael Chen', 'Launch new product campaign', 'Overdue 2 days'),
        item('—', 'Content pipeline slippage', 'Due today'),
      ],
    );
  }

  Widget _buildUpcomingSection() {
    Widget row(String title, String name, String due, Color chipColor) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2840),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(name, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: chipColor.withAlpha(0x33), borderRadius: BorderRadius.circular(6)),
              child: Text(due, style: TextStyle(color: chipColor, fontSize: 12)),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upcoming (7–14 days)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        row('Quarterly roadmap draft', 'Sarah Johnson', 'Due in 5 days', const Color(0xFFC10D00)),
        row('Retention playbook v2', 'Emily Rodriguez', 'Due in 12 days', Colors.greenAccent),
      ],
    );
  }

  Widget _buildRecentlyCompletedSection() {
    Widget chip(String label, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: color.withAlpha(0x26), borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: TextStyle(color: color, fontSize: 11)),
        );
    Widget card(String title, String name, String when) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2840),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$name • $when', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Row(children: [chip('share', const Color(0xFFC10D00)), const SizedBox(width: 6), chip('kudos', Colors.orangeAccent)])
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recently Completed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        card('Customer win-back workflow', 'Emily Rodriguez', '2d ago'),
        card('Campaign brief v1', 'Sarah Johnson', '4d ago'),
      ],
    );
  }

  Widget _buildQuickActions() {
    Widget action(IconData icon, String label, Color color) {
      return Expanded(
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: Icon(icon, color: Colors.white, size: 16),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }
    return Row(
      children: [
        action(Icons.add_task, 'New Goal', const Color(0xFFC10D00)),
        const SizedBox(width: 10),
        action(Icons.campaign, 'Nudge', const Color(0xFFC10D00)),
        const SizedBox(width: 10),
        action(Icons.event, 'Schedule 1:1', const Color(0xFFC10D00)),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
        const Expanded(
          child: Text(
            'Khono Team Goals',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFC10D00),
            borderRadius: BorderRadius.circular(5),
          ),
          child: const Text(
            'Filter',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalCard(
    BuildContext context, {
    required String name,
    required String goal,
    required String dueDate,
    required double progress,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: name == 'Michael Chen' ? Colors.red.withAlpha(0x80) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              CircularPercentIndicator(
                radius: 25.0,
                lineWidth: 5.0,
                percent: progress.clamp(0.0, 1.0),
                center: Text(
                  "${(progress * 100).toInt()}%",
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
                progressColor: statusColor,
                backgroundColor: Colors.grey.withAlpha(0x4D),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            goal,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(0x33),
              borderRadius: BorderRadius.circular(5),
            ),
                  child: Text(
              dueDate,
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.circle, color: statusColor, size: 12),
              const SizedBox(width: 5),
              Text(
                status,
                style: TextStyle(color: statusColor, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            style: const TextStyle(color: Colors.white70),
            decoration: InputDecoration(
              hintText: 'Add check-in notes...',
              hintStyle: TextStyle(color: Colors.white70.withAlpha(0x80)),
              filled: true,
              fillColor: const Color(0xFF2C3E50),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Acknowledged goal for $name')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Acknowledge', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stretch Goal for $name')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('+ Stretch Goal', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIManagerInsights() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline, color: Color(0xFFC10D00), size: 20),
              SizedBox(width: 8),
              Text(
                'AI Manager Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildInsightBullet(
              'Michael\'s campaign is behind schedule. Consider reallocating resources from Sarah\'s project.'),
          _buildInsightBullet(
              'Team morale appears high based on recent check-ins. Emily\'s success could be shared as best practices.'),
          _buildInsightBullet(
              'Recommend scheduling 1:1s with at-risk team members this week.'),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: () {},
            child: const Text(
              'View Full Analysis',
              style: TextStyle(
                color: Color(0xFFC10D00),
                decoration: TextDecoration.underline,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
