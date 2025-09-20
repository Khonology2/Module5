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
      ),
    );
  }
}

class _GlobalChatbotWrapper extends StatelessWidget {
  final Widget child;

  const _GlobalChatbotWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        child,
        Directionality(
          textDirection: TextDirection.ltr, // Explicitly provide Directionality
          child: const ChatbotButton(),
        ),
      ],
    );
  }
}

class ChatbotButton extends StatelessWidget {
  const ChatbotButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        onPressed: () {
          // Navigate to the AI Chatbot screen using the global key
          navigatorKey.currentState!.pushNamed('/ai_chatbot');
        },
        backgroundColor: const Color(0xFFC10D00), // Use the app's red color
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
    );
  }
}
