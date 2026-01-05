import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';

class RoleService {
  RoleService._internal();
  static final RoleService instance = RoleService._internal();

  String? _cachedRole; // 'manager' | 'employee'
  Stream<String?>? _roleBroadcast;
  String? _currentUserId; // Track which user the stream is for

  String? get cachedRole => _cachedRole;

  Future<String?> getRole({bool refresh = false}) async {
    if (!refresh && _cachedRole != null) return _cachedRole;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _cachedRole = null;
      return null;
    }

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await ref.get();

      if (!snap.exists) {
        // Document doesn't exist - return null, don't create it
        // This allows registration to set the role properly
        _cachedRole = null;
        return null;
      }

      // Document exists - get the role
      final roleData = snap.data();
      String? role = roleData?['role'] as String?;

      // Only set default role if role is truly missing (null or empty string)
      // NEVER overwrite an existing role, even if it's empty string
      // Empty string might indicate a role is being set elsewhere
      if (role == null || role.isEmpty) {
        // Double-check: read the document again to make sure we have the latest data
        // This prevents race conditions where role might have been set between reads
        final retrySnap = await ref.get();
        final retryRole = retrySnap.data()?['role'] as String?;

        if (retryRole != null && retryRole.isNotEmpty) {
          // Role was set between reads, use it
          _cachedRole = retryRole;
          return _cachedRole;
        }

        // Role is still missing - only then set default
        // But first, check if this is a brand new user (created in last 10 seconds)
        // If so, don't set default - let registration complete
        final createdAt = roleData?['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final now = Timestamp.now();
          final secondsSinceCreation = now.seconds - createdAt.seconds;
          if (secondsSinceCreation < 10) {
            // User was just created, don't set default role yet
            _cachedRole = null;
            return null;
          }
        }

        // Role is missing and user is not brand new - do NOT set a default here
        // Avoid accidental downgrades; let registration/admin flows set the role
        _cachedRole = null;
        return null;
      }

      _cachedRole = role;
      return _cachedRole;
    } catch (e) {
      developer.log('Error getting role: $e');
      // Return cached role if available, otherwise return null
      // Let the calling code decide what to do with null role
      return _cachedRole;
    }
  }

  Stream<String?> roleStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _clearStream();
      return const Stream.empty();
    }

    // If user changed, clear old stream first to prevent multiple listeners
    if (_currentUserId != null && _currentUserId != user.uid) {
      _clearStream();
    }

    // Lazily initialize a single broadcast stream so all listeners share one Firestore subscription
    if (_roleBroadcast == null) {
      _currentUserId = user.uid;
      try {
        _roleBroadcast = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .map((doc) {
              try {
                final role = doc.data()?['role'] as String?;
                _cachedRole = role;
                return role;
              } catch (e) {
                developer.log('Error processing role snapshot: $e');
                return _cachedRole;
              }
            })
            .distinct()
            .handleError((error) {
              developer.log('Error in role stream: $error');
              // Don't propagate error, just return cached role
            })
            .asBroadcastStream();
      } catch (e) {
        developer.log('Error creating role stream: $e');
        // Return a stream with cached role
        return Stream.value(_cachedRole);
      }
    }

    return _roleBroadcast!;
  }

  void _clearStream() {
    _roleBroadcast = null;
    _currentUserId = null;
  }

  // Method to clear cache (useful for sign out)
  void clearCache() {
    _cachedRole = null;
    _clearStream();
  }

  // Method to ensure role is loaded and cached
  Future<void> ensureRoleLoaded() async {
    if (_cachedRole == null) {
      await getRole(refresh: true);
      // If still null after first attempt, wait a bit and retry (for timing issues)
      if (_cachedRole == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        await getRole(refresh: true);
      }
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

  @override
  void initState() {
    super.initState();
    _initializeRole();
  }

  Future<void> _initializeRole() async {
    // Ensure role is loaded before showing the stream
    await RoleService.instance.ensureRoleLoaded();
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

    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, snapshot) {
        final role = snapshot.data ?? RoleService.instance.cachedRole;
        if (widget.requiredRole == RequiredRole.any) return widget.child;
        
        // If stream is still waiting and role is null, show loading for managers
        // This handles the case where role hasn't loaded yet after login
        if (snapshot.connectionState == ConnectionState.waiting && role == null) {
          if (widget.requiredRole == RequiredRole.manager) {
            return Center(child: CircularProgressIndicator(color: Color(0xFFC10D00)));
          }
          // For employees, allow access while loading
          if (widget.requiredRole == RequiredRole.employee) {
            return widget.child;
          }
        }
        
        if (snapshot.hasError) {
          if (widget.requiredRole == RequiredRole.employee) return widget.child;
          return widget.unauthorized ?? _Unauthorized(role: role);
        }
        
        // If role is null after stream has emitted, user truly has no role
        if (role == null) {
          if (widget.requiredRole == RequiredRole.employee) return widget.child;
          // For managers with no role, show unauthorized
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
