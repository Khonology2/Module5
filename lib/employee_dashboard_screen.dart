import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/employee_profile_screen.dart'; // Import EmployeeProfileScreen
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_components.dart';
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
import 'package:showcaseview/showcaseview.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

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

  // Tutorial state
  bool _shouldShowTutorial = false;
  int _currentTutorialStep = 0;
  final List<GlobalKey> _sidebarTutorialKeys = List.generate(
    11, // 10 sidebar items + 1 collapse toggle
    (index) => GlobalKey(),
  );

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Load streak data after a short delay to ensure other data loads first
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadStreakData();
    });

    // Start real-time badge tracking and streak tracking for this user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      BadgeService.startRealtimeTracking(user.uid);
      StreakService.startRealtimeTracking(user.uid);
    }

    // Check if tutorial should be shown
    _checkTutorial();
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
        ShowCaseWidget.of(context).startShowCase([_sidebarTutorialKeys[0]]);
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
    final totalSteps = SidebarConfig.employeeItems.length + 1;
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
        ShowCaseWidget.of(
          context,
        ).startShowCase([_sidebarTutorialKeys[_currentTutorialStep]]);
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
              ShowCaseWidget.of(
                context,
              ).startShowCase([_sidebarTutorialKeys[_currentTutorialStep]]);
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
      ShowCaseWidget.of(context).dismiss();
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

  Future<void> _loadStreakData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final streak = await StreakService.getCurrentStreak(user.uid);
        final activityToday = await StreakService.hasActivityToday(user.uid);

        if (mounted) {
          setState(() {
            currentStreak = streak;
            hasActivityToday = activityToday;
          });
        }
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
        });
      }
    }
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

  Future<void> _loadUserData() async {
    try {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        error = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await DatabaseService.getUserProfile(user.uid);
        final goals = await DatabaseService.getUserGoals(user.uid);

        if (!mounted) return;
        setState(() {
          userProfile = profile;
          userGoals = goals;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Stream<UserProfile?> _getUserProfileStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return UserProfile.fromFirestore(doc);
        });
  }

  Stream<List<Goal>> _getUserGoalsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final goals = snapshot.docs
              .map((doc) => Goal.fromFirestore(doc))
              .toList();
          goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return goals;
        });
  }

  Stream<int> _getEarnedBadgesCountStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('badges')
        .where('isEarned', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.where((d) => d.id != 'init').length)
        .handleError((_) => 0);
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

    return AppScaffold(
      title: 'Employee Dashboard',
      showAppBar: false,
      items: SidebarConfig.employeeItems,
      currentRouteName: '/employee_dashboard',
      topRightAction: _profileButton(context),
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
          navigator.pushNamedAndRemoveUntil('/sign_in', (route) => false);
        }
      },
      content: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: AppComponents.backgroundWithImage(
          imagePath: 'assets/khono_bg.png',
          child: StreamBuilder<UserProfile?>(
            stream: _getUserProfileStream(),
            builder: (context, profileSnapshot) {
              return StreamBuilder<List<Goal>>(
                stream: _getUserGoalsStream(),
                builder: (context, goalsSnapshot) {
                  // Use any available data while streams connect to avoid showing a spinner
                  final effectiveProfile = profileSnapshot.data ?? userProfile;
                  final effectiveGoals = goalsSnapshot.data ?? userGoals;
                  if (effectiveProfile == null) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.activeColor,
                        ),
                      ),
                    );
                  }

                  // Handle errors
                  if (profileSnapshot.hasError || goalsSnapshot.hasError) {
                    final error = profileSnapshot.error ?? goalsSnapshot.error;
                    final errorMessage = error.toString();

                    // Check if it's a Firestore index error
                    if (errorMessage.contains('failed-precondition') ||
                        errorMessage.contains('index')) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 64,
                              color: AppColors.warningColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Setting up your dashboard...',
                              style: AppTypography.heading4,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This is your first time using the app. Let\'s get you started!',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(
                                  context,
                                  '/my_goal_workspace',
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create Your First Goal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.activeColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppColors.dangerColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading dashboard',
                            style: AppTypography.heading4,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please try again in a moment',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(
                                () {},
                              ); // Trigger rebuild to restart streams
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  // Update local state with latest (or fallback) data
                  userProfile = effectiveProfile;
                  userGoals = List<Goal>.from(effectiveGoals);

                  return RefreshIndicator(
                    onRefresh: () async {
                      setState(() {}); // Trigger rebuild to restart streams
                    },
                    child: SingleChildScrollView(
                      padding: AppSpacing.screenPadding,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeCard(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildDailyMotivationCard(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildQuickStats(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildRecentActivity(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildQuickActions(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildUpcomingGoals(),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _profileButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<String?>(
      future: user != null
          ? DatabaseService.getUserNameFromOnboarding(
              userId: user.uid,
              email: user.email,
            )
          : Future.value(null),
      builder: (context, snapshot) {
        String userName = 'User';
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty) {
          userName = snapshot.data!;
        } else if (user?.displayName != null && user!.displayName!.isNotEmpty) {
          userName = user.displayName!;
        } else if (user?.email != null && user!.email!.isNotEmpty) {
          userName = user.email!.split('@').first;
        }

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const EmployeeProfileScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  userName,
                  style: AppTypography.bodySmall.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard() {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'User';

    // Try to get name from onboarding collection first, then fallback to other sources
    if (user != null) {
      return FutureBuilder<String?>(
        future: DatabaseService.getUserNameFromOnboarding(
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
                color: Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
              color: Colors.black.withValues(alpha: 0.15),
            ),
            child: ClipOval(
              child: photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 36,
                      ),
                    )
                  : const Icon(Icons.person, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting, $userName!', style: AppTypography.heading4),
                const SizedBox(height: 5),
                Text(
                  motivationalMessage,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (userProfile?.level != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.military_tech,
                        size: 16,
                        color: AppColors.warningColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Level ${userProfile!.level}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (userProfile!.badges.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.workspace_premium,
                          size: 16,
                          color: AppColors.successColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${userProfile!.badges.length} Badge${userProfile!.badges.length == 1 ? '' : 's'}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                      color: AppColors.activeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDailyMotivation(),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
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

  Widget _buildQuickStats() {
    // Calculate real stats from user data
    final activeGoals = userGoals
        .where(
          (goal) =>
              (goal.status != GoalStatus.completed) && (goal.progress < 100),
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
                iconWidget: SizedBox(
                  width: 48,
                  height: 48,
                  child: Image.asset(
                    'Goal_Target/Goal_Target_White_Badge_Red_Badge_White.png', // Corrected path to use forward slashes
                    fit: BoxFit.contain,
                  ),
                ), // Replaced icon with iconWidget
                iconColor: AppColors.activeColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppComponents.kpiCard(
                label: 'Completed',
                value: completedGoals.toString(),
                iconWidget: SizedBox(
                  width: 37,
                  height: 37,
                  child: Image.asset(
                    'Approved_Tick/Approved_White_Badge_Red.png',
                    fit: BoxFit.contain,
                  ),
                ), // Replaced icon with iconWidget
                iconColor: AppColors.successColor,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppComponents.kpiCard(
                label: 'Points',
                value: _formatNumber(totalPoints),
                iconWidget: SizedBox(
                  width: 37, // Adjust size as needed
                  height: 37, // Adjust size as needed
                  child: Image.asset(
                    'process_flows_automation/Process_Flows_Automation_White_Badge_Red.png', // Corrected path and filename
                    fit: BoxFit.contain,
                  ),
                ), // Replaced icon with iconWidget
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
                icon: hasActivityToday
                    ? Icons.local_fire_department
                    : Icons.local_fire_department_outlined,
                iconColor: hasActivityToday
                    ? AppColors.warningColor
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppComponents.kpiCard(
                label: 'Today\'s Activity',
                value: hasActivityToday ? 'Active' : 'None',
                iconWidget: SizedBox(
                  width: 37,
                  height: 37,
                  child: Image.asset(
                    'Approved_Tick/Approved_White_Badge_Red.png',
                    fit: BoxFit.contain,
                  ),
                ), // Replaced icon with iconWidget
                iconColor: hasActivityToday
                    ? AppColors.successColor
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StreamBuilder<int>(
                stream: _getEarnedBadgesCountStream(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return AppComponents.kpiCard(
                    label: 'Badges',
                    value: count.toString(),
                    icon: Icons.workspace_premium,
                    iconColor: AppColors.successColor,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'You have $count badge${count == 1 ? '' : 's'}',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: AppTypography.heading4),
          const SizedBox(height: AppSpacing.md),
          if (recentGoals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    SizedBox(
                      width: 48, // Set a consistent size for the image
                      height: 48,
                      child: Image.asset(
                        'Approved_Tick/approved_red_badge_white.png', // Updated to use the new asset
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recent activity',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start by creating your first goal!',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
                  iconWidget: Image.asset(
                    'Approved_Tick/approved_red_badge_white.png',
                    width: 60, // Match the size defined in activityItem
                    height: 60, // Match the size defined in activityItem
                    fit: BoxFit.contain,
                  ),
                  title: '$actionText "${goal.title}"',
                  subtitle: _getTimeAgo(goal.createdAt),
                  iconColor:
                      iconColor, // iconColor is still used for text if not replaced
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

  Widget _buildQuickActions() {
    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTypography.heading4),
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

  // This method is no longer needed as we're using AppComponents.primaryButton

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
              Text('Upcoming Goals', style: AppTypography.heading4),
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
                      color: AppColors.activeColor,
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
                child: Column(
                  children: [
                    SizedBox(
                      width: 78, // Set a consistent size for the image
                      height: 78,
                      child: Image.asset(
                        'Business_Growth_Development/Growth_Development_Red.png', // Replaced flag icon with custom image
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No active goals',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create your first goal to get started!',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/my_goal_workspace');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Goal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.activeColor,
                      ),
                    ),
                  ],
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
    Color deadlineColor = AppColors.textSecondary;

    if (isOverdue) {
      deadlineText =
          'Overdue by ${(-daysUntilDeadline)} day${(-daysUntilDeadline) == 1 ? '' : 's'}';
      deadlineColor = AppColors.dangerColor;
    } else if (daysUntilDeadline == 0) {
      deadlineText = 'Due today';
      deadlineColor = AppColors.warningColor;
    } else if (daysUntilDeadline == 1) {
      deadlineText = 'Due tomorrow';
      deadlineColor = AppColors.warningColor;
    } else if (daysUntilDeadline <= 7) {
      deadlineText = 'Due in $daysUntilDeadline days';
      deadlineColor = AppColors.warningColor;
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
        backgroundColor: AppColors.elevatedBackground,
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
                      color: _getPriorityColor(goal.priority),
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
}
