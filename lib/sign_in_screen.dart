// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';
import 'dart:ui'; // Import for ImageFilter

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:pdh/services/role_service.dart'; // Add RoleService import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:pdh/services/badge_service.dart';

// The main entry point for the Flutter application.
// void main() {
//   runApp(const MyApp());
// }

// A StatelessWidget that sets up the MaterialApp.
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Personal Development Hub',
//       theme: ThemeData(
//         brightness: Brightness.dark,
//         primarySwatch: Colors.blue,
//         fontFamily: 'Inter',
//       ),
//       home: const LoginScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

// The main screen widget for the Personal Development Hub login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSigningIn = false;

  final microsoftProvider = MicrosoftAuthProvider();
  final githubProvider = GithubAuthProvider();

  // Using FirebaseAuth OAuth providers across platforms

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Helper function to handle post-login navigation
  Future<void> _handlePostLoginNavigation(BuildContext context) async {
    if (!context.mounted) return;

    try {
      // Get user's role from database and ensure it's cached
      final role = await RoleService.instance.getRole(refresh: true);

      if (!context.mounted) return;

      String? currentRole = role;
      final user = FirebaseAuth.instance.currentUser;

      if (user != null && currentRole == null) {
        // User is authenticated but has no role yet, assign default 'employee' role
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'role': 'employee'},
          SetOptions(merge: true), // Merge with existing data
        );
        currentRole = 'employee'; // Update currentRole to employee
        // Refresh the cached role in RoleService
        await RoleService.instance.getRole(refresh: true);
      }

      if (!context.mounted) return;

      // Before navigating, ensure badges are up to date for this session
      if (user != null) {
        await BadgeService.checkAndAwardBadges(user.uid);
      }

      // User already has a role, redirect to appropriate portal
      if (currentRole == 'manager') {
        Navigator.pushReplacementNamed(context, '/manager_portal');
      } else if (currentRole == 'employee') {
        // Route employees directly to the dashboard
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      } else {
        // Unknown role or no role selected, redirect to sign in as fallback
        Navigator.pushReplacementNamed(
          context,
          '/employee_dashboard',
        ); // Default to employee dashboard
      }
    } catch (e) {
      // If there's an error getting the role, redirect to sign in as fallback
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/employee_dashboard',
      ); // Default to employee dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Dark galaxy swirl background
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.3),
                BlendMode.darken,
              ),
              child: Image.asset(
                'assets/khono_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Main content with standalone top logo
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Image.asset(
                    'assets/khono.png',
                    height: 160, // match Get Started page
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 500),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Welcome Back headline
                              const Text(
                                'Welcome Back',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Subtitle
                              Text(
                                'Sign in to continue your growth journey',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withOpacity(0.8),
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              const SizedBox(height: 40),
                              // Email input field
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                                  child: TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.black.withOpacity(0.3),
                                      hintText: 'Email',
                                      hintStyle: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontFamily: 'Poppins',
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1.0,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFC10D00),
                                          width: 2.0,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Poppins',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      final emailPattern = RegExp(
                                        r"^[^\s@]+@[^\s@]+\.[^\s@]+$",
                                      );
                                      if (!emailPattern.hasMatch(value)) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Password input field
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                                  child: TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.black.withOpacity(0.3),
                                      hintText: 'Password (leave blank if onboarding)',
                                      hintStyle: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        fontFamily: 'Poppins',
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.white.withOpacity(0.2),
                                          width: 1.0,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFC10D00),
                                          width: 2.0,
                                        ),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 16,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Poppins',
                                    ),
                                    validator: (value) {
                                      if (value != null &&
                                          value.isNotEmpty &&
                                          value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              // Primary Sign In button
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  color: const Color(0xFFC10D00),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFC10D00).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextButton(
                                  onPressed: _isSigningIn
                                      ? null
                                      : () async {
                                          if (!_formKey.currentState!.validate()) {
                                            return;
                                          }
                                          final rawEmail = _emailController.text.trim();
                                          final password = _passwordController.text;
                                          if (rawEmail.isEmpty) {
                                            await _showCenterNotice('Please enter your email.');
                                            return;
                                          }

                                          setState(() {
                                            _isSigningIn = true;
                                          });

                                          try {
                                            UserCredential? credential;

                                            if (password.isNotEmpty) {
                                              try {
                                                credential = await FirebaseAuth.instance
                                                    .signInWithEmailAndPassword(
                                                      email: rawEmail,
                                                      password: password,
                                                    );
                                              } on FirebaseAuthException catch (authError) {
                                                if (_shouldAttemptOnboardingFallback(authError.code)) {
                                                  credential = await _signInUsingOnboarding(rawEmail);
                                                  if (credential == null) {
                                                    return;
                                                  }
                                                } else {
                                                  await _showCenterNotice(
                                                    _mapAuthErrorMessage(authError),
                                                  );
                                                  return;
                                                }
                                              }
                                            } else {
                                              credential = await _signInUsingOnboarding(rawEmail);
                                              if (credential == null) {
                                                return;
                                              }
                                            }

                                            final userCredential = credential;
                                            final user = userCredential.user;
                                            if (user != null) {
                                              await _recordSuccessfulLogin(user);
                                              if (!mounted) return;
                                              await _handlePostLoginNavigation(context);
                                            }
                                          } on FirebaseAuthException catch (e) {
                                            await _showCenterNotice(_mapAuthErrorMessage(e));
                                          } catch (e) {
                                            if (!mounted) return;
                                            await _showCenterNotice('An unexpected error occurred: ${e.toString()}');
                                          } finally {
                                            if (mounted) {
                                              setState(() {
                                                _isSigningIn = false;
                                              });
                                            }
                                          }
                                        },
                                  child: _isSigningIn
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
                                          'SIGN IN',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            fontFamily: 'Poppins',
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              // Divider with "or" text
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      'or',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 14,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              // Google Sign In button
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: TextButton(
                                  onPressed: _isSigningIn
                                      ? null
                                      : () async {
                                          try {
                                            UserCredential cred;
                                            if (kIsWeb) {
                                              cred = await FirebaseAuth.instance
                                                  .signInWithPopup(
                                                    GoogleAuthProvider(),
                                                  );
                                            } else {
                                              cred = await FirebaseAuth.instance
                                                  .signInWithProvider(
                                                    GoogleAuthProvider(),
                                                  );
                                            }
                                            // Store lastLoginAt and record daily login activity
                                            final user = cred.user;
                                            if (user != null) {
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .set({
                                                    'lastLoginAt':
                                                        FieldValue.serverTimestamp(),
                                                  }, SetOptions(merge: true));
                                              try {
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(user.uid)
                                                    .collection('daily_activities')
                                                    .doc(
                                                      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                                                    )
                                                    .set({
                                                      'date':
                                                          FieldValue.serverTimestamp(),
                                                      'activities':
                                                          FieldValue.arrayUnion([
                                                            'login',
                                                          ]),
                                                      'createdAt':
                                                          FieldValue.serverTimestamp(),
                                                    }, SetOptions(merge: true));
                                              } catch (_) {}
                                            }
                                            if (!mounted) return;
                                            await _handlePostLoginNavigation(context);
                                          } on FirebaseAuthException catch (e) {
                                            String message =
                                                e.message ?? 'Google Sign-In failed.';
                                            if (e.code == 'popup-closed-by-user') {
                                              message =
                                                  'Popup closed before completing sign-in.';
                                            } else if (e.code ==
                                                'network-request-failed') {
                                              message =
                                                  'Network error. Check internet and authorized domains.';
                                            } else if (e.code ==
                                                'unauthorized-domain') {
                                              message =
                                                  'Unauthorized domain. Add your host to Firebase Auth domains.';
                                            }
                                            if (!mounted) return;
                                            await _showCenterNotice(message);
                                          } catch (e) {
                                            if (!mounted) return;
                                            await _showCenterNotice('An unexpected error occurred: ${e.toString()}');
                                          }
                                        },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/Google_Icon.png',
                                        height: 20.0,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Continue with Google',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Microsoft Sign In button
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: TextButton(
                                  onPressed: _isSigningIn
                                      ? null
                                      : () async {
                                          try {
                                            setState(() {
                                              _isSigningIn = true;
                                            });
                                            UserCredential cred;
                                            if (kIsWeb) {
                                              cred = await FirebaseAuth.instance
                                                  .signInWithPopup(microsoftProvider);
                                            } else {
                                              cred = await FirebaseAuth.instance
                                                  .signInWithProvider(
                                                    microsoftProvider,
                                                  );
                                            }
                                            final user = cred.user;
                                            if (user != null) {
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .set({
                                                    'lastLoginAt':
                                                        FieldValue.serverTimestamp(),
                                                  }, SetOptions(merge: true));
                                              try {
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(user.uid)
                                                    .collection('daily_activities')
                                                    .doc(
                                                      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                                                    )
                                                    .set({
                                                      'date':
                                                          FieldValue.serverTimestamp(),
                                                      'activities':
                                                          FieldValue.arrayUnion([
                                                            'login',
                                                          ]),
                                                      'createdAt':
                                                          FieldValue.serverTimestamp(),
                                                    }, SetOptions(merge: true));
                                              } catch (_) {}
                                            }
                                            if (!mounted) return;
                                            await _handlePostLoginNavigation(context);
                                          } on FirebaseAuthException catch (e) {
                                            setState(() {
                                              _isSigningIn = false;
                                            });
                                            String message =
                                                e.message ??
                                                'Microsoft Sign-In failed.';
                                            if (e.code == 'popup-closed-by-user') {
                                              message =
                                                  'Popup closed before completing sign-in.';
                                            } else if (e.code ==
                                                'network-request-failed') {
                                              message =
                                                  'Network error. Check internet and authorized domains.';
                                            } else if (e.code ==
                                                'unauthorized-domain') {
                                              message =
                                                  'Unauthorized domain. Add your host to Firebase Auth domains.';
                                            }
                                            if (!mounted) return;
                                            await _showCenterNotice(message);
                                          } catch (e) {
                                            setState(() {
                                              _isSigningIn = false;
                                            });
                                            if (!mounted) return;
                                            await _showCenterNotice('An unexpected error occurred: ${e.toString()}');
                                          }
                                        },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset('assets/mslogo.png', height: 20.0),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Continue with Microsoft',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // GitHub Sign In button
                              Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: TextButton(
                                  onPressed: _isSigningIn
                                      ? null
                                      : () async {
                                          try {
                                            UserCredential cred;
                                            if (kIsWeb) {
                                              cred = await FirebaseAuth.instance
                                                  .signInWithPopup(githubProvider);
                                            } else {
                                              cred = await FirebaseAuth.instance
                                                  .signInWithProvider(githubProvider);
                                            }
                                            final user = cred.user;
                                            if (user != null) {
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(user.uid)
                                                  .set({
                                                    'lastLoginAt':
                                                        FieldValue.serverTimestamp(),
                                                  }, SetOptions(merge: true));
                                              try {
                                                await FirebaseFirestore.instance
                                                    .collection('users')
                                                    .doc(user.uid)
                                                    .collection('daily_activities')
                                                    .doc(
                                                      '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                                                    )
                                                    .set({
                                                      'date':
                                                          FieldValue.serverTimestamp(),
                                                      'activities':
                                                          FieldValue.arrayUnion([
                                                            'login',
                                                          ]),
                                                      'createdAt':
                                                          FieldValue.serverTimestamp(),
                                                    }, SetOptions(merge: true));
                                              } catch (_) {}
                                            }
                                            if (!mounted) return;
                                            await _handlePostLoginNavigation(context);
                                          } on FirebaseAuthException catch (e) {
                                            String message =
                                                e.message ?? 'GitHub Sign-In failed.';
                                            if (e.code == 'popup-closed-by-user') {
                                              message =
                                                  'Popup closed before completing sign-in.';
                                            } else if (e.code ==
                                                'network-request-failed') {
                                              message =
                                                  'Network error. Check internet and authorized domains.';
                                            } else if (e.code ==
                                                'unauthorized-domain') {
                                              message =
                                                  'Unauthorized domain. Add your host to Firebase Auth domains.';
                                            }
                                            if (!mounted) return;
                                            await _showCenterNotice(message);
                                          } catch (e) {
                                            if (!mounted) return;
                                            await _showCenterNotice('An unexpected error occurred: ${e.toString()}');
                                          }
                                        },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/github_icon_2.png',
                                        height: 20.0,
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'Continue with GitHub',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          fontFamily: 'Poppins',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 30),
                              // Register link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/register');
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                              child: const Text(
                                'SIGN UP',
                                      style: TextStyle(
                                        color: Color(0xFFC10D00),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Poppins',
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordSuccessfulLogin(User user) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final now = DateTime.now();
    final dayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_activities')
          .doc(dayKey)
          .set({
        'date': FieldValue.serverTimestamp(),
        'activities': FieldValue.arrayUnion(['login']),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  bool _shouldAttemptOnboardingFallback(String code) {
    return code == 'user-not-found' ||
        code == 'wrong-password' ||
        code == 'invalid-credential';
  }

  String _mapAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again or reset your password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again later.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }

  Future<UserCredential?> _signInUsingOnboarding(String email) async {
    final record = await _findOnboardingRecord(email);
    if (record == null) {
      await _showCenterNotice(
        'We could not find an onboarding record for that email. Please contact your administrator.',
      );
      return null;
    }

    final onboardingData = record.data() ?? <String, dynamic>{};
    final storedEmail = (onboardingData['email'] as String?)?.trim();
    final normalizedEmail =
        (storedEmail ?? email).trim().toLowerCase();
    final password = _generateOnboardingPassword(normalizedEmail);

    final auth = FirebaseAuth.instance;
    UserCredential credential;
    bool isNewUser = false;

    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      isNewUser = credential.additionalUserInfo?.isNewUser == true;
    } on FirebaseAuthException catch (createError) {
      if (createError.code == 'email-already-in-use') {
        try {
          credential = await auth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
          isNewUser = credential.additionalUserInfo?.isNewUser == true;
        } on FirebaseAuthException catch (signInError) {
          if (signInError.code == 'wrong-password') {
            await _showCenterNotice(
              'This account already has a password set. Please use your password or reset it.',
            );
            return null;
          }
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    final user = credential.user;
    if (user != null) {
      final userUpdates = <String, dynamic>{
        'email': normalizedEmail,
        'onboardedFrom': 'onboarding',
        'onboardedAt': FieldValue.serverTimestamp(),
        'onboardingRecordId': record.id,
      };

      final possibleName = onboardingData['fullName'] ??
          onboardingData['name'] ??
          onboardingData['displayName'];
      if (possibleName is String && possibleName.trim().isNotEmpty) {
        userUpdates['fullName'] = possibleName.trim();
      }

      final resolvedRole = _extractRoleFromOnboarding(onboardingData);
      if (resolvedRole != null) {
        userUpdates['role'] = resolvedRole;
      } else if (isNewUser) {
        userUpdates['role'] = 'employee';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userUpdates, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('onboarding').doc(record.id).set({
        'authUid': user.uid,
        'activated': true,
        'activatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return credential;
  }

  String? _extractRoleFromOnboarding(Map<String, dynamic> data) {
    const managerKeywords = {
      'manager',
      'admin',
      'administrator',
      'leader',
      'supervisor',
      'coach',
      'teamlead',
      'team lead',
      'lead',
      'executive',
      'director',
    };

    const employeeKeywords = {
      'employee',
      'staff',
      'associate',
      'member',
      'individual',
      'participant',
      'user',
      'teammate',
    };

    const roleFieldCandidates = {
      'role',
      'Role',
      'persona',
      'Persona',
      'userType',
      'user_type',
      'user-type',
      'accountType',
      'account_type',
      'account-type',
      'profileType',
      'profile_type',
      'profile',
      'position',
      'title',
      'designation',
      'jobRole',
      'job_role',
      'job-role',
      'accessLevel',
      'access_level',
      'access-level',
      'membership',
      'category',
      'type',
    };

    String? matchFromString(String value) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      if (managerKeywords.any(normalized.contains)) return 'manager';
      if (employeeKeywords.any(normalized.contains)) return 'employee';
      return null;
    }

    for (final key in roleFieldCandidates) {
      final raw = data[key];
      if (raw is String) {
        final matched = matchFromString(raw);
        if (matched != null) return matched;
      } else if (raw is List) {
        for (final element in raw) {
          if (element is String) {
            final matched = matchFromString(element);
            if (matched != null) return matched;
          }
        }
      }
    }

    final boolFieldCandidates = {
      'isManager',
      'is_manager',
      'manager',
      'managerFlag',
      'manager_flag',
      'isLeader',
      'isAdmin',
      'hasManagerAccess',
      'managerAccess',
      'manager_access',
    };

    for (final key in boolFieldCandidates) {
      final raw = data[key];
      if (raw is bool) {
        if (raw) return 'manager';
      } else if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true' || normalized == 'yes') {
          return 'manager';
        }
      }
    }

    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findOnboardingRecord(
    String email,
  ) async {
    final onboardingCollection =
        FirebaseFirestore.instance.collection('onboarding');
    final trimmedEmail = email.trim();
    final normalizedEmail = trimmedEmail.toLowerCase();

    final fieldCandidates = <String>{
      'email',
      'emailLowercase',
      'email_lowercase',
      'emailaddress',
      'emailAddress',
      'email_address',
      'Email',
      'EmailAddress',
      'Email_Address',
      'primaryEmail',
      'primary_email',
      'workEmail',
      'work_email',
    };

    final valueCandidates = <String>{
      trimmedEmail,
      normalizedEmail,
    };

    for (final field in fieldCandidates) {
      for (final value in valueCandidates) {
        try {
          final snap = await onboardingCollection
              .where(field, isEqualTo: value)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            return snap.docs.first;
          }
        } on FirebaseException {
          // Ignore and continue trying other fields
        }
      }
    }

    final arrayFields = <String>{
      'emails',
      'lookupEmails',
      'lookup_emails',
      'alternateEmails',
      'alternate_emails',
      'lookupKeys',
      'lookup_keys',
    };

    for (final field in arrayFields) {
      for (final value in valueCandidates) {
        try {
          final snap = await onboardingCollection
              .where(field, arrayContains: value)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            return snap.docs.first;
          }
        } on FirebaseException {
          // Ignore and continue trying other array fields
        }
      }
    }

    final docIdCandidates = <String>{
      normalizedEmail,
      trimmedEmail,
      normalizedEmail.replaceAll('.', '_'),
      normalizedEmail.replaceAll('@', '_'),
    };

    for (final candidate in docIdCandidates) {
      try {
        final doc = await onboardingCollection.doc(candidate).get();
        if (doc.exists) {
          return doc;
        }
      } catch (_) {}
    }

    try {
      final sample = await onboardingCollection.limit(200).get();
      for (final doc in sample.docs) {
        final data = doc.data();
        for (final entry in data.entries) {
          final value = entry.value;
          if (value is String) {
            final normalizedValue = value.trim().toLowerCase();
            if (valueCandidates.contains(value.trim()) ||
                normalizedValue == normalizedEmail) {
              return doc;
            }
          } else if (value is List) {
            for (final element in value) {
              if (element is String) {
                final normalizedValue = element.trim().toLowerCase();
                if (valueCandidates.contains(element.trim()) ||
                    normalizedValue == normalizedEmail) {
                  return doc;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  String _generateOnboardingPassword(String email) {
    final normalized = email.trim().toLowerCase();
    final encoded = base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
    final buffer = StringBuffer('OnB@');
    if (encoded.length >= 10) {
      buffer.write(encoded.substring(0, 10));
    } else {
      buffer.write(encoded.padRight(10, 'A'));
    }
    buffer.write('!');
    return buffer.toString();
  }

  Future<void> _showCenterNotice(String message) async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFC10D00)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFC10D00)),
              ),
            ),
          ],
        );
      },
    );
  }
}
