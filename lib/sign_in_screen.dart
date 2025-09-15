// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:google_sign_in/google_sign_in.dart'; // Import Google Sign-In
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart'; // Import Facebook Auth

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

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  String? _verificationId;
  bool _codeSent = false;
  bool _isSigningIn = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn.standard();

  Future<void> _signInWithFacebook() async {
    setState(() {
      _isSigningIn = true;
    });
    try {
      final LoginResult result = await FacebookAuth.instance.login();

      if (result.status == LoginStatus.success) {
        final AccessToken? accessToken = result.accessToken;
        if (accessToken != null) {
          final AuthCredential credential = FacebookAuthProvider.credential(accessToken.token);
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/rolebaseview');
        }
      } else if (result.status == LoginStatus.cancelled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Facebook login cancelled.')),
        );
      } else if (result.status == LoginStatus.failed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Facebook login failed: ${result.message}')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firebase Auth with Facebook failed: ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
      );
    }
    setState(() {
      _isSigningIn = false;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

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
          Positioned.fill( // Ensure the overlay covers the whole screen
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Apply stronger blur effect
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
                      child: Column(
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
                          // Email Address
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
                              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                              child: TextFormField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withAlpha(25), // Semi-transparent white for blurred effect
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFC7E3FF), width: 1.0),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                style: const TextStyle(color: Colors.white),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
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
                              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                              child: TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withAlpha(25), // Semi-transparent white for blurred effect
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFC7E3FF), width: 1.0),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                style: const TextStyle(color: Colors.white),
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
                                colors: [Color(0xFF6B4EE8), Color(0xFF48A6ED)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            child: TextButton(
                              onPressed: _isSigningIn ? null : () async {
                                if (_formKey.currentState!.validate()) {
                                  try {
                                    await FirebaseAuth.instance.signInWithEmailAndPassword(
                                      email: _emailController.text,
                                      password: _passwordController.text,
                                    );
                                    if (!mounted) return;
                                    Navigator.pushReplacementNamed(context, '/rolebaseview');
                                  } on FirebaseAuthException catch (e) {
                                    String message;
                                    if (e.code == 'user-not-found') {
                                      message = 'No user found for that email.';
                                    } else if (e.code == 'wrong-password') {
                                      message = 'Wrong password provided for that user.';
                                    } else {
                                      message = e.message ?? 'An unknown error occurred.';
                                    }
                                    if (!mounted) return; // Guard against context use after async gap
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(message)),
                                    );
                                  } catch (e) {
                                    if (!mounted) return; // Guard against context use after async gap
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
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
                          const SizedBox(height: 20), // Add spacing after Sign In button
                          // Phone Number Input
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
                              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white.withAlpha(25),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFC7E3FF), width: 1.0),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                style: const TextStyle(color: Colors.white),
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
                                colors: [Color(0xFF6B4EE8), Color(0xFF48A6ED)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            child: TextButton(
                              onPressed: _isSigningIn ? null : () async {
                                if (_formKey.currentState!.validate()) {
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
                                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                child: TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white.withAlpha(25),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFFC7E3FF), width: 1.0),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  style: const TextStyle(color: Colors.white),
                                  onChanged: (value) {
                                    if (value.length == 6 && _verificationId != null) {
                                      _signInWithPhoneAuthCredential(
                                        PhoneAuthProvider.credential(
                                          verificationId: _verificationId!,
                                          smsCode: value,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white, // Google button background color
                            ),
                            child: TextButton(
                              onPressed: _isSigningIn ? null : () async {
                                try {
                                  GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
                                  if (googleUser == null) return; // User cancelled sign-in

                                  GoogleSignInAuthentication googleAuth = await googleUser.authentication;
                                  AuthCredential credential = GoogleAuthProvider.credential(
                                    accessToken: googleAuth.accessToken,
                                    idToken: googleAuth.idToken,
                                  );

                                  await FirebaseAuth.instance.signInWithCredential(credential);
                                  if (!mounted) return;
                                  Navigator.pushReplacementNamed(context, '/rolebaseview');
                                } on FirebaseAuthException catch (e) {
                                  String message = e.message ?? 'Google Sign-In failed.';
                                  if (!mounted) return; // Guard against context use after async gap
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(message)),
                                  );
                                } catch (e) {
                                  if (!mounted) return; // Guard against context use after async gap
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
                                  );
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/goog.jpeg', // Use the new Google logo asset
                                    height: 24.0,
                                  ),
                                  const SizedBox(width: 10),
                                  const Flexible( // Wrap text with Flexible to prevent overflow
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
                          // Microsoft Sign-In Button
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.blue, // Microsoft button background color
                            ),
                            child: TextButton(
                              onPressed: _isSigningIn ? null : () async {
                                try {
                                  setState(() {
                                    _isSigningIn = true;
                                  });
                                  final microsoftProvider = MicrosoftAuthProvider();
                                  await FirebaseAuth.instance.signInWithProvider(microsoftProvider);
                                  if (!mounted) return;
                                  Navigator.pushReplacementNamed(context, '/rolebaseview');
                                } on FirebaseAuthException catch (e) {
                                  setState(() {
                                    _isSigningIn = false;
                                  });
                                  String message = e.message ?? 'Microsoft Sign-In failed.';
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
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/soft_2.png', // Microsoft logo asset
                                    height: 24.0,
                                  ),
                                  // const SizedBox(width: 10),
                                  // const Flexible(
                                  //   child: Text(
                                  //     'Sign in with Microsoft',
                                  //     style: TextStyle(
                                  //       color: Colors.white,
                                  //       fontSize: 18,
                                  //       fontWeight: FontWeight.bold,
                                  //     ),
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Facebook Sign-In Button
                          Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFF1877F2), // Facebook brand color
                            ),
                            child: TextButton(
                              onPressed: _isSigningIn ? null : _signInWithFacebook,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.facebook, color: Colors.white, size: 24.0),
                                  const SizedBox(width: 10),
                                  const Flexible(
                                    child: Text(
                                      'Sign in with Facebook',
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
                                  Navigator.pushNamed(context, '/register');
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
