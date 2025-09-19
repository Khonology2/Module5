// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:pdh/services/role_service.dart'; // Add RoleService import
// Removed unused Google/Facebook/Firestore imports
import 'package:flutter/foundation.dart' show kIsWeb;

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

  final _phoneController = TextEditingController();
  String? _verificationId;
  bool _codeSent = false;
  bool _isSigningIn = false;

  final microsoftProvider = MicrosoftAuthProvider();

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
    _phoneController.dispose();
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
      
      if (role != null) {
        // User already has a role, redirect to appropriate portal
        if (role == 'manager') {
          Navigator.pushReplacementNamed(context, '/manager_portal');
        } else if (role == 'employee') {
          Navigator.pushReplacementNamed(context, '/employee_portal');
        } else {
          // Unknown role, redirect to role selection
          Navigator.pushReplacementNamed(context, '/rolebaseview');
        }
      } else {
        // User doesn't have a role yet, redirect to role selection
        Navigator.pushReplacementNamed(context, '/rolebaseview');
      }
    } catch (e) {
      // If there's an error getting the role, redirect to role selection as fallback
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/rolebaseview');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
              child: Image.asset(
                'assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay for gradient effect and content (optional, can be removed if not desired)
          Positioned.fill( // Ensure the overlay covers the whole screen
            child: Form(
              key: _formKey,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome Back!',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC7E3FF),
                          ),
                        ),
                        const SizedBox(height: 50),
                        const Text(
                          'Email Address',
                          style: TextStyle(
                            color: Color(0xFFC7E3FF),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 5.0,
                              sigmaY: 5.0,
                            ),
                            child: TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withAlpha(25),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    10,
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    10,
                                  ),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFC7E3FF),
                                    width: 1.0,
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                final emailPattern = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$");
                                if (!emailPattern.hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_codeSent) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Verification Code',
                            style: TextStyle(
                              color: Color(0xFFC7E3FF),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 5.0,
                                sigmaY: 5.0,
                              ),
                              child: TextFormField(
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withAlpha(25),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      10,
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      10,
                                    ),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFC7E3FF),
                                      width: 1.0,
                                    ),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                ),
                                onChanged: (value) {
                                  if (value.length == 6 &&
                                      _verificationId != null) {
                                    _signInWithPhoneAuthCredential(
                                      PhoneAuthProvider.credential(
                                        verificationId:
                                            _verificationId!,
                                        smsCode: value,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        const Text(
                          'Password',
                          style: TextStyle(
                            color: Color(0xFFC7E3FF),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 5.0,
                              sigmaY: 5.0,
                            ),
                            child: TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withAlpha(25),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    10,
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    10,
                                  ),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFC7E3FF),
                                    width: 1.0,
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFC10D00),
                                Color(0xFFC10D00),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: TextButton(
                            onPressed: _isSigningIn
                                ? null
                                : () async {
                                    if (_formKey.currentState!
                                        .validate()) {
                                      try {
                                        await FirebaseAuth.instance
                                            .signInWithEmailAndPassword(
                                              email:
                                                  _emailController.text,
                                              password:
                                                  _passwordController
                                                      .text,
                                            );
                                        if (!mounted) return;
                                        // Use the new navigation helper
                                        await _handlePostLoginNavigation(context);
                                      } on FirebaseAuthException catch (
                                        e
                                      ) {
                                        String message;
                                        if (e.code ==
                                            'user-not-found') {
                                          message =
                                              'No user found for that email.';
                                        } else if (e.code ==
                                            'wrong-password') {
                                          message =
                                              'Wrong password provided for that user.';
                                        } else {
                                          message =
                                              e.message ??
                                              'An unknown error occurred.';
                                        }
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(message),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'An unexpected error occurred: ${e.toString()}',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: const Text(
                              'Sign In',
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
                          'Phone Number (for SMS verification)',
                          style: TextStyle(
                            color: Color(0xFFC7E3FF),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 5.0,
                              sigmaY: 5.0,
                            ),
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white.withAlpha(25),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    10,
                                  ),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    10,
                                  ),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFC7E3FF),
                                    width: 1.0,
                                  ),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFC10D00),
                                Color(0xFFC10D00),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: TextButton(
                            onPressed: _isSigningIn
                                ? null
                                : () async {
                                    if (_formKey.currentState!
                                        .validate()) {
                                      _verifyPhoneNumber();
                                    }
                                  },
                            child: const Text(
                              'Send Code',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: TextButton(
                            onPressed: _isSigningIn
                                ? null
                                : () async {
                                    try {
                                      if (kIsWeb) {
                                        await FirebaseAuth.instance
                                            .signInWithPopup(
                                              GoogleAuthProvider(),
                                            );
                                      } else {
                                        await FirebaseAuth.instance
                                            .signInWithProvider(
                                              GoogleAuthProvider(),
                                            );
                                      }
                                      if (!mounted) return;
                                      // Use the new navigation helper
                                      await _handlePostLoginNavigation(context);
                                    } on FirebaseAuthException catch (
                                      e
                                    ) {
                                      String message =
                                          e.message ??
                                          'Google Sign-In failed.';
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(message),
                                        ),
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'An unexpected error occurred: ${e.toString()}',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/Google_Icon.png',
                                  height: 24.0,
                                ),
                                const SizedBox(width: 10),
                                const Flexible(
                                  child: Text(
                                    'Sign in with Google',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Color(0xFFC10D00),
                          ),
                          child: TextButton(
                            onPressed: _isSigningIn
                                ? null
                                : () async {
                                    try {
                                      setState(() {
                                        _isSigningIn = true;
                                      });
                                      if (kIsWeb) {
                                        await FirebaseAuth.instance
                                            .signInWithPopup(
                                              microsoftProvider,
                                            );
                                      } else {
                                        await FirebaseAuth.instance
                                            .signInWithProvider(
                                              microsoftProvider,
                                            );
                                      }
                                      if (!mounted) return;
                                      // Use the new navigation helper
                                      await _handlePostLoginNavigation(context);
                                    } on FirebaseAuthException catch (
                                      e
                                    ) {
                                      setState(() {
                                        _isSigningIn = false;
                                      });
                                      String message =
                                          e.message ??
                                          'Microsoft Sign-In failed.';
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(message),
                                        ),
                                      );
                                    } catch (e) {
                                      setState(() {
                                        _isSigningIn = false;
                                      });
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'An unexpected error occurred: ${e.toString()}',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  'assets/mslogo.png',
                                  height: 24.0,
                                ),
                                const SizedBox(width: 10),
                                const Flexible(
                                  child: Text(
                                    'Sign in with Microsoft',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have your account yet?",
                              style: TextStyle(
                                color: Color(0xFF8B9FB7),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 5),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/register',
                                );
                              },
                              child: const Text(
                                'Register Now?',
                                style: TextStyle(
                                  color: Color(0xFFC10D00),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
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

  void _verifyPhoneNumber() async {
    setState(() {
      _isSigningIn = true;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: _phoneController.text,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signInWithPhoneAuthCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          _isSigningIn = false;
        });
        String message;
        if (e.code == 'invalid-phone-number') {
          message = 'The provided phone number is not valid.';
        } else if (e.code == 'too-many-requests') {
          message = 'Too many requests. Please try again later.';
        } else if (e.code == 'missing-activity-for-recaptcha') {
          message = 'reCAPTCHA verification attempted with null Activity';
        } else {
          message = e.message ?? 'An unknown error occurred.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      },
      codeSent: (String verificationId, int? resendToken) async {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _isSigningIn = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent!')),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
        setState(() {
          _isSigningIn = false;
        });
      },
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _signInWithPhoneAuthCredential(PhoneAuthCredential credential) async {
    setState(() {
      _isSigningIn = true;
    });
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      // Use the new navigation helper
      await _handlePostLoginNavigation(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isSigningIn = false;
      });
      String message;
      if (e.code == 'invalid-verification-code') {
        message = 'The verification code entered was invalid.';
      } else if (e.code == 'invalid-credential') {
        message = 'The credential is invalid.';
      } else {
        message = e.message ?? 'An unknown error occurred.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      setState(() {
        _isSigningIn = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
      );
    }
  }
}
