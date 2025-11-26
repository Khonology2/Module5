import 'package:flutter/material.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/employee_tutorial_service.dart';
import 'package:pdh/widgets/employee_sidebar_tutorial.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/employee_profile_screen.dart';
import 'package:pdh/manager_profile_screen.dart';
import 'package:pdh/widgets/notifications_bell.dart';

/// MainLayout provides a persistent, collapsible sidebar layout for all
/// application pages. It reuses the dashboard's sidebar and visuals.
class MainLayout extends StatelessWidget {
  const MainLayout({
    super.key,
    required this.title,
    required this.currentRouteName,
    required this.body,
  });

  /// Title shown when an AppBar is enabled (we keep it hidden by default)
  final String title;

  /// The current route name (e.g. '/my_pdp'). Used to highlight the active item
  final String currentRouteName;

  /// The main page content
  final Widget body;

  @override
  Widget build(BuildContext context) {
    // Get tutorial state from global service and update context
    final tutorialService = EmployeeTutorialService.instance;
    if (tutorialService.isTutorialActive) {
      tutorialService.setCurrentContext(context);

      // Check if we should show tutorial popup for this screen
      // This happens after navigation when the new screen builds
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (tutorialService.isTutorialActive) {
          // Check if current route matches the tutorial step
          final currentRoute = ModalRoute.of(context)?.settings.name;
          if (currentRoute != null &&
              tutorialService.currentTutorialStep <
                  EmployeeSidebarTutorialConfig.steps.length) {
            final step = EmployeeSidebarTutorialConfig
                .steps[tutorialService.currentTutorialStep];
            if (step.route == currentRoute ||
                (step.route == '__collapse_toggle__' &&
                    tutorialService.currentTutorialStep ==
                        SidebarConfig.employeeItems.length)) {
              // This screen matches the current tutorial step, show popup
              Future.delayed(const Duration(milliseconds: 500), () {
                if (tutorialService.isTutorialActive) {
                  // ignore: use_build_context_synchronously
                  tutorialService.showTutorialPopup(context);
                }
              });
            }
          }
        }
      });
    }
    final tutorialParams = tutorialService.getTutorialParams();

    return AppScaffold(
      title: title,
      showAppBar: false,
      items: SidebarConfig.employeeItems,
      currentRouteName: currentRouteName,
      topRightAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NotificationsBell(),
          const SizedBox(width: 8),
          _ProfileButton(),
        ],
      ),
      tutorialStepIndex: tutorialParams['tutorialStepIndex'] as int?,
      sidebarTutorialKeys:
          tutorialParams['sidebarTutorialKeys'] as List<GlobalKey>?,
      onTutorialNext: tutorialParams['onTutorialNext'] as VoidCallback?,
      onTutorialSkip: tutorialParams['onTutorialSkip'] as VoidCallback?,
      onNavigate: (route) {
        if (ModalRoute.of(context)?.settings.name != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        await AuthService().signOut();
        // ignore: use_build_context_synchronously
        Navigator.pushNamedAndRemoveUntil(context, '/sign_in', (r) => false);
      },
      // Keep background and spacing consistent with dashboard
      content: AppComponents.backgroundWithImage(
        imagePath: 'assets/khono_bg.png',
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: body,
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, snapshot) {
        final user = FirebaseAuth.instance.currentUser;
        final isManager =
            (snapshot.data ?? RoleService.instance.cachedRole) == 'manager';

        return FutureBuilder<String?>(
          future: user != null
              ? DatabaseService.getUserNameFromOnboarding(
                  userId: user.uid,
                  email: user.email,
                )
              : Future.value(null),
          builder: (context, nameSnapshot) {
            String userName = 'User';
            if (nameSnapshot.hasData &&
                nameSnapshot.data != null &&
                nameSnapshot.data!.isNotEmpty) {
              userName = nameSnapshot.data!;
            } else if (user?.displayName != null &&
                user!.displayName!.isNotEmpty) {
              userName = user.displayName!;
            } else if (user?.email != null && user!.email!.isNotEmpty) {
              userName = user.email!.split('@').first;
            }

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => isManager
                        ? const ManagerProfileScreen()
                        : const EmployeeProfileScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3652),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x1FFFFFFF)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
