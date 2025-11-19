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
      // Extract token from URL
      final token = await TokenAuthService.instance.extractTokenFromUrl();
      
      if (token != null && token.isNotEmpty) {
        setState(() {
          _tokenAuthInProgress = true;
        });

        // Authenticate with token
        final result = await TokenAuthService.instance
            .authenticateExistingUserWithToken(token);

        if (result != null && result['success'] == true) {
          // Token authentication successful
          final role = result['role'] as String?;
          final email = result['email'] as String?;

          if (role != null && email != null) {
            // Get or create Firebase Auth user
            User? user = FirebaseAuth.instance.currentUser;

            // If user is not authenticated, we need to handle it
            // For now, we'll update the role if user exists
            // In production, you'd call a backend to create custom token
            if (user != null) {
              // User is already logged in, just update role
              await _updateUserRole(user.uid, role, email);
              await RoleService.instance.getRole(refresh: true);
              
              // Navigate to appropriate dashboard
              if (mounted) {
                _navigateToDashboard(role);
                return;
              }
            } else {
              // User not logged in - try to sign in with custom token from backend
              try {
                final userCredential = await BackendAuthService.instance
                    .signInWithCustomToken(token);
                
                if (userCredential != null && userCredential.user != null) {
                  // Successfully signed in with custom token
                  await _updateUserRole(
                    userCredential.user!.uid,
                    role,
                    email,
                  );
                  await RoleService.instance.getRole(refresh: true);
                  
                  if (mounted) {
                    _navigateToDashboard(role);
                    return;
                  }
                } else {
                  // Backend service not available or failed
                  // Store token info for later use
                  await _storeTokenAuthInfo(email, role, token);
                  
                  if (mounted) {
                    // Show login screen but with token info stored
                    // User can log in normally and role will be applied
                    setState(() {
                      _isCheckingToken = false;
                      _tokenAuthInProgress = false;
                    });
                    return;
                  }
                }
              } catch (e) {
                debugPrint('Error signing in with custom token: $e');
                // Fall back to storing token info
                await _storeTokenAuthInfo(email, role, token);
                
                if (mounted) {
                  setState(() {
                    _isCheckingToken = false;
                    _tokenAuthInProgress = false;
                  });
                  return;
                }
              }
            }
          }
        } else {
          // Token authentication failed
          debugPrint('Token authentication failed: ${result?['error']}');
        }
      }

      // No token or token auth failed, proceed with normal flow
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
  Future<void> _updateUserRole(String userId, String role, String email) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'email': email,
        'role': role,
        'tokenAuthenticated': true,
        'tokenAuthenticatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user role: $e');
    }
  }

  /// Store token auth info for later use (when user logs in)
  Future<void> _storeTokenAuthInfo(
    String email,
    String role,
    String token,
  ) async {
    try {
      // Store in SharedPreferences or similar for later retrieval
      // This allows us to apply the role when user logs in normally
      // For now, we'll just log it - you can implement SharedPreferences storage
      debugPrint('Storing token auth info for: $email with role: $role');
    } catch (e) {
      debugPrint('Error storing token auth info: $e');
    }
  }

  /// Navigate to appropriate dashboard based on role
  void _navigateToDashboard(String role) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      if (role == 'manager') {
        Navigator.pushReplacementNamed(context, '/manager_dashboard');
      } else if (role == 'employee') {
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/sign_in');
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
      if (role == 'manager') {
        Navigator.pushReplacementNamed(context, '/manager_dashboard');
      } else {
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
