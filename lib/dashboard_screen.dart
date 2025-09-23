import 'package:flutter/material.dart';
import 'package:pdh/manager_nav_drawer.dart';
import 'dart:ui'; // Added for ImageFilter
import 'package:pdh/employee_profile_screen.dart'; // Import the new profile screen
import 'package:pdh/manager_profile_screen.dart'; // Import the new manager profile screen
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/database_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isManager = false;
  bool _isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userProfile = await DatabaseService.getUserProfile(user.uid);
        setState(() {
          _isManager = userProfile.role == 'manager';
          _isLoading = false; // Set loading to false after role is determined
        });
      } catch (e) {
        // Handle error, e.g., show a snackbar or log it
        // ignore: avoid_print
        print('Error fetching user role: $e');
        setState(() {
          _isLoading = false; // Stop loading even if there's an error
        });
      }
    } else {
      setState(() {
        _isLoading = false; // Stop loading if user is null
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isLoading) // Show a loading indicator if still loading
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            IconButton(
              icon: const Icon(Icons.person, color: Colors.white),
              onPressed: () {
                if (_isManager) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerProfileScreen()));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()));
                }
              },
            ),
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + kToolbarHeight + 16.0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _filtersBar(),
                      const SizedBox(height: 16),
                      _kpiRow(),
                      const SizedBox(height: 20),
                      _quickActions(context),
                      const SizedBox(height: 20),
                      _aiInsights(),
                      const SizedBox(height: 20),
                      _workloadHeatmap(),
                      const SizedBox(height: 20),
                      _engagementSummary(),
                      const SizedBox(height: 20),
                      _statusSections(),
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

  Widget _filtersBar() {
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
                chip('Marketing'),
                chip('Design'),
                chip('At risk'),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white70),
            onPressed: () {},
          )
        ],
      ),
    );
  }

  Widget _kpiRow() {
    Widget tile(String label, String value, Color color) => Expanded(
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
                Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
    return Row(
      children: [
        tile('Active Goals', '24', Color(0xFFC10D00)),
        const SizedBox(width: 12),
        tile('At Risk', '3', Colors.orangeAccent),
        const SizedBox(width: 12),
        tile('Overdue', '1', Colors.redAccent),
      ],
    );
  }

  Widget _quickActions(BuildContext context) {
    Widget action(IconData icon, String label, Color color) => Expanded(
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
    return Row(
      children: [
        action(Icons.add_task, 'New Goal', const Color(0xFFC10D00)),
        const SizedBox(width: 10),
        action(Icons.campaign, 'Send Nudge', const Color(0xFFC10D00)),
        const SizedBox(width: 10),
        action(Icons.event, 'Schedule 1:1', Color(0xFFC10D00)),
      ],
    );
  }

  Widget _statusSections() {
    Widget section(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...children,
          ],
        );

    Widget card({required Color stripe, required String heading, required String sub, Widget? trailing}) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2840),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: stripe, width: 3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      );
    }

    return Column(
      children: [
        section('At Risk', [
          card(
            stripe: Colors.orangeAccent,
            heading: 'Launch new product campaign',
            sub: 'Michael Chen • Overdue 2 days',
            trailing: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(backgroundColor: const Color(0xFFC10D00)),
              child: const Text('Nudge', style: TextStyle(color: Colors.white)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        section('Upcoming (7–14 days)', [
          card(
            stripe: Color(0xFFC10D00),
            heading: 'Quarterly roadmap draft',
            sub: 'Sarah Johnson • Due in 5 days',
          ),
          card(
            stripe: Colors.tealAccent,
            heading: 'Retention playbook v2',
            sub: 'Emily Rodriguez • Due in 12 days',
          ),
        ]),
        const SizedBox(height: 16),
        section('Recently Completed', [
          card(
            stripe: Colors.greenAccent,
            heading: 'Customer win-back workflow',
            sub: 'Emily Rodriguez • 2d ago',
            trailing: Row(children: [
              _chip('share', Color(0xFFC10D00)),
              const SizedBox(width: 6),
              _chip('kudos', Colors.orangeAccent),
            ]),
          ),
        ]),
      ],
    );
  }

  static Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: color, fontSize: 11)),
      );

  Widget _aiInsights() {
    Widget bullet(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(color: Colors.white70, fontSize: 16)),
              Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14))),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1F2840), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline, color: Color(0xFFC10D00), size: 20),
              SizedBox(width: 8),
              Text('AI Manager Insights', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          bullet('Forecasted risk: campaign slippage by 3 days. Consider reallocating resources.'),
          bullet('High morale signals this week. Share Emily’s win-back workflow as best practice.'),
          bullet('Schedule 1:1s with at-risk owners to unblock issues.'),
        ],
      ),
    );
  }

  Widget _workloadHeatmap() {
    List<List<double>> mock = const [
      [0.2, 0.8, 0.4, 0.1, 0.0, 0.3, 0.6],
      [0.1, 0.3, 0.2, 0.5, 0.7, 0.9, 0.4],
      [0.0, 0.2, 0.1, 0.6, 0.8, 0.5, 0.2],
    ];
    Color cell(double v) => Color.lerp(const Color(0xFF22304A), Color(0xFFC10D00), v) ?? const Color(0xFF22304A);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Workload & Capacity', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1F2840), borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Mon', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('Tue', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('Wed', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('Thu', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('Fri', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('Sat', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text('Sun', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                children: mock
                    .map((row) => Row(
                          children: row
                              .map((v) => Expanded(
                                    child: Container(
                                      height: 16,
                                      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                                      decoration: BoxDecoration(color: cell(v), borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ))
                              .toList(),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _engagementSummary() {
    Widget tile(IconData icon, String label, String value, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1F2840), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                )),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Engagement & Check-ins', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            tile(Icons.rate_review, 'Check-ins this week', '9', Color(0xFFC10D00)),
            const SizedBox(width: 12),
            tile(Icons.forum, 'Open comments', '5', Colors.orangeAccent),
            const SizedBox(width: 12),
            tile(Icons.alarm, 'Nudges pending', '3', Colors.pinkAccent),
          ],
        ),
      ],
    );
  }
}


