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

          // Extract user info from decoded token (matches Khonobuzz JWT structure)
          // JWT payload contains: user_id, email, module_role, exp, iat
          final userInfo = TokenAuthService.instance.extractUserInfo(
            decodedToken,
          );
          if (userInfo != null) {
            email = userInfo['email'] as String?;
            final userId = userInfo['userId'] as String?;
            final moduleRole = userInfo['moduleRole'] as String?;
            debugPrint(
              'Landing screen: Extracted user info - email: $email, userId: $userId, moduleRole: $moduleRole',
            );
          } else {
            // Fallback: try to get email directly from token
            email =
                decodedToken['email'] as String? ??
                decodedToken['user_id'] as String?; // user_id might be email
          }

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
      // Try both encrypted token (as received) and decrypted JWT (if available)
      debugPrint(
        'Landing screen: Validating token with onboarding collection...',
      );
      debugPrint(
        'Landing screen: Using email from token: ${email ?? "not available"}',
      );

      // Try validating with the encrypted token first (as stored in database)
      Map<String, dynamic>? onboardingData = await TokenAuthService.instance
          .validateTokenWithOnboarding(token, email);

      // If that fails and we have a decrypted JWT, try with the decrypted token
      if (onboardingData == null && decodedToken != null) {
        debugPrint(
          'Landing screen: Trying validation with decrypted JWT token...',
        );
        // Get the decrypted JWT string from the processEncryptedToken result
        // We need to decrypt again to get the JWT string
        final decryptedJwt = await TokenAuthService.instance.decryptToken(
          token,
        );
        if (decryptedJwt != null) {
          onboardingData = await TokenAuthService.instance
              .validateTokenWithOnboarding(decryptedJwt, email);
        }
      }

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

      // Get user_id from onboarding data - this is the primary identifier
      // Email is optional and will be retrieved from users collection if available
      // Try multiple field names and use onboardingDocId as fallback
      final userId =
          onboardingData['user_id'] as String? ??
          onboardingData['userId'] as String? ??
          onboardingData['onboarding_id'] as String? ??
          onboardingData['onboardingDocId'] as String?;
      
      if (userId == null || userId.isEmpty) {
        debugPrint('Landing screen: Cannot proceed without user_id');
        debugPrint(
          'Landing screen: Onboarding data keys: ${onboardingData.keys.join(", ")}',
        );
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
          });
        }
        return;
      }
      
      debugPrint('Landing screen: User ID confirmed: $userId');
      
      // Try to get email from users collection (optional - for user document)
      final onboardingEmail = onboardingData['email'] as String?;
      if (onboardingEmail != null && onboardingEmail.isNotEmpty) {
        email = onboardingEmail.trim();
        debugPrint(
          'Landing screen: Email retrieved from onboarding data: $email',
        );
      } else {
        // Email is optional - we can proceed without it using user_id
        debugPrint('Landing screen: Email not found, but proceeding with user_id: $userId');
      }

      // Check user status - must be Active
      final status = onboardingData['status'] as String?;
      if (status != null && status != 'Active') {
        debugPrint(
          'Landing screen: User status is $status, not Active. Cannot proceed with login.',
        );
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
          });
        }
        return;
      }

      // Extract module role from JWT token or onboarding data
      final moduleAccessRole = TokenAuthService.instance.extractModuleRole(
        decodedToken,
        onboardingData,
      );

      if (moduleAccessRole == null) {
        debugPrint(
          'Landing screen: No module role found in token or onboarding data',
        );
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
          });
        }
        return;
      }

      debugPrint(
        'Landing screen: Token validated successfully. ModuleAccessRole: $moduleAccessRole',
      );
      debugPrint('Landing screen: User ID confirmed: $userId');

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

      // Step 6: Create or update user document in Firestore using user_id
      // This ensures the user exists in the users collection
      final userData = <String, dynamic>{
        'user_id': userId,
        'role': role,
        'tokenAuthenticated': true,
        'tokenAuthenticatedAt': FieldValue.serverTimestamp(),
      };
      
      // Add email if available (optional)
      if (email != null && email.isNotEmpty) {
        userData['email'] = email;
      }
      
      // Use user_id as the document ID
      await FirebaseFirestore.instance.collection('users').doc(userId).set(
        userData,
        SetOptions(merge: true),
      );
      
      debugPrint('Landing screen: User document created/updated in Firestore with user_id: $userId');

      // Step 7: Check if user is already logged in with Firebase Auth
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // User is already logged in, update role and navigate
        debugPrint(
          'Landing screen: User already logged in, updating role and redirecting...',
        );
        
        // Also update the Firebase Auth user's document if UID differs from user_id
        if (user.uid != userId) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'user_id': userId,
            'role': role,
            'tokenAuthenticated': true,
            'tokenAuthenticatedAt': FieldValue.serverTimestamp(),
            if (email != null && email.isNotEmpty) 'email': email,
          }, SetOptions(merge: true));
        }
        
        await RoleService.instance.getRole(refresh: true);

        if (mounted) {
          _navigateToDashboard(role);
          return;
        }
      } else {
        // User is not logged in with Firebase Auth
        // Since we're using user_id, we can proceed without Firebase Auth login
        // The user document is already created in Firestore above
        debugPrint(
          'Landing screen: User not logged in with Firebase Auth, but user document created. Proceeding with navigation...',
        );
        
        // Update role service with the role
        await RoleService.instance.getRole(refresh: true);
        
        if (mounted) {
          debugPrint('Landing screen: Redirecting to $role dashboard...');
          _navigateToDashboard(role);
          return;
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
