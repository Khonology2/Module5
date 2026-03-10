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
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // If role is still null after loading, don't spin forever.
            if (role == null) {
              return _RoleNotSetScreen(
                onTryAgain: () async {
                  RoleService.instance.clearCache();
                  await RoleService.instance.ensureRoleLoaded();
                  if (context.mounted) setState(() {});
                },
                onSignOut: () async {
                  await FirebaseAuth.instance.signOut();
                },
              );
            }

            final String targetRoute;
            if (role == 'manager') {
              targetRoute = '/manager_portal';
            } else if (role == 'admin') {
              targetRoute = '/admin_portal';
            } else {
              targetRoute = '/employee_dashboard';
            }

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

class _RoleNotSetScreen extends StatelessWidget {
  final Future<void> Function() onTryAgain;
  final Future<void> Function() onSignOut;

  const _RoleNotSetScreen({
    required this.onTryAgain,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1931),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2840),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.help_outline, color: Colors.orangeAccent),
                  const SizedBox(height: 12),
                  const Text(
                    'We can’t determine your portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your account role is missing or not accessible. This can happen if your user profile wasn’t created yet, or if permissions prevent reading it.',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await onTryAgain();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Try again'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await onSignOut();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
