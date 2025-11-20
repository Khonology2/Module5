import 'package:flutter/material.dart';
import 'package:pdh/sign_in_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/token_auth_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingToken = true;
  bool _tokenAuthInProgress = false;

  @override
  void initState() {
    super.initState();
    _checkTokenAndAuthenticate();
  }

  /// Check for token in URL and authenticate if present
  Future<void> _checkTokenAndAuthenticate() async {
    try {
      // Step A: Extract token from URL
      final token = await TokenAuthService.extractTokenFromUrl();

      if (token == null || token.isEmpty) {
        // No token found, proceed with normal flow
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _tokenAuthInProgress = false;
          });
        }
        return;
      }

      setState(() {
        _tokenAuthInProgress = true;
      });

      // Step B: Validate token using the backend API
      final validationResponse = await BackendAuthService.instance
          .validateTokenWithBackend(token);

      if (validationResponse == null) {
        debugPrint('Token validation failed - backend returned null');
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _tokenAuthInProgress = false;
          });
        }
        return;
      }

      // Extract data from backend response
      final firebaseTokenRaw = validationResponse['firebase_token'] as String?;
      final email = validationResponse['email'] as String?;
      final roles = validationResponse['roles'] as List<dynamic>?;

      if (firebaseTokenRaw == null || firebaseTokenRaw.isEmpty) {
        debugPrint('Backend validation failed - no firebase_token in response');
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _tokenAuthInProgress = false;
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

      debugPrint(
        'AuthWrapper: Firebase token extracted (length: ${firebaseToken.length}, starts with: ${firebaseToken.substring(0, firebaseToken.length > 20 ? 20 : firebaseToken.length)}...)',
      );

      // Validate token format (should be a JWT with 3 parts)
      final tokenParts = firebaseToken.split('.');
      if (tokenParts.length != 3) {
        debugPrint(
          'AuthWrapper: Invalid Firebase token format - expected 3 parts, got ${tokenParts.length}',
        );
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _tokenAuthInProgress = false;
          });
        }
        return;
      }

      // Extract PDH role from roles list
      String? pdhRole;
      if (roles != null && roles.isNotEmpty) {
        for (final role in roles) {
          final roleStr = role.toString();
          if (roleStr.contains('PDH - Employee') ||
              roleStr.contains('PDH-Employee')) {
            pdhRole = 'PDH - Employee';
            break;
          } else if (roleStr.contains('PDH - Admin') ||
              roleStr.contains('PDH-Admin') ||
              roleStr.contains('PDH - Manager') ||
              roleStr.contains('PDH-Manager')) {
            pdhRole = 'PDH - Admin';
            break;
          }
        }
      }

      if (pdhRole == null) {
        debugPrint('No PDH role found in backend response');
        if (mounted) {
          setState(() {
            _isCheckingToken = false;
            _tokenAuthInProgress = false;
          });
        }
        return;
      }

      // Step C: Sign in using Firebase custom token
      try {
        final userCredential = await FirebaseAuth.instance
            .signInWithCustomToken(firebaseToken);

        if (userCredential.user != null && email != null) {
          // Update user role in Firestore
          await _updateUserRole(userCredential.user!.uid, pdhRole, email);
          await RoleService.instance.getRole(refresh: true);

          // Call backend callback to notify authentication is complete
          await BackendAuthService.instance.callAuthCallback(
            userId: userCredential.user!.uid,
            email: email,
            role: pdhRole,
            authenticated: true,
          );

          // Step D: Route user based on roles
          if (mounted) {
            _navigateToDashboard(pdhRole);
            return;
          }
        } else {
          debugPrint('Failed to sign in with custom token');
        }
      } catch (e) {
        debugPrint('Error signing in with custom token: $e');
      }

      // If we reach here, authentication failed
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
          _tokenAuthInProgress = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking token: $e');
      if (mounted) {
        setState(() {
          _isCheckingToken = false;
          _tokenAuthInProgress = false;
        });
      }
    }
  }

  /// Update user role in Firestore
  Future<void> _updateUserRole(
    String userId,
    String pdhRole,
    String email,
  ) async {
    try {
      // Map PDH role to internal role for backward compatibility
      String internalRole;
      if (pdhRole == 'PDH - Employee') {
        internalRole = 'employee';
      } else if (pdhRole == 'PDH - Admin') {
        internalRole = 'manager'; // Admin uses manager role internally
      } else {
        internalRole = 'employee'; // Default fallback
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': email,
        'role': internalRole,
        'pdhRole': pdhRole, // Store original PDH role
        'tokenAuthenticated': true,
        'tokenAuthenticatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user role: $e');
    }
  }

  /// Navigate to appropriate dashboard based on role
  void _navigateToDashboard(String role) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (role == 'PDH - Employee') {
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      } else if (role == 'PDH - Admin') {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else {
        // Fallback to employee dashboard for unknown roles
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking token
    if (_isCheckingToken || _tokenAuthInProgress) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1931),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
          ),
        ),
      );
    }

    // Check if user is already authenticated
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A1931),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user != null) {
          // User is signed in, navigate to appropriate dashboard based on role
          return _AuthenticatedWrapper(user: user);
        } else {
          // User is signed out, show login screen
          return const LoginScreen();
        }
      },
    );
  }
}

/// Widget to handle authenticated users and route them to appropriate dashboard
class _AuthenticatedWrapper extends StatefulWidget {
  final User user;

  const _AuthenticatedWrapper({required this.user});

  @override
  State<_AuthenticatedWrapper> createState() => _AuthenticatedWrapperState();
}

class _AuthenticatedWrapperState extends State<_AuthenticatedWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAndNavigate();
  }

  Future<void> _initializeAndNavigate() async {
    try {
      // Ensure role is loaded
      await RoleService.instance.getRole(refresh: true);

      if (!mounted) return;

      final role = await RoleService.instance.getRole();

      if (!mounted) return;

      // Navigate based on role
      // Handle both old format (employee/manager) and new format (PDH - Employee/PDH - Admin)
      if (role == 'PDH - Admin' || role == 'manager') {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else if (role == 'PDH - Employee' || role == 'employee') {
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      } else {
        // Default to employee dashboard
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      }
    } catch (e) {
      debugPrint('Error initializing user: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A1931),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
          ),
        ),
      );
    }

    // This should not be reached as navigation happens in initState
    return const LoginScreen();
  }
}
