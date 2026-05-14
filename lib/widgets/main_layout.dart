// ignore_for_file: unused_element, duplicate_import

import 'package:flutter/material.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/widgets/sidebar.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/employee_tutorial_service.dart';
import 'package:pdh/widgets/employee_sidebar_tutorial.dart';
import 'package:pdh/widgets/header_action_icons.dart';

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
      topRightAction: const HeaderActionIcons(),
      tutorialStepIndex: tutorialParams['tutorialStepIndex'] as int?,
      sidebarTutorialKeys: null,
      onTutorialNext: tutorialParams['onTutorialNext'] as VoidCallback?,
      onTutorialSkip: tutorialParams['onTutorialSkip'] as VoidCallback?,
      onNavigate: (route) {
        final activeRoute = ModalRoute.of(context)?.settings.name ?? currentRouteName;
        debugPrint('[MainLayout] navigate from=$activeRoute to=$route');
        if (activeRoute != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        await AuthService().signOut();
        // ignore: use_build_context_synchronously
        Navigator.pushNamedAndRemoveUntil(context, '/landing', (r) => false);
      },
      // Horizontal page margins; full-bleed background is painted by [AppScaffold].
      content: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xxl,
          0,
          AppSpacing.xxl,
          AppSpacing.xxl,
        ),
        child: body,
      ),
    );
  }
}
