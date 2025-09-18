import 'package:flutter/material.dart';
import 'package:pdh/employee_drawer.dart'; // Import the EmployeeDrawer
import 'package:pdh/manager_nav_drawer.dart';
import 'package:pdh/services/role_service.dart';

class RepositoryAuditScreen extends StatelessWidget { 
  const RepositoryAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Ensure transparent background for full-screen effect
      extendBodyBehindAppBar: true, // Extend body behind AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Repository & Audit', style: TextStyle(color: Colors.white)),
      ),
      drawer: const _RoleAwareDrawer(),
      body: Container(
        // The background gradient to match the vibrant green/blue.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00C7B7), // Top color from the screenshot
              Color(0xFF00A896), // Bottom color, slightly darker green
            ],
          ),
        ),
        child: Column(
          children: [
            // AppBar replacement with search and title.
            Builder(
              builder: (context) => _RepositoryAppBarContent(
                onMenuPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0), // Padding for the list view
                children: [
                  StreamBuilder<String?>(
                    stream: RoleService.instance.roleStream(),
                    builder: (context, snapshot) {
                      final isManager = snapshot.data == 'manager';
                      return _RoleSummaryBar(isManager: isManager);
                    },
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<String?>(
                    stream: RoleService.instance.roleStream(),
                    builder: (context, snapshot) {
                      final isManager = snapshot.data == 'manager';
                      return Column(children: [
                        _buildGoalCard(
                          title: 'Increase Customer Satisfaction Score',
                          date: 'March 15, 2024',
                          status: 'Verified',
                          statusColor: const Color(0xFF2E8B57),
                          evidence: [
                            'Survey Results Report',
                            'Dashboard Analytics Link',
                            'Customer Feedback Files',
                          ],
                          acknowledgedBy: 'Sarah Chen',
                          score: '4.8',
                          isManager: isManager,
                        ),
                        _buildGoalCard(
                          title: 'Launch New Product Feature',
                          date: 'February 28, 2024',
                          status: 'Pending',
                          statusColor: const Color(0xFFE4A11A),
                          evidence: [
                            'Feature Specification Document',
                            'GitHub Repository Link',
                          ],
                          acknowledgedBy: null,
                          score: null,
                          isManager: isManager,
                        ),
                        _buildGoalCard(
                          title: 'Strategic Market Expansion Plan',
                          date: 'January 20, 2024',
                          status: 'Verified',
                          statusColor: const Color(0xFF2E8B57),
                          evidence: [
                            'Market Research Summary',
                            'Competitor Analysis',
                            'Expansion Proposal Document',
                          ],
                          acknowledgedBy: 'John Doe',
                          score: '4.5',
                          isManager: isManager,
                        ),
                        _buildGoalCard(
                          title: 'Complete Leadership Training',
                          date: 'December 10, 2023',
                          status: 'Verified',
                          statusColor: const Color(0xFF2E8B57),
                          evidence: [
                            'Course Completion Certificate',
                            'Leadership Workshop Notes',
                          ],
                          acknowledgedBy: 'Jane Smith',
                          score: '4.9',
                          isManager: isManager,
                        ),
                      ]);
                    },
                  ),
                ],
              ),
            ),
            // Bottom navigation buttons
            // Container(
            //   padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
            //   decoration: const BoxDecoration(
            //     color: Color(0xFF1E172F), // Darker background for the button bar
            //     borderRadius: BorderRadius.only(
            //       topLeft: Radius.circular(30),
            //       topRight: Radius.circular(30),
            //     ),
            //   ),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceAround,
            //     children: [
            //       _buildRoleButton('Manager', true), // Manager button is selected
            //       _buildRoleButton('Employee', false), // Employee button is not selected
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
      // bottomNavigationBar removed per request
    );
  }

  // Removed bottom navigation; helper no longer needed

  // Helper widget to build individual goal cards.
  Widget _buildGoalCard({
    required String title,
    required String date,
    required String status,
    required Color statusColor,
    required List<String> evidence,
    String? acknowledgedBy,
    String? score,
    required bool isManager,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E172F), // Card background color
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [ // Optional: subtle shadow for cards
          BoxShadow(
            color: Colors.black.withAlpha(51), // Replaced withOpacity(0.2) with withAlpha(51)
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(51), // Replaced withOpacity(0.2) with withAlpha(51)
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Completed on $date',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 15),
          const Text(
            'Evidence & Documentation:',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          ...evidence.map((item) => _buildEvidenceItem(item)),
          if (isManager) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.verified, size: 16),
                  label: const Text('Verify Evidence'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white38)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.comment, size: 16),
                  label: const Text('Request Changes'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white38)),
                ),
              ],
            ),
          ],
          if (acknowledgedBy != null)
            Padding(
              padding: const EdgeInsets.only(top: 15.0),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white70, size: 20),
                  const SizedBox(width: 5),
                  Text(
                    'Acknowledged by $acknowledgedBy',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (score != null)
                    Text(
                      '(Score: $score)',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Helper widget to build individual evidence items.
  Widget _buildEvidenceItem(String text) {
    IconData icon;
    if (text.toLowerCase().contains('report') || text.toLowerCase().contains('document') || text.toLowerCase().contains('files')) {
      icon = Icons.description;
    } else if (text.toLowerCase().contains('link') || text.toLowerCase().contains('repository')) {
      icon = Icons.link;
    } else {
      icon = Icons.attachment;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleSummaryBar extends StatelessWidget {
  final bool isManager;
  const _RoleSummaryBar({required this.isManager});

  @override
  Widget build(BuildContext context) {
    Widget chip(Color color, String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
        );

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0x802C223E), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isManager ? Icons.manage_accounts : Icons.person, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isManager ? 'Manager view' : 'Employee view',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 6,
                    runSpacing: 6,
                    children: isManager
                        ? [
                            chip(const Color(0xFF2E8B57), 'Verified 12'),
                            chip(const Color(0xFFE4A11A), 'Pending 5'),
                          ]
                        : [
                            chip(const Color(0xFF2E8B57), 'My Verified 4'),
                            chip(const Color(0xFFE4A11A), 'My Pending 1'),
                          ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RepositoryAppBarContent extends StatelessWidget {
  final VoidCallback onMenuPressed; // Add the callback parameter

  const _RepositoryAppBarContent({required this.onMenuPressed}); // Update constructor

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 0), // Adjusted top padding
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search completed goals, audit logs...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0x802C223E),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15.0)),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25), // Spacing between search bar and title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Completed Goals Archive',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              // Archive icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.archive_outlined, color: Colors.white, size: 24),
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
