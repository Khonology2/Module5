import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async'; // For Timer
import 'package:pdh/services/token_auth_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/widgets/floating_circles_particle_animation.dart';
import 'package:pdh/widgets/version_control_widget.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';
import 'package:pdh/utils/web_origin_stub.dart' if (dart.library.html) 'package:pdh/utils/web_origin_web.dart' as web_origin;

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
  const PersonalDevelopmentHubScreen({super.key, this.initialToken});

  final String? initialToken;

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
  bool _isLightMode = false;

  // Animation controller for bounce effect
  late AnimationController _bounceController;
  final TextEditingController _tokenController = TextEditingController();

  Color get _solidTextColor => _isLightMode ? Colors.black : Colors.white;
  Color get _subtitleColor =>
      _isLightMode ? Colors.black : const Color.fromARGB(204, 255, 255, 255);
  String get _backgroundAsset =>
      _isLightMode ? 'assets/light_mode_bg.png' : 'assets/khono_bg.png';

  @override
  void initState() {
    super.initState();
    employeeDashboardLightModeNotifier.value = false;
    _resetAuthStateForLanding();

    // Initialize bounce animation
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Start initial bounce animation when screen loads
    _bounceController.forward();

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
      precacheImage(
        const AssetImage('assets/light_mode_bg.png'),
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
      precacheImage(const AssetImage('assets/discs.png'), context);
      precacheImage(const AssetImage('assets/Red_Khono_Discs.png'), context);
    });
  }

  Future<void> _resetAuthStateForLanding() async {
    try {
      // Ensure landing never auto-routes from a stale session.
      RoleService.instance.clearCache();
      RoleService.instance.clearRoleOverride();
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (e) {}
  }

  bool _isTokenThemeLight(dynamic tokenTheme) {
    final raw = tokenTheme?.toString().trim().toLowerCase() ?? '';
    return raw == 'light';
  }

  Future<void> _applyThemeBeforeLogin(dynamic tokenTheme) async {
    final light = _isTokenThemeLight(tokenTheme);
    if (!mounted) {
      employeeDashboardLightModeNotifier.value = light;
      return;
    }
    setState(() {
      _isLightMode = light;
    });
    employeeDashboardLightModeNotifier.value = light;
    // Let MaterialApp + landing repaint before sign-in.
    await SchedulerBinding.instance.endOfFrame;
    await SchedulerBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 50));
  }

  /// Check for token in URL, validate with backend API, and auto-login
  /// This method uses the backend API for all token validation
  Future<void> _checkTokenAndAutoLogin({String? manualToken}) async {
    try {
      // Prevent stale role routing from a previous session/login attempt.
      RoleService.instance.clearRoleOverride();
      setState(() {
        _isCheckingToken = true;
      });
      // Trigger bounce animation when starting token check
      _bounceController.reset();
      _bounceController.forward();

      // Step A: Extract token from URL or use manual token
      final token = manualToken ?? await TokenAuthService.extractTokenFromUrl();

      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cant login right now, please try to login again from KhonoBuzz.'),
              backgroundColor: Color(0xFFC10D00),
            ),
          );
        }
        return;
      }

      // Fresh token login should not inherit cached role from a prior session.
      RoleService.instance.clearCache();

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
      final tokenTheme = validationResponse['theme'];

      if (firebaseTokenRaw == null || firebaseTokenRaw.isEmpty) {
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

      // Validate token format (should be a JWT with 3 parts)
      final tokenParts = firebaseToken.split('.');
      if (tokenParts.length != 3) {
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
          });
        }
        return;
      }

      // Extract PDH role from roles list (backend returns e.g. PDH - Employee, PDH - Manager, PDH - Admin)
      String? pdhRole;
      if (roles != null && roles.isNotEmpty) {
        for (final role in roles) {
          final s = role.toString().toLowerCase();
          if (s.contains('admin')) {
            pdhRole = 'PDH - Admin';
            break;
          }
          if (s.contains('manager')) {
            pdhRole = 'PDH - Manager';
            break;
          }
          if (s.contains('employee') || s.contains('staff')) {
            pdhRole = 'PDH - Employee';
            break;
          }
        }
      }

      if (pdhRole == null) {
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _isProcessingButton = false;
          });
        }
        return;
      }

      // Apply token theme before sign-in and before dashboard navigation.
      await _applyThemeBeforeLogin(tokenTheme);

      // Step C: Sign in using Firebase custom token (config from backend /firebase-config or firebase_options)
      try {
        final userCredential = await FirebaseAuth.instance
            .signInWithCustomToken(firebaseToken);

        if (userCredential.user != null && email != null) {
          final userId = userCredential.user!.uid;
          String internalRole;
          if (pdhRole == 'PDH - Employee') {
            internalRole = 'employee';
          } else if (pdhRole == 'PDH - Admin') {
            internalRole = 'admin';
          } else {
            internalRole = 'manager';
          }

          // Brief delay so Firestore client picks up the new auth token (avoids permission-denied race)
          await Future.delayed(const Duration(milliseconds: 150));

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
          } catch (e) {}

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
            });
            _navigateToDashboard(pdhRole);
            return;
          }
        }
      } catch (e) {
        if (mounted && e is FirebaseAuthException) {
          if (e.code == 'custom-token-mismatch') {
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
          } else if (e.code == 'api-key-not-valid' ||
              (e.message != null && e.message!.toLowerCase().contains('api-key-not-valid'))) {
            final origin = web_origin.getWebOrigin();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  origin != null && origin.isNotEmpty
                      ? 'API key rejected. In Google Cloud → Credentials → Browser key add HTTP referrer: $origin/*'
                      : 'Firebase API key rejected. In Google Cloud (pdh-v2): enable Identity Toolkit API and add your site URL to Browser key HTTP referrers.',
                ),
                backgroundColor: const Color(0xFFC10D00),
                duration: const Duration(seconds: 12),
              ),
            );
          }
        }
      }

      // If we reach here, authentication failed
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
          _isProcessingButton = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
          _isProcessingButton = false;
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

  Future<void> _handleGetStarted() async {
    if (_isCheckingToken || _isProcessingButton) return;
    setState(() {
      _isProcessingButton = true;
      _isCheckingToken = true;
    });
    _bounceController.reset();
    _bounceController.forward();
    await _checkTokenAndAutoLogin(manualToken: widget.initialToken);
  }

  /// Navigate to appropriate dashboard based on role
  void _navigateToDashboard(String pdhRole) {
    if (!mounted) {
      return;
    }

    try {
      if (pdhRole == 'PDH - Employee') {
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      } else if (pdhRole == 'PDH - Admin') {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else if (pdhRole == 'PDH - Manager') {
        Navigator.pushReplacementNamed(context, '/manager_portal');
      } else {
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      }
    } catch (e) {}
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
                  image: AssetImage(_backgroundAsset),
                  fit: BoxFit.cover,
                  colorFilter: _isLightMode
                      ? null
                      : ColorFilter.mode(
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
              circleColor: (_isLightMode
                      ? Colors.black
                      : const Color(0xFFC10D00))
                  .withValues(alpha: 0.7),
              numberOfParticles: 20,
              maxParticleSize: 6.0,
            ),
          ),

          // Content overlay
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, -0.08),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),

                    // KHONdemy logo (matches screenshot)
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          _animationKey.currentState
                              ?.triggerParticleExplosion();
                        },
                        child: Image.asset(
                          'assets/khono.png',
                          height: 115,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    Text(
                      'Personal Development Hub',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _solidTextColor,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'Empower growth through purposeful, role-aligned development pathways.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: _subtitleColor,
                        fontFamily: 'Poppins',
                        height: 1.35,
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (!_isCheckingToken) ...[
                      ElevatedButton(
                        onPressed: _handleGetStarted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 38,
                            vertical: 14,
                          ),
                          shape: const StadiumBorder(),
                          elevation: 4,
                        ),
                        child: const Text(
                          'GET STARTED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Image.asset(
                        _isLightMode
                            ? 'assets/Red_Khono_Discs.png'
                            : 'assets/discs.png',
                        height: 42,
                        fit: BoxFit.contain,
                      ),
                    ] else ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFC10D00),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Logging in...',
                        style: TextStyle(
                          color: _isLightMode ? Colors.black : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                              color: _solidTextColor.withAlpha(128),
                            ),
                            filled: true,
                            fillColor: _isLightMode
                                ? Colors.white.withAlpha(220)
                                : Colors.white.withAlpha(26),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _solidTextColor.withAlpha(51),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _solidTextColor.withAlpha(51),
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
                              color: _solidTextColor.withAlpha(179),
                            ),
                          ),
                          style: TextStyle(
                            color: _solidTextColor,
                            fontSize: 16,
                          ),
                          obscureText: false,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Info text: tell user to get token from KhonoBuzz
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          'Go back to KhonoBuzz and copy your login link, then paste it above. '
                          'The app will sign you in automatically.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _solidTextColor.withAlpha(204),
                            fontSize: 13,
                            height: 1.35,
                          ),
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
                  ],
                ),
              ),
            ),
          ),

          // Version control text: bottom-left in both themes.
          Positioned(
            bottom: 18,
            left: 14,
            child: VersionControlWidget(
              fontSize: 12,
              textColor: _isLightMode ? Colors.black : Colors.white,
              hoverColor: _isLightMode ? Colors.black : Colors.white,
            ),
          ),

        ],
      ),
    );
  }
}
