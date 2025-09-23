import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget { // Renamed from BottomNavBar
  final int selectedIndex;
  final Function(int) onTabTapped;

  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTabTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero, // Removed curves
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(25), // Replaced withOpacity(0.1) with withAlpha(25)
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        // borderRadius: const BorderRadius.only(
        //   topLeft: Radius.circular(30.0),
        //   topRight: Radius.circular(30.0),
        // ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: onTabTapped, // Use the callback directly
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFFC10D00),
          unselectedItemColor: Colors.grey[400],
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
          ),
          items: const <BottomNavigationBarItem>[
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
}
