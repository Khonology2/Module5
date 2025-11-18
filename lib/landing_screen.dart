// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'package:pdh/services/token_auth_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/backend_auth_service.dart';
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
  State<PersonalDevelopmentHubScreen> createState() =>
      _PersonalDevelopmentHubScreenState();
}

class _PersonalDevelopmentHubScreenState
    extends State<PersonalDevelopmentHubScreen> {
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

  /// Check for token in URL, validate with onboarding collection, and auto-login
  /// This method automatically reads the token from URL, verifies it with the onboarding
  /// collection, checks moduleAccessRole, and logs the user in automatically
  Future<void> _checkTokenAndAutoLogin() async {
    try {
      setState(() {
        _isCheckingToken = true;
      });

      debugPrint('Landing screen: Starting token check...');

      // Step 1: Extract token from URL
      final token = await TokenAuthService.instance.extractTokenFromUrl();

      if (token == null || token.isEmpty) {
        debugPrint('Landing screen: No token found in URL');
        // No token found, show landing screen
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
          });
        }
        return;
      }

      debugPrint('Landing screen: Token found in URL, starting validation...');
      debugPrint('Landing screen: Token length: ${token.length}');

      // Step 2: Decrypt and decode the encrypted token
      // Token format: Base64 encoded -> Fernet encrypted -> JWT
      debugPrint(
        'Landing screen: Decrypting token (Base64 -> Fernet -> JWT)...',
      );
      String? email;
      Map<String, dynamic>? decodedToken;

      try {
        // Process encrypted token: decrypt and decode
        decodedToken = await TokenAuthService.instance.processEncryptedToken(
          token,
        );

        if (decodedToken != null) {
          debugPrint(
            'Landing screen: Token decrypted and decoded successfully',
          );

          // Extract email from decoded token
          email =
              decodedToken['email'] as String? ??
              decodedToken['sub'] as String? ??
              decodedToken['user_email'] as String?;

          if (email != null && email.isNotEmpty) {
            debugPrint(
              'Landing screen: Email extracted from decrypted token: $email',
            );
          } else {
            debugPrint(
              'Landing screen: Email not found in token, will get from onboarding collection',
            );
          }
        } else {
          debugPrint(
            'Landing screen: Failed to decrypt/decode token, will try direct onboarding validation',
          );
        }
      } catch (e) {
        debugPrint('Landing screen: Error during token decryption: $e');
        debugPrint(
          'Landing screen: Will proceed with onboarding collection validation by token',
        );
      }

      // Step 4: Validate token with onboarding collection and get moduleAccessRole
      // This is the critical step - checking the database to verify the token
      // We can validate by token directly, even if we don't have email from JWT
      debugPrint(
        'Landing screen: Validating token with onboarding collection...',
      );
      debugPrint(
        'Landing screen: Using email from token: ${email ?? "not available"}',
      );

      final onboardingData = await TokenAuthService.instance
          .validateTokenWithOnboarding(token, email);

      if (onboardingData == null) {
        debugPrint(
          'Landing screen: Token validation failed - token not found in onboarding collection or mismatch',
        );
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
          });
        }
        return;
      }

      // Get email from onboarding data if we didn't get it from token
      final onboardingEmail = onboardingData['email'] as String?;
      if (onboardingEmail != null && onboardingEmail.isNotEmpty) {
        email = onboardingEmail;
        debugPrint(
          'Landing screen: Email retrieved from onboarding collection: $email',
        );
      }

      final moduleAccessRole = onboardingData['moduleAccessRole'] as String;
      debugPrint(
        'Landing screen: Token validated successfully. ModuleAccessRole: $moduleAccessRole',
      );

      // Ensure we have email for user creation
      if (email == null || email.isEmpty) {
        debugPrint('Landing screen: Cannot proceed without email');
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
          });
        }
        return;
      }

      // Step 5: Map moduleAccessRole to internal role
      final role = TokenAuthService.instance.mapModuleAccessRoleToRole(
        moduleAccessRole,
      );

      if (role == null) {
        debugPrint(
          'Landing screen: Invalid moduleAccessRole: $moduleAccessRole',
        );
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
          });
        }
        return;
      }

      debugPrint('Landing screen: Role mapped successfully: $role');

      // Step 6: Automatically sign in the user
      // Check if user is already logged in
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // User is already logged in, update role and navigate
        debugPrint(
          'Landing screen: User already logged in, updating role and redirecting...',
        );
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
      } else {
        // User is not logged in - automatically sign them in using backend custom token
        debugPrint(
          'Landing screen: User not logged in, attempting automatic sign-in with custom token...',
        );
        try {
          final userCredential = await BackendAuthService.instance
              .signInWithCustomToken(token);

          if (userCredential != null && userCredential.user != null) {
            // Successfully signed in automatically
            debugPrint('Landing screen: Automatic sign-in successful!');
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userCredential.user!.uid)
                .set({
                  'email': email,
                  'role': role,
                  'tokenAuthenticated': true,
                  'tokenAuthenticatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

            await RoleService.instance.getRole(refresh: true);

            if (mounted) {
              debugPrint('Landing screen: Redirecting to $role dashboard...');
              _navigateToDashboard(role);
              return;
            }
          } else {
            // Backend service not available - cannot auto-login without backend
            debugPrint(
              'Landing screen: Backend service not available - cannot auto-login. User must sign in manually.',
            );
            // Show landing screen so user can manually sign in
          }
        } catch (e) {
          debugPrint('Landing screen: Error during automatic sign-in: $e');
          // Continue to show landing screen
        }
      }

      // Token check complete (whether successful or not)
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
        });
      }
    } catch (e) {
      debugPrint('Landing screen: Error checking token: $e');
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
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.4),
                BlendMode.darken,
              ),
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
                        backgroundColor: Color(
                          0xFFC10D00,
                        ), // Use the new red color
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape:
                            const StadiumBorder(), // Changed to StadiumBorder
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
