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
  bool _isProcessingButton = false;

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

  /// Handle GET STARTED button click
  /// Triggers authentication flow and shows loading state on button
  Future<void> _handleGetStartedClick() async {
    setState(() {
      _isProcessingButton = true;
    });

    // Check for token and authenticate
    await _checkTokenAndAutoLogin();

    // If authentication didn't complete (no token or failed), navigate to sign in
    // If _isCheckingToken is true, it means token was found and full-screen loading is shown
    // Navigation will happen automatically, so we don't need to do anything here
    if (mounted && !_isCheckingToken) {
      setState(() {
        _isProcessingButton = false;
      });
      // No token found or authentication failed, go to sign in screen
      Navigator.pushNamed(context, '/sign_in');
    }
  }

  /// Check for token in URL, validate with backend API, and auto-login
  /// This method uses the backend API for all token validation
  Future<void> _checkTokenAndAutoLogin() async {
    try {
      setState(() {
        _isCheckingToken = true;
      });

      debugPrint('Landing screen: Starting token check...');

      // Step A: Extract token from URL
      final token = await TokenAuthService.extractTokenFromUrl();

      if (token == null || token.isEmpty) {
        debugPrint('Landing screen: No token found in URL');
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
          });
        }
        return;
      }

      debugPrint('Landing screen: Token found in URL, starting validation...');

      // If button was clicked and token found, switch to full-screen loading
      if (_isProcessingButton) {
        setState(() {
          _isCheckingToken = true;
        });
      }

      // Step B: Validate token using the backend API
      final validationResponse = await BackendAuthService.instance
          .validateTokenWithBackend(token);

      if (validationResponse == null) {
        debugPrint('Landing screen: Token validation failed');
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
          });
        }
        return;
      }

      // Extract data from backend response
      final firebaseTokenRaw = validationResponse['firebase_token'] as String?;
      final email = validationResponse['email'] as String?;
      final roles = validationResponse['roles'] as List<dynamic>?;

      if (firebaseTokenRaw == null || firebaseTokenRaw.isEmpty) {
        debugPrint('Landing screen: No firebase_token in response');
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
          });
        }
        return;
      }

      // Clean the token: trim whitespace and remove any quotes
      String firebaseToken = firebaseTokenRaw.trim();
      if (firebaseToken.startsWith('"') && firebaseToken.endsWith('"')) {
        firebaseToken = firebaseToken.substring(1, firebaseToken.length - 1);
      }
      if (firebaseToken.startsWith("'") && firebaseToken.endsWith("'")) {
        firebaseToken = firebaseToken.substring(1, firebaseToken.length - 1);
      }
      firebaseToken = firebaseToken.trim();

      debugPrint(
        'Landing screen: Firebase token extracted (length: ${firebaseToken.length})',
      );
      debugPrint(
        'Landing screen: Token preview - first 50 chars: ${firebaseToken.substring(0, firebaseToken.length > 50 ? 50 : firebaseToken.length)}...',
      );

      // Validate token format (should be a JWT with 3 parts)
      final tokenParts = firebaseToken.split('.');
      if (tokenParts.length != 3) {
        debugPrint(
          'Landing screen: Invalid Firebase token format - expected 3 parts, got ${tokenParts.length}',
        );
        debugPrint(
          'Landing screen: Token parts: ${tokenParts.map((p) => p.length).join(", ")}',
        );
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
          });
        }
        return;
      }

      debugPrint(
        'Landing screen: Token format valid - 3 parts with lengths: ${tokenParts.map((p) => p.length).join(", ")}',
      );

      // Extract PDH role from roles list
      String? pdhRole;
      if (roles != null && roles.isNotEmpty) {
        for (final role in roles) {
          final roleStr = role.toString();
          if (roleStr.contains('PDH - Employee') ||
              roleStr.contains('PDH-Employee')) {
            pdhRole = 'PDH - Employee';
            break;
          } else if (roleStr.contains('PDH - Admin') ||
              roleStr.contains('PDH-Admin') ||
              roleStr.contains('PDH - Manager') ||
              roleStr.contains('PDH-Manager')) {
            pdhRole = 'PDH - Admin';
            break;
          }
        }
      }

      if (pdhRole == null) {
        debugPrint('Landing screen: No PDH role found');
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
          });
        }
        return;
      }

      // Step C: Sign in using Firebase custom token
      try {
        final userCredential = await FirebaseAuth.instance
            .signInWithCustomToken(firebaseToken);

        if (userCredential.user != null && email != null) {
          // Update user role in Firestore
          final userId = userCredential.user!.uid;
          String internalRole;
          if (pdhRole == 'PDH - Employee') {
            internalRole = 'employee';
          } else {
            internalRole = 'manager'; // Admin uses manager role internally
          }

          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'email': email,
            'role': internalRole,
            'pdhRole': pdhRole,
            'tokenAuthenticated': true,
            'tokenAuthenticatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          await RoleService.instance.getRole(refresh: true);

          // Call backend callback to notify authentication is complete
          await BackendAuthService.instance.callAuthCallback(
            userId: userId,
            email: email,
            role: pdhRole,
            authenticated: true,
          );

          // Step D: Route user based on roles
          if (mounted) {
            setState(() {
              _isCheckingToken = false;
              _isProcessingButton = false;
            });
            _navigateToDashboard(pdhRole);
            return;
          }
        }
      } catch (e) {
        debugPrint('Landing screen: Error signing in with custom token: $e');
      }

      // If we reach here, authentication failed
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
          _isProcessingButton = false;
        });
      }
    } catch (e) {
      debugPrint('Landing screen: Error checking token: $e');
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
          _isProcessingButton = false;
        });
      }
    }
  }

  /// Navigate to appropriate dashboard based on role
  void _navigateToDashboard(String pdhRole) {
    if (!mounted) {
      debugPrint('Landing screen: Cannot navigate - widget not mounted');
      return;
    }

    debugPrint(
      'Landing screen: _navigateToDashboard called with role: $pdhRole',
    );

    try {
      if (pdhRole == 'PDH - Employee') {
        debugPrint('Landing screen: Navigating to employee dashboard...');
        Navigator.pushReplacementNamed(context, '/employee_dashboard')
            .then(
              (_) => debugPrint(
                'Landing screen: Navigation to employee dashboard completed',
              ),
            )
            .catchError(
              (e) => debugPrint('Landing screen: Navigation error: $e'),
            );
      } else if (pdhRole == 'PDH - Admin') {
        debugPrint('Landing screen: Navigating to admin dashboard...');
        Navigator.pushReplacementNamed(context, '/admin_dashboard')
            .then(
              (_) => debugPrint(
                'Landing screen: Navigation to admin dashboard completed',
              ),
            )
            .catchError(
              (e) => debugPrint('Landing screen: Navigation error: $e'),
            );
      } else {
        debugPrint(
          'Landing screen: Unknown role: $pdhRole, defaulting to employee dashboard',
        );
        Navigator.pushReplacementNamed(context, '/employee_dashboard')
            .then(
              (_) => debugPrint(
                'Landing screen: Navigation to employee dashboard completed',
              ),
            )
            .catchError(
              (e) => debugPrint('Landing screen: Navigation error: $e'),
            );
      }
    } catch (e) {
      debugPrint('Landing screen: Error during navigation: $e');
      debugPrint('Landing screen: Stack trace: ${StackTrace.current}');
    }
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
                      onPressed: _isProcessingButton
                          ? null
                          : () {
                              _handleGetStartedClick();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(
                          0xFFC10D00,
                        ), // Use the new red color
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: const StadiumBorder(),
                        disabledBackgroundColor: Color(
                          0xFFC10D00,
                        ).withOpacity(0.6),
                      ),
                      child: _isProcessingButton
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
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
