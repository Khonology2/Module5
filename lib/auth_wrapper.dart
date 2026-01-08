import 'package:flutter/material.dart';
import 'package:pdh/sign_in_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/role_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A1931),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
              ),
            ),
          );
        }

        final user = snapshot.data;

        // If no authenticated user, show the normal login screen
        if (user == null) {
          return const LoginScreen();
        }

        // User is signed in: determine their role and route them
        return FutureBuilder<String?>(
          future: () async {
            await RoleService.instance.ensureRoleLoaded();
            // ensureRoleLoaded caches the role; return cached value
            return RoleService.instance.cachedRole;
          }(),
          builder: (context, roleSnapshot) {
            final role = roleSnapshot.data ?? RoleService.instance.cachedRole;

            // While role is unknown, keep a loading screen to avoid misrouting
            if (role == null || roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final targetRoute = role == 'manager'
                ? '/manager_portal'
                : '/employee_dashboard';

            // Navigate after the current frame to avoid build-time navigation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, targetRoute);
            });

            // Temporary placeholder while navigation happens
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
    );
  }
}
