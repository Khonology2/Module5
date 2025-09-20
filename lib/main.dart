import 'package:flutter/material.dart';
import 'package:pdh/landing_screen.dart';
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
import 'package:pdh/rolebaseview.dart';
import 'package:pdh/employee_portal_screen.dart';
import 'package:pdh/employee_dashboard_screen.dart';
import 'package:pdh/manager_portal_screen.dart';
import 'package:pdh/dashboard_screen.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/ai_chatbot.dart'; // Import the new AI Chatbot screen

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); // Declare a global key for the Navigator

// Define a ValueNotifier to hold the current route name
final ValueNotifier<String?> currentRouteNotifier = ValueNotifier<String?>(null);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Remove _initialRoute and _checkCurrentUser as we always start from landing

  @override
  Widget build(BuildContext context) {
    return _GlobalChatbotWrapper(
      currentRouteNotifier: currentRouteNotifier, // Pass the ValueNotifier
      child: MaterialApp(
        navigatorKey: navigatorKey, // Assign the global key to MaterialApp
        title: 'Personal Development Hub',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.red, // Changed from Colors.blue to Colors.red
          fontFamily: 'Poppins',
        ),
        initialRoute: '/', // Always start from the landing screen
        routes: {
          '/': (context) =>
              const PersonalDevelopmentHubScreen(), // Set the root route to PersonalDevelopmentHubScreen
          '/register': (context) => const RegisterScreen(),
          '/sign_in': (context) => const LoginScreen(),
          '/my_pdp': (context) => RoleGate(requiredRole: RequiredRole.employee, child: const MyPdpScreen()),
          '/progress_visuals': (context) => const ProgressVisualsScreen(),
          '/my_goal_workspace': (context) => RoleGate(requiredRole: RequiredRole.employee, child: const MyGoalWorkspaceScreen()),
          '/gamification': (context) => const GamificationScreen(),
          '/repository_audit': (context) => const RepositoryAuditScreen(),
          '/alerts_nudges': (context) => const AlertsNudgesScreen(),
          '/season_challenge': (context) => const SeasonChallengeScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/manager_review_team_dashboard': (context) => RoleGate(requiredRole: RequiredRole.manager, child: const ManagerReviewTeamDashboardScreen()),
          '/badges_points': (context) => const BadgesPointsScreen(),
          '/leaderboard': (context) => const LeaderboardScreen(),
          '/rolebaseview': (context) => const RoleBaseViewScreen(),
          '/employee_portal': (context) => RoleGate(requiredRole: RequiredRole.employee, child: const EmployeePortalScreen()),
          '/employee_dashboard': (context) => RoleGate(requiredRole: RequiredRole.employee, child: const EmployeeDashboardScreen()),
          '/manager_portal': (context) => RoleGate(requiredRole: RequiredRole.manager, child: const ManagerPortalScreen()),
          '/dashboard': (context) => RoleGate(requiredRole: RequiredRole.manager, child: const DashboardScreen()),
          '/ai_chatbot': (context) => const AiChatbotScreen(), // Add the new AI Chatbot route
        },
        debugShowCheckedModeBanner: false,
        // Add the custom NavigatorObserver
        navigatorObservers: [MyNavigatorObserver()],
      ),
    );
  }
}

class _GlobalChatbotWrapper extends StatelessWidget {
  final Widget child;
  final ValueNotifier<String?> currentRouteNotifier;

  const _GlobalChatbotWrapper({required this.child, required this.currentRouteNotifier});

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        Directionality(
          textDirection: TextDirection.ltr, // Explicitly provide Directionality
          child: ValueListenableBuilder<String?>(
            valueListenable: currentRouteNotifier,
            builder: (context, currentRoute, _) {
              return ChatbotButton(currentRoute: currentRoute);
            },
          ),
        ),
      ],
    );
  }
}

class ChatbotButton extends StatelessWidget { // Changed to StatelessWidget
  final String? currentRoute;
  const ChatbotButton({super.key, this.currentRoute});

  @override
  Widget build(BuildContext context) {
    // Check if the current route is one of the allowed screens
    final allowedRoutes = [
      '/dashboard',
      '/my_pdp',
      '/my_goal_workspace',
      '/progress_visuals',
      '/alerts_nudges',
      '/badges_points',
      '/leaderboard',
      '/repository_audit',
      '/employee_dashboard', // Add the employee dashboard route
    ];
    if (currentRoute == null || !allowedRoutes.contains(currentRoute) || currentRoute == '/ai_chatbot') {
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
        child: Image.asset('assets/AI_Red.png', width: 40.0, height: 40.0), // Use the AI_Red.png image
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
