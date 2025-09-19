import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:pdh/employee_drawer.dart';
import 'package:pdh/manager_nav_drawer.dart';

class ProgressVisualsScreen extends StatefulWidget {
  const ProgressVisualsScreen({super.key});

  @override
  State<ProgressVisualsScreen> createState() => _ProgressVisualsScreenState();
}

class _ProgressVisualsScreenState extends State<ProgressVisualsScreen> {
  @override
  Widget build(BuildContext context) => const _ProgressVisualsContent();
}

class _ProgressVisualsContent extends StatelessWidget {
  const _ProgressVisualsContent();

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final isManagerOrigin = args is Map && args['origin'] == 'manager';
    return Scaffold(
      backgroundColor: const Color(0xFF0A1931),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1931),
        elevation: 0,
        title: const Text(
          'Progress Visuals',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      drawer: isManagerOrigin ? const ManagerNavDrawer() : const EmployeeDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPortfolioOverview(),
            const SizedBox(height: 30),
            _buildGoalsProgress(context),
            const SizedBox(height: 30),
            _buildAIInsights(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildPortfolioOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Portfolio Overview',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2B3C),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Burn Down',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(0xFFC10D00).withValues(alpha: 127),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 60,
                          color: Color(0xFFC10D00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2B3C),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    const Text(
                      'Burn Up',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
            child: Container(
                          width: 40,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Time to Due',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A1B9A),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text(
                  '12 days left',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'Current Streak',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.indigoAccent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                SizedBox(width: 5),
                Text(
                  '7 days',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsProgress(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Goals Progress',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        _buildGoalProgressCard(
          context,
          goal: 'Complete Mobile App',
          dueDate: 'Due in 3 days',
          progress: 0.8,
          progressColor: Color(0xFFC10D00),
          streakDays: 4,
        ),
        const SizedBox(height: 15),
        _buildGoalProgressCard(
          context,
          goal: 'Learn Data Science',
          dueDate: 'Due in 15 days',
          progress: 0.4,
          progressColor: Color(0xFFC10D00),
          streakDays: 1,
        ),
        const SizedBox(height: 15),
        _buildGoalProgressCard(
          context,
          goal: 'Fitness Challenge',
          dueDate: 'Due in 25 days',
          progress: 0.6,
          progressColor: Colors.orange,
          streakDays: 12,
        ),
      ],
    );
  }

  Widget _buildGoalProgressCard(
    BuildContext context, {
    required String goal,
    required String dueDate,
    required double progress,
    required Color progressColor,
    required int streakDays,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 30.0,
            lineWidth: 6.0,
            percent: progress,
            center: Text(
              "${(progress * 100).toInt()}%",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            progressColor: progressColor,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  dueDate,
                  style: TextStyle(color: Colors.white70.withValues(alpha: 0.7), fontSize: 13),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
              const SizedBox(width: 5),
              Text(
                '$streakDays day',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'AI Insights',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 15),
        _buildInsightCard(
          'You\'re 15% ahead of schedule on your mobile app project!',
          Color(0xFFC10D00),
          Icons.arrow_circle_up,
        ),
        const SizedBox(height: 10),
        _buildInsightCard(
          'Consider increasing daily effort on Data Science to meet your deadline.',
          Colors.orange,
          Icons.access_alarm,
        ),
        const SizedBox(height: 10),
        _buildInsightCard(
          'Great job maintaining your fitness streak! Keep it up!',
          Colors.greenAccent,
          Icons.verified,
        ),
      ],
    );
  }

  Widget _buildInsightCard(String text, Color iconColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
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

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      color: const Color(0xFF0A1931),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Manager'),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2B3C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Employee'),
          ),
        ],
      ),
    );
  }
}
