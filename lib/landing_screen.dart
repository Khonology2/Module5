import 'package:flutter/material.dart';
import 'dart:async'; // For Timer
import 'package:pdh/services/token_auth_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/widgets/floating_circles_particle_animation.dart';
import 'package:pdh/widgets/version_control_widget.dart';

/// Set to true to show the token input field and Login button on the landing screen.
/// Set to false to hide them (e.g. when using only URL-based token flow).
const bool kShowTokenLoginUI = false;

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
    extends State<PersonalDevelopmentHubScreen>
    with SingleTickerProviderStateMixin {
  late List<String> inspirationalLines;
  int _currentLineIndex = 0;
  late Timer _timer;
  bool _isCheckingToken = false;
  bool _isProcessingButton = false;
  bool _isSlowNetwork = false;

  // Animation controller for bounce effect
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  bool _isRedirecting = false;
  final TextEditingController _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize bounce animation
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.bounceOut),
    );

    // Start initial bounce animation when screen loads
    _bounceController.forward();

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

  /// Check for token in URL, validate with backend API, and auto-login
  /// This method uses the backend API for all token validation
  Future<void> _checkTokenAndAutoLogin({String? manualToken}) async {
    try {
      setState(() {
        _isCheckingToken = true;
        _isSlowNetwork = false;
      });
      // Trigger bounce animation when starting token check
      _bounceController.reset();
      _bounceController.forward();
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        if (_isCheckingToken) {
          setState(() {
            _isSlowNetwork = true;
          });
        }
      });

      debugPrint('Landing screen: Starting token check...');

      // Step A: Extract token from URL or use manual token
      final token = manualToken ?? await TokenAuthService.extractTokenFromUrl();

      if (token == null || token.isEmpty) {
        debugPrint('Landing screen: No token found in URL');

        // Only check for existing user if we're not doing manual token login
        if (manualToken == null) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final role = await RoleService.instance.getRole(refresh: true);
            if (mounted) {
              setState(() {
                _isCheckingToken = true;
                _isProcessingButton = false;
                _isSlowNetwork = false;
                _isRedirecting = true;
              });
              // Trigger bounce animation when starting token validation
              _bounceController.reset();
              _bounceController.forward();
              if (role == 'manager') {
                Navigator.pushReplacementNamed(context, '/manager_dashboard');
              } else {
                Navigator.pushReplacementNamed(context, '/employee_dashboard');
              }
            }
            return;
          }
        }

        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
            _isSlowNetwork = false;
            _isRedirecting = false;
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
        // Trigger bounce animation when starting button processing
        _bounceController.reset();
        _bounceController.forward();
      }

      BackendAuthService.instance.warmUpBackend();

      // Step B: Validate token using the backend API
      final validationResponse = await BackendAuthService.instance
          .validateTokenWithBackend(token);

      if (validationResponse == null) {
        debugPrint('Landing screen: Token validation failed');
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
            _isSlowNetwork = false;
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
            _isSlowNetwork = false;
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
        bool hasEmployeeOrStaff = false;
        bool hasAdminOrManager = false;
        for (final role in roles) {
          final s = role.toString().toLowerCase();
          if (s.contains('employee') || s.contains('staff')) {
            hasEmployeeOrStaff = true;
          }
          if (s.contains('admin') || s.contains('manager')) {
            hasAdminOrManager = true;
          }
        }
        // Prioritize Employee/Staff over Admin/Manager if both are present
        if (hasEmployeeOrStaff) {
          pdhRole = 'PDH - Employee';
        } else if (hasAdminOrManager) {
          pdhRole = 'PDH - Admin';
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
      // Fail fast if this build is using wrong Firebase project (stale cache / old deploy)
      final currentProjectId = Firebase.app().options.projectId;
      if (currentProjectId != 'pdh-v2') {
        debugPrint(
          'Landing screen: Wrong Firebase project "$currentProjectId". '
          'Rebuild: flutter clean && flutter pub get && flutter run -d chrome',
        );
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
            _isSlowNetwork = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'App is using wrong Firebase project ($currentProjectId). '
                'Rebuild the app: flutter clean, then flutter pub get, then run again.',
              ),
              backgroundColor: const Color(0xFFC10D00),
              duration: const Duration(seconds: 12),
            ),
          );
        }
        return;
      }
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

          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .set({
                  'email': email,
                  'role': internalRole,
                  'pdhRole': pdhRole,
                  'tokenAuthenticated': true,
                  'tokenAuthenticatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('Landing screen: Firestore write failed: $e');
          }

          RoleService.instance.setRoleOverride(internalRole);

          // Call backend callback to notify authentication is complete
          BackendAuthService.instance.callAuthCallback(
            userId: userId,
            email: email,
            role: pdhRole,
            authenticated: true,
          );

          // Step D: Route user based on roles
          if (mounted) {
            setState(() {
              _isCheckingToken = true;
              _isProcessingButton = false;
              _isSlowNetwork = false;
              _isRedirecting = true;
            });
            _navigateToDashboard(pdhRole);
            return;
          }
        }
      } catch (e) {
        debugPrint('Landing screen: Error signing in with custom token: $e');
        if (mounted && e is FirebaseAuthException && e.code == 'custom-token-mismatch') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This page may be cached or the app needs redeploy. '
                'Try: Hard refresh (Ctrl+Shift+R) or open in a private/incognito window.',
              ),
              backgroundColor: Color(0xFFC10D00),
              duration: Duration(seconds: 10),
            ),
          );
        }
      }

      // If we reach here, authentication failed
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
          _isProcessingButton = false;
          _isSlowNetwork = false;
        });
      }
    } catch (e) {
      debugPrint('Landing screen: Error checking token: $e');
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
          _isProcessingButton = false;
          _isSlowNetwork = false;
        });
      }
    }
  }

  /// Handle manual token login when user clicks login button
  Future<void> _handleManualTokenLogin() async {
    final token = _tokenController.text.trim();

    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a token'),
          backgroundColor: Color(0xFFC10D00),
        ),
      );
      return;
    }

    setState(() {
      _isProcessingButton = true;
      _isCheckingToken = true;
    });

    // Trigger bounce animation when starting manual login
    _bounceController.reset();
    _bounceController.forward();

    await _checkTokenAndAutoLogin(manualToken: token);
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
        debugPrint('Landing screen: Navigating to manager dashboard...');
        Navigator.pushReplacementNamed(context, '/manager_dashboard')
            .then(
              (_) => debugPrint(
                'Landing screen: Navigation to manager dashboard completed',
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
    _tokenController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  final GlobalKey<FloatingCirclesParticleAnimationState> _animationKey =
      GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage('assets/khono_bg.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.4),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),

          // Particle Animation
          Positioned.fill(
            child: FloatingCirclesParticleAnimation(
              key: _animationKey,
              circleColor: const Color(0xFFC10D00).withValues(alpha: 0.7),
              numberOfParticles: 20,
              maxParticleSize: 6.0,
            ),
          ),

          // Content overlay
          Positioned.fill(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo - Centered
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _animationKey.currentState
                              ?.triggerParticleExplosion();
                        },
                        child: Image.asset(
                          'assets/khono.png',
                          height: 160,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
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
                    // Show AI Avatar GIF with bounce animation only when checking token
                    if (_isCheckingToken) ...[
                      AnimatedBuilder(
                        animation: _bounceAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              0,
                              -20 * (1 - _bounceAnimation.value),
                            ),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFC10D00), // Red border
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/videos/Ai_Avatar.gif',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Show token input field and login button when not checking token (and when enabled)
                    if (kShowTokenLoginUI && !_isCheckingToken) ...[
                      const SizedBox(height: 24),
                      // Token input field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: TextField(
                          controller: _tokenController,
                          decoration: InputDecoration(
                            hintText: 'Enter your authentication token',
                            hintStyle: TextStyle(
                              color: Colors.white.withAlpha(128),
                            ),
                            filled: true,
                            fillColor: Colors.white.withAlpha(26),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withAlpha(51),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.white.withAlpha(51),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFC10D00),
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.vpn_key,
                              color: Colors.white.withAlpha(179),
                            ),
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          obscureText: false,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Login button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: ElevatedButton(
                          onPressed: _isProcessingButton
                              ? null
                              : _handleManualTokenLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC10D00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: _isProcessingButton
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                    // Show subtle loading indicator when checking token
                    if (_isCheckingToken) ...[
                      Text(
                        _isRedirecting
                            ? 'Redirecting to your dashboard...'
                            : (_isSlowNetwork
                                  ? 'We\'re Are Signing You In... Just A Moment'
                                  : 'Validating token...'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Version Control Widget - Bottom of screen
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: VersionControlWidget(
                fontSize: 12.0,
                textColor: Colors.white70,
                hoverColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
