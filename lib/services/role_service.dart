import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';
import 'package:pdh/services/onboarding_service.dart';
import 'package:pdh/services/token_auth_service.dart';

class RoleService {
  RoleService._internal();
  static final RoleService instance = RoleService._internal();

  String? _cachedRole; // 'manager' | 'employee'
  String? _sessionRoleOverride;
  Stream<String?>? _roleBroadcast;
  String? _currentUserId; // Track which user the stream is for
  String? _onboardingInferAttemptedUserId;
  String? _onboardingCachedRole;

  String? get cachedRole => _cachedRole;

  String? _normalizeRole(dynamic role) {
    return normalizeRoleLabel(role?.toString());
  }

  String? normalizeRoleLabel(String? rawRole) {
    final role = rawRole?.trim().toLowerCase();
    if (role == null || role.isEmpty) return null;
    if (role.contains('manager')) return 'manager';
    if (role.contains('admin')) return 'admin';
    if (role.contains('employee') || role.contains('staff')) return 'employee';
    return null;
  }

  String routeForRole(String? role) {
    final normalized = normalizeRoleLabel(role);
    if (normalized == 'manager') return '/manager_portal';
    if (normalized == 'admin') return '/admin_dashboard';
    if (normalized == 'employee') return '/employee_dashboard';
    return '/employee_dashboard';
  }

  Future<void> setRoleForSession(String? role) async {
    final normalized = normalizeRoleLabel(role);
    if (normalized != null) {
      _sessionRoleOverride = normalized;
      _cachedRole = normalized;
      return;
    }
    _sessionRoleOverride = 'employee';
    _cachedRole = 'employee';
  }

  /// Admin portal / Firestore `isAdmin()` alignment: exact `admin` plus common aliases.
  /// Matches [DatabaseService] admin-like detection for approval privileges.
  static bool isAdminPortalRole(String? role) {
    final r = role?.trim().toLowerCase();
    if (r == null || r.isEmpty) return false;
    return r == 'admin' ||
        r == 'administrator' ||
        r == 'super_admin' ||
        r == 'superadmin' ||
        r.contains('admin');
  }

  Future<String?> _inferRoleFromOnboarding({
    required String userId,
    required String? email,
  }) async {
    // Prevent repeated Firestore reads during rebuilds.
    if (_onboardingInferAttemptedUserId == userId) {
      return _onboardingCachedRole;
    }
    _onboardingInferAttemptedUserId = userId;

    try {
      // First try onboarding by UID.
      final byId = await FirebaseFirestore.instance
          .collection('onboarding')
          .doc(userId)
          .get();

      Map<String, dynamic>? onboardingData = byId.exists ? byId.data() : null;

      // If not found by UID, try by email.
      if (onboardingData == null && (email ?? '').trim().isNotEmpty) {
        final byEmail = await FirebaseFirestore.instance
            .collection('onboarding')
            .where('email', isEqualTo: email!.trim())
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          onboardingData = byEmail.docs.first.data();
        }
      }

      final moduleAccessRole = onboardingData?['moduleAccessRole'] as String?;
      final inferred = OnboardingService.extractPersonaForApp(moduleAccessRole);
      _onboardingCachedRole = inferred;
      return inferred;
    } catch (e) {
      developer.log('Error inferring role from onboarding: $e');
      _onboardingCachedRole = null;
      return null;
    }
  }

  Future<String?> getRole({bool refresh = false}) async {
    if (_sessionRoleOverride != null) return _sessionRoleOverride;
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
      final role = _normalizeRole(roleData?['role']);

      // Only set default role if role is truly missing (null or empty string)
      // NEVER overwrite an existing role, even if it's empty string
      // Empty string might indicate a role is being set elsewhere
      if (role == null) {
        // Double-check: read the document again to make sure we have the latest data
        // This prevents race conditions where role might have been set between reads
        final retrySnap = await ref.get();
        final retryRole = _normalizeRole(retrySnap.data()?['role']);

        if (retryRole != null) {
          // Role was set between reads, use it
          _cachedRole = retryRole;
          return _cachedRole;
        }

        // Attempt to infer the role from the onboarding collection (common for
        // Google sign-in users where `users/<uid>.role` may be missing).
        final inferred = await _inferRoleFromOnboarding(
          userId: user.uid,
          email: user.email,
        );
        if (inferred != null) {
          _cachedRole = inferred;
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
      return Stream.value(_cachedRole);
    }

    // If user changed, we need a new stream
    // But only clear if we're sure the old stream has no listeners
    if (_currentUserId != null && _currentUserId != user.uid) {
      // User changed - clear reference but let old stream close naturally
      _roleBroadcast = null;
      _currentUserId = user.uid; // Set new user ID immediately
    }

    // Lazily initialize a single broadcast stream so all listeners share one Firestore subscription
    if (_roleBroadcast == null) {
      _currentUserId = user.uid;
      try {
        // Create the Firestore stream and convert to broadcast
        // This ensures only ONE Firestore listener exists per user
        final firestoreStream = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots();

        _roleBroadcast = firestoreStream
            .asyncMap((doc) async {
              try {
                if (_sessionRoleOverride != null) {
                  _cachedRole = _sessionRoleOverride;
                  return _sessionRoleOverride;
                }
                final role = _normalizeRole(doc.data()?['role']);
                if (role != null) {
                  _cachedRole = role;
                  return role;
                }

                // If role is missing in users doc, try onboarding inference once.
                if (_cachedRole != null) return _cachedRole;
                final inferred = await _inferRoleFromOnboarding(
                  userId: user.uid,
                  email: user.email,
                );
                if (inferred != null) {
                  _cachedRole = inferred;
                }
                return _cachedRole;
              } catch (e) {
                developer.log('Error processing role snapshot: $e');
                return _cachedRole;
              }
            })
            .distinct()
            .asBroadcastStream();
      } catch (e) {
        developer.log('Error creating role stream: $e');
        // Return a stream with cached role as fallback
        return Stream.value(_cachedRole);
      }
    }

    return _roleBroadcast!;
  }

  void _clearStream() {
    // Only clear stream reference - don't force cancellation
    // Let Firestore handle cleanup naturally when all listeners unsubscribe
    _roleBroadcast = null;
    _currentUserId = null;
    _onboardingInferAttemptedUserId = null;
    _onboardingCachedRole = null;
  }

  // Method to clear cache (useful for sign out)
  void clearCache() {
    _cachedRole = null;
    _sessionRoleOverride = null;
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

enum RequiredRole { manager, employee, admin, any }

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
      // Admin and manager see loading until role is resolved
      return Center(child: CircularProgressIndicator(color: Color(0xFFC10D00)));
    }

    // If not authenticated, redirect to sign in
    final isAuthenticated = FirebaseAuth.instance.currentUser != null;
    if (!isAuthenticated) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          final target = TokenAuthService.hasTokenInCurrentUrl()
              ? '/landing'
              : '/sign_in';
          Navigator.pushNamedAndRemoveUntil(context, target, (route) => false);
        }
      });
      return const SizedBox.shrink();
    }

    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      initialData: RoleService.instance.cachedRole,
      builder: (context, snapshot) {
        final role = snapshot.data ?? RoleService.instance.cachedRole;
        if (widget.requiredRole == RequiredRole.any) return widget.child;

        final isLoading =
            (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.none) &&
            role == null;

        // While role is loading, never show unauthorized to managers;
        // employees are allowed through.
        if (isLoading) {
          if (widget.requiredRole == RequiredRole.employee) return widget.child;
          return Center(
            child: CircularProgressIndicator(color: Color(0xFFC10D00)),
          );
        }

        if (snapshot.hasError) {
          if (widget.requiredRole == RequiredRole.employee) return widget.child;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final target = RoleService.instance.routeForRole(role);
            Navigator.pushNamedAndRemoveUntil(
              context,
              target,
              (route) => false,
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If role is still null, treat as loading for managers, allow employees through.
        if (role == null) {
          if (widget.requiredRole == RequiredRole.employee) return widget.child;
          // If the stream is active but still no role, don't spin forever.
          final isStillWaiting =
              snapshot.connectionState == ConnectionState.waiting ||
              snapshot.connectionState == ConnectionState.none;
          if (isStillWaiting) {
            return Center(
              child: CircularProgressIndicator(color: Color(0xFFC10D00)),
            );
          }
          return widget.unauthorized ?? const _RoleUnknown();
        }

        final ok =
            (widget.requiredRole == RequiredRole.manager &&
                role == 'manager') ||
            (widget.requiredRole == RequiredRole.employee &&
                role == 'employee') ||
            (widget.requiredRole == RequiredRole.admin &&
                RoleService.isAdminPortalRole(role));
        if (ok) return widget.child;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          final target = RoleService.instance.routeForRole(role);
          Navigator.pushNamedAndRemoveUntil(context, target, (route) => false);
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class _RoleUnknown extends StatelessWidget {
  const _RoleUnknown();

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
              const Icon(Icons.help_outline, color: Colors.orangeAccent),
              const SizedBox(height: 12),
              const Text(
                'Account role not set',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'We could not determine your portal access. Please try again, or sign out and sign back in.',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      RoleService.instance.clearCache();
                      await RoleService.instance.ensureRoleLoaded();
                      if (context.mounted) {
                        // Force a rebuild of the gate by replacing the route.
                        Navigator.pushReplacementNamed(
                          context,
                          ModalRoute.of(context)?.settings.name ?? '/sign_in',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC10D00),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Try again'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/sign_in',
                          (route) => false,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
