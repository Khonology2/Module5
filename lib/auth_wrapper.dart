import 'package:flutter/material.dart';
import 'package:pdh/sign_in_screen.dart'; // Import LoginScreen which is the actual sign-in screen
// Uncomment these imports when re-enabling authentication flow:
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:pdh/services/database_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    // For development/testing: Always navigate to the LoginScreen
    // To re-enable authentication flow, uncomment the StreamBuilder code below
    return const LoginScreen();

    /*
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;

        if (user != null) {
          // User is signed in, initialize data if needed and navigate to appropriate screen
          DatabaseService.initializeUserData(user.uid, user.displayName, user.email);
          // Navigate to dashboard based on user role - this would need role checking logic
          return const LoginScreen(); // Placeholder - implement role-based navigation
        } else {
          // User is signed out, show SignInScreen
          return const LoginScreen(); // Use the actual LoginScreen from sign_in_screen.dart
        }
      },
    );
    */
  }
}
