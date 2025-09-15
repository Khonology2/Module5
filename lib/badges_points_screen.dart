import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:pdh/employee_drawer.dart'; // Import the EmployeeDrawer

class BadgesPointsScreen extends StatelessWidget {
  const BadgesPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        title: const Text('Badges & Points', style: TextStyle(color: Colors.white)), // Ensure title is visible
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
      ),
      drawer: const EmployeeDrawer(), // Use the EmployeeDrawer widget
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
                    'Badges & Points Screen Content',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
