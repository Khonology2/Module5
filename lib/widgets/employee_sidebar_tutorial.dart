import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';

/// Tutorial step information for sidebar items
class SidebarTutorialStep {
  final String route;
  final String title;
  final String description;

  SidebarTutorialStep({
    required this.route,
    required this.title,
    required this.description,
  });
}

/// Tutorial configuration for employee sidebar
class EmployeeSidebarTutorialConfig {
  EmployeeSidebarTutorialConfig._();

  static final List<SidebarTutorialStep> steps = [
    SidebarTutorialStep(
      route: '/employee_dashboard',
      title: 'Welcome to Your Dashboard!',
      description:
          'This is your main dashboard where you can see your progress, goals, and activities at a glance.',
    ),
    SidebarTutorialStep(
      route: '/my_pdp',
      title: 'My PDP (Personal Development Plan)',
      description:
          'Access your Personal Development Plan to set and track your long-term career goals.',
    ),
    SidebarTutorialStep(
      route: '/my_profile',
      title: 'My Profile',
      description:
          'View and manage your profile information, skills, and career aspirations.',
    ),
    SidebarTutorialStep(
      route: '/my_goal_workspace',
      title: 'Goal Workspace',
      description:
          'Create, manage, and track all your individual goals in one place.',
    ),
    SidebarTutorialStep(
      route: '/progress_visuals',
      title: 'Progress Visuals',
      description:
          'Visualize your progress with charts and graphs to see how you\'re advancing.',
    ),
    SidebarTutorialStep(
      route: '/alerts_nudges',
      title: 'Alerts & Nudges',
      description:
          'Stay on track with personalized alerts and helpful reminders about your goals.',
    ),
    SidebarTutorialStep(
      route: '/badges_points',
      title: 'Badges & Points',
      description:
          'Earn badges and points for achieving milestones and completing goals.',
    ),
    SidebarTutorialStep(
      route: '/leaderboard',
      title: 'Leaderboard',
      description:
          'See how you rank against your peers and compete for the top spot!',
    ),
    SidebarTutorialStep(
      route: '/repository_audit',
      title: 'Repository & Audit',
      description:
          'Access resources, learning materials, and review your activity audit trail.',
    ),
    SidebarTutorialStep(
      route: '/settings',
      title: 'Settings & Privacy',
      description:
          'Manage your account settings, privacy preferences, and app configurations.',
    ),
  ];
}

/// Widget that wraps sidebar items with tutorial showcase
class EmployeeSidebarTutorialWrapper extends StatelessWidget {
  final Widget child;
  final String route;
  final int stepIndex;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLastStep;
  final GlobalKey showcaseKey;

  const EmployeeSidebarTutorialWrapper({
    super.key,
    required this.child,
    required this.route,
    required this.stepIndex,
    required this.onNext,
    required this.onSkip,
    required this.isLastStep,
    required this.showcaseKey,
  });

  @override
  Widget build(BuildContext context) {
    final step = EmployeeSidebarTutorialConfig.steps[stepIndex];

    return Showcase(
      key: showcaseKey,
      title: step.title,
      description: step.description,
      targetShapeBorder: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      tooltipBackgroundColor: AppColors.backgroundColor,
      textColor: AppColors.textPrimary,
      titleTextStyle: AppTypography.heading4,
      descTextStyle: AppTypography.bodyMedium,
      overlayColor: Colors.black87,
      overlayOpacity: 0.8,
      tooltipPadding: const EdgeInsets.all(20),
      showArrow: true,
      onBarrierClick: onNext,
      onTargetClick: onNext,
      onToolTipClick: onNext,
      child: child,
    );
  }
}
