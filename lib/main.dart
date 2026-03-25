// ignore_for_file: duplicate_ignore, unnecessary_underscores, sort_child_properties_last

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/firebase_options.dart';
import 'package:pdh/my_pdp_screen.dart';
import 'package:pdh/progress_visuals_screen.dart';
import 'package:pdh/my_goal_workspace_screen.dart';
import 'package:pdh/gamification_screen.dart';
import 'package:pdh/repository_audit_screen.dart';
import 'package:pdh/screens/milestone_audit_screen.dart';
// Keep for reference
import 'package:pdh/alerts_nudges_screen.dart';
import 'package:pdh/season_challenge_screen.dart';
import 'package:pdh/settings_screen.dart';
import 'package:pdh/register.dart';
import 'package:pdh/sign_in_screen.dart';
import 'package:pdh/manager_review_team_dashboard_screen.dart';
import 'package:pdh/badges_points_screen.dart';
import 'package:pdh/leaderboard_screen.dart';
import 'package:pdh/manager_leaderboard_screen.dart';
import 'package:pdh/employee_dashboard_screen.dart';
import 'package:pdh/manager_portal_screen.dart';
import 'package:pdh/admin_portal_screen.dart';
import 'package:pdh/admin_profile_screen.dart';
import 'package:pdh/dashboard_screen.dart';
import 'package:pdh/manager_alerts_nudges_screen.dart';
import 'package:pdh/manager_inbox_screen.dart';
import 'package:pdh/manager_badges_points_screen.dart';
import 'package:pdh/employee_profile_detail_screen.dart';
import 'package:pdh/employee_profile_screen.dart';
import 'package:pdh/manager_profile_screen.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/landing_screen.dart';
import 'package:pdh/auth_wrapper.dart'; // Import AuthWrapper
import 'package:pdh/ai_chatbot.dart'
    hide ChatMessage; // Import the new AI Chatbot screen
import 'package:pdh/services/speech_recognition_service.dart'; // Import the speech recognition service
import 'package:pdh/team_chats.dart';
import 'package:pdh/widgets/khonnect_chat_widget.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:pdh/design_system/app_theme.dart'; // Import the reload_system theme
import 'package:pdh/team_goals_screen.dart'; // Added import for team goals screen
import 'package:showcaseview/showcaseview.dart'; // Import showcaseview for tutorial
import 'package:pdh/team_challenges_seasons_screen.dart';
import 'package:pdh/season_management_screen.dart' as season_mgmt;
import 'package:pdh/employee_season_challenges_screen.dart'; // Import Team Challenges & Seasons screen
import 'package:pdh/season_goal_completion_screen.dart'; // Import Season Goal Completion screen
import 'package:pdh/team_details_screen.dart'; // Import the new TeamDetailsScreen
import 'package:pdh/team_management_screen.dart'; // Import the new TeamManagementScreen
import 'package:pdh/widgets/main_layout.dart'; // Import MainLayout
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pdh/l10n/generated/app_localizations.dart';
import 'package:pdh/utils/firestore_web_circuit_breaker.dart';
import 'dart:ui' as ui;

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>(); // Declare a global key for the Navigator

// Define a ValueNotifier to hold the current route name
final ValueNotifier<String?> currentRouteNotifier = ValueNotifier<String?>(
  null,
);

// Add a ValueNotifier for speech recognition status
final ValueNotifier<String?> speechRecognitionStatusNotifier =
    ValueNotifier<String?>(null);

// Global locale notifier for runtime language changes
// Global notifier used by Settings screen to trigger locale changes
final ValueNotifier<Locale?> appLocaleNotifier = ValueNotifier<Locale?>(null);

/// Clears Firestore local cache (IndexedDB/SQLite) on startup to reduce
/// corrupted client state that can trigger internal assertion errors.
Future<void> _clearFirestoreCache() async {
  final fs = FirebaseFirestore.instance;
  // On web, persistence is disabled above and terminate() can leave the client
  // irrecoverable; just attempt a cache clear and move on.
  if (kIsWeb) {
    try {
      await fs.clearPersistence();
      debugPrint('Firestore cache cleared on startup (web)');
    } catch (e) {
      debugPrint('Firestore cache clear skipped/failed on web: $e');
    }
    return;
  }

  try {
    await fs.terminate(); // stop active clients
    await fs.clearPersistence();
    debugPrint('Firestore cache cleared on startup');
  } catch (e) {
    // If persistence is disabled or the client was already terminated, just log it.
    debugPrint('Firestore cache clear skipped/failed: $e');
  } finally {
    // Always try to bring the client back online so later calls do not see a terminated client.
    try {
      await fs.enableNetwork();
    } catch (e) {
      debugPrint('Firestore enableNetwork after cache clear failed: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // CONFLICT TEST: This line will conflict with MAIN branch
  // Ensure stable auth session persistence on web to avoid popup/redirect quirks
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (_) {
      // Non-web or older SDKs will ignore
    }
    // Mitigate Firestore Web internal assertion bugs by disabling persistence
    // Must be set before any Firestore usage
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    } catch (_) {}
  }

  // Clear cached Firestore state before the app mounts any listeners.
  await _clearFirestoreCache();

  // Global error handling: prevent web inspector from crashing on Diagnostics
  // and show a simple fallback widget instead of a blank white screen.
  FlutterError.onError = (FlutterErrorDetails details) {
    final error = details.exceptionAsString();
    debugPrint('FlutterError: $error');

    // Catch Firestore internal assertion errors and prevent them from crashing
    if (error.contains('FIRESTORE') &&
        error.contains('INTERNAL ASSERTION FAILED')) {
      debugPrint(
        'Caught Firestore internal assertion error - suppressing crash',
      );
      FirestoreWebCircuitBreaker.maybeReload(details.exception);
      // Don't mark as broken to allow retry logic to work
      // FirestoreWebCircuitBreaker.isBroken = true;
      // Don't show error dialog for Firestore internal errors
      return;
    }

    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
    if (!kIsWeb) {
      FlutterError.presentError(details);
    }
  };

  // Catch uncaught async errors (including some web/JS promise rejections).
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    if (FirestoreWebCircuitBreaker.isFirestoreInternalUnexpectedState(error)) {
      FirestoreWebCircuitBreaker.maybeReload(error);
      // Don't mark as broken to allow retry logic to work
      // FirestoreWebCircuitBreaker.isBroken = true;
      return true;
    }
    return false;
  };

  // Note: For unhandled async errors, FlutterError.onError should catch most cases
  // PlatformDispatcher.onError is available in Flutter 3.7+ but we'll rely on
  // FlutterError.onError for broader compatibility
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'An error occurred. Please refresh or try again.',
            style: const TextStyle(color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SpeechRecognitionService _speechRecognitionService =
      SpeechRecognitionService();

  @override
  void initState() {
    super.initState();
    _initializeSpeechRecognition();
    _initializeLocale(); // Load persisted language
    _speechRecognitionService.speechCommands.listen((command) {
      speechRecognitionStatusNotifier.value = 'Recognized: $command';
      // Implement navigation logic here later
      final String? route =
          _speechRecognitionService.commandRoutes[command.toLowerCase()];
      if (route != null) {
        navigatorKey.currentState?.pushNamed(route);
      } else {
        speechRecognitionStatusNotifier.value =
            'Command not recognized: $command';
      }
    });
  }

  void _initializeSpeechRecognition() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('speechRecognitionEnabled') ?? false;
    if (isEnabled) {
      _speechRecognitionService.startSpeechRecognition();
    }
  }

  Future<void> _initializeLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('appLocale');

    Locale resolvedLocale;
    if (code == null || code.isEmpty) {
      // If no explicit app locale is stored yet, prefer the device locale
      // when it is supported; otherwise fall back to English (South Africa).
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      // Supported locales based on ARB files in lib/l10n/
      const supported = [
        Locale('en', 'ZA'),
        Locale('en'),
        Locale('af'),
        Locale('zu'),
        Locale('st'),
        Locale('nr'),
        Locale('nso'),
        Locale('ss'),
        Locale('tn'),
        Locale('ts'),
        Locale('ve'),
        Locale('xh'),
      ];
      resolvedLocale = supported.firstWhere(
        (l) =>
            l.languageCode == deviceLocale.languageCode &&
            (l.countryCode == null ||
                l.countryCode == deviceLocale.countryCode),
        orElse: () => const Locale('en', 'ZA'),
      );
    } else {
      final parts = code.split('_');
      resolvedLocale = parts.length == 2
          ? Locale(parts[0], parts[1])
          : Locale(parts[0]);
    }

    appLocaleNotifier.value = resolvedLocale;
  }

  @override
  void dispose() {
    _speechRecognitionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      builder: (context) => _GlobalChatbotWrapper(
        currentRouteNotifier: currentRouteNotifier,
        child: ValueListenableBuilder<Locale?>(
          valueListenable: appLocaleNotifier,
          builder: (context, locale, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Personal Development Hub',
              theme: AppTheme.darkTheme,
              initialRoute: '/', // Let AuthWrapper handle authentication flow
              locale: locale,
              debugShowCheckedModeBanner: false, // Disable debug banner
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                DefaultMaterialLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              localeResolutionCallback: (deviceLocale, supportedLocales) {
                // If a specific app locale has been chosen, always honor it.
                if (locale != null) {
                  return locale;
                }

                if (deviceLocale == null) {
                  return supportedLocales.first;
                }

                for (final supportedLocale in supportedLocales) {
                  if (supportedLocale.languageCode ==
                          deviceLocale.languageCode &&
                      (supportedLocale.countryCode == null ||
                          supportedLocale.countryCode ==
                              deviceLocale.countryCode)) {
                    return supportedLocale;
                  }
                }

                return supportedLocales.first;
              },
              builder: (context, child) {
                if (child == null) return const SizedBox.shrink();
                // Flutter Web can assert during view focus changes when
                // `WidgetOrderTraversalPolicy` queries semantic bounds before layout
                // (e.g. `RenderTapRegionSurface was not laid out`), which causes a full
                // page reload. Disable the global traversal group on web.
                if (kIsWeb) return child;
                return FocusTraversalGroup(
                  policy: WidgetOrderTraversalPolicy(),
                  child: child,
                );
              },
              routes: {
                '/landing': (context) => const PersonalDevelopmentHubScreen(),
                '/': (context) => const AuthWrapper(),
                '/register': (context) => const RegisterScreen(),
                '/sign_in': (context) => const LoginScreen(),
                '/my_pdp': (context) => RoleGate(
                  requiredRole: RequiredRole.employee,
                  child: MainLayout(
                    title: 'Profile',
                    currentRouteName: '/my_pdp',
                    body: const MyPdpScreen(),
                  ),
                ),
                '/my_profile': (context) => RoleGate(
                  requiredRole: RequiredRole.employee,
                  child: MainLayout(
                    title: 'My Profile',
                    currentRouteName: '/my_profile',
                    body: const EmployeeProfileScreen(embedded: true),
                  ),
                ),
                '/manager_profile': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const ManagerProfileScreen(),
                ),
                '/progress_visuals': (context) => MainLayout(
                  title: 'Progress Visuals',
                  currentRouteName: '/progress_visuals',
                  body: const ProgressVisualsScreen(),
                ),
                '/my_goal_workspace': (context) => RoleGate(
                  requiredRole: RequiredRole.employee,
                  child: const MyGoalWorkspaceScreen(),
                ),
                '/gamification': (context) => const GamificationScreen(),
                '/repository_audit': (context) => MainLayout(
                  title: 'Repository & Audit',
                  currentRouteName: '/repository_audit',
                  body: const RepositoryAuditScreen(),
                ),
                '/milestone_audit': (context) => MainLayout(
                  title: 'Milestone Audit',
                  currentRouteName: '/milestone_audit',
                  body: const MilestoneAuditScreen(),
                ),
                '/alerts_nudges': (context) => const AlertsNudgesScreen(),
                '/season_challenge': (context) => const SeasonChallengeScreen(),
                '/settings': (context) => MainLayout(
                  title: 'Settings & Privacy',
                  currentRouteName: '/settings',
                  body: const SettingsScreen(),
                ),
                '/manager_review_team_dashboard': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const ManagerReviewTeamDashboardScreen(),
                ),
                '/badges_points': (context) => const BadgesPointsScreen(),
                '/leaderboard': (context) => MainLayout(
                  title: 'Leaderboard',
                  currentRouteName: '/leaderboard',
                  body: const LeaderboardScreen(),
                ),
                '/manager_leaderboard': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const ManagerLeaderboardScreen(),
                ),
                '/employee_portal': (context) => RoleGate(
                  requiredRole: RequiredRole.employee,
                  child: const EmployeeDashboardScreen(),
                ),
                '/employee_dashboard': (context) => RoleGate(
                  requiredRole: RequiredRole.employee,
                  child: const EmployeeDashboardScreen(),
                ),
                '/manager_portal': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const ManagerPortalScreen(),
                ),
                '/admin_portal': (context) => RoleGate(
                  requiredRole: RequiredRole.admin,
                  child: const AdminPortalScreen(),
                ),
                '/admin_dashboard': (context) => RoleGate(
                  requiredRole: RequiredRole.admin,
                  child: Builder(
                    builder: (context) => AdminPortalScreen(),
                  ),
                ),
                '/admin_profile': (context) => RoleGate(
                  requiredRole: RequiredRole.admin,
                  child: const AdminProfileScreen(embedded: true),
                ),
                '/manager_oversight': (context) => RoleGate(
                  requiredRole: RequiredRole.admin,
                  child: Builder(
                    builder: (context) => AdminPortalScreen(),
                  ),
                ),
                '/admin_inbox': (context) => RoleGate(
                  requiredRole: RequiredRole.admin,
                  child: Builder(
                    builder: (context) => AdminPortalScreen(),
                  ),
                ),
                '/org_leaderboard': (context) => RoleGate(
                  requiredRole: RequiredRole.admin,
                  child: Builder(
                    builder: (context) => AdminPortalScreen(),
                  ),
                ),
                '/admin_settings': (context) => RoleGate(
                  requiredRole: RequiredRole.admin,
                  child: const SettingsScreen(),
                ),
                '/dashboard': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const DashboardScreen(),
                ),
                '/manager_alerts_nudges': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const ManagerAlertsNudgesScreen(),
                ),
                '/manager_inbox': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const ManagerInboxScreen(),
                ),
                '/manager_badges_points': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const ManagerBadgesPointsScreen(),
                ),
                '/employee_profile_detail': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: Builder(
                    builder: (context) => EmployeeProfileDetailScreen(
                      employeeId:
                          (ModalRoute.of(context)?.settings.arguments
                              as String?) ??
                          '',
                    ),
                  ),
                ),
                '/team_goals': (context) => RoleGate(
                  requiredRole: RequiredRole.employee,
                  child: const TeamGoalsScreen(),
                ),
                '/team_challenges_seasons': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const TeamChallengesSeasonsScreen(),
                ),
                '/season_management': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: season_mgmt.SeasonManagementScreen(
                    seasonId:
                        (ModalRoute.of(context)?.settings.arguments
                            as Map<String, dynamic>?)?['seasonId'],
                  ),
                ),
                '/season_challenges': (context) => RoleGate(
                  requiredRole: RequiredRole.employee,
                  child: const EmployeeSeasonChallengesScreen(),
                ),
                '/season_goal_completion': (context) => RoleGate(
                  requiredRole: RequiredRole.employee,
                  child: SeasonGoalCompletionScreen(
                    seasonId:
                        (ModalRoute.of(context)?.settings.arguments
                            as Map<String, dynamic>?)?['seasonId'] ??
                        '',
                    goalId:
                        (ModalRoute.of(context)?.settings.arguments
                            as Map<String, dynamic>?)?['goalId'],
                  ),
                ),
                '/team_details': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: Builder(
                    builder: (context) => TeamDetailsScreen(
                      teamGoalId:
                          (ModalRoute.of(context)?.settings.arguments
                              as String?) ??
                          '',
                    ),
                  ),
                ),
                '/ai_chatbot': (context) => const AiChatbotScreen(),
                '/team_chats': (context) => const TeamChatsScreen(),
                '/team_management': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: Builder(
                    builder: (context) => TeamManagementScreen(
                      teamGoalId:
                          (ModalRoute.of(context)?.settings.arguments
                              as String?) ??
                          '',
                    ),
                  ),
                ),
                // Manager Goal Workspace dropdown – reuse employee UI with manager sidebar
                '/manager_gw_menu_dashboard': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const EmployeeDashboardScreen(
                    forManagerGwMenu: true,
                    managerGwMenuRoute: '/manager_gw_menu_dashboard',
                  ),
                ),
                '/manager_gw_menu_goal_workspace': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: MainLayout(
                    title: 'Goal Workspace',
                    currentRouteName: '/manager_gw_menu_goal_workspace',
                    items: SidebarConfig.managerItems,
                    body: const MyPdpScreen(),
                  ),
                ),
                '/manager_gw_menu_alerts': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const AlertsNudgesScreen(
                    forManagerGwMenu: true,
                    managerGwMenuRoute: '/manager_gw_menu_alerts',
                  ),
                ),
                '/manager_gw_menu_my_pdp': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const MyGoalWorkspaceScreen(
                    forManagerGwMenu: true,
                    managerGwMenuRoute: '/manager_gw_menu_my_pdp',
                  ),
                ),
                '/manager_gw_menu_progress': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: MainLayout(
                    title: 'Progress Visuals',
                    currentRouteName: '/manager_gw_menu_progress',
                    items: SidebarConfig.managerItems,
                    body: const ProgressVisualsScreen(
                      embedded: true,
                      forManagerGwMenu: true,
                    ),
                  ),
                ),
                '/manager_gw_menu_leaderboard': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: MainLayout(
                    title: 'Leaderboard',
                    currentRouteName: '/manager_gw_menu_leaderboard',
                    items: SidebarConfig.managerItems,
                    body: const LeaderboardScreen(),
                  ),
                ),
                '/manager_gw_menu_badges': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const BadgesPointsScreen(
                    forManagerGwMenu: true,
                    managerGwMenuRoute: '/manager_gw_menu_badges',
                  ),
                ),
                '/manager_gw_menu_season_challenges': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const EmployeeSeasonChallengesScreen(
                    forManagerGwMenu: true,
                    managerGwMenuRoute: '/manager_gw_menu_season_challenges',
                  ),
                ),
                '/manager_gw_menu_repository': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: MainLayout(
                    title: 'Repository & Audit',
                    currentRouteName: '/manager_gw_menu_repository',
                    items: SidebarConfig.managerItems,
                    body: const RepositoryAuditScreen(),
                  ),
                ),
              },
              navigatorObservers: [MyNavigatorObserver()],
            );
          },
        ),
      ),
    );
  }
}

class _GlobalChatbotWrapper extends StatefulWidget {
  final Widget child;
  final ValueNotifier<String?> currentRouteNotifier;

  const _GlobalChatbotWrapper({
    required this.child,
    required this.currentRouteNotifier,
  });

  @override
  State<_GlobalChatbotWrapper> createState() => _GlobalChatbotWrapperState();
}

class _GlobalChatbotWrapperState extends State<_GlobalChatbotWrapper> {
  @override
  void initState() {
    super.initState();
    // Precache common icons/images once after first frame to reduce jank on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      precacheImage(
        const AssetImage('assets/AI_Red.png'),
        context,
        size: const Size(40, 40),
      );
      precacheImage(
        const AssetImage('assets/khonodemy-sidebar-logo-red.png'),
        context,
        size: const Size(300, 60),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<String?>(
            valueListenable: widget.currentRouteNotifier,
            builder: (context, currentRoute, _) {
              return ChatFloatingActionButtons(currentRoute: currentRoute);
            },
          ),
        ),
      ],
    );
  }
}

/// Single FAB that expands to show Chatbot and Team Chat actions.
class ChatFloatingActionButtons extends StatefulWidget {
  final String? currentRoute;

  const ChatFloatingActionButtons({super.key, this.currentRoute});

  @override
  State<ChatFloatingActionButtons> createState() =>
      _ChatFloatingActionButtonsState();
}

class _ChatFloatingActionButtonsState extends State<ChatFloatingActionButtons>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  static const List<String> _allowedRoutes = [
    '/dashboard',
    '/my_pdp',
    '/my_profile',
    '/manager_profile',
    '/my_goal_workspace',
    '/progress_visuals',
    '/alerts_nudges',
    '/badges_points',
    '/leaderboard',
    '/repository_audit',
    '/settings',
    '/gamification',
    '/season_challenge',
    '/manager_review_team_dashboard',
    '/employee_dashboard',
    '/employee_portal',
    '/manager_portal',
    '/manager_gw_menu_dashboard',
    '/manager_gw_menu_goal_workspace',
    '/manager_gw_menu_alerts',
    '/manager_gw_menu_my_pdp',
    '/manager_gw_menu_progress',
    '/manager_gw_menu_leaderboard',
    '/manager_gw_menu_badges',
    '/manager_gw_menu_season_challenges',
    '/manager_gw_menu_repository',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _openChatbot() {
    _toggleExpanded();
    navigatorKey.currentState!.pushNamed('/ai_chatbot');
  }

  void _openTeamChat() {
    _toggleExpanded();
    final navContext = navigatorKey.currentContext;
    if (navContext != null) {
      showKhonnectChatModal(navContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentRoute == null ||
        !_allowedRoutes.contains(widget.currentRoute) ||
        widget.currentRoute == '/ai_chatbot' ||
        widget.currentRoute == '/team_chats') {
      return const SizedBox.shrink();
    }

    const double miniFabSize = 48.0;
    const double spacing = 12.0;

    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expanded child buttons (Team Chat above, Chatbot above that)
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: -1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: spacing),
                _MiniFab(
                  size: miniFabSize,
                  onTap: _openTeamChat,
                  child: Image.asset(
                    'assets/Team_Meeting/Team.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    // ignore: unnecessary_underscores
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.chat, color: Colors.white, size: 24),
                  ),
                  backgroundColor: AppColors.activeColor,
                ),
                const SizedBox(height: spacing),
                _MiniFab(
                  size: miniFabSize,
                  onTap: _openChatbot,
                  child: Image.asset(
                    'assets/AI_Red.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.smart_toy, color: Colors.white, size: 24),
                  ),
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: spacing),
              ],
            ),
          ),
          // Main dropdown – arrow icon only, no background
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggleExpanded,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  _expanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniFab extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  final Widget child;
  final Color backgroundColor;

  const _MiniFab({
    required this.size,
    required this.onTap,
    required this.child,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

// Custom NavigatorObserver to update the current route
class MyNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    currentRouteNotifier.value = route.settings.name;
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    currentRouteNotifier.value = newRoute?.settings.name;
  }

  // ADDITIONAL CONFLICT TEST: This method will conflict with MAIN branch
  @override
  void didRemove(Route route, Route? previousRoute) {
    currentRouteNotifier.value = previousRoute?.settings.name;
    // Added extra logging for conflict testing
    debugPrint('Route removed: ${route.settings.name}');
    debugPrint('Previous route: ${previousRoute?.settings.name}');
    debugPrint('Current route after removal: ${currentRouteNotifier.value}');
    debugPrint('Navigation stack updated in Nathi-S11 branch');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    currentRouteNotifier.value = previousRoute?.settings.name;
  }
}
