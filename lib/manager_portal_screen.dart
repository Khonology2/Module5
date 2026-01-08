import 'package:flutter/material.dart';
import 'package:pdh/widgets/sidebar.dart'; // Import ResponsiveSidebar
import 'package:pdh/manager_review_team_dashboard_screen.dart'; // Import ManagerReviewTeamDashboardScreen
import 'package:pdh/manager_dashboard_screen.dart'; // New Manager Dashboard
import 'package:pdh/progress_visuals_screen.dart'; // Import ProgressVisualsScreen
import 'package:pdh/manager_alerts_nudges_screen.dart'; // Import ManagerAlertsNudgesScreen
import 'package:pdh/manager_inbox_screen.dart'; // Manager Inbox
import 'package:pdh/alerts_nudges_screen.dart'; // Personal Alerts
// Removed: employee leaderboard import; manager uses ManagerLeaderboardScreen
// Removed in favor of employee leaderboard UI for uniformity
import 'package:pdh/leaderboard_screen.dart'; // Use employee leaderboard UI
import 'package:pdh/repository_audit_screen.dart'; // Import RepositoryAuditScreen
import 'package:pdh/settings_screen.dart'; // Import SettingsScreen
import 'package:pdh/my_pdp_screen.dart'; // Import MyPdpScreen
// Import MyGoalWorkspaceScreen
import 'package:pdh/badges_points_screen.dart'; // Import BadgesPointsScreen
import 'package:pdh/manager_badges_points_screen.dart'; // Import ManagerBadgesPointsScreen
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth for logout
import 'package:pdh/services/database_service.dart'; // Import DatabaseService for onboarding data
import 'package:pdh/sign_in_screen.dart'; // Import SignInScreen for post-logout navigation
import 'package:pdh/manager_profile_screen.dart'; // Import ManagerProfileScreen
import 'package:pdh/team_challenges_seasons_screen.dart'; // Import TeamChallengesSeasonsScreen
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/services/manager_tutorial_service.dart';
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:pdh/widgets/version_badge.dart';
import 'package:showcaseview/showcaseview.dart';
import 'dart:developer' as developer;
import 'package:pdh/widgets/notifications_bell.dart';

class ManagerPortalScreen extends StatefulWidget {
  const ManagerPortalScreen({super.key});

  @override
  State<ManagerPortalScreen> createState() => _ManagerPortalScreenState();
}

class _ManagerPortalScreenState extends State<ManagerPortalScreen> {
  String _currentRoute = '/dashboard'; // Default to Dashboard
  bool _didInitFromArgs = false;

  // Tutorial state
  bool _shouldShowTutorial = false;
  int _currentTutorialStep = 0;
  final List<GlobalKey> _sidebarTutorialKeys = List.generate(
    12,
    (index) => GlobalKey(),
  );

  Widget _getBodyWidget() {
    switch (_currentRoute) {
      case '/dashboard':
        return const ManagerDashboardScreen(embedded: true);
      case '/my_pdp':
        return const MyPdpScreen();
      case '/manager_profile':
        return const ManagerProfileScreen(embedded: true);
      case '/team_challenges_seasons':
        return const TeamChallengesSeasonsScreen();
      case '/progress_visuals':
        return const ProgressVisualsScreen(embedded: true);
      case '/manager_alerts_nudges':
        return const ManagerAlertsNudgesScreen(embedded: true);
      case '/manager_inbox':
        return const ManagerInboxScreen(embedded: true);
      case '/alerts_nudges':
        return const AlertsNudgesScreen(embedded: true);
      case '/manager_badges_points':
        return const ManagerBadgesPointsScreen(embedded: true);
      case '/badges_points':
        return const BadgesPointsScreen(embedded: true);
      case '/manager_leaderboard':
        return const LeaderboardScreen();
      case '/repository_audit':
        return const RepositoryAuditScreen();
      case '/settings':
        return const SettingsScreen();
      case '/manager_review_team_dashboard':
        return const ManagerReviewTeamDashboardScreen();
      default:
        return const ManagerDashboardScreen();
    }
  }

  void _onNavigate(String route) {
    setState(() {
      _currentRoute = route;
    });
  }

  Future<void> _onLogout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    // Check if tutorial should be shown
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _checkTutorial();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check tutorial when screen becomes visible again
    if (!_shouldShowTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkTutorial();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_didInitFromArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final initial = args['initialRoute'] as String?;
        if (initial != null && initial.isNotEmpty && initial != _currentRoute) {
          _currentRoute = initial;
        }
      }
      _didInitFromArgs = true;
    }
    // Set system UI overlay style here if needed to ensure consistency across the portal
    // SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    //   statusBarColor: Colors.transparent, // Transparent status bar
    //   systemNavigationBarColor: Colors.transparent, // Transparent navigation bar
    //   statusBarIconBrightness: Brightness.light, // For dark status bar icons
    //   systemNavigationBarIconBrightness: Brightness.light, // For dark navigation bar icons
    // ));
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset('assets/khono_bg.png', fit: BoxFit.cover),
          ),
          // Overlay for gradient effect and content
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Color(0x880A0F1F), // More opaque semi-transparent overlay
                    Color(0x88040610), // More opaque semi-transparent overlay
                  ],
                  stops: [0.0, 1.0],
                ),
              ),
              child: Row(
                children: [
                  ResponsiveSidebar(
                    items: SidebarConfig.managerItems,
                    onNavigate: _onNavigate,
                    currentRouteName: _currentRoute,
                    onLogout: _onLogout,
                    tutorialStepIndex: _shouldShowTutorial
                        ? _currentTutorialStep
                        : null,
                    sidebarTutorialKeys:
                        _shouldShowTutorial && _sidebarTutorialKeys.isNotEmpty
                        ? _sidebarTutorialKeys
                        : null,
                    onTutorialNext: _shouldShowTutorial
                        ? _moveToNextTutorialStep
                        : null,
                    onTutorialSkip: _shouldShowTutorial ? _skipTutorial : null,
                  ),
                  Expanded(child: _getBodyWidget()),
                ],
              ),
            ),
          ),
          // Profile button positioned in top-right corner
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NotificationsBell(),
                const SizedBox(width: 8),
                _buildProfileButton(context),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: true,
              child: SafeArea(
                left: true,
                right: true,
                bottom: true,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: VersionBadge(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Simplified immediate start
  void _startTutorialImmediate() {
    if (!mounted || !_shouldShowTutorial) return;

    developer.log(
      'Starting manager tutorial immediately - step: $_currentTutorialStep',
      name: 'ManagerPortalScreen',
    );

    try {
      // Check if key is attached
      final keyContext = _sidebarTutorialKeys[0].currentContext;
      developer.log(
        'Key context check: ${keyContext != null ? "ATTACHED" : "NOT ATTACHED"}',
        name: 'ManagerPortalScreen',
      );

      if (keyContext != null) {
        // Key is attached, start showcase
        ShowCaseWidget.of(context).startShowCase([_sidebarTutorialKeys[0]]);
        developer.log(
          'Started manager showcase for step 0',
          name: 'ManagerPortalScreen',
        );
      } else {
        // Key not attached yet, retry
        developer.log(
          'Key not attached, retrying in 500ms...',
          name: 'ManagerPortalScreen',
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
        name: 'ManagerPortalScreen',
        error: e,
      );
      developer.log('Stack: $stackTrace', name: 'ManagerPortalScreen');

      // Retry after error
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _shouldShowTutorial) {
          _startTutorialImmediate();
        }
      });
    }
  }

  Future<void> _checkTutorial({int retryCount = 0}) async {
    if (!mounted) return;

    try {
      developer.log(
        'Checking if manager sidebar tutorial should start...',
        name: 'ManagerPortalScreen',
      );

      // Add delay for first attempt to ensure Firestore writes are complete
      if (retryCount == 0) {
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final shouldShow = await ManagerTutorialService.instance
          .shouldShowTutorial();
      developer.log(
        'Manager sidebar tutorial check result: shouldShow=$shouldShow',
        name: 'ManagerPortalScreen',
      );

      if (shouldShow && mounted) {
        developer.log(
          'Tutorial should start - initializing...',
          name: 'ManagerPortalScreen',
        );

        // Set tutorial state first
        setState(() {
          _shouldShowTutorial = true;
          _currentTutorialStep = 0;
        });

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
                  name: 'ManagerPortalScreen',
                );
                _startTutorialImmediate();
              }
            });
          });
        });
      } else if (retryCount < 2 && mounted) {
        // Retry up to 2 times if tutorial should show but didn't
        developer.log(
          'Tutorial check returned false, retrying (attempt ${retryCount + 1}/2)...',
          name: 'ManagerPortalScreen',
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _checkTutorial(retryCount: retryCount + 1);
          }
        });
      } else {
        developer.log(
          'Tutorial will NOT start - shouldShow=$shouldShow',
          name: 'ManagerPortalScreen',
        );
      }
    } catch (e) {
      developer.log(
        'Error checking manager sidebar tutorial: $e',
        name: 'ManagerPortalScreen',
        error: e,
      );
    }
  }

  void _moveToNextTutorialStep() {
    if (!mounted || !_shouldShowTutorial) return;

    if (_currentTutorialStep < SidebarConfig.managerItems.length - 1) {
      setState(() {
        _currentTutorialStep++;
      });

      // Trigger showcase for next step
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _shouldShowTutorial) {
          try {
            final keyContext =
                _sidebarTutorialKeys[_currentTutorialStep].currentContext;
            if (keyContext != null) {
              ShowCaseWidget.of(
                context,
              ).startShowCase([_sidebarTutorialKeys[_currentTutorialStep]]);
              developer.log(
                'Started showcase for step $_currentTutorialStep',
                name: 'ManagerPortalScreen',
              );
            } else {
              developer.log(
                'Key not attached for step $_currentTutorialStep, retrying...',
                name: 'ManagerPortalScreen',
              );
              // Retry
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && _shouldShowTutorial) {
                  try {
                    ShowCaseWidget.of(context).startShowCase([
                      _sidebarTutorialKeys[_currentTutorialStep],
                    ]);
                  } catch (e) {
                    developer.log(
                      'Retry failed: $e',
                      name: 'ManagerPortalScreen',
                    );
                  }
                }
              });
            }
          } catch (e) {
            developer.log(
              'Could not start showcase for step $_currentTutorialStep: $e',
              name: 'ManagerPortalScreen',
              error: e,
            );
          }
        }
      });
    } else {
      // Tutorial complete
      _completeTutorial();
    }
  }

  Future<void> _completeTutorial() async {
    developer.log(
      'Completing manager sidebar tutorial',
      name: 'ManagerPortalScreen',
    );
    await ManagerTutorialService.instance.markTutorialCompleted();

    if (mounted) {
      setState(() {
        _shouldShowTutorial = false;
        _currentTutorialStep = 0;
      });
    }
  }

  Future<void> _skipTutorial() async {
    developer.log(
      'Skipping manager sidebar tutorial',
      name: 'ManagerPortalScreen',
    );

    // Dismiss the current showcase overlay
    try {
      ShowCaseWidget.of(context).dismiss();
    } catch (e) {
      developer.log(
        'Error dismissing showcase: $e',
        name: 'ManagerPortalScreen',
      );
    }

    // Mark tutorial as completed
    await ManagerTutorialService.instance.markTutorialCompleted();

    if (mounted) {
      setState(() {
        _shouldShowTutorial = false;
        _currentTutorialStep = 0;
      });
    }
  }

  Widget _buildProfileButton(BuildContext context) {
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
        } else if (user?.displayName != null &&
            user!.displayName!.isNotEmpty) {
          userName = user.displayName!;
        } else if (user?.email != null && user!.email!.isNotEmpty) {
          userName = user.email!.split('@').first;
        }
        
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ManagerProfileScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.elevatedBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderColor),
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
}
