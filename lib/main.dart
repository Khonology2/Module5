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
import 'package:pdh/manager_dashboard_screen.dart';
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
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/services/cache_service.dart'; // Import CacheService
import 'package:pdh/services/backend_auth_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pdh/l10n/generated/app_localizations.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // All token handling now uses PDH backend API
  // No .env file loading needed - backend URL is hardcoded in BackendAuthService

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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
  // Start periodic cache cleanup for optimal performance
  CacheService.startPeriodicCleanup();
  BackendAuthService.instance.warmUpBackend();
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
              initialRoute: '/landing',
              locale: locale,
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
                '/manager_dashboard': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const ManagerDashboardScreen(),
                ),
                '/admin_dashboard': (context) => RoleGate(
                  requiredRole: RequiredRole.manager,
                  child: const ManagerDashboardScreen(),
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
              },
              debugShowCheckedModeBanner: false,
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
          textDirection: TextDirection.ltr, // Explicitly provide Directionality
          child: ValueListenableBuilder<String?>(
            valueListenable: widget.currentRouteNotifier,
            builder: (context, currentRoute, _) {
              return ChatbotButton(currentRoute: currentRoute);
            },
          ),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<String?>(
            valueListenable: widget.currentRouteNotifier,
            builder: (context, currentRoute, _) {
              return TeamChatButton(currentRoute: currentRoute);
            },
          ),
        ),
      ],
    );
  }
}

class ChatbotButton extends StatefulWidget {
  final String? currentRoute;
  const ChatbotButton({super.key, this.currentRoute});

  @override
  State<ChatbotButton> createState() => _ChatbotButtonState();
}

class _ChatbotButtonState extends State<ChatbotButton> {
  @override
  Widget build(BuildContext context) {
    // Check if the current route is one of the allowed screens
    final allowedRoutes = [
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
      '/employee_dashboard', // Employee dashboard route
      '/employee_portal', // Legacy mapping shows dashboard; keep chatbot visible
      '/manager_portal', // Manager portal route
    ];
    if (widget.currentRoute == null ||
        !allowedRoutes.contains(widget.currentRoute) ||
        widget.currentRoute == '/ai_chatbot') {
      return const SizedBox.shrink(); // Hide the button on screens not in the allowed list or the chatbot screen itself
    }

    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        onPressed: () {
          // Navigate to the AI Chatbot screen using the global key
          navigatorKey.currentState!.pushNamed('/ai_chatbot');
        },
        backgroundColor: Colors.white, // Use white background
        shape: const CircleBorder(), // Make the button round
        child: Image.asset(
          'assets/AI_Red.png',
          width: 40.0,
          height: 40.0,
        ), // Use the AI_Red.png image
      ),
    );
  }
}

class TeamChatButton extends StatefulWidget {
  final String? currentRoute;
  const TeamChatButton({super.key, this.currentRoute});

  @override
  State<TeamChatButton> createState() => _TeamChatButtonState();
}

class _TeamChatButtonState extends State<TeamChatButton> {
  @override
  Widget build(BuildContext context) {
    final allowedRoutes = [
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
    ];

    if (widget.currentRoute == null ||
        !allowedRoutes.contains(widget.currentRoute) ||
        widget.currentRoute == '/team_chats') {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 90,
      right: 20,
      child: Builder(
        builder: (context) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              splashColor: Colors.white24,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              onTap: () {
                // Use the MaterialApp navigator context so we have
                // proper Navigator + MaterialLocalizations ancestors
                final navContext = navigatorKey.currentContext;
                if (navContext != null) {
                  showKhonnectChatModal(navContext);
                }
              },
              borderRadius: BorderRadius.circular(28.0),
              child: Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  color: AppColors.activeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8.0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/Team_Meeting/Team.png',
                    width: 32.0,
                    height: 32.0,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.chat, color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        },
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

  @override
  void didPop(Route route, Route? previousRoute) {
    currentRouteNotifier.value = previousRoute?.settings.name;
  }
}
