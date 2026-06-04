// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/services/database_service.dart'; // Import DatabaseService
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/onboarding_service.dart';
import 'package:pdh/services/role_service.dart'; // Import RoleService
import 'dart:async'; // Import for Timer
import 'package:pdh/widgets/custom_logo_loader.dart';

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
    try {
      _hintTimer.cancel();
    } catch (_) {}
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

  String _pdhRoleLabelForSelection(String role) {
    switch (role.trim().toLowerCase()) {
      case 'manager':
        return 'PDH - Manager';
      case 'admin':
        return 'PDH - Admin';
      case 'employee':
      default:
        return 'PDH - Employee';
    }
  }

  bool _isRoleStoredInUserRecord(Map<String, dynamic> userData, String role) {
    final raw = userData['role']?.toString().trim().toLowerCase();
    return raw == role.trim().toLowerCase();
  }

  bool _isRoleStoredInOnboarding(Map<String, dynamic> onboardingData, String role) {
    final normalized = role.trim().toLowerCase();
    final candidates = <String?>[
      onboardingData['moduleAccessRole']?.toString(),
      onboardingData['module_access_role']?.toString(),
      onboardingData['moduleRole']?.toString(),
      onboardingData['module_role']?.toString(),
      onboardingData['role']?.toString(),
    ];

    for (final candidate in candidates) {
      final persona = OnboardingService.extractPersonaForApp(candidate);
      if (persona == normalized) {
        return true;
      }
      final raw = candidate?.trim().toLowerCase();
      if (raw == null || raw.isEmpty) continue;
      if (normalized == 'manager' && raw.contains('manager')) return true;
      if (normalized == 'admin' && raw.contains('admin')) return true;
      if (normalized == 'employee' && raw.contains('employee')) return true;
    }
    return false;
  }

  Future<void> _ensureBackendRolePersisted({
    required String uid,
    required String email,
    required String displayName,
    required String role,
  }) async {
    final pdhRoleLabel = _pdhRoleLabelForSelection(role);

    for (var attempt = 0; attempt < 3; attempt++) {
      final userData = await BackendAuthService.instance.tryGetOnboarding(uid);
      Map<String, dynamic> onboardingData = userData;
      if (onboardingData.isEmpty && email.trim().isNotEmpty) {
        final matches = await OnboardingService.listOnboardingRecords(
          email: email.trim(),
          limit: 1,
        );
        if (matches.isNotEmpty) {
          onboardingData = matches.first;
        }
      }

      Map<String, dynamic> backendUser = {};
      try {
        backendUser = await BackendAuthService.instance.getUser(uid);
      } catch (_) {}

      final userRoleOk = backendUser.isNotEmpty &&
          _isRoleStoredInUserRecord(backendUser, role);
      final onboardingRoleOk = onboardingData.isNotEmpty &&
          _isRoleStoredInOnboarding(onboardingData, role);

      if (userRoleOk && onboardingRoleOk) {
        return;
      }

      await BackendAuthService.instance.updateUserProfile(uid, {
        'email': email,
        'displayName': displayName,
        'role': role,
      });
      await BackendAuthService.instance.updateOnboarding(uid, {
        'email': email,
        'displayName': displayName,
        'fullName': displayName,
        'role': pdhRoleLabel,
        'moduleAccessRole': pdhRoleLabel,
        'moduleRole': pdhRoleLabel,
        'status': 'Active',
      });

      await Future.delayed(const Duration(milliseconds: 250));
    }

    final finalUser = await BackendAuthService.instance.tryGetOnboarding(uid);
    final finalBackendUser = await BackendAuthService.instance.getUser(uid);
    final finalOnboardingOk =
        finalUser.isNotEmpty && _isRoleStoredInOnboarding(finalUser, role);
    final finalUserOk =
        finalBackendUser.isNotEmpty && _isRoleStoredInUserRecord(finalBackendUser, role);
    if (!finalUserOk || !finalOnboardingOk) {
      throw StateError('Backend role record was not persisted for the new account.');
    }
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
              child: Image.asset('assets/khono_bg.png', fit: BoxFit.cover),
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
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/sign_in');
                    },
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Image.asset(
                          'assets/BackButton-Red.png',
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
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
                                filter: ImageFilter.blur(
                                  sigmaX: 8.0,
                                  sigmaY: 8.0,
                                ),
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
                                filter: ImageFilter.blur(
                                  sigmaX: 8.0,
                                  sigmaY: 8.0,
                                ),
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
                                          _obscureConfirmPassword =
                                              !_obscureConfirmPassword;
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
                                    color: const Color(
                                      0xFFC10D00,
                                    ).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                onPressed: _isRegistering
                                    ? null
                                    : () async {
                              if (_fullNameController.text.isEmpty) {
                                          await _showCenterNotice(
                                            'Please enter your full name.',
                                          );
                                return;
                              }
                              if (_usernameController.text.isEmpty) {
                                          await _showCenterNotice(
                                            'Please enter a username.',
                                          );
                                return;
                              }
                              if (_emailController.text.isEmpty) {
                                          await _showCenterNotice(
                                            'Please enter your email.',
                                          );
                                return;
                              }
                              if (!RegExp(
                                r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                              ).hasMatch(_emailController.text)) {
                                          await _showCenterNotice(
                                            'Please enter a valid email address.',
                                          );
                                return;
                              }
                                        if (_passwordController.text.length <
                                            8) {
                                          await _showCenterNotice(
                                            'Password must be at least 8 characters long.',
                                          );
                                return;
                              }
                              if (_passwordController.text !=
                                  _confirmPasswordController.text) {
                                          await _showCenterNotice(
                                            'Passwords do not match.',
                                          );
                                return;
                              }
                              if (_selectedRole == null) {
                                          await _showCenterNotice(
                                            'Please select a role.',
                                          );
                                return;
                              }

                                        setState(() {
                                          _isRegistering = true;
                                        });
                              _showLoadingDialog();
                              try {
                                          UserCredential
                                          userCredential = await FirebaseAuth
                                              .instance
                                        .createUserWithEmailAndPassword(
                                          email: _emailController.text,
                                                password:
                                                    _passwordController.text,
                                        );
                                // Post-auth blocklist check; if blocked, delete the just-created user and stop
                                try {
                                            final emailLower = _emailController
                                                .text
                                                .trim()
                                                .toLowerCase();
                                            final deletedAccounts =
                                                await BackendAuthService
                                                    .instance
                                                    .getCollectionItems(
                                                      'deleted_accounts',
                                                      limit: 500,
                                                    );
                                            final blocked = deletedAccounts
                                                .any(
                                              (row) =>
                                                  (row['emailLower'] ??
                                                          row['email'])
                                                      ?.toString()
                                                      .trim()
                                                      .toLowerCase() ==
                                                  emailLower,
                                            );
                                  if (blocked) {
                                              try {
                                                await userCredential.user
                                                    ?.delete();
                                              } catch (_) {}
                                              try {
                                                await FirebaseAuth.instance
                                                    .signOut();
                                              } catch (_) {}
                                    if (!context.mounted) return;
                                              await _showCenterNotice(
                                                'This email was permanently deleted and cannot be used to register.',
                                              );
                                    return;
                                  }
                                } catch (_) {
                                  // Ignore errors here; inability to read blocklist should not break registration
                                }
                                // Clear RoleService cache before setting up new user
                                RoleService.instance.clearCache();
                                
                                // Small delay to let PostgreSQL backend settle after user creation
                                await Future.delayed(const Duration(milliseconds: 300));

                                final role = _selectedRole!.toLowerCase();
                                final displayName = _fullNameController.text.trim();
                                final email = _emailController.text.trim();

                                // Persist profile via DatabaseService (PostgreSQL API)
                                try {
                                  await DatabaseService.initializeUserData(
                                    userCredential.user!.uid,
                                    displayName,
                                    email,
                                    role: role,
                                  );
                                  await _ensureBackendRolePersisted(
                                    uid: userCredential.user!.uid,
                                    email: email,
                                    displayName: displayName,
                                    role: role,
                                  );
                                } catch (e) {
                                  debugPrint('Error initializing user data: $e');
                                  try {
                                    await userCredential.user?.delete();
                                  } catch (_) {}
                                  try {
                                    await FirebaseAuth.instance.signOut();
                                  } catch (_) {}
                                  if (!context.mounted) return;
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).maybePop();
                                  setState(() {
                                    _isRegistering = false;
                                  });
                                  await _showCenterNotice(
                                    'We could not save your role to the backend database. Please try registering again.',
                                  );
                                  return;
                                }

                                // Initialize badges (employees: v2-only; managers may still use legacy)
                                try {
                                  final uid = userCredential.user!.uid;
                                  if (role == 'manager') {
                                    await BadgeService.initializeUserBadges(uid);
                                    // Small delay between badge operations
                                    await Future.delayed(
                                      const Duration(milliseconds: 200),
                                    );
                                    await BadgeService.checkAndAwardBadges(uid);
                                  }
                                  await BadgeService.initializeUserBadgesV2(uid);
                                  await BadgeService.checkAndAwardBadgesV2(uid);
                                } catch (e) {
                                  debugPrint('Error initializing badges: $e');
                                  // Continue even if badges fail - registration should succeed
                                }

                                if (!context.mounted) {
                                  return; // Guard against context use after async gap
                                }
                                          Navigator.of(
                                            context,
                                            rootNavigator: true,
                                          ).maybePop();
                                          setState(() {
                                            _isRegistering = false;
                                          });
                                          await _showCenterNotice(
                                            'Registration Successful!',
                                          );
                                if (!context.mounted) {
                                  return; // Guard against context use after async gap
                                }
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/sign_in',
                                );
                              } on FirebaseAuthException catch (e) {
                                debugPrint('FirebaseAuthException: code=${e.code}, message=${e.message}');
                                String message;
                                switch (e.code) {
                                  case 'weak-password':
                                    message = 'The password provided is too weak.';
                                    break;
                                  case 'email-already-in-use':
                                    message = 'The account already exists for that email.';
                                    break;
                                  case 'operation-not-allowed':
                                    message = 'Email/Password sign-in is not enabled. Ask your admin to enable it in Firebase Console → Authentication → Sign-in method.';
                                    break;
                                  case 'invalid-email':
                                    message = 'The email address is invalid.';
                                    break;
                                  case 'invalid-credential':
                                    message = 'Invalid credentials. Try signing out and registering again.';
                                    break;
                                  case 'network-request-failed':
                                    message = 'Network error. Check your connection and try again.';
                                    break;
                                  default:
                                    message = e.message ?? 'Authentication failed (${e.code}).';
                                }
                                if (!context.mounted) {
                                  return; // Guard against context use after async gap
                                }
                                          Navigator.of(
                                            context,
                                            rootNavigator: true,
                                          ).maybePop();
                                          setState(() {
                                            _isRegistering = false;
                                          });
                                await _showCenterNotice(message);
                              } catch (e, st) {
                                debugPrint('Registration error: $e');
                                debugPrint('Stack trace: $st');
                                if (!context.mounted) {
                                  return;
                                }
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).maybePop();
                                setState(() {
                                  _isRegistering = false;
                                });

                                final errorString = e.toString().toLowerCase();
                                final isTransientBackendIssue =
                                    errorString.contains('backend_unavailable') ||
                                    errorString.contains('timeout') ||
                                    errorString.contains('network_error') ||
                                    (errorString.contains('firestore') &&
                                        errorString.contains('internal assertion failed'));
                                if (isTransientBackendIssue) {
                                  await _showCenterNotice(
                                    'Registration completed, but there was a temporary issue. Please try signing in.',
                                  );
                                  if (context.mounted) {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/sign_in',
                                    );
                                  }
                                } else {
                                  // 400 from signUp often means: Email/Password disabled, or domain not authorized (web)
                                  await _showCenterNotice(
                                    'Registration failed. If you see a 400 error: enable Email/Password in Firebase Console → Authentication → Sign-in method, and add your domain (e.g. localhost) to Authorized domains.',
                                  );
                                }
                              }
                            },
                                child: _isRegistering
                                    ? SizedBox(
                                        height: 34,
                                        width: 76,
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                          child: CustomLogoLoader(
                                            size: 28,
                                            discOverlap: 10,
                                            centerInViewport: false,
                                          ),
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
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/sign_in',
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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

  // ignore: unused_element
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
        borderSide: const BorderSide(color: Color(0xFFC10D00), width: 2.0),
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
          decoration: _inputDecoration().copyWith(hintText: hintText),
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
          decoration: _inputDecoration().copyWith(hintText: 'Select your role'),
          dropdownColor: const Color(
            0x880A0F1F,
          ), // Darker background for dropdown
          style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
          ), // Apply Poppins to selected item
          items: <String>['employee', 'manager', 'admin'].map((String value) {
            final label = value == 'employee'
                ? 'Employee'
                : value == 'manager'
                    ? 'Manager'
                    : 'Admin';
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                label,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 76,
                width: 140,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: CustomLogoLoader(
                    size: 46,
                    discOverlap: 14,
                    centerInViewport: false,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Creating your account...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
