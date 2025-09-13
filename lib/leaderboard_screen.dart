import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:pdh/app_drawer.dart'; // Import the new AppDrawer
import 'package:pdh/bottom_nav_bar.dart'; // Import the new AppBottomNavBar

class LeaderboardScreen extends StatefulWidget { // Changed to StatefulWidget
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  int _selectedIndex = 0; // Add state variable for selected index

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setInitialIndex();
  }

  void _setInitialIndex() {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/my_pdp') {
      setState(() {
        _selectedIndex = 0; // Corresponds to My PDP
      });
    } else if (currentRoute == '/leaderboard') {
      setState(() {
        _selectedIndex = 1; // Corresponds to Leaderboard
      });
    } else if (currentRoute == '/progress_visuals') {
      setState(() {
        _selectedIndex = 2; // Corresponds to Progress Visuals
      });
    } else if (currentRoute == '/settings') {
      setState(() {
        _selectedIndex = 3; // Corresponds to Setting
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Handle navigation based on the selected index
    String targetRoute;
    switch (index) {
      case 0: // My PDP
        targetRoute = '/my_pdp';
        break;
      case 1: // Leaderboard
        targetRoute = '/leaderboard';
        break;
      case 2: // Progress Visuals
        targetRoute = '/progress_visuals';
        break;
      case 3: // Setting
        targetRoute = '/settings';
        break;
      default:
        targetRoute = '/my_pdp'; // Default to my_pdp (or appropriate fallback)
    }
    if (ModalRoute.of(context)?.settings.name != targetRoute) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        targetRoute,
        (Route<dynamic> route) => route.settings.name == '/my_pdp' || route.isFirst, // Keep my_pdp or first route
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        title: const Text('Leaderboard', style: TextStyle(color: Colors.white)), // Ensure title is visible
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
      ),
      drawer: const AppDrawer(), // Use the new AppDrawer widget
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
                child: const Center(
                  child: Text(
                    'Leaderboard Screen Content',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedIndex,
        onTabTapped: _onItemTapped,
      ),
    );
  }
}
