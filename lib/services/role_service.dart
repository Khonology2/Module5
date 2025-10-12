import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

class RoleService {
  RoleService._internal();
  static final RoleService instance = RoleService._internal();

  String? _cachedRole; // 'manager' | 'employee'

  Future<String?> getRole({bool refresh = false}) async {
    if (!refresh && _cachedRole != null) return _cachedRole;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _cachedRole = snap.data()?['role'] as String?;
      return _cachedRole;
    } catch (_) {
      // Fail soft: keep cached value (if any) or return null
      return _cachedRole;
    }
  }

  Stream<String?> roleStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.data()?['role'] as String?)
        .handleError((_) => _cachedRole)
        .map((role) {
          _cachedRole = role ?? _cachedRole;
          return _cachedRole;
        });
  }

  // Method to clear cache (useful for sign out)
  void clearCache() {
    _cachedRole = null;
  }

  // Method to ensure role is loaded and cached
  Future<void> ensureRoleLoaded() async {
    if (_cachedRole == null) {
      await getRole();
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
  String? _role;

  @override
  void initState() {
    super.initState();
    _initializeRole();
  }

  Future<void> _initializeRole() async {
    // Ensure role is loaded before showing the stream
    await RoleService.instance.ensureRoleLoaded();
    _role = await RoleService.instance.getRole();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFC10D00)));
    }

    // If not authenticated, redirect to sign in
    final isAuthenticated = FirebaseAuth.instance.currentUser != null;
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

    if (widget.requiredRole == RequiredRole.any) return widget.child;
    if (_role == null) {
      return Center(child: CircularProgressIndicator(color: Color(0xFFC10D00)));
    }
    final ok =
        (widget.requiredRole == RequiredRole.manager && _role == 'manager') ||
        (widget.requiredRole == RequiredRole.employee && _role == 'employee');
    if (ok) return widget.child;
    return widget.unauthorized ?? _Unauthorized(role: _role);
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
                    Navigator.pushReplacementNamed(context, '/manager_portal');
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
