import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

class RoleService {
  RoleService._internal();
  static final RoleService instance = RoleService._internal();

  String? _cachedRole; // 'manager' | 'employee'
  Stream<String?>? _roleBroadcast;

  String? get cachedRole => _cachedRole;

  Future<String?> getRole({bool refresh = false}) async {
    if (!refresh && _cachedRole != null) return _cachedRole;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snap = await ref.get();
    String? role = snap.data()?['role'] as String?;
    if (role == null || role.isEmpty) {
      try {
        await ref.set({'role': 'employee'}, SetOptions(merge: true));
        role = 'employee';
      } catch (_) {}
    }
    _cachedRole = role ?? 'employee';
    return _cachedRole;
  }

  Stream<String?> roleStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    // Lazily initialize a single broadcast stream so all listeners share one Firestore subscription
    _roleBroadcast ??= FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          final role = doc.data()?['role'] as String?;
          _cachedRole = role;
          return role;
        })
        .distinct()
        .asBroadcastStream();

    return _roleBroadcast!;
  }

  // Method to clear cache (useful for sign out)
  void clearCache() {
    _cachedRole = null;
    _roleBroadcast = null;
  }

  // Method to ensure role is loaded and cached
  Future<void> ensureRoleLoaded() async {
    if (_cachedRole == null) {
      await getRole();
    }
  }

  // Method to set role directly using user_id (for token-based auth without Firebase Auth)
  Future<void> setRoleByUserId(String userId, String role) async {
    try {
      // Store role in Firestore using user_id
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'role': role,
        'user_id': userId,
      }, SetOptions(merge: true));

      // Cache the role locally
      _cachedRole = role;
      debugPrint('RoleService: Role set to $role for user_id: $userId');
    } catch (e) {
      debugPrint('RoleService: Error setting role by user_id: $e');
      // Still cache the role locally even if Firestore update fails
      _cachedRole = role;
    }
  }

  // Method to get role by user_id (for token-based auth without Firebase Auth)
  Future<String?> getRoleByUserId(String userId) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(userId);
      final snap = await ref.get();
      String? role = snap.data()?['role'] as String?;
      if (role != null && role.isNotEmpty) {
        _cachedRole = role;
        return role;
      }
      return null;
    } catch (e) {
      debugPrint('RoleService: Error getting role by user_id: $e');
      return null;
    }
  }
}

enum RequiredRole { manager, employee, any }

class RoleGate extends StatefulWidget {
  final RequiredRole requiredRole;
  final Widget child;
  final Widget? unauthorized;

  const RoleGate({
    super.key,
    required this.requiredRole,
    required this.child,
    this.unauthorized,
  });

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  bool _isInitializing = true;
  bool _hasTokenAuth = false;

  @override
  void initState() {
    super.initState();
    _initializeRole();
  }

  Future<void> _initializeRole() async {
    // Check for Firebase Auth user first
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      // Traditional Firebase Auth - ensure role is loaded
      await RoleService.instance.ensureRoleLoaded();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
      return;
    }

    // If no Firebase Auth user, check for token-based authentication
    // Look for user document with tokenAuthenticated flag
    try {
      // Try to find a user document that was created via token authentication
      // We'll check the cached role first, then query Firestore
      if (RoleService.instance.cachedRole != null) {
        // Role is already cached from token authentication
        _hasTokenAuth = true;
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
        return;
      }

      // If no cached role, the role should have been set by landing screen
      // If it's not cached, we'll rely on the cached role check below
      // The landing screen should have already set it via setRoleByUserId()
    } catch (e) {
      debugPrint('RoleGate: Error checking token auth: $e');
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      // Do not block employee views during initial role warm-up
      if (widget.requiredRole == RequiredRole.employee ||
          widget.requiredRole == RequiredRole.any) {
        return widget.child;
      }
      return Center(child: CircularProgressIndicator(color: Color(0xFFC10D00)));
    }

    // Check authentication - either Firebase Auth or token-based
    final isFirebaseAuthenticated = FirebaseAuth.instance.currentUser != null;
    final isAuthenticated =
        isFirebaseAuthenticated ||
        _hasTokenAuth ||
        RoleService.instance.cachedRole != null;

    if (!isAuthenticated) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/sign_in',
            (route) => false,
          );
        }
      });
      return const SizedBox.shrink();
    }

    // For token-based auth, use cached role directly (no stream needed)
    // For Firebase Auth, use the stream
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null && RoleService.instance.cachedRole != null) {
      // Token-based authentication - use cached role
      final role = RoleService.instance.cachedRole;
      if (widget.requiredRole == RequiredRole.any) return widget.child;
      if (role == null) {
        if (widget.requiredRole == RequiredRole.employee) return widget.child;
        return widget.unauthorized ?? _Unauthorized(role: role);
      }
      final ok =
          (widget.requiredRole == RequiredRole.manager && role == 'manager') ||
          (widget.requiredRole == RequiredRole.employee && role == 'employee');
      if (ok) return widget.child;
      return widget.unauthorized ?? _Unauthorized(role: role);
    }

    // Firebase Auth - use stream
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, snapshot) {
        final role = snapshot.data ?? RoleService.instance.cachedRole;
        if (widget.requiredRole == RequiredRole.any) return widget.child;
        if (snapshot.hasError || role == null) {
          if (widget.requiredRole == RequiredRole.employee) return widget.child;
          return widget.unauthorized ?? _Unauthorized(role: role);
        }
        final ok =
            (widget.requiredRole == RequiredRole.manager &&
                role == 'manager') ||
            (widget.requiredRole == RequiredRole.employee &&
                role == 'employee');
        if (ok) return widget.child;
        return widget.unauthorized ?? _Unauthorized(role: role);
      },
    );
  }
}

class _Unauthorized extends StatelessWidget {
  final String? role;
  const _Unauthorized({this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1931),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2840),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.orangeAccent),
              const SizedBox(height: 12),
              const Text(
                'Access restricted',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your role (${role ?? "unknown"}) does not have access to this page.',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  if (role == 'manager') {
                    Navigator.pushReplacementNamed(
                      context,
                      '/manager_dashboard',
                    );
                  } else {
                    Navigator.pushReplacementNamed(context, '/employee_portal');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go to my portal'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
