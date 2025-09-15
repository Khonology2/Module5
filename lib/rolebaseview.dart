import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter

class RoleBaseViewScreen extends StatelessWidget {
  const RoleBaseViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/hillyxyz_Generate_a_background_image_for_a_personal_development_app._Theme_1b482d56-7423-46ca-8b2d-ea094e0e91f6.png',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay for gradient effect and content
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F), // More opaque semi-transparent overlay
                      Color(0x88040610), // More opaque semi-transparent overlay
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.work,
                          size: 80,
                          color: Color(0xFFC7E3FF),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Welcome to Personal Development Hub.',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC7E3FF),
                          ),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          'Select your role.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFC7E3FF),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildRoleButton(
                          context,
                          'Employee',
                          Icons.person,
                          () {
                            // Navigate to employee portal
                            Navigator.pushReplacementNamed(context, '/employee_portal');
                          },
                        ),
                        const SizedBox(height: 15),
                        _buildRoleButton(
                          context,
                          'Manager',
                          Icons.manage_accounts,
                          () {
                            // Navigate to manager portal
                            Navigator.pushReplacementNamed(context, '/manager_portal');
                          },
                        ),
                        const SizedBox(height: 40),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6B4EE8), Color(0xFF48A6ED)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: TextButton(
                            onPressed: () {
                              // Navigate back to sign in
                              Navigator.pushReplacementNamed(context, '/sign_in');
                            },
                            child: const Text(
                              'Back to Sign In',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Choose your role to access your personalized dashboard',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF8B9FB7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(BuildContext context, String role, IconData icon, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          colors: [Color(0xFF6B4EE8), Color(0xFF48A6ED)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 24),
        label: Text(
          role,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}