import 'package:flutter/material.dart';
import 'package:pdh/app_drawer.dart'; // Import the new AppDrawer

class RepositoryAuditScreen extends StatelessWidget { 
  const RepositoryAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Ensure transparent background for full-screen effect
      extendBodyBehindAppBar: true, // Extend body behind AppBar
      // appBar: AppBar(
      //   title: const Text('Repository & Audit', style: TextStyle(color: Colors.white)), // Ensure title is visible
      //   backgroundColor: Colors.transparent, // Make AppBar transparent
      //   elevation: 0, // Remove AppBar shadow
      // ),
      drawer: const AppDrawer(), // Re-integrate the AppDrawer
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
            _RepositoryAppBarContent(onMenuPressed: () => Scaffold.of(context).openDrawer()), // Pass the callback
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0), // Padding for the list view
                children: [
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
                  ),
                  // Add more _buildGoalCard widgets as needed to fill the screen
                  // For example, duplicating the existing ones for demonstration:
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
      bottomNavigationBar: BottomAppBar(
        color: Colors.white, // White background for the BottomAppBar
        shape: const CircularNotchedRectangle(), // Optional: if you want a notch for a FloatingActionButton
        notchMargin: 8.0, // Space between FAB and app bar
        elevation: 10.0, // Add some elevation for a subtle shadow
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent, // Make inner nav bar transparent
          selectedItemColor: const Color(0xFF1976D2), // Blue for selected item
          unselectedItemColor: Colors.grey[600], // Dark grey for unselected items
          currentIndex: _getCurrentTabIndex(context), // Determine current index based on route
          selectedFontSize: 12.0, // Reduced font size
          unselectedFontSize: 12.0, // Reduced font size
          onTap: (index) {
            if (!context.mounted) return;
            String targetRoute;
            switch (index) {
              case 0:
                targetRoute = '/my_pdp';
                break;
              case 1:
                targetRoute = '/leaderboard';
                break;
              case 2:
                targetRoute = '/progress_visuals';
                break;
              case 3:
                targetRoute = '/settings';
                break;
              default:
                targetRoute = '/dashboard';
            }
            Navigator.pushNamedAndRemoveUntil(
              context,
              targetRoute,
              (Route<dynamic> route) => route.settings.name == '/dashboard' || route.isFirst,
            );
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.person), // Icon for My PDP
              label: 'My PDP',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.leaderboard), // Icon for Leaderboard
              label: 'Leaderboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), // Icon for Progress Visuals
              label: 'Progress Visuals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), // Icon for Setting
              label: 'Setting',
            ),
          ],
        ),
      ),
    );
  }

  int _getCurrentTabIndex(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/my_pdp') {
      return 0;
    } else if (currentRoute == '/leaderboard') {
      return 1;
    } else if (currentRoute == '/progress_visuals') {
      return 2;
    } else if (currentRoute == '/settings') {
      return 3;
    }
    return 0; // Default to My PDP if route is not found
  }

  // Helper widget to build individual goal cards.
  Widget _buildGoalCard({
    required String title,
    required String date,
    required String status,
    required Color statusColor,
    required List<String> evidence,
    String? acknowledgedBy,
    String? score,
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
          ...evidence.map((item) => _buildEvidenceItem(item)), // Removed .toList()
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
              // Hamburger icon (menu)
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: onMenuPressed, // Use the callback here
              ),
              const SizedBox(width: 15),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search completed goals, audit logs...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0x802C223E), // Slightly transparent for depth
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(15.0)),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0), // Adjust vertical padding for search bar
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
              const Text(
                'Completed Goals Archive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
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
