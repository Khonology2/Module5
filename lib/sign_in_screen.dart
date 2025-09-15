// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:flutter/foundation.dart' show kIsWeb; // For platform detection

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

  // Using FirebaseAuth OAuth providers across platforms

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user != null) {
        Navigator.pushReplacementNamed(context, '/rolebaseview');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // _checkRedirectResult(); // This line is removed as per the edit hint.
    }
  }

  // Future<void> _checkRedirectResult() async { // This method is removed as per the edit hint.
  //   try {
  //     // ignore: unnecessary_nullable_for_final_variable_declarations
  //     final UserCredential? userCredential = await FirebaseAuth.instance.getRedirectResult();
  //     if (userCredential != null && userCredential.user != null) {
  //       if (!mounted) return;
  //       Navigator.pushReplacementNamed(context, '/dashboard');
  //     }
  //   } on FirebaseAuthException catch (e) {
  //     String message = e.message ?? 'Authentication failed after redirect.';
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text(message)),
  //     );
  //   } catch (e) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
  //     );
  //   }
  // }

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
          // Overlay for gradient effect and content (optional, can be removed if not desired)
          Positioned.fill(
            // Ensure the overlay covers the whole screen
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 5.0,
                sigmaY: 5.0,
              ), // Apply stronger blur effect
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
                                        if (!RegExp(
                                          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\\.[a-zA-Z]+",
                                        ).hasMatch(value)) {
                                          return 'Please enter a valid email';
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
                                        Color(0xFF6B4EE8),
                                        Color(0xFF48A6ED),
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
                                        Color(0xFF6B4EE8),
                                        Color(0xFF48A6ED),
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
                                                Navigator.pushReplacementNamed(
                                                  context,
                                                  '/rolebaseview',
                                                );
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
                                              Navigator.pushReplacementNamed(
                                                context,
                                                '/rolebaseview',
                                              );
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
                                          'assets/goog.jpeg',
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
                                    color: Colors.blue,
                                  ),
                                  child: TextButton(
                                    onPressed: _isSigningIn
                                        ? null
                                        : () async {
                                            try {
                                              setState(() {
                                                _isSigningIn = true;
                                              });
                                              final microsoftProvider =
                                                  MicrosoftAuthProvider();
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
                                              Navigator.pushReplacementNamed(
                                                context,
                                                '/rolebaseview',
                                              );
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
                                          color: Color(0xFF48A6ED),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> _signInWithPhoneAuthCredential(
    PhoneAuthCredential credential,
  ) async {
    setState(() {
      _isSigningIn = true;
    });
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/rolebaseview');
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      setState(() {
        _isSigningIn = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
        ),
      );
    }
  }
}
