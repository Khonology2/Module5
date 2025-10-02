import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore

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
              'assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png',
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
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/khonodemy.png',
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Welcome to KhonoDemy Your Personal Development Programme.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 40),
                          const Text(
                            'Select your role.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          const SizedBox(height: 20),
                          _buildRoleButton(context, 'Employee', () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .set({
                                    'role': 'employee',
                                    'roleSetAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                            }
                            if (!context.mounted) return;
                            // Send employees directly to the dashboard
                            Navigator.pushReplacementNamed(
                              context,
                              '/employee_dashboard',
                            );
                          }),
                          const SizedBox(height: 15),
                          _buildRoleButton(context, 'Manager', () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .set({
                                    'role': 'manager',
                                    'roleSetAt': FieldValue.serverTimestamp(),
                                  }, SetOptions(merge: true));
                            }
                            if (!context.mounted) return;
                            Navigator.pushReplacementNamed(
                              context,
                              '/manager_portal',
                            );
                          }),
                          const SizedBox(height: 40),
                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(28),
                              ),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFC10D00), Color(0xFFC10D00)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            child: TextButton(
                              onPressed: () {
                                // Navigate back to sign in
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/sign_in',
                                );
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
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildRoleButton(
    BuildContext context,
    String role,
    VoidCallback onPressed,
  ) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        gradient: const LinearGradient(
          colors: [Color(0xFFC10D00), Color(0xFFC10D00)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: TextButton(
        onPressed: onPressed,
        child: Text(
          role,
          textAlign: TextAlign.center,
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
