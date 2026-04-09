import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/widgets/notifications_bell.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/streak_service.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/goal_detail_screen.dart';
import 'package:pdh/upcoming_goals_list_screen.dart';
import 'package:pdh/services/employee_tutorial_service.dart';
import 'package:pdh/services/settings_service.dart';
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:pdh/widgets/employee_sidebar_tutorial.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/season_service.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:pdh/utils/firestore_safe.dart';
import 'package:pdh/widgets/version_control_widget.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

/// Employee dashboard card surface (requested #3D3D40; user note had a typo).
// In dark mode we intentionally reduce alpha so the background image shows through.
// "Drop opacity by 40%" => keep ~60% opacity.
const Color _kDashboardCardBg = Color(0x993D3D40);
const Color _kPointsAccent = Color(0xFF6CA510);

/// All dashboard copy uses solid white for clarity on dark cards.
const Color _kDashboardText = Color(0xFFFFFFFF);

/// Quick Actions tile hover fill (mockup solid red).
const Color _kQuickActionHoverRed = Color(0xFFC10D00);

/// Light mode for dashboard chrome. Uses [employeeDashboardLightModeNotifier] — **not**
/// [EmployeeDashboardThemeScope.lightOf] with [State.context], because the scope sits
/// *below* [EmployeeDashboardScreen] in the tree, so inherited lookup from the state
/// context always misses the scope (only inner [BuildContext]s under the scope resolve).
bool _dashIsLight() => employeeDashboardLightModeNotifier.value;

Color _dashFg(BuildContext context) {
  return _dashIsLight() ? const Color(0xFF000000) : _kDashboardText;
}

Color _dashCard(BuildContext context) {
  // Light mode: also reduced opacity (same 40% drop request).
  return _dashIsLight() ? const Color(0x99FFFFFF) : _kDashboardCardBg;
}

Color _dashBorder(BuildContext context) {
  return _dashIsLight()
      ? const Color(0x1E000000)
      : Colors.white.withValues(alpha: 0.12);
}

Color _dashDivider(BuildContext context) {
  return _dashIsLight()
      ? const Color(0x1E000000)
      : Colors.white.withValues(alpha: 0.13);
}

Color _dashTopPerfRowBg(BuildContext context) {
  return _dashIsLight()
      ? Colors.black.withValues(alpha: 0.024)
      : Colors.white.withValues(alpha: 0.036);
}

Color _dashTopPerfRowBorder(BuildContext context) {
  return _dashIsLight()
      ? const Color(0x0C000000)
      : Colors.white.withValues(alpha: 0.048);
}

/// Bell icon in section headers: dark-on-light vs light-on-dark.
String _dashBellAssetPath(BuildContext context) {
  return _dashIsLight() ? 'assets/red_bell.png' : 'assets/white_bell.png';
}

/// KPI / row badge images: show assets as-is (no tint) so red badge art stays visible in light mode.
Widget _dashDashboardAsset(String assetPath, {double size = 48}) {
  return Image.asset(assetPath, width: size, height: size, fit: BoxFit.contain);
}

Widget _quickActionLeadingIcon(
  BuildContext context, {
  required bool hover,
  required String assetPath,
}) {
  return Image.asset(
    assetPath,
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) => Icon(
      Icons.touch_app_outlined,
      color: hover ? Colors.white : _dashFg(context),
      size: 40,
    ),
  );
}

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({
    super.key,
    this.forManagerGwMenu = false,
    this.managerGwMenuRoute,
    this.embedded = false,
    this.forAdminOversight = false,
    this.selectedManagerId,
  });

  /// When true, use manager sidebar and [managerGwMenuRoute] (for manager Goal Workspace menu).
  final bool forManagerGwMenu;
  final String? managerGwMenuRoute;

  /// When true, only build content (no AppScaffold/sidebar); for use inside ManagerPortalScreen.
  final bool embedded;

  /// When true, admin is viewing; data for [selectedManagerId] if set.
  final bool forAdminOversight;
  final String? selectedManagerId;

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  UserProfile? userProfile;
  List<Goal> userGoals = [];
  bool isLoading = true;
  String? error;
  int currentStreak = 0;
  bool hasActivityToday = false;
  Future<String?>? _onboardingNameFuture;
  Stream<UserProfile?>? _userProfileStream;
  Stream<List<Goal>>? _userGoalsStream;

  /// When [forAdminOversight] and [selectedManagerId] are set, use that uid for data; else current user.
  String? get _effectiveUserId {
    if (widget.forAdminOversight && widget.selectedManagerId != null) {
      return widget.selectedManagerId;
    }
    return FirebaseAuth.instance.currentUser?.uid;
  }

  // Tutorial state
  bool _shouldShowTutorial = false;
  int _currentTutorialStep = 0;
  final List<GlobalKey> _sidebarTutorialKeys = List.generate(
    11, // 10 sidebar items + 1 collapse toggle
    (index) => GlobalKey(),
  );

  // Safety: avoid infinite spinner if streams never emit (e.g., permission issues).
  final Stopwatch _initialProfileLoadWatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _configureDashboardStreams();
    _loadAllData();

    // Start real-time badge tracking and streak tracking for this user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      BadgeService.startRealtimeTracking(user.uid);
      StreakService.startRealtimeTracking(user.uid);
    }

    // Check if tutorial should be shown
    _checkTutorial();

    // Cache onboarding name lookups to avoid repeated Firestore reads on rebuilds (esp. on web).
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      _onboardingNameFuture = DatabaseService.getUserNameFromOnboarding(
        userId: authUser.uid,
        email: authUser.email,
      );
    }
  }

  @override
  void didUpdateWidget(covariant EmployeeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedManagerId != widget.selectedManagerId ||
        oldWidget.forAdminOversight != widget.forAdminOversight) {
      _configureDashboardStreams();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check tutorial when screen becomes visible again (e.g., navigating back from settings)
    // Only check if tutorial isn't already active
    if (!_shouldShowTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkTutorial();
        }
      });
    }
  }

  // Simplified immediate start
  void _startTutorialImmediate() {
    if (!mounted || !_shouldShowTutorial) return;

    developer.log(
      'Starting tutorial immediately - step: $_currentTutorialStep',
      name: 'EmployeeDashboardScreen',
    );

    try {
      // Check if key is attached
      final keyContext = _sidebarTutorialKeys[0].currentContext;
      developer.log(
        'Key context check: ${keyContext != null ? "ATTACHED" : "NOT ATTACHED"}',
        name: 'EmployeeDashboardScreen',
      );

      if (keyContext != null) {
        // Key is attached, start showcase
        ShowcaseView.get().startShowCase([_sidebarTutorialKeys[0]]);
        developer.log(
          'Showcase started successfully!',
          name: 'EmployeeDashboardScreen',
        );
      } else {
        // Key not attached yet, retry
        developer.log(
          'Key not attached, retrying in 500ms...',
          name: 'EmployeeDashboardScreen',
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _shouldShowTutorial) {
            _startTutorialImmediate();
          }
        });
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error starting showcase: $e',
        name: 'EmployeeDashboardScreen',
        error: e,
      );
      developer.log('Stack: $stackTrace', name: 'EmployeeDashboardScreen');

      // Retry after error
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _shouldShowTutorial) {
          _startTutorialImmediate();
        }
      });
    }
  }

  Future<void> _checkTutorial() async {
    if (!mounted) return;

    try {
      developer.log(
        'Checking if employee sidebar tutorial should start...',
        name: 'EmployeeDashboardScreen',
      );

      final shouldShow = await EmployeeTutorialService.instance
          .shouldShowTutorial();
      developer.log(
        'Employee sidebar tutorial check result: shouldShow=$shouldShow',
        name: 'EmployeeDashboardScreen',
      );

      if (shouldShow && mounted) {
        developer.log(
          'Tutorial should start - initializing...',
          name: 'EmployeeDashboardScreen',
        );

        // Set tutorial state first
        setState(() {
          _shouldShowTutorial = true;
          _currentTutorialStep = 0;
        });

        // Store tutorial state globally so it persists across navigation
        // Use global methods that work from any screen
        EmployeeTutorialService.instance.setTutorialState(
          isActive: true,
          currentStep: 0,
          keys: _sidebarTutorialKeys,
          context: context,
        );

        // Ensure sidebar is expanded
        SidebarState.instance.isCollapsed.value = false;

        // Wait for widgets to rebuild with tutorial state
        await Future.delayed(const Duration(milliseconds: 200));

        // Start tutorial after widgets rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted && _shouldShowTutorial) {
                developer.log(
                  'Starting tutorial from check...',
                  name: 'EmployeeDashboardScreen',
                );
                // Navigate to first screen if needed
                if (EmployeeSidebarTutorialConfig.steps.isNotEmpty) {
                  final firstStep = EmployeeSidebarTutorialConfig.steps[0];
                  if (firstStep.route != '__collapse_toggle__') {
                    final currentRoute = ModalRoute.of(context)?.settings.name;
                    if (currentRoute != firstStep.route) {
                      Navigator.pushReplacementNamed(
                        context,
                        firstStep.route,
                      ).then((_) {
                        // The new screen will update context in its build method
                        // Then we'll show the popup via the retry mechanism
                        Future.delayed(const Duration(milliseconds: 800), () {
                          final tutorialService =
                              EmployeeTutorialService.instance;
                          if (tutorialService.isTutorialActive &&
                              tutorialService.currentContext != null) {
                            tutorialService.showTutorialPopup(
                              tutorialService.currentContext!,
                            );
                          }
                        });
                      });
                      return;
                    }
                  }
                }
                _startTutorialImmediate();
              }
            });
          });
        });
      } else {
        developer.log(
          'Tutorial will NOT start - shouldShow=$shouldShow',
          name: 'EmployeeDashboardScreen',
        );
      }
    } catch (e) {
      developer.log(
        'Error checking employee sidebar tutorial: $e',
        name: 'EmployeeDashboardScreen',
        error: e,
      );
    }
  }

  // Use the immediate start method
  // ignore: unused_element
  void _startTutorial() {
    _startTutorialImmediate();
  }

  void _moveToNextTutorialStep() {
    if (!mounted || !_shouldShowTutorial) return;

    // Total steps = sidebar items + collapse toggle
    final totalSteps =
        (widget.forManagerGwMenu
            ? SidebarConfig.managerItems.length
            : SidebarConfig.employeeItems.length) +
        1;
    if (_currentTutorialStep < totalSteps - 1) {
      final nextStep = _currentTutorialStep + 1;

      setState(() {
        _currentTutorialStep = nextStep;
      });

      // Update global tutorial state
      EmployeeTutorialService.instance.updateTutorialStep(nextStep);

      // Navigate to the screen for this tutorial step
      if (nextStep < EmployeeSidebarTutorialConfig.steps.length) {
        final step = EmployeeSidebarTutorialConfig.steps[nextStep];
        // Only navigate if it's not the collapse toggle
        if (step.route != '__collapse_toggle__') {
          final currentRoute = ModalRoute.of(context)?.settings.name;
          if (currentRoute != step.route) {
            developer.log(
              'Navigating to ${step.route} for tutorial step $nextStep',
              name: 'EmployeeDashboardScreen',
            );
            // Use pushReplacementNamed to replace current screen and avoid GlobalKey conflicts
            Navigator.pushReplacementNamed(context, step.route).then((_) {
              // After navigation completes, wait for the new screen to build
              // The new screen will update context and trigger popup via MainLayout
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Future.delayed(const Duration(milliseconds: 800), () {
                  final tutorialService = EmployeeTutorialService.instance;
                  if (tutorialService.isTutorialActive &&
                      tutorialService.currentContext != null) {
                    // Use the global service to show popup from any screen
                    tutorialService.showTutorialPopup(
                      tutorialService.currentContext!,
                    );
                  }
                });
              });
            });
            return; // Exit early, popup will be shown after navigation
          }
        }
      }

      // Trigger showcase for next step (if no navigation needed)
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _shouldShowTutorial) {
          _showTutorialPopup();
        }
      });
    } else {
      // Tutorial complete
      _completeTutorial();
    }
  }

  void _showTutorialPopup() {
    if (!mounted || !_shouldShowTutorial) return;

    try {
      final keyContext =
          _sidebarTutorialKeys[_currentTutorialStep].currentContext;
      if (keyContext != null) {
        ShowcaseView.get().startShowCase([_sidebarTutorialKeys[_currentTutorialStep]]);
        developer.log(
          'Started showcase for step $_currentTutorialStep',
          name: 'EmployeeDashboardScreen',
        );
      } else {
        developer.log(
          'Key not attached for step $_currentTutorialStep, retrying...',
          name: 'EmployeeDashboardScreen',
        );
        // Retry
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _shouldShowTutorial) {
            try {
              ShowcaseView.get().startShowCase([_sidebarTutorialKeys[_currentTutorialStep]]);
            } catch (e) {
              developer.log(
                'Retry failed: $e',
                name: 'EmployeeDashboardScreen',
              );
            }
          }
        });
      }
    } catch (e) {
      developer.log(
        'Could not start showcase for step $_currentTutorialStep: $e',
        name: 'EmployeeDashboardScreen',
        error: e,
      );
    }
  }

  Future<void> _completeTutorial() async {
    developer.log(
      'Completing employee sidebar tutorial',
      name: 'EmployeeDashboardScreen',
    );
    await EmployeeTutorialService.instance.markTutorialCompleted();

    // Clear global tutorial state
    EmployeeTutorialService.instance.clearTutorialState();

    if (mounted) {
      setState(() {
        _shouldShowTutorial = false;
        _currentTutorialStep = 0;
      });
    }
  }

  Future<void> _skipTutorial() async {
    developer.log(
      'Skipping employee sidebar tutorial',
      name: 'EmployeeDashboardScreen',
    );

    // Dismiss the current showcase overlay
    try {
      ShowcaseView.get().dismiss();
    } catch (e) {
      developer.log(
        'Error dismissing showcase: $e',
        name: 'EmployeeDashboardScreen',
      );
    }

    // Mark tutorial as completed and disable it in settings
    await EmployeeTutorialService.instance.markTutorialCompleted();
    await SettingsService.updateSetting('tutorialEnabled', false);

    // Clear global tutorial state
    EmployeeTutorialService.instance.clearTutorialState();

    if (mounted) {
      setState(() {
        _shouldShowTutorial = false;
        _currentTutorialStep = 0;
      });
    }
  }

  Future<void> _loadAllData() async {
    try {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        error = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Load all data in parallel for faster performance
        final results = await Future.wait([
          DatabaseService.getUserProfile(user.uid),
          DatabaseService.getUserGoals(user.uid),
          StreakService.getCurrentStreak(user.uid),
          StreakService.hasActivityToday(user.uid),
        ]);

        if (!mounted) return;
        setState(() {
          userProfile = results[0] as UserProfile;
          userGoals = results[1] as List<Goal>;
          currentStreak = results[2] as int;
          hasActivityToday = results[3] as bool;
          isLoading = false;
        });
      }
    } catch (e) {
      developer.log(
        'Error loading streak data: $e',
        name: 'EmployeeDashboardScreen',
      );
      // Set default values on error
      if (mounted) {
        setState(() {
          currentStreak = 0;
          hasActivityToday = false;
          // Stop showing "loading" forever if initial fetch failed.
          isLoading = false;
          error = e.toString();
        });
      }
    }
  }

  void _configureDashboardStreams() {
    _userProfileStream = _getUserProfileStream();
    _userGoalsStream = _getUserGoalsStream();
  }

  @override
  void dispose() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      BadgeService.stopRealtimeTracking(user.uid);
      StreakService.stopRealtimeTracking(user.uid);
    }
    super.dispose();
  }

  Stream<UserProfile?> _getUserProfileStream() {
    final uid = _effectiveUserId;
    if (uid == null) return Stream.value(null);
    return FirestoreSafe.stream(
      FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
    ).map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    });
  }

  Stream<List<Goal>> _getUserGoalsStream() {
    final uid = _effectiveUserId;
    if (uid == null) return Stream.value([]);
    return FirestoreSafe.stream(
      FirebaseFirestore.instance
          .collection('goals')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
    ).map((snapshot) {
      final goals = snapshot.docs
          .map((doc) => Goal.fromFirestore(doc))
          .toList();
      // Removed in-memory sort - using Firestore orderBy instead
      return goals;
    });
  }

  Stream<int> _getEarnedBadgesCountStream() {
    final uid = _effectiveUserId;
    if (uid == null) return Stream.value(0);
    return FirestoreSafe.stream(
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('badges')
          .where('isEarned', isEqualTo: true)
          .snapshots(),
    ).map((snapshot) {
      return snapshot.docs
          .where((d) => d.id != 'init')
          .where((d) => d.id.toLowerCase().startsWith('v2_'))
          .length;
    });
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _getDailyMotivation() {
    final motivations = [
      "Every expert was once a beginner. Keep learning!",
      "Progress, not perfection, is the goal.",
      "Your future self will thank you for the work you do today.",
      "Small steps daily lead to big changes yearly.",
      "Believe in yourself and all that you are capable of.",
      "Success is the sum of small efforts repeated day in and day out.",
      "The only way to do great work is to love what you do.",
      "Challenges are opportunities in disguise. Embrace them!",
      "Your potential is limitless when you commit to growth.",
      "Today's effort is tomorrow's achievement.",
      "Consistency is the key to unlocking your potential.",
      "Every setback is a setup for a comeback.",
      "Focus on progress, not perfection.",
      "You are capable of more than you know.",
      "The best time to start was yesterday. The second best is now.",
      "Your dedication will take you places you've never imagined.",
      "Growth happens outside your comfort zone.",
      "Small daily improvements lead to massive results.",
      "You have the power to create the life you want.",
      "Every day is a fresh start to become better.",
      "Your journey of a thousand miles begins with a single step.",
      "Success is built one day at a time.",
      "The only person you should try to be better than is who you were yesterday.",
      "Your hard work today is an investment in your future.",
      "Dream big, work hard, and stay focused.",
      "You are stronger than you think and more capable than you imagine.",
      "Every accomplishment starts with the decision to try.",
      "The future belongs to those who believe in their dreams.",
      "Your attitude determines your direction.",
      "Keep going. Your breakthrough is just around the corner.",
    ];

    // Use day of month to get consistent daily motivation (1-30)
    final dayOfMonth = DateTime.now().day;
    return motivations[(dayOfMonth - 1) % motivations.length];
  }

  @override
  Widget build(BuildContext context) {
    // Always use global service for tutorial state to ensure consistency
    final tutorialService = EmployeeTutorialService.instance;

    // Update context if tutorial is active
    if (tutorialService.isTutorialActive) {
      tutorialService.setCurrentContext(context);

      // Check if we should show tutorial popup for this screen (dashboard)
      // This happens when tutorial first starts or when navigating back to dashboard
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !tutorialService.isTutorialActive) return;

        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute == '/employee_dashboard' &&
            tutorialService.currentTutorialStep <
                EmployeeSidebarTutorialConfig.steps.length) {
          final step = EmployeeSidebarTutorialConfig
              .steps[tutorialService.currentTutorialStep];
          if (step.route == '/employee_dashboard') {
            // This is the dashboard step, show popup
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted && tutorialService.isTutorialActive) {
                // ignore: use_build_context_synchronously
                tutorialService.showTutorialPopup(context);
              }
            });
          }
        }
      });
    }

    // Get tutorial state from global service (prefer global over local)
    final tutorialStep = tutorialService.isTutorialActive
        ? tutorialService.currentTutorialStep
        : (_shouldShowTutorial ? _currentTutorialStep : null);
    final tutorialKeys = tutorialService.isTutorialActive
        ? tutorialService.tutorialKeys
        : (_shouldShowTutorial && _sidebarTutorialKeys.isNotEmpty
              ? _sidebarTutorialKeys
              : null);
    // Always use global service callbacks to ensure consistent navigation
    final onTutorialNext = tutorialService.isTutorialActive
        ? tutorialService.onTutorialNext
        : (_shouldShowTutorial ? _moveToNextTutorialStep : null);
    final onTutorialSkip = tutorialService.isTutorialActive
        ? tutorialService.onTutorialSkip
        : (_shouldShowTutorial ? _skipTutorial : null);

    final sidebarItems =
        widget.forManagerGwMenu && widget.managerGwMenuRoute != null
        ? SidebarConfig.managerItems
        : SidebarConfig.employeeItems;
    final routeName =
        widget.forManagerGwMenu && widget.managerGwMenuRoute != null
        ? widget.managerGwMenuRoute!
        : '/employee_dashboard';
    return AppScaffold(
      title: 'Employee Dashboard',
      showAppBar: false,
      embedded: widget.embedded,
      items: sidebarItems,
      currentRouteName: routeName,
      topRightAction: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [NotificationsBell()],
      ),
      tutorialStepIndex: tutorialStep,
      sidebarTutorialKeys: tutorialKeys,
      onTutorialNext: onTutorialNext,
      onTutorialSkip: onTutorialSkip,
      onNavigate: (route) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        if (mounted) {
          navigator.pushNamedAndRemoveUntil('/landing', (route) => false);
        }
      },
      content: ValueListenableBuilder<bool>(
        valueListenable: employeeDashboardLightModeNotifier,
        builder: (context, light, _) {
          return AppComponents.backgroundWithImage(
            blurSigma: 0,
            imagePath: light
                ? 'assets/light_mode_bg.png'
                : 'assets/khono_bg.png',
            gradientColors: light
                ? [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.08),
                  ]
                : null,
            child: EmployeeDashboardThemeScope(
              light: light,
              child: StreamBuilder<UserProfile?>(
                stream: _userProfileStream,
                builder: (context, profileSnapshot) {
                  return StreamBuilder<List<Goal>>(
                    stream: _userGoalsStream,
                    builder: (context, goalsSnapshot) {
                      // Use any available data while streams connect to avoid showing a spinner
                      // Always prefer stream data, but fall back to cached data if streams fail
                      // This prevents flashing of error messages when streams temporarily fail
                      final effectiveProfile =
                          profileSnapshot.data ??
                          userProfile ??
                          _fallbackUserProfileFromAuth();
                      final effectiveGoals = goalsSnapshot.data ?? userGoals;

                      // Log errors but don't block the dashboard from showing
                      if (profileSnapshot.hasError || goalsSnapshot.hasError) {
                        final error =
                            profileSnapshot.error ?? goalsSnapshot.error;
                        developer.log(
                          'Dashboard stream error (showing dashboard anyway): $error',
                          name: 'EmployeeDashboardScreen',
                          error: error,
                        );
                      }

                      // If we have no profile data at all, show loading spinner
                      if (effectiveProfile == null &&
                          _effectiveUserId != null) {
                        final timedOut =
                            _initialProfileLoadWatch.elapsed >
                            const Duration(seconds: 12);
                        if (timedOut) {
                          return _buildLoadTimeout(
                            message:
                                'We couldn’t load your profile. This is usually caused by a connection issues.',
                          );
                        }
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.activeColor,
                            ),
                          ),
                        );
                      }

                      // Update local state with latest (or fallback) data
                      userProfile = effectiveProfile;
                      userGoals = List<Goal>.from(effectiveGoals);
                      // We have data; stop the timeout watch.
                      if (_initialProfileLoadWatch.isRunning) {
                        _initialProfileLoadWatch.stop();
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(() {}); // Trigger rebuild to restart streams
                        },
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: AppSpacing.screenPadding,
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDashboardHeader(),
                                    const SizedBox(height: AppSpacing.lg),
                                    _buildQuickStats(),
                                    const SizedBox(height: AppSpacing.lg),
                                    _buildMotivationRecentAndQuickActionsRow(),
                                    const SizedBox(height: AppSpacing.lg),
                                    _buildSeasonAndTopPerformersRow(),
                                  ],
                                ),
                              ),
                            ),
                            SafeArea(
                              top: false,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: AppSpacing.xxl,
                                  right: AppSpacing.xxl,
                                  bottom: AppSpacing.md,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: VersionControlWidget(
                                    textColor: _dashFg(context),
                                    hoverColor: _dashFg(context),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _buildWelcomeCard() {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'User';

    // Try to get name from onboarding collection first, then fallback to other sources
    if (user != null) {
      return FutureBuilder<String?>(
        future:
            _onboardingNameFuture ??
            DatabaseService.getUserNameFromOnboarding(
              userId: user.uid,
              email: user.email,
            ),
        builder: (context, snapshot) {
          // Determine userName with priority: onboarding fullName > userProfile > Firebase Auth > email
          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            // Use full name from onboarding
            userName = snapshot.data!;
          } else if (userProfile?.displayName != null &&
              userProfile!.displayName.isNotEmpty) {
            userName = userProfile!.displayName;
          } else if (user.displayName != null && user.displayName!.isNotEmpty) {
            userName = user.displayName!;
          } else if (user.email != null && user.email!.isNotEmpty) {
            userName = user.email!.split('@').first;
          }

          return _buildWelcomeCardContent(userName);
        },
      );
    }

    return _buildWelcomeCardContent(userName);
  }

  Widget _buildWelcomeCardContent(String userName) {
    final greeting = _getTimeBasedGreeting();
    final currentHour = DateTime.now().hour;
    String motivationalMessage;
    if (currentHour < 12) {
      motivationalMessage = 'Ready to start your day strong?';
    } else if (currentHour < 17) {
      motivationalMessage = 'Keep up the great momentum!';
    } else {
      motivationalMessage = 'Time to wrap up and reflect on your progress!';
    }

    // Determine avatar photo URL: prefer Firestore profile; only fall back to Auth if profile is not yet loaded
    final authUserForAvatar = FirebaseAuth.instance.currentUser;
    String photoUrl = '';
    if (userProfile == null) {
      photoUrl = (authUserForAvatar?.photoURL ?? '');
    } else {
      final p = userProfile!.profilePhotoUrl ?? '';
      photoUrl = p.isNotEmpty ? p : '';
    }

    return AppComponents.accentCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _dashIsLight()
                    ? const Color(0x33000000)
                    : Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
              color: Colors.black.withValues(alpha: 0.15),
            ),
            child: ClipOval(
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.person, color: _dashFg(context), size: 36),
                    )
                  : Icon(Icons.person, color: _dashFg(context), size: 36),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $userName!',
                  style: AppTypography.heading4.copyWith(
                    color: _dashFg(context),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  motivationalMessage,
                  style: AppTypography.bodyMedium.copyWith(
                    color: _dashFg(context),
                  ),
                ),
                if (userProfile?.badgesV2.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        size: 16,
                        color: _dashFg(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${userProfile!.badgesV2.length} Badge${userProfile!.badgesV2.length == 1 ? '' : 's'}',
                        style: AppTypography.bodySmall.copyWith(
                          color: _dashFg(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'Name Surname';
    if ((userProfile?.displayName ?? '').trim().isNotEmpty) {
      userName = userProfile!.displayName.trim();
    } else if ((user?.displayName ?? '').trim().isNotEmpty) {
      userName = user!.displayName!.trim();
    } else if ((user?.email ?? '').trim().isNotEmpty) {
      userName = user!.email!.split('@').first;
    }

    return Row(
      children: [
        Flexible(
          child: Text(
            'Employee Dashboard',
            style: AppTypography.heading3.copyWith(color: _dashFg(context)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Text(
            'Hello, $userName',
            style: AppTypography.bodyMedium.copyWith(color: _dashFg(context)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildDailyMotivationCard() {
    return AppComponents.card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppColors.activeColor.withValues(alpha: 0.1),
              AppColors.warningColor.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors
                    .transparent, // Changed background color to transparent
                borderRadius: BorderRadius.circular(50),
              ),
              child: Image.asset(
                'Innovation_Brainstorm/innovation_brainstorm_red_badge_white.png',
                width: 78, // Increased from 24 to 48
                height: 78, // Increased from 24 to 48
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Motivation',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _dashFg(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDailyMotivation(),
                    style: AppTypography.bodyMedium.copyWith(
                      color: _dashFg(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMotivationCompactCard() {
    return AppComponents.card(
      backgroundColor: _dashCard(context),
      borderColor: _dashBorder(context),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Image.asset(
              'assets/Innovation_Brainstorm.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Motivation',
                  style: AppTypography.heading4.copyWith(
                    color: _dashFg(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getDailyMotivation(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: _dashFg(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    // Calculate real stats from user data
    // Only count approved goals as active (pending/rejected goals should not appear)
    final activeGoals = userGoals
        .where(
          (goal) =>
              goal.approvalStatus == GoalApprovalStatus.approved &&
              (goal.status != GoalStatus.completed) &&
              (goal.progress < 100),
        )
        .length;
    final completedGoals = userGoals
        .where(
          (goal) => goal.status == GoalStatus.completed || goal.progress >= 100,
        )
        .length;
    final totalPoints = userProfile?.totalPoints ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AppComponents.kpiCard(
                label: 'Active Goals',
                value: activeGoals.toString(),
                backgroundColor: _dashCard(context),
                borderColor: _dashBorder(context),
                valueColor: _dashFg(context),
                labelColor: _dashFg(context),
                iconWidget: SizedBox(
                  width: 64,
                  height: 64,
                  child: _dashDashboardAsset(
                    'assets/Goal_Target/Goal_Target_White_Badge_Red.png',
                  ),
                ),
                iconColor: AppColors.activeColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppComponents.kpiCard(
                label: 'Completed',
                value: completedGoals.toString(),
                backgroundColor: _dashCard(context),
                borderColor: _dashBorder(context),
                valueColor: _dashFg(context),
                labelColor: _dashFg(context),
                iconWidget: SizedBox(
                  width: 64,
                  height: 64,
                  child: _dashDashboardAsset(
                    'assets/Approved_Tick/Approved_White_Badge_Red.png',
                  ),
                ),
                iconColor: AppColors.successColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppComponents.kpiCard(
                label: 'Points Achieved',
                value: _formatNumber(totalPoints),
                backgroundColor: _dashCard(context),
                borderColor: _dashBorder(context),
                valueColor: _dashFg(context),
                labelColor: _dashFg(context),
                iconWidget: SizedBox(
                  width: 64,
                  height: 64,
                  child: Image.asset(
                    'assets/Team_Meeting/Team.png',
                    fit: BoxFit.contain,
                  ),
                ),
                iconColor: AppColors.warningColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: AppComponents.kpiCard(
                label: 'Current Streak',
                value: '${currentStreak.toString()} days',
                backgroundColor: _dashCard(context),
                borderColor: _dashBorder(context),
                valueColor: _dashFg(context),
                labelColor: _dashFg(context),
                iconWidget: SizedBox(
                  width: 64,
                  height: 64,
                  child: _dashDashboardAsset(
                    'assets/Goal_Target/Goal_Target_White_Badge_Red.png',
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppComponents.kpiCard(
                label: 'Daily Activity',
                value: hasActivityToday ? '1' : '0',
                backgroundColor: _dashCard(context),
                borderColor: _dashBorder(context),
                valueColor: _dashFg(context),
                labelColor: _dashFg(context),
                iconWidget: SizedBox(
                  width: 64,
                  height: 64,
                  child: _dashDashboardAsset(
                    'assets/Task_Management/Task_Management_White_Badge_Red.png',
                  ),
                ),
                iconColor: hasActivityToday
                    ? AppColors.successColor
                    : (_dashIsLight()
                          ? _dashFg(context)
                          : AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StreamBuilder<int>(
                stream: _getEarnedBadgesCountStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return AppComponents.kpiCard(
                    label: 'Badges Achieved',
                    value: count.toString(),
                    backgroundColor: _dashCard(context),
                    borderColor: _dashBorder(context),
                    valueColor: _dashFg(context),
                    labelColor: _dashFg(context),
                    iconWidget: SizedBox(
                      width: 48,
                      height: 48,
                      child: Image.asset(
                        'assets/Badge.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: const Color(0xFF2C2C2C),
                          content: Text(
                            'You have $count badge${count == 1 ? '' : 's'}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Left: Daily Motivation stacked above Recent Activities. Right: Quick Actions
  /// full height (matches mockup).
  Widget _buildMotivationRecentAndQuickActionsRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDailyMotivationCompactCard(),
                const SizedBox(height: AppSpacing.lg),
                _buildRecentActivity(),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 5,
            child: _buildCombinedQuickActionsCard(fillHeight: true),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonAndTopPerformersRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: _buildSeasonProgressAlertsCard()),
        const SizedBox(width: AppSpacing.md),
        Expanded(flex: 3, child: _buildTopPerformersCard()),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  // This method is no longer needed as we're using AppComponents.kpiCard

  Widget _buildRecentActivity() {
    // Get recent goals sorted by creation date
    final recentGoals = List<Goal>.from(userGoals)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return AppComponents.card(
      backgroundColor: _dashCard(context),
      borderColor: _dashBorder(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Image.asset(
                  _dashBellAssetPath(context),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Recent Activities',
                style: AppTypography.heading4.copyWith(color: _dashFg(context)),
              ),
            ],
          ),
          Divider(height: 1, thickness: 1, color: _dashDivider(context)),
          const SizedBox(height: AppSpacing.md),
          if (recentGoals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No recent activity',
                  style: AppTypography.bodyMedium.copyWith(
                    color: _dashFg(context),
                  ),
                ),
              ),
            )
          else
            ...recentGoals.take(3).map((goal) {
              Color iconColor;
              String actionText;
              switch (goal.status) {
                case GoalStatus.completed:
                  iconColor = AppColors.successColor;
                  actionText = 'Completed';
                  break;
                case GoalStatus.acknowledged:
                  iconColor = AppColors.successColor;
                  actionText = 'Acknowledged';
                  break;
                case GoalStatus.inProgress:
                  iconColor = AppColors.activeColor;
                  actionText = 'Started working on';
                  break;
                case GoalStatus.notStarted:
                  iconColor = AppColors.activeColor;
                  actionText = 'Created';
                  break;
                case GoalStatus.paused:
                  iconColor = AppColors.textSecondary;
                  actionText = 'Paused';
                  break;
                case GoalStatus.burnout:
                  iconColor = AppColors.dangerColor;
                  actionText = 'On hold';
                  break;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppComponents.activityItem(
                  iconWidget: SizedBox(
                    width: 28,
                    height: 28,
                    child: _dashDashboardAsset(
                      'assets/Goal_Target/Goal_Target_White_Badge_Red.png',
                      size: 28,
                    ),
                  ),
                  title: '$actionText "${goal.title}"',
                  subtitle: _getTimeAgo(goal.createdAt),
                  iconColor: iconColor,
                  titleColor: _dashFg(context),
                  subtitleColor: _dashFg(context),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // This method is no longer needed as we're using AppComponents.activityItem

  // ignore: unused_element
  Widget _buildQuickActions() {
    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: AppTypography.heading4.copyWith(color: _dashFg(context)),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Goal Workspace',
                  onPressed: () {
                    Navigator.pushNamed(context, '/my_goal_workspace');
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Progress Visuals',
                  onPressed: () {
                    Navigator.pushNamed(context, '/progress_visuals');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Leaderboard',
                  onPressed: () {
                    Navigator.pushNamed(context, '/leaderboard');
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Badges & Points',
                  onPressed: () {
                    Navigator.pushNamed(context, '/badges_points');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedQuickActionsCard({bool fillHeight = false}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Image.asset(
                'assets/Innovation_Brainstorm.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: AppTypography.heading4.copyWith(
                      color: _dashFg(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Additional description can be included if required.',
                    style: AppTypography.bodySmall.copyWith(
                      color: _dashFg(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (fillHeight)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionTile(
                        label: 'Goal Workspace',
                        assetPath:
                            'assets/Project_Management/Management_White_Badge_Red.png',
                        onTap: () =>
                            Navigator.pushNamed(context, '/my_goal_workspace'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _QuickActionTile(
                        label: 'Progress Visuals',
                        assetPath:
                            'assets/Process_Flows_Automation/Process_Flows_Automation_White_Badge_Red.png',
                        onTap: () =>
                            Navigator.pushNamed(context, '/progress_visuals'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionTile(
                        label: 'Leaderboard',
                        assetPath:
                            'assets/Project_Direction_Acceleration/Project_Direction_Acceleration_White_Badge_Red.png',
                        onTap: () =>
                            Navigator.pushNamed(context, '/leaderboard'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _QuickActionTile(
                        label: 'Badges & Points',
                        assetPath:
                            'assets/Business_Growth_Development/Business_Growth_Development_White_Badge_Red.png',
                        onTap: () =>
                            Navigator.pushNamed(context, '/badges_points'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  label: 'Goal Workspace',
                  assetPath:
                      'assets/Project_Management/Management_White_Badge_Red.png',
                  onTap: () =>
                      Navigator.pushNamed(context, '/my_goal_workspace'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _QuickActionTile(
                  label: 'Progress Visuals',
                  assetPath:
                      'assets/Process_Flows_Automation/Process_Flows_Automation_White_Badge_Red.png',
                  onTap: () =>
                      Navigator.pushNamed(context, '/progress_visuals'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  label: 'Leaderboard',
                  assetPath:
                      'assets/Project_Direction_Acceleration/Project_Direction_Acceleration_White_Badge_Red.png',
                  onTap: () => Navigator.pushNamed(context, '/leaderboard'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _QuickActionTile(
                  label: 'Badges & Points',
                  assetPath:
                      'assets/Business_Growth_Development/Business_Growth_Development_White_Badge_Red.png',
                  onTap: () => Navigator.pushNamed(context, '/badges_points'),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    final card = AppComponents.card(
      backgroundColor: _dashCard(context),
      borderColor: _dashBorder(context),
      child: content,
    );

    if (!fillHeight) return card;
    return SizedBox.expand(child: card);
  }

  Widget _buildSeasonProgressAlertsCard() {
    final uid = _effectiveUserId;
    if (uid == null) {
      return AppComponents.card(
        backgroundColor: _dashCard(context),
        borderColor: _dashBorder(context),
        child: Text(
          'Season Progress Alerts',
          style: AppTypography.heading4.copyWith(color: _dashFg(context)),
        ),
      );
    }
    return AppComponents.card(
      backgroundColor: _dashCard(context),
      borderColor: _dashBorder(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Image.asset(
                  _dashBellAssetPath(context),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Season Progress Alerts',
                style: AppTypography.heading4.copyWith(color: _dashFg(context)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StreamBuilder<List<Season>>(
            stream: SeasonService.getParticipantSeasonsStream(uid),
            builder: (context, snapshot) {
              final seasons = (snapshot.data ?? [])
                  .where((s) => s.status == SeasonStatus.active)
                  .take(3)
                  .toList();
              if (seasons.isEmpty) {
                return Text(
                  'No active season progress yet.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: _dashFg(context),
                  ),
                );
              }
              return Column(
                children: seasons.map((season) {
                  final total = season.participantIds.length;
                  final completed = season.participantIds
                      .where((id) => _isSeasonParticipantComplete(season, id))
                      .length;
                  final progress = total == 0 ? 0.0 : completed / total;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          season.title,
                          style: AppTypography.bodySmall.copyWith(
                            color: _dashFg(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Progress: $completed/$total Employees Completed',
                          style: AppTypography.bodySmall.copyWith(
                            color: _dashFg(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: _dashIsLight()
                              ? const Color(0x33000000)
                              : AppColors.borderColor,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.activeColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  bool _isSeasonParticipantComplete(Season season, String participantId) {
    final participation = season.participations[participantId];
    if (participation == null) return false;
    int totalMilestones = 0;
    int completed = 0;
    for (final challenge in season.challenges) {
      totalMilestones += challenge.milestones.length;
      for (final milestone in challenge.milestones) {
        final key = '${challenge.id}.${milestone.id}';
        final status =
            participation.milestoneProgress[key] ??
            participation.milestoneProgress[milestone.id];
        if (status == MilestoneStatus.completed) {
          completed++;
        }
      }
    }
    return totalMilestones > 0 && completed == totalMilestones;
  }

  Widget _buildTopPerformersCard() {
    return AppComponents.card(
      backgroundColor: _dashCard(context),
      borderColor: _dashBorder(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Image.asset(
                  _dashBellAssetPath(context),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Top Performers',
                style: AppTypography.heading4.copyWith(color: _dashFg(context)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirestoreSafe.stream(
              FirebaseFirestore.instance
                  .collection('users')
                  .limit(250)
                  .snapshots(),
            ),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? const [];
              final rows =
                  docs
                      .map((d) => d.data())
                      .where((u) {
                        final role = (u['role'] ?? 'employee')
                            .toString()
                            .toLowerCase();
                        final optIn =
                            u['leaderboardOptin'] == true ||
                            u['leaderboardParticipation'] == true;
                        return role == 'employee' && optIn;
                      })
                      .map(
                        (u) => {
                          'name': (u['displayName'] ?? 'Employee').toString(),
                          'points': (u['totalPoints'] is num)
                              ? (u['totalPoints'] as num).toInt()
                              : int.tryParse('${u['totalPoints'] ?? 0}') ?? 0,
                        },
                      )
                      .toList()
                    ..sort(
                      (a, b) =>
                          (b['points'] as int).compareTo(a['points'] as int),
                    );
              final top = rows.take(3).toList();
              if (top.isEmpty) {
                return Text(
                  'No top performers yet.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: _dashFg(context),
                  ),
                );
              }
              return Column(
                children: top.map((u) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _dashTopPerfRowBg(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _dashTopPerfRowBorder(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Image.asset(
                              'assets/Star.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              u['name'] as String,
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: _dashFg(context),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _kPointsAccent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${u['points']} Points',
                              style: AppTypography.caption.copyWith(
                                color: _dashFg(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // This method is no longer needed as we're using AppComponents.primaryButton

  // ignore: unused_element
  Widget _buildUpcomingGoals() {
    // Get active goals sorted by target date
    final upcomingGoals =
        userGoals
            .where(
              (goal) =>
                  goal.approvalStatus == GoalApprovalStatus.approved &&
                  goal.status != GoalStatus.completed &&
                  goal.progress < 100,
            )
            .toList()
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Upcoming Goals',
                style: AppTypography.heading4.copyWith(color: _dashFg(context)),
              ),
              if (upcomingGoals.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UpcomingGoalsListScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'View All',
                    style: AppTypography.bodySmall.copyWith(
                      color: _dashFg(context),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (upcomingGoals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No active goals',
                  style: AppTypography.bodyMedium.copyWith(
                    color: _dashFg(context),
                  ),
                ),
              ),
            )
          else
            ...upcomingGoals.take(3).map((goal) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _buildGoalItem(goal: goal),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildGoalItem({required Goal goal}) {
    final now = DateTime.now();
    final daysUntilDeadline = goal.targetDate.difference(now).inDays;
    final isOverdue = daysUntilDeadline < 0;
    final progress = goal.progress / 100.0; // Convert to 0-1 range

    String deadlineText;
    Color deadlineColor = _dashFg(context);

    if (isOverdue) {
      deadlineText =
          'Overdue by ${(-daysUntilDeadline)} day${(-daysUntilDeadline) == 1 ? '' : 's'}';
      deadlineColor = _dashFg(context);
    } else if (daysUntilDeadline == 0) {
      deadlineText = 'Due today';
      deadlineColor = _dashFg(context);
    } else if (daysUntilDeadline == 1) {
      deadlineText = 'Due tomorrow';
      deadlineColor = _dashFg(context);
    } else if (daysUntilDeadline <= 7) {
      deadlineText = 'Due in $daysUntilDeadline days';
      deadlineColor = _dashFg(context);
    } else {
      deadlineText = 'Due in $daysUntilDeadline days';
    }

    return InkWell(
      onTap: () {
        if (goal.approvalStatus != GoalApprovalStatus.approved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Awaiting manager approval.')),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GoalDetailScreen(goal: goal)),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: AppComponents.card(
        padding: const EdgeInsets.all(12),
        backgroundColor: _dashCard(context),
        borderColor: _dashBorder(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    goal.title,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _dashFg(context),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(
                      goal.priority,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getPriorityColor(
                        goal.priority,
                      ).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    goal.priority.name.toUpperCase(),
                    style: AppTypography.bodySmall.copyWith(
                      color: _dashFg(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              deadlineText,
              style: AppTypography.muted.copyWith(color: deadlineColor),
            ),
            const SizedBox(height: 8),
            AppComponents.progressBar(
              value: progress,
              label: '${goal.progress}% Complete',
              labelColor: _dashFg(context),
              backgroundColor: _dashIsLight() ? const Color(0x33000000) : null,
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return AppColors.dangerColor;
      case GoalPriority.medium:
        return AppColors.warningColor;
      case GoalPriority.low:
        return AppColors.successColor;
    }
  }

  Widget _buildLoadTimeout({required String message}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppComponents.card(
            backgroundColor: _dashCard(context),
            borderColor: _dashBorder(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Still loading…',
                  style: AppTypography.heading4.copyWith(
                    color: _dashFg(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: _dashFg(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        _initialProfileLoadWatch
                          ..reset()
                          ..start();
                        await _loadAllData();
                        if (mounted) setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.activeColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        await AuthService().signOut();
                        if (mounted) {
                          navigator.pushNamedAndRemoveUntil(
                            '/landing',
                            (route) => false,
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _dashIsLight()
                            ? const Color(0xFF000000)
                            : Colors.white,
                        side: BorderSide(
                          color: _dashIsLight()
                              ? const Color(0x33000000)
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
                if ((error ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: AppTypography.caption.copyWith(
                      color: _dashFg(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  UserProfile? _fallbackUserProfileFromAuth() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final email = user.email ?? '';
    final displayName = (user.displayName ?? '').trim().isNotEmpty
        ? user.displayName!.trim()
        : (email.isNotEmpty ? email.split('@').first : 'User');
    return UserProfile(
      uid: user.uid,
      email: email,
      displayName: displayName,
      totalPoints: userProfile?.totalPoints ?? 0,
      level: userProfile?.level ?? 1,
      badges: userProfile?.badges ?? const [],
      badgesV2: userProfile?.badgesV2 ?? const [],
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({
    required this.label,
    required this.assetPath,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final VoidCallback onTap;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final light = _dashIsLight();
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: _hover ? _kQuickActionHoverRed : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _hover
                    ? _kQuickActionHoverRed
                    : (light
                          ? const Color(0x33000000)
                          : Colors.white.withValues(alpha: 0.25)),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  width: double.infinity,
                  child: _quickActionLeadingIcon(
                    context,
                    hover: _hover,
                    assetPath: widget.assetPath,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: _hover ? Colors.white : _dashFg(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
