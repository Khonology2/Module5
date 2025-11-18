// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'package:pdh/services/token_auth_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// The main entry point for the Flutter application.
// void main() {
//   runApp(const MyApp());
// }

// A StatelessWidget that sets up the MaterialApp.
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Personal Development Hub',
//       theme: ThemeData(
//         brightness: Brightness.dark,
//         primarySwatch: Colors.blue,
//         fontFamily: 'Inter',
//       ),
//       home: const PersonalDevelopmentHubScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

// The main screen widget for the Personal Development Hub.
class PersonalDevelopmentHubScreen extends StatefulWidget {
  const PersonalDevelopmentHubScreen({super.key});

  @override
  State<PersonalDevelopmentHubScreen> createState() => _PersonalDevelopmentHubScreenState();
}

class _PersonalDevelopmentHubScreenState extends State<PersonalDevelopmentHubScreen> {
  late List<String> inspirationalLines;
  int _currentLineIndex = 0;
  late Timer _timer;
  bool _isCheckingToken = false;

  @override
  void initState() {
    super.initState();
    _checkTokenAndAutoLogin();
    inspirationalLines = [
      "Cultivate your mind, blossom your potential.",
      "Every step forward is a victory.",
      "Organize your life, clarify your purpose.",
      "Knowledge is the compass of growth.",
      "Build strong habits, build a strong future.",
      "Financial wisdom empowers freedom.",
      "Unlock your inner creativity.",
      "Mindfulness lights the path to peace.",
      "Fitness fuels your ambition.",
      "Learn relentlessly, live boundlessly.",
      "Your journey, your rules, your growth.",
      "Small changes, significant impact.",
      "Embrace the challenge, find your strength.",
      "Beyond limits, lies growth.",
      "Master your days, master your destiny.",
      "Innovate, iterate, inspire.",
      "The best investment is in yourself.",
      "Find your balance, elevate your being.",
      "Progress, not perfection.",
      "Dream big, start small, act now.",
    ];
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        _currentLineIndex = (_currentLineIndex + 1) % inspirationalLines.length;
      });
    });

    // Precache hero images after first frame to avoid jank on first paint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = this.context;
      if (!mounted) return;
      // Background image sized to screen width to reduce decode cost
      final int bgWidth = (MediaQuery.of(context).size.width * 1.5).toInt();
      precacheImage(
        const AssetImage('assets/khono_bg.png'),
        context,
        size: Size(bgWidth.toDouble(), MediaQuery.of(context).size.height),
      );
      // Logo: decode at device-pixel-ratio size to keep it crisp
      final double dpr = MediaQuery.of(context).devicePixelRatio;
      precacheImage(
        const AssetImage('assets/khono.png'),
        context,
        size: Size(320 * dpr, 160 * dpr),
      );
    });
  }

  /// Check for token in URL and auto-login if present
  Future<void> _checkTokenAndAutoLogin() async {
    try {
      setState(() {
        _isCheckingToken = true;
      });

      // Extract token from URL
      final token = await TokenAuthService.instance.extractTokenFromUrl();
      
      if (token != null && token.isNotEmpty) {
        // Authenticate with token
        final result = await TokenAuthService.instance
            .authenticateExistingUserWithToken(token);

        if (result != null && result['success'] == true) {
          final role = result['role'] as String?;
          final email = result['email'] as String?;

          if (role != null && email != null) {
            // Get current user
            User? user = FirebaseAuth.instance.currentUser;

            if (user != null) {
              // User is already logged in, update role and navigate
              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'email': email,
                'role': role,
                'tokenAuthenticated': true,
                'tokenAuthenticatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              
              await RoleService.instance.getRole(refresh: true);
              
              if (mounted) {
                _navigateToDashboard(role);
                return;
              }
            }
          }
        }
      }

      // No token or token auth failed
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking token on landing: $e');
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
        });
      }
    }
  }

  /// Navigate to appropriate dashboard based on role
  void _navigateToDashboard(String role) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (role == 'manager') {
        Navigator.pushReplacementNamed(context, '/manager_portal');
      } else if (role == 'employee') {
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking token
    if (_isCheckingToken) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1931),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
              child: Image.asset(
                'assets/khono_bg.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheWidth: (MediaQuery.of(context).size.width * 1.5).toInt(),
              ),
            ),
          ),
          // Content overlay
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo - Centered
                  Center(
                    child: Image.asset(
                      'assets/khono.png',
                      height: 160,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tagline - Centered
                  const Center(
                    child: Text(
                      'Your Growth Journey, Simplified',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC10D00),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Inspirational message - Centered
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        inspirationalLines[_currentLineIndex],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white.withAlpha(204),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Button - Centered
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/sign_in');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFC10D00), // Use the new red color
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: const StadiumBorder(), // Changed to StadiumBorder
                      ),
                      child: const Text(
                        'GET STARTED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}