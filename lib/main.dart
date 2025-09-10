import 'package:flutter/material.dart';
import 'package:pdh/landing_screen.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome
import 'package:firebase_core/firebase_core.dart';
import 'package:pdh/firebase_options.dart';
import 'package:pdh/dashboard_screen.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding is initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Development Hub',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const PersonalDevelopmentHubScreen(),
        '/register': (context) => const RegisterScreen(),
        '/sign_in': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/my_pdp': (context) => const MyPdpScreen(),
        '/progress_visuals': (context) => const ProgressVisualsScreen(),
        '/my_goal_workspace': (context) => const MyGoalWorkspaceScreen(),
        '/gamification': (context) => const GamificationScreen(),
        '/repository_audit': (context) => const RepositoryAuditScreen(),
        '/alerts_nudges': (context) => const AlertsNudgesScreen(),
        '/season_challenge': (context) => const SeasonChallengeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
