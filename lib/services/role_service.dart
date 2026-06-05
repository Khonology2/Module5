import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/scheduler.dart';
import 'package:pdh/services/onboarding_service.dart';
import 'package:pdh/services/token_auth_service.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/agent_debug_log.dart';
import 'package:pdh/widgets/custom_logo_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoleService {
  RoleService._internal();
  static final RoleService instance = RoleService._internal();

  String? _cachedRole; // 'manager' | 'employee'
  String? _stickyRole; // Last known good role; kept across transient backend failures
  String? _sessionRoleOverride;
  Stream<String?>? _roleBroadcast;
  String? _currentUserId; // Track which user the stream is for
  String? _onboardingInferAttemptedUserId;
  String? _onboardingCachedRole;
  Future<String?>? _roleLoadInFlight;

  String? get cachedRole => _cachedRole;

  /// Best role for navigation/sidebar; never cleared by a failed refresh poll.
  String? get effectiveRole =>
      normalizeRoleLabel(
        _cachedRole ?? _sessionRoleOverride ?? _stickyRole,
      );

  static String _persistedRoleKey(String userId) => 'pdh_role_$userId';

  Future<String?> _readPersistedRole(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return normalizeRoleLabel(prefs.getString(_persistedRoleKey(userId)));
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistRole(String userId, String role) async {
    final normalized = normalizeRoleLabel(role);
    if (normalized == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_persistedRoleKey(userId), normalized);
    } catch (_) {}
  }

  void _applyResolvedRole(String role) {
    final normalized = normalizeRoleLabel(role);
    if (normalized == null) return;
    _cachedRole = normalized;
    _stickyRole = normalized;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      unawaited(_persistRole(uid, normalized));
    }
  }

  Future<String?> _fallbackRoleForSignedInUser(String userId) async {
    if (_stickyRole != null) return _stickyRole;
    if (_sessionRoleOverride != null) return _sessionRoleOverride;
    final persisted = await _readPersistedRole(userId);
    if (persisted != null) {
      _stickyRole = persisted;
      _cachedRole = persisted;
      return persisted;
    }
    return null;
  }

  String? normalizeRoleLabel(String? rawRole) {
    final role = rawRole?.trim().toLowerCase();
    if (role == null || role.isEmpty) return null;
    if (role.contains('manager')) return 'manager';
    if (role.contains('admin')) return 'admin';
    if (role.contains('employee') || role.contains('staff')) return 'employee';
    return null;
  }

  String? _resolveRoleFromRecord(Map<String, dynamic> record) {
    final candidates = <dynamic>[
      record['moduleAccessRole'],
      record['module_access_role'],
      record['moduleRole'],
      record['module_role'],
      record['role'],
    ];

    String? bestRole;
    var bestPriority = 0;

    void consider(String? role) {
      final normalized = normalizeRoleLabel(role);
      if (normalized == null) return;
      final priority = _rolePriority(normalized);
      if (priority > bestPriority) {
        bestPriority = priority;
        bestRole = normalized;
      }
    }

    for (final candidate in candidates) {
      final raw = candidate?.toString().trim();
      if (raw == null || raw.isEmpty) continue;

      consider(OnboardingService.extractPersonaForApp(raw));

      if (raw.contains(',')) {
        for (final segment in raw.split(',')) {
          consider(OnboardingService.extractPersonaForApp(segment.trim()));
        }
      }

      consider(normalizeRoleLabel(raw));
    }

    return bestRole;
  }

  int _rolePriority(String? role) {
    switch (normalizeRoleLabel(role)) {
      case 'admin':
        return 3;
      case 'manager':
        return 2;
      case 'employee':
        return 1;
      default:
        return 0;
    }
  }

  Future<String?> _resolveRoleByEmail(String? email) async {
    final normalizedEmail = email?.trim().toLowerCase();
    if (normalizedEmail == null || normalizedEmail.isEmpty) return null;

    try {
      final users = await BackendAuthService.instance.listUsers(limit: 2000);
      String? bestRole;
      var bestPriority = 0;
      for (final user in users) {
        final userEmail = user['email']?.toString().trim().toLowerCase();
        if (userEmail != normalizedEmail) continue;

        final role = _resolveRoleFromRecord(user);
        final priority = _rolePriority(role);
        if (priority > bestPriority) {
          bestPriority = priority;
          bestRole = role;
        }
        if (bestPriority == 3) break;
      }
      return bestRole;
    } catch (e) {
      developer.log('Error resolving role by email: $e');
      return null;
    }
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
      _applyResolvedRole(normalized);
      return;
    }
    _sessionRoleOverride = null;
  }

  /// Admin portal alignment: exact `admin` plus common aliases.
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
    // Prevent repeated backend reads during rebuilds.
    if (_onboardingInferAttemptedUserId == userId) {
      return _onboardingCachedRole;
    }
    _onboardingInferAttemptedUserId = userId;

    try {
      Map<String, dynamic>? onboardingData;
      try {
        onboardingData = await BackendAuthService.instance.getOnboarding(userId);
      } catch (_) {}

      if (onboardingData == null || onboardingData.isEmpty) {
        final normalizedEmail = email?.trim();
        if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
          try {
            final onboardingMatches =
                await OnboardingService.listOnboardingRecords(
                  email: normalizedEmail,
                  limit: 1,
                );
            if (onboardingMatches.isNotEmpty) {
              onboardingData = onboardingMatches.first;
            }
          } catch (_) {}
        }
      }

      final inferred = onboardingData == null ? null : _resolveRoleFromRecord(onboardingData);
      _onboardingCachedRole = inferred;
      return inferred;
    } catch (e) {
      developer.log('Error inferring role from onboarding: $e');
      _onboardingCachedRole = null;
      return null;
    }
  }

  Future<String?> getRole({bool refresh = false}) async {
    if (!refresh && _sessionRoleOverride != null) return _sessionRoleOverride;
    if (!refresh && _cachedRole != null) return _cachedRole;
    if (!refresh && _roleLoadInFlight != null) return _roleLoadInFlight;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _cachedRole = null;
      _stickyRole = null;
      return null;
    }

    if (!refresh && _stickyRole == null) {
      final persisted = await _readPersistedRole(user.uid);
      if (persisted != null) {
        _stickyRole = persisted;
        _cachedRole ??= persisted;
      }
    }

    Future<String?> loadRole() async {
      try {
        final userData = await BackendAuthService.instance.getUser(user.uid);
        final role = _resolveRoleFromRecord(userData);
        if (role != null) {
          _applyResolvedRole(role);
          return _cachedRole;
        }
      } catch (e) {
        developer.log('Error getting role from user record: $e');
      }

      final inferred = await _inferRoleFromOnboarding(
        userId: user.uid,
        email: user.email,
      );
      if (inferred != null) {
        _applyResolvedRole(inferred);
        return _cachedRole;
      }

      final emailRole = await _resolveRoleByEmail(user.email);
      if (emailRole != null) {
        _applyResolvedRole(emailRole);
        return _cachedRole;
      }

      if (_sessionRoleOverride != null) {
        _applyResolvedRole(_sessionRoleOverride!);
        return _cachedRole;
      }

      return _fallbackRoleForSignedInUser(user.uid);
    }

    final inFlight = loadRole();
    if (!refresh) {
      _roleLoadInFlight = inFlight;
    }
    try {
      return await inFlight;
    } finally {
      if (_roleLoadInFlight == inFlight) {
        _roleLoadInFlight = null;
      }
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

    // Lazily initialize a single broadcast stream so all listeners share one backend poller.
    if (_roleBroadcast == null) {
      _currentUserId = user.uid;
      try {
        _roleBroadcast = _pollRoleStream().asBroadcastStream();
      } catch (e) {
        developer.log('Error creating role stream: $e');
        // Return a stream with cached role as fallback
        return Stream.value(_cachedRole);
      }
    }

    return _roleBroadcast!;
  }

  Stream<String?> _pollRoleStream() async* {
    final first = await getRole(refresh: true);
    yield first ?? _stickyRole ?? _cachedRole;
    while (true) {
      await Future.delayed(const Duration(seconds: 30));
      final previous = _cachedRole ?? _stickyRole;
      final next = await getRole(refresh: true);
      yield next ?? previous;
    }
  }

  void _clearStream() {
    // Only clear stream reference - don't force cancellation.
    _roleBroadcast = null;
    _currentUserId = null;
    _onboardingInferAttemptedUserId = null;
    _onboardingCachedRole = null;
    _roleLoadInFlight = null;
  }

  // Method to clear cache (useful for sign out)
  void clearCache() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _cachedRole = null;
    _stickyRole = null;
    _sessionRoleOverride = null;
    _clearStream();
    if (uid != null) {
      unawaited(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_persistedRoleKey(uid));
        } catch (_) {}
      }());
    }
  }

  // Method to ensure role is loaded and cached
  Future<void> ensureRoleLoaded() async {
    if (_cachedRole != null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _stickyRole == null) {
      final persisted = await _readPersistedRole(user.uid);
      if (persisted != null) {
        _stickyRole = persisted;
        _cachedRole = persisted;
        return;
      }
    }
    for (var attempt = 0; attempt < 6 && _cachedRole == null; attempt++) {
      await getRole(refresh: attempt > 0);
      if (_cachedRole != null) return;
      if (attempt < 5) {
        await Future.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
    if (_cachedRole == null && user != null) {
      final fallback = await _fallbackRoleForSignedInUser(user.uid);
      if (fallback != null) {
        _cachedRole = fallback;
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
    // #region agent log
    agentDebugLog(
      hypothesisId: 'C',
      location: 'role_service.dart:_RoleGateState._initializeRole',
      message: 'role_gate_init_done',
      data: {
        'required': widget.requiredRole.name,
        'cachedRole': RoleService.instance.cachedRole,
      },
    );
    // #endregion
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // #region agent log
    agentDebugLog(
      hypothesisId: 'C',
      location: 'role_service.dart:RoleGate.build',
      message: 'role_gate_frame',
      data: {
        'required': widget.requiredRole.name,
        'initializing': _isInitializing,
        'authUid': FirebaseAuth.instance.currentUser?.uid != null,
      },
    );
    // #endregion
    if (_isInitializing) {
      // Do not block employee views during initial role warm-up
      if (widget.requiredRole == RequiredRole.employee ||
          widget.requiredRole == RequiredRole.any) {
        return widget.child;
      }
      // Admin and manager see loading until role is resolved
      return CustomLogoLoader(centerInViewport: true);
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC10D00)),
        ),
      );
    }

    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      initialData: RoleService.instance.cachedRole,
      builder: (context, snapshot) {
        final role =
            snapshot.data ??
            RoleService.instance.cachedRole ??
            RoleService.instance.effectiveRole;
        if (widget.requiredRole == RequiredRole.any) return widget.child;

        final isLoading =
            (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.none) &&
            role == null;

        // While role is loading, never show unauthorized to managers;
        // employees are allowed through.
        if (isLoading) {
          if (widget.requiredRole == RequiredRole.employee) return widget.child;
          return CustomLogoLoader(centerInViewport: true);
        }

        if (snapshot.hasError) {
          if (widget.requiredRole == RequiredRole.employee) return widget.child;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final target = RoleService.instance.routeForRole(
              RoleService.instance.effectiveRole ?? role,
            );
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

        // Signed-in users should never hit a dead-end role screen.
        if (role == null) {
          if (widget.requiredRole == RequiredRole.employee) return widget.child;
          return CustomLogoLoader(centerInViewport: true);
        }

        final ok =
            (widget.requiredRole == RequiredRole.manager &&
                role == 'manager') ||
            (widget.requiredRole == RequiredRole.employee &&
                role == 'employee') ||
            (widget.requiredRole == RequiredRole.admin &&
                RoleService.isAdminPortalRole(role));
        // #region agent log
        agentDebugLog(
          hypothesisId: 'C',
          location: 'role_service.dart:RoleGate.StreamBuilder',
          message: 'role_gate_stream',
          data: {
            'required': widget.requiredRole.name,
            'role': role,
            'conn': snapshot.connectionState.name,
            'ok': ok,
          },
        );
        // #endregion
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
