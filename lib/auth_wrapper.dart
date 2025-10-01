import 'package:flutter/material.dart';
import 'package:pdh/sign_in_screen.dart'; // Import LoginScreen which is the actual sign-in screen

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
          // User is signed in, initialize data if needed and navigate to RoleBaseViewScreen
          DatabaseService.initializeUserData(user.uid, user.displayName, user.email);
          return const RoleBaseViewScreen();
        } else {
          // User is signed out, show SignInScreen
          return const LoginScreen(); // Use the actual LoginScreen from sign_in_screen.dart
        }
      },
    );
    */
  }
}
