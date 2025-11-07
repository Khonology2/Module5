import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:firebase_core/firebase_core.dart';
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
import 'package:pdh/dashboard_screen.dart';
import 'package:pdh/manager_alerts_nudges_screen.dart';
import 'package:pdh/manager_inbox_screen.dart';
import 'package:pdh/manager_badges_points_screen.dart';
import 'package:pdh/employee_profile_detail_screen.dart';
import 'package:pdh/employee_profile_screen.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/landing_screen.dart';
import 'package:pdh/auth_wrapper.dart'; // Import AuthWrapper
import 'package:pdh/ai_chatbot.dart' hide ChatMessage; // Import the new AI Chatbot screen
import 'package:pdh/services/speech_recognition_service.dart'; // Import the speech recognition service
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:pdh/design_system/app_theme.dart'; // Import the reload_system theme
import 'package:pdh/team_goals_screen.dart'; // Added import for team goals screen
import 'package:pdh/team_challenges_seasons_screen.dart';
import 'package:pdh/season_management_screen.dart' as season_mgmt;
import 'package:pdh/employee_season_challenges_screen.dart'; // Import Team Challenges & Seasons screen
import 'package:pdh/season_goal_completion_screen.dart'; // Import Season Goal Completion screen
import 'package:pdh/team_details_screen.dart'; // Import the new TeamDetailsScreen
import 'package:pdh/team_management_screen.dart'; // Import the new TeamManagementScreen
import 'package:pdh/widgets/main_layout.dart'; // Import MainLayout
import 'package:pdh/team_chats.dart' hide ChatMessage;

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>(); // Declare a global key for the Navigator

// Define a ValueNotifier to hold the current route name
final ValueNotifier<String?> currentRouteNotifier = ValueNotifier<String?>(
  null,
);

// Add a ValueNotifier for speech recognition status
final ValueNotifier<String?> speechRecognitionStatusNotifier =
    ValueNotifier<String?>(null);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Ensure stable auth session persistence on web to avoid popup/redirect quirks
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (_) {
      // Non-web or older SDKs will ignore
    }
  }
  // Global error handling: prevent web inspector from crashing on Diagnostics
  // and show a simple fallback widget instead of a blank white screen.
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log to console
    debugPrint('FlutterError: \\n${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
    // Fallback to default behavior
    FlutterError.presentError(details);
  };
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

  @override
  void dispose() {
    _speechRecognitionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlobalChatbotWrapper(
      currentRouteNotifier: currentRouteNotifier, // Pass the ValueNotifier
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          MaterialApp(
            navigatorKey: navigatorKey, // Assign the global key to MaterialApp
            title: 'Personal Development Hub',
            theme: AppTheme.darkTheme,
            initialRoute: '/landing',
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();
              return FocusTraversalGroup(
                policy: WidgetOrderTraversalPolicy(),
                child: child,
              );
            },
            routes: {
              '/landing': (context) => const PersonalDevelopmentHubScreen(),
              '/': (context) =>
                  const AuthWrapper(), // Set the root route to AuthWrapper
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
              // Map legacy employee_portal route to the dashboard to remove the old portal screen
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
              '/ai_chatbot': (context) =>
                  const AiChatbotScreen(), // Add the new AI Chatbot route
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
              // Goal Proof route removed
            },
            debugShowCheckedModeBanner: false,
            // Add the custom NavigatorObserver
            navigatorObservers: [MyNavigatorObserver()],
          ),
          // Speech recognition feedback overlay
          ValueListenableBuilder<String?>(
            valueListenable: speechRecognitionStatusNotifier,
            builder: (context, status, child) {
              if (status == null) {
                return const SizedBox.shrink();
              }
              return Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic, color: Colors.white),
                        const SizedBox(width: 8.0),
                        Text(
                          status,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
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
      precacheImage(const AssetImage('assets/AI_Red.png'), context, size: const Size(40, 40));
      precacheImage(const AssetImage('assets/khonodemy-sidebar-logo-red.png'), context, size: const Size(300, 60));
    });
  }
  @override
  Widget build(BuildContext context) {
    return Stack(
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
      child: GestureDetector(
        onTap: () {
          navigatorKey.currentState!.pushNamed('/team_chats');
        },
        child: SizedBox(
          width: 56.0,
          height: 56.0,
          child: Center(
            child: Image.asset(
              'assets/Team_Meeting/Team.png',
              width: 44.0,
              height: 44.0,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
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

  @override
  void didPop(Route route, Route? previousRoute) {
    currentRouteNotifier.value = previousRoute?.settings.name;
  }
}
