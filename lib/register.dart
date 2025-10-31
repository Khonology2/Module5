// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore for blocklist
import 'package:pdh/services/badge_service.dart';
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
  String? _selectedRole;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  double _passwordStrength = 0.0;
  Color _passwordStrengthColor = Colors.grey;
  String _passwordHint = '';
  bool _isRegistering = false;

  late Timer _hintTimer;

  @override
  void initState() {
    super.initState();
    // Timer retained to keep structure minimal though hints are static now
    _hintTimer = Timer(const Duration(milliseconds: 1), () {});
  }

  @override
  void dispose() {
    try { _hintTimer.cancel(); } catch (_) {}
    // Clean up the controllers when the widget is disposed.
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength(String password) {
    setState(() {
      _passwordStrength = 0.0;
      _passwordStrengthColor = Colors.grey;
      _passwordHint = '';

      if (password.isEmpty) {
        _passwordStrength = 0.0;
        _passwordStrengthColor = Colors.grey;
        _passwordHint = 'Please enter a password';
        return;
      }

      // Criteria for password strength
      bool hasMinLength = password.length >= 8;
      bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
      bool hasLowercase = password.contains(RegExp(r'[a-z]'));
      bool hasDigit = password.contains(RegExp(r'[0-9]'));
      bool hasSpecialChar = password.contains(
        RegExp(r'[!@#$%^&*(),.?\":{}|<>] '),
      );

      int strengthScore = 0;
      if (hasMinLength) strengthScore++;
      if (hasUppercase) strengthScore++;
      if (hasLowercase) strengthScore++;
      if (hasDigit) strengthScore++;
      if (hasSpecialChar) strengthScore++;

      // Determine strength and color
      if (strengthScore == 0) {
        _passwordStrength = 0.0;
        _passwordStrengthColor = Colors.grey;
        _passwordHint = 'Enter password';
      } else if (strengthScore == 1) {
        _passwordStrength = 0.2;
        _passwordStrengthColor = Colors.red;
        _passwordHint = 'Weak: Add more characters, numbers, and symbols';
      } else if (strengthScore == 2) {
        _passwordStrength = 0.4;
        _passwordStrengthColor = Colors.orange;
        _passwordHint =
            'Moderate: Try to include uppercase and special characters';
      } else if (strengthScore == 3) {
        _passwordStrength = 0.6;
        _passwordStrengthColor = Colors.yellow;
        _passwordHint = 'Good: Almost there! Consider adding more variety';
      } else if (strengthScore == 4) {
        _passwordStrength = 0.8;
        _passwordStrengthColor = Colors.lightGreen;
        _passwordHint = 'Strong: Excellent password!';
      } else if (strengthScore == 5) {
        _passwordStrength = 1.0;
        _passwordStrengthColor = Colors.green;
        _passwordHint = 'Very Strong: Great job!';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Transparent status bar
        systemNavigationBarColor:
            Colors.transparent, // Transparent navigation bar
        statusBarIconBrightness: Brightness.light, // For dark status bar icons
        systemNavigationBarIconBrightness:
            Brightness.light, // For dark navigation bar icons
      ),
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.4),
                BlendMode.darken,
              ),
              child: Image.asset(
                'assets/khono_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: Column(
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Image.asset(
                    'assets/khono.png',
                    height: 160,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 12),
                // Centered back button image under logo
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/sign_in');
                    },
                    child: Image.asset(
                      'assets/TikTok Social/BackButton-Red.png',
                      height: 48,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 500),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text(
                              'Create Your Account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 40),
                            _buildTextField(
                              controller: _fullNameController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your full name';
                                }
                                return null;
                              },
                              hintText: 'Full name',
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _usernameController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a username';
                                }
                                return null;
                              },
                              hintText: 'Username',
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _emailController,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(
                                  r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                                ).hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                              hintText: 'Email',
                            ),
                            const SizedBox(height: 20),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                                child: TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: _inputDecoration().copyWith(
                                    hintText: 'Password',
                                    suffixIcon: IconButton(
                                      icon: Image.asset(
                                        'assets/Concentration_Key_Focus/eye.png',
                                        width: 22,
                                        height: 22,
                                        filterQuality: FilterQuality.high,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Poppins',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.length < 8) {
                                      return 'Password must be at least 8 characters long';
                                    }
                                    return null;
                                  },
                                  onChanged: _updatePasswordStrength,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: _passwordStrength,
                              backgroundColor: Colors.white24,
                              color: _passwordStrengthColor,
                              minHeight: 5,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _passwordHint,
                              style: TextStyle(
                                color: _passwordStrengthColor,
                                fontSize: 12,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(height: 20),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                                child: TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirmPassword,
                                  decoration: _inputDecoration().copyWith(
                                    hintText: 'Confirm password',
                                    suffixIcon: IconButton(
                                      icon: Image.asset(
                                        'assets/Concentration_Key_Focus/eye.png',
                                        width: 22,
                                        height: 22,
                                        filterQuality: FilterQuality.high,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword = !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Poppins',
                                  ),
                                  validator: (value) {
                                    if (value != _passwordController.text) {
                                      return 'Passwords do not match';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildRoleDropdown(),
                            const SizedBox(height: 30),
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
                            onPressed: _isRegistering ? null : () async {
                              if (_fullNameController.text.isEmpty) {
                                await _showCenterNotice('Please enter your full name.');
                                return;
                              }
                              if (_usernameController.text.isEmpty) {
                                await _showCenterNotice('Please enter a username.');
                                return;
                              }
                              if (_emailController.text.isEmpty) {
                                await _showCenterNotice('Please enter your email.');
                                return;
                              }
                              if (!RegExp(
                                r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                              ).hasMatch(_emailController.text)) {
                                await _showCenterNotice('Please enter a valid email address.');
                                return;
                              }
                              if (_passwordController.text.length < 8) {
                                await _showCenterNotice('Password must be at least 8 characters long.');
                                return;
                              }
                              if (_passwordController.text !=
                                  _confirmPasswordController.text) {
                                await _showCenterNotice('Passwords do not match.');
                                return;
                              }
                              if (_selectedRole == null) {
                                await _showCenterNotice('Please select a role.');
                                return;
                              }

                              // Enforce domain rule: Only emails ending with @khonodemy or @khonodemy.com
                              // can register as manager. Others must register as employee.
                              final String emailLower = _emailController.text
                                  .trim()
                                  .toLowerCase();
                              final bool isKhonodemyEmail =
                                  emailLower.endsWith('@khonodemy') ||
                                  emailLower.endsWith('@khonodemy.com');
                              if (_selectedRole == 'manager' &&
                                  !isKhonodemyEmail) {
                                await _showManagerRestrictionDialog(context);
                                return; // Stop submission; user must adjust role
                              }

                              setState(() { _isRegistering = true; });
                              _showLoadingDialog();
                              try {
                                UserCredential userCredential =
                                    await FirebaseAuth.instance
                                        .createUserWithEmailAndPassword(
                                          email: _emailController.text,
                                          password: _passwordController.text,
                                        );
                                // Post-auth blocklist check; if blocked, delete the just-created user and stop
                                try {
                                  final emailLower = _emailController.text.trim().toLowerCase();
                                  final blocked = await FirebaseFirestore.instance
                                      .collection('deleted_accounts')
                                      .where('emailLower', isEqualTo: emailLower)
                                      .limit(1)
                                      .get();
                                  if (blocked.docs.isNotEmpty) {
                                    try { await userCredential.user?.delete(); } catch (_) {}
                                    try { await FirebaseAuth.instance.signOut(); } catch (_) {}
                                    if (!context.mounted) return;
                                    await _showCenterNotice('This email was permanently deleted and cannot be used to register.');
                                    return;
                                  }
                                } catch (_) {
                                  // Ignore errors here; inability to read blocklist should not break registration
                                }
                                // Store additional user data in Firestore
                                // Removed direct Firestore set call; using DatabaseService.initializeUserData instead
                                await DatabaseService.initializeUserData(
                                  userCredential.user!.uid,
                                  _fullNameController.text,
                                  _emailController.text,
                                  role: _selectedRole!, // Use the selected role
                                );

                                // Initialize default badges and run initial check
                                await BadgeService.initializeUserBadges(
                                  userCredential.user!.uid,
                                );
                                await BadgeService.checkAndAwardBadges(
                                  userCredential.user!.uid,
                                );

                                if (!context.mounted) {
                                  return; // Guard against context use after async gap
                                }
                                Navigator.of(context, rootNavigator: true).maybePop();
                                setState(() { _isRegistering = false; });
                                await _showCenterNotice('Registration Successful!');
                                if (!context.mounted) {
                                  return; // Guard against context use after async gap
                                }
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/sign_in',
                                );
                              } on FirebaseAuthException catch (e) {
                                String message;
                                if (e.code == 'weak-password') {
                                  message =
                                      'The password provided is too weak.';
                                } else if (e.code == 'email-already-in-use') {
                                  message =
                                      'The account already exists for that email.';
                                } else {
                                  message =
                                      e.message ?? 'An unknown error occurred.';
                                }
                                if (!context.mounted) {
                                  return; // Guard against context use after async gap
                                }
                                Navigator.of(context, rootNavigator: true).maybePop();
                                setState(() { _isRegistering = false; });
                                await _showCenterNotice(message);
                              } catch (e) {
                                if (!context.mounted) {
                                  return; // Guard against context use after async gap
                                }
                                Navigator.of(context, rootNavigator: true).maybePop();
                                setState(() { _isRegistering = false; });
                                await _showCenterNotice('An unexpected error occurred: ${e.toString()}');
                              }
                            },
                                child: _isRegistering
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'SIGN UP',
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
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacementNamed(context, '/sign_in');
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'SIGN IN',
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
                          ],
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

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(color: Color(0xFFC10D00), fontSize: 16),
    );
  }

  // Helper function to create the input decoration for text fields.
  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.black.withOpacity(0.3),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: _inputDecoration().copyWith(
            hintText: hintText,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Poppins',
          ),
          validator: validator,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: DropdownButtonFormField<String>(
          value: _selectedRole,
          decoration: _inputDecoration().copyWith(
            hintText: 'Select your role',
          ),
          dropdownColor: const Color(
            0x880A0F1F,
          ), // Darker background for dropdown
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
          ), // Apply Poppins to selected item
          items: <String>['employee', 'manager'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value == 'employee' ? 'Employee' : 'Manager',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                ), // Apply Poppins to dropdown items
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

  Future<void> _showManagerRestrictionDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: const [
              Icon(Icons.lock_outline, color: Color(0xFFC10D00)),
              SizedBox(width: 8),
              Text('Access restricted', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'Manager sign-up requires a verified company email.\n\nPlease continue as Employee to proceed.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
              ),
              onPressed: () {
                setState(() {
                  _selectedRole = 'employee';
                });
                Navigator.of(dialogContext).pop();
                _showCenterNotice(
                  'Continuing as Employee. You can proceed to sign up.',
                );
              },
              child: const Text('Continue as Employee'),
            ),
          ],
        );
      },
    );
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

  void _showLoadingDialog() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: const [
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Creating your account...',
                  style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
