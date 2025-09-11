import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore

// The registration screen widget.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double _passwordStrength = 0.0;
  Color _passwordStrengthColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    // Add a listener to the password controller to update the strength meter.
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    // Clean up the controllers when the widget is disposed.
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Method to calculate and update the password strength meter.
  void _updatePasswordStrength() {
    final password = _passwordController.text;
    double strength = 0.0;
    Color color = Colors.red;

    if (password.isNotEmpty) {
      if (password.length >= 8) {
        strength += 0.25;
      }
      if (RegExp(r'[a-z]').hasMatch(password) && RegExp(r'[A-Z]').hasMatch(password)) {
        strength += 0.25;
      }
      if (RegExp(r'[0-9]').hasMatch(password)) {
        strength += 0.25;
      }
      if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) {
        strength += 0.25;
      }
    }

    if (strength == 1.0) {
      color = Colors.green;
    } else if (strength >= 0.5) {
      color = Colors.orange;
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent status bar
      systemNavigationBarColor: Colors.transparent, // Transparent navigation bar
      statusBarIconBrightness: Brightness.light, // For dark status bar icons
      systemNavigationBarIconBrightness: Brightness.light, // For dark navigation bar icons
    ));

    return Scaffold(
      extendBody: true, // Allows the body to extend behind the bottom navigation bar
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/hillyxyz_Generate_a_background_image_for_a_personal_development_app._Theme_e3acd3c0-0b7d-4207-920f-391ae25d9690.png',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay for subtle gradient effect and content
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Apply stronger blur effect
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F), // More opaque semi-transparent overlay (alpha 0x88)
                      Color(0x88040610), // More opaque semi-transparent overlay (alpha 0x88)
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 40.0, right: 40.0, top: 80.0, bottom: 40.0), // Adjust padding for better layout
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start, // Align content to the start (top)
                        crossAxisAlignment: CrossAxisAlignment.start, // Left-align text labels
                        children: [
                          const Text(
                            'Create Your Account',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC7E3FF),
                            ),
                          ),
                          const SizedBox(height: 50), // Space after title
                          // Full Name
                          const Text(
                            'Full Name',
                            style: TextStyle(
                              color: Color(0xFFC7E3FF),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildBlurredTextField(
                            controller: _fullNameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your full name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          // Username
                          const Text(
                            'Username',
                            style: TextStyle(
                              color: Color(0xFFC7E3FF),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildBlurredTextField(
                            controller: _usernameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a username';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          // Email Address
                          const Text(
                            'Email Address',
                            style: TextStyle(
                              color: Color(0xFFC7E3FF),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildBlurredTextField(
                            controller: _emailController,
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
                          const SizedBox(height: 20),
                          // Password
                          const Text(
                            'Password',
                            style: TextStyle(
                              color: Color(0xFFC7E3FF),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildBlurredTextField(
                            controller: _passwordController,
                            obscureText: true,
                            onChanged: (_) => _updatePasswordStrength(),
                            validator: (value) {
                              if (value == null || value.length < 8) {
                                return 'Password must be at least 8 characters long';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: _passwordStrength,
                            backgroundColor: const Color(0xFF1B2A40),
                            valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                          ),
                          const SizedBox(height: 20),
                          // Confirm Password
                          const Text(
                            'Confirm Password',
                            style: TextStyle(
                              color: Color(0xFFC7E3FF),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildBlurredTextField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 30),
                          // Sign Up Button
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
                              onPressed: () async {
                                if (_formKey.currentState!.validate()) {
                                  try {
                                    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                      email: _emailController.text,
                                      password: _passwordController.text,
                                    );
                                    // Store additional user data in Firestore
                                    await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
                                      'uid': userCredential.user!.uid,
                                      'email': _emailController.text,
                                      'username': _usernameController.text,
                                      'fullName': _fullNameController.text, // Use the new _fullNameController
                                      'createdAt': Timestamp.now(),
                                      'role': 'employee', // Default role
                                    });

                                    if (!mounted) return; // Guard against context use after async gap
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Registration Successful!')),
                                    );
                                    if (!mounted) return; // Guard against context use after async gap
                                    Navigator.pushReplacementNamed(context, '/sign_in');
                                  } on FirebaseAuthException catch (e) {
                                    String message;
                                    if (e.code == 'weak-password') {
                                      message = 'The password provided is too weak.';
                                    } else if (e.code == 'email-already-in-use') {
                                      message = 'The account already exists for that email.';
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
                                'Sign Up',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          // Removed SizedBox(height: 50)
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

// Helper function to create the input decoration for text fields.
  InputDecoration _inputDecoration() {
    return InputDecoration(
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
    );
  }

// Helper widget to build a blurred text field.
  Widget _buildBlurredTextField({
    TextEditingController? controller,
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: _inputDecoration(),
          style: const TextStyle(color: Colors.white),
          validator: validator,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
