import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdh/widgets/sidebar.dart'; // Import ResponsiveSidebar
import 'package:pdh/manager_review_team_dashboard_screen.dart'; // Import ManagerReviewTeamDashboardScreen
import 'package:pdh/manager_dashboard_screen.dart'; // New Manager Dashboard
import 'package:pdh/progress_visuals_screen.dart'; // Import ProgressVisualsScreen
import 'package:pdh/manager_alerts_nudges_screen.dart'; // Import ManagerAlertsNudgesScreen
import 'package:pdh/manager_inbox_screen.dart'; // Manager Inbox
import 'package:pdh/alerts_nudges_screen.dart'; // Personal Alerts
import 'package:pdh/manager_leaderboard_screen.dart';
import 'package:pdh/repository_audit_screen.dart'; // Import RepositoryAuditScreen
import 'package:pdh/settings_screen.dart'; // Import SettingsScreen
import 'package:pdh/my_pdp_screen.dart'; // Import MyPdpScreen
import 'package:pdh/my_goal_workspace_screen.dart'; // Import MyGoalWorkspaceScreen
import 'package:pdh/badges_points_screen.dart'; // Import BadgesPointsScreen
import 'package:pdh/employee_dashboard_screen.dart'; // Manager GW menu dashboard (reuse employee UI)
import 'package:pdh/employee_season_challenges_screen.dart'; // Manager GW menu season challenges
import 'package:pdh/manager_badges_points_screen.dart'; // Import ManagerBadgesPointsScreen
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth for logout
import 'package:pdh/sign_in_screen.dart'; // Import SignInScreen for post-logout navigation
import 'package:pdh/manager_profile_screen.dart'; // Import ManagerProfileScreen
import 'package:pdh/team_challenges_seasons_screen.dart'; // Import TeamChallengesSeasonsScreen
import 'package:pdh/leaderboard_screen.dart';
import 'package:pdh/employee_profile_screen.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/services/manager_tutorial_service.dart';
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:showcaseview/showcaseview.dart';
import 'dart:developer' as developer;
import 'package:pdh/widgets/notifications_bell.dart';
import 'package:pdh/widgets/messages_icon.dart';
import 'package:pdh/services/season_service.dart';
import 'package:pdh/services/workspace_context_service.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

class ManagerPortalScreen extends StatefulWidget {
  const ManagerPortalScreen({super.key});

  @override
  State<ManagerPortalScreen> createState() => _ManagerPortalScreenState();
}

class _ManagerPortalScreenState extends State<ManagerPortalScreen> {
  String _currentRoute = '/dashboard'; // Default to Dashboard
  bool _didInitFromArgs = false;
  final WorkspaceContextService _workspaceService = WorkspaceContextService();

  /// Incremented each time we navigate to manager_alerts_nudges so the screen loads fresh data.
  int _alertsScreenKey = 0;

  // Routes managed inside manager portal shell. Used for URL sync/deep-link.
  static const Set<String> _portalRoutes = {
    '/dashboard',
    '/my_pdp',
    '/manager_profile',
    '/team_challenges_seasons',
    '/progress_visuals',
    '/manager_alerts_nudges',
    '/manager_inbox',
    '/alerts_nudges',
    '/manager_badges_points',
    '/badges_points',
    '/manager_leaderboard',
    '/repository_audit',
    '/settings',
    '/manager_review_team_dashboard',
    '/manager_gw_menu_dashboard',
    '/manager_gw_menu_goal_workspace',
    '/manager_gw_menu_alerts',
    '/manager_gw_menu_my_pdp',
    '/manager_gw_menu_progress',
    '/manager_gw_menu_leaderboard',
    '/manager_gw_menu_badges',
    '/manager_gw_menu_season_challenges',
    '/manager_gw_menu_repository',
    '/my_goal_workspace',
    '/leaderboard',
    '/season_challenges',
    '/my_profile',
  };

  // Tutorial state
  bool _shouldShowTutorial = false;
  int _currentTutorialStep = 0;
  final List<GlobalKey> _sidebarTutorialKeys = List.generate(
    12,
    (index) => GlobalKey(),
  );

  /// Matches [MainLayout]’s `AppSpacing.screenPadding` for bodies that do not
  /// apply their own full-bleed inset (e.g. [MyPdpScreen] uses zero scroll padding).
  static EdgeInsets _portalMainContentPadding(String route) {
    switch (route) {
      case '/my_pdp':
      case '/manager_gw_menu_goal_workspace':
        return AppSpacing.screenPadding;
      default:
        return EdgeInsets.zero;
    } 
  }

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
        return ManagerAlertsNudgesScreen(
          key: ValueKey('manager_alerts_$_alertsScreenKey'),
          embedded: true,
        );
      case '/manager_inbox':
        return const ManagerInboxScreen(embedded: true);
      case '/alerts_nudges':
        return const AlertsNudgesScreen(embedded: true);
      case '/manager_badges_points':
        return const ManagerBadgesPointsScreen(embedded: true);
      case '/badges_points':
        return const BadgesPointsScreen(embedded: true);
      case '/manager_leaderboard':
        return const ManagerLeaderboardScreen(embedded: true);
      case '/repository_audit':
        return const RepositoryAuditScreen(forManagerWorkspace: true);
      case '/settings':
        return const SettingsScreen();
      case '/manager_review_team_dashboard':
        return const ManagerReviewTeamDashboardScreen();
      // Manager Goal Workspace dropdown – same UI as employee, manager-scoped; body-only to avoid second sidebar
      case '/manager_gw_menu_dashboard':
        return const EmployeeDashboardScreen(
          embedded: true,
          forManagerGwMenu: true,
          managerGwMenuRoute: '/manager_gw_menu_dashboard',
        );
      case '/manager_gw_menu_goal_workspace':
        return const MyPdpScreen(managerOwnGoalsOnly: true);
      case '/manager_gw_menu_alerts':
        return const AlertsNudgesScreen(
          embedded: true,
          forManagerGwMenu: true,
          managerGwMenuRoute: '/manager_gw_menu_alerts',
        );
      case '/manager_gw_menu_my_pdp':
        return const MyGoalWorkspaceScreen(
          embedded: true,
          forManagerGwMenu: true,
          managerGwMenuRoute: '/manager_gw_menu_my_pdp',
        );
      case '/manager_gw_menu_progress':
        return const ProgressVisualsScreen(
          embedded: true,
          forManagerGwMenu: true,
        );
      case '/manager_gw_menu_leaderboard':
        return const ManagerLeaderboardScreen(
          embedded: true,
          compareManagers: true,
        );
      case '/manager_gw_menu_badges':
        return const BadgesPointsScreen(
          embedded: true,
          forManagerGwMenu: true,
          managerGwMenuRoute: '/manager_gw_menu_badges',
        );
      case '/manager_gw_menu_season_challenges':
        return const EmployeeSeasonChallengesScreen(
          embedded: true,
          forManagerGwMenu: true,
          managerGwMenuRoute: '/manager_gw_menu_season_challenges',
        );
      case '/manager_gw_menu_repository':
        return const RepositoryAuditScreen();
      // My Workspace routes for managers
      case '/my_goal_workspace':
        return const MyGoalWorkspaceScreen(embedded: true);
      case '/leaderboard':
        return const LeaderboardScreen();
      case '/season_challenges':
        return const EmployeeSeasonChallengesScreen(embedded: true);
      case '/my_profile':
        return const EmployeeProfileScreen(embedded: true);
      default:
        return const ManagerDashboardScreen(embedded: true);
    }
  }

  bool _isMyWorkspaceRoute(String route) {
    switch (route) {
      case '/manager_gw_menu_dashboard':
      case '/manager_gw_menu_goal_workspace':
      case '/manager_gw_menu_alerts':
      case '/manager_gw_menu_my_pdp':
      case '/manager_gw_menu_progress':
      case '/manager_gw_menu_leaderboard':
      case '/manager_gw_menu_badges':
      case '/manager_gw_menu_season_challenges':
      case '/manager_gw_menu_repository':
      case '/employee_dashboard':
      case '/my_pdp':
      case '/alerts_nudges':
      case '/my_goal_workspace':
      case '/leaderboard':
      case '/badges_points':
      case '/season_challenges':
      case '/my_profile':
        return true;
      default:
        return false;
    }
  }

  void _syncWorkspaceContextForRoute(String route) {
    _workspaceService.switchToContext(
      _isMyWorkspaceRoute(route)
          ? WorkspaceContext.myWorkspace
          : WorkspaceContext.managerWorkspace,
    );
  }

  void _onNavigate(String route) {
    _syncWorkspaceContextForRoute(route);
    setState(() {
      if (route == '/manager_alerts_nudges') {
        _alertsScreenKey++;
      }
      _currentRoute = route;
    });
    _syncPortalUrl(route);
  }

  bool _isPortalRoute(String route) => _portalRoutes.contains(route);

  bool _shouldShowPortalTopActions(String route) {
    // Keep dashboard-style screens uncluttered because those screens already
    // render their own message/notification icons in their header.
    final show = route != '/dashboard' && route != '/manager_gw_menu_dashboard';
    return show;
  }

  String? _routeFromPortalUrl() {
    // Hash strategy URL example:
    // http://localhost:64790/#/manager_portal?screen=/manager_inbox
    final fragment = Uri.base.fragment;
    if (fragment.isEmpty) return null;
    final normalized = fragment.startsWith('/') ? fragment : '/$fragment';
    try {
      final parsed = Uri.parse(normalized);
      if (parsed.path != '/manager_portal') return null;
      final screen = parsed.queryParameters['screen'];
      if (screen == null || screen.trim().isEmpty) return null;
      final decoded = Uri.decodeComponent(screen).trim();
      return _isPortalRoute(decoded) ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  void _syncPortalUrl(String route) {
    if (!kIsWeb) return;
    final location = '/manager_portal?screen=${Uri.encodeComponent(route)}';
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse(location),
      replace: true,
      state: <String, dynamic>{'screen': route},
    );
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

    // Sync manager season points from season metrics into the manager's user doc.
    // This is required because employee milestone updates cannot write to the manager's user doc.
    Future.microtask(() => SeasonService.syncCurrentManagerSeasonPoints());
    // Sync manager season badges earned (tracked on seasons) into the manager's badges collection.
    Future.microtask(() => SeasonService.syncCurrentManagerSeasonBadges());

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
  void dispose() {
    // Cancel any pending operations
    _shouldShowTutorial = false;
    _currentTutorialStep = 0;

    // Clean up tutorial keys
    _sidebarTutorialKeys.clear();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_didInitFromArgs) {
      var initial = _routeFromPortalUrl();
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        final argRoute = args['initialRoute'] as String?;
        if (argRoute != null && argRoute.isNotEmpty) {
          initial = argRoute;
        }
      }
      if (initial != null && initial.isNotEmpty && _isPortalRoute(initial)) {
        _currentRoute = initial;
      }
      _syncWorkspaceContextForRoute(_currentRoute);
      _syncPortalUrl(_currentRoute);
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
      body: DashboardThemedBackground(
        child: Stack(
          children: [
            Row(
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
                Expanded(
                  child: Padding(
                    padding: _portalMainContentPadding(_currentRoute),
                    child: _getBodyWidget(),
                  ),
                ),
              ],
            ),
            if (_shouldShowPortalTopActions(_currentRoute))
              Positioned(
                top: 24,
                right: 24,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MessagesIcon(),
                    const SizedBox(width: 8),
                    const NotificationsBell(),
                  ],
                ),
              ),
          ],
        ),
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

}
