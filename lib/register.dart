// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
// import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore - Removed as DatabaseService handles it
import 'package:pdh/services/database_service.dart'; // Import DatabaseService
import 'dart:async'; // Import for Timer

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
  String? _selectedRole; // New: Variable to store selected role
  // Removed unused _formKey
  // Removed unused _passwordStrength
  // Removed unused _passwordStrengthColor

  List<String> _fullNameHints = [];
  List<String> _usernameHints = [];
  List<String> _emailHints = [];
  List<String> _passwordHints = [];
  List<String> _confirmPasswordHints = [];

  int _currentHintIndex = 0;
  late Timer _hintTimer;

  @override
  void initState() {
    super.initState();
    _fullNameHints = List.generate(20, (index) => 'Enter your full name ${index + 1}');
    _usernameHints = List.generate(20, (index) => 'Choose a username ${index + 1}');
    _emailHints = List.generate(20, (index) => 'Your email address ${index + 1}');
    _passwordHints = List.generate(20, (index) => 'Create a password ${index + 1}');
    _confirmPasswordHints = List.generate(20, (index) => 'Confirm your password ${index + 1}');

    _hintTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        _currentHintIndex = (_currentHintIndex + 1) % 20;
      });
    });
  }

  @override
  void dispose() {
    _hintTimer.cancel();
    // Clean up the controllers when the widget is disposed.
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Removed _updatePasswordStrength method

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
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
              child: Image.asset(
                'assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Overlay for subtle gradient effect and content
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                // No longer applying gradient colors or blur
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(left: 40.0, right: 40.0, top: 80.0, bottom: 40.0), // Adjust padding for better layout
                  child: Form(
                    // Removed key: _formKey
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start, // Align content to the start (top)
                      crossAxisAlignment: CrossAxisAlignment.start, // Left-align text labels
                      children: [
                        const Text(
                          'Create Your Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 50), // Space after title
                        // Full Name
                        _buildFieldLabel('Full Name'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _fullNameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                          hintText: _fullNameHints[_currentHintIndex],
                        ),
                        const SizedBox(height: 20),
                        // Username
                        _buildFieldLabel('Username'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _usernameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a username';
                            }
                            return null;
                          },
                          hintText: _usernameHints[_currentHintIndex],
                        ),
                        const SizedBox(height: 20),
                        // Email Address
                        _buildFieldLabel('Email Address'),
                        const SizedBox(height: 8),
                        _buildTextField(
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
                          hintText: _emailHints[_currentHintIndex],
                        ),
                        const SizedBox(height: 20),
                        // Password
                        _buildFieldLabel('Password'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _passwordController,
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.length < 8) {
                              return 'Password must be at least 8 characters long';
                            }
                            return null;
                          },
                          hintText: _passwordHints[_currentHintIndex],
                        ),
                        const SizedBox(height: 20),
                        // Confirm Password
                        _buildFieldLabel('Confirm Password'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          hintText: _confirmPasswordHints[_currentHintIndex],
                        ),
                        const SizedBox(height: 20),
                        // Role Selection Dropdown
                        _buildFieldLabel('Role'),
                        const SizedBox(height: 8),
                        _buildRoleDropdown(),
                        const SizedBox(height: 30),
                        // Sign Up Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: ShapeDecoration(
                            shape: const StadiumBorder(),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFC10D00), Color(0xFFC10D00)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                          ),
                          child: TextButton(
                            onPressed: () async {
                              if (_fullNameController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter your full name.')),
                                );
                                return;
                              }
                              if (_usernameController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a username.')),
                                );
                                return;
                              }
                              if (_emailController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter your email.')),
                                );
                                return;
                              }
                              if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(_emailController.text)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please enter a valid email address.')),
                                );
                                return;
                              }
                              if (_passwordController.text.length < 8) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password must be at least 8 characters long.')),
                                );
                                return;
                              }
                              if (_passwordController.text != _confirmPasswordController.text) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Passwords do not match.')),
                                );
                                return;
                              }
                              if (_selectedRole == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please select a role.')),
                                );
                                return;
                              }

                              try {
                                UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                  email: _emailController.text,
                                  password: _passwordController.text,
                                );
                                // Store additional user data in Firestore
                                // Removed direct Firestore set call; using DatabaseService.initializeUserData instead
                                await DatabaseService.initializeUserData(
                                  userCredential.user!.uid,
                                  _fullNameController.text,
                                  _emailController.text,
                                  role: _selectedRole!, // Use the selected role
                                );

                                if (!context.mounted) return; // Guard against context use after async gap
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Registration Successful!')),
                                );
                                if (!context.mounted) return; // Guard against context use after async gap
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
                                if (!context.mounted) return; // Guard against context use after async gap
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              } catch (e) {
                                if (!context.mounted) return; // Guard against context use after async gap
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('An unexpected error occurred: ${e.toString()}')),
                                );
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

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFC10D00),
        fontSize: 16,
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
  Widget _buildTextField({
    TextEditingController? controller,
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    required String hintText, // Add hintText parameter
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: _inputDecoration().copyWith(
            hintText: hintText, // Use the dynamic hintText
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)), // Hint text style
          ),
          style: const TextStyle(color: Colors.white),
          validator: validator,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: DropdownButtonFormField<String>(
          value: _selectedRole,
          decoration: _inputDecoration().copyWith(
            hintText: 'Select your role',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          dropdownColor: const Color(0x880A0F1F), // Darker background for dropdown
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'), // Apply Poppins to selected item
          items: <String>['employee', 'manager'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value == 'employee' ? 'Employee' : 'Manager',
                style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'), // Apply Poppins to dropdown items
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedRole = newValue;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a role';
            }
            return null;
          },
        ),
      ),
    );
  }
}
