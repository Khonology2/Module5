// ignore_for_file: unused_element, duplicate_import

import 'package:flutter/material.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/widgets/sidebar.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/employee_tutorial_service.dart';
import 'package:pdh/widgets/employee_sidebar_tutorial.dart';
import 'package:pdh/widgets/messages_icon.dart';
import 'package:pdh/widgets/notifications_bell.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

/// MainLayout provides a persistent, collapsible sidebar layout for all
/// application pages. It reuses the dashboard's sidebar and visuals.
class MainLayout extends StatelessWidget {
  const MainLayout({
    super.key,
    required this.title,
    required this.currentRouteName,
    required this.body,
    this.items,
  });

  /// Title shown when an AppBar is enabled (we keep it hidden by default)
  final String title;

  /// The current route name (e.g. '/my_pdp'). Used to highlight the active item
  final String currentRouteName;

  /// The main page content
  final Widget body;

  /// Sidebar items; when null, uses [SidebarConfig.employeeItems] (e.g. for manager GW menu use [SidebarConfig.managerItems]).
  final List<SidebarItem>? items;


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

    final sidebarItems = items ?? SidebarConfig.employeeItems;
    return AppScaffold(
      title: title,
      showAppBar: false,
      items: sidebarItems,
      currentRouteName: currentRouteName,
      topRightAction: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MessagesIcon(),
          SizedBox(width: 8),
          NotificationsBell(),
        ],
      ),
      tutorialStepIndex: tutorialParams['tutorialStepIndex'] as int?,
      sidebarTutorialKeys: null,
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
        Navigator.pushNamedAndRemoveUntil(context, '/landing', (r) => false);
      },
      // Full-viewport background (light/dark) behind content — not inside the page
      // scroll view, so the image stays fixed while [body] scrolls internally.
      content: ValueListenableBuilder<bool>(
        valueListenable: employeeDashboardLightModeNotifier,
        builder: (context, light, _) {
          return AppComponents.backgroundWithImage(
            blurSigma: 0,
            imagePath: light
                ? 'assets/light_mode_bg.png'
                : 'assets/khono_bg.png',
            gradientColors: light
                ? [
                    Colors.white.withValues(alpha: 0.2),
                    Colors.white.withValues(alpha: 0.08),
                  ]
                : null,
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: body,
            ),
          );
        },
      ),
    );
  }
}
