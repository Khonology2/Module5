// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:pdh/employee_profile_screen.dart'; // Import EmployeeProfileScreen
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Employee Dashboard',
      showAppBar: false,
      items: SidebarConfig.employeeItems,
      currentRouteName: '/employee_dashboard',
      topRightAction: _profileButton(context),
      onNavigate: (route) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        await AuthService().signOut();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/sign_in',
          (route) => false,
        );
      },
      content: AppComponents.backgroundWithImage(
        imagePath:
            'assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png',
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeCard(),
              const SizedBox(height: AppSpacing.xl),
              _buildQuickStats(),
              const SizedBox(height: AppSpacing.xl),
              _buildRecentActivity(),
              const SizedBox(height: AppSpacing.xl),
              _buildQuickActions(),
              const SizedBox(height: AppSpacing.xl),
              _buildUpcomingGoals(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Profile';
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const EmployeeProfileScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.elevatedBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              userName,
              style: AppTypography.bodySmall.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'User';
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      userName = user.displayName!.split(' ').first;
    } else if (user?.email != null && user!.email!.isNotEmpty) {
      userName = user.email!.split('@').first;
    }

    return AppComponents.accentCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.activeColor,
            child: Icon(Icons.person, size: 30, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back, $userName!', style: AppTypography.heading4),
                const SizedBox(height: 5),
                Text(
                  'Ready to achieve your goals today?',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: AppComponents.kpiCard(
            label: 'Active Goals',
            value: '8',
            icon: Icons.track_changes,
            iconColor: AppColors.activeColor,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppComponents.kpiCard(
            label: 'Completed',
            value: '12',
            icon: Icons.check_circle,
            iconColor: AppColors.successColor,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppComponents.kpiCard(
            label: 'Points',
            value: '1,250',
            icon: Icons.stars,
            iconColor: AppColors.warningColor,
          ),
        ),
      ],
    );
  }

  // This method is no longer needed as we're using AppComponents.kpiCard

  Widget _buildRecentActivity() {
    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activity', style: AppTypography.heading4),
          const SizedBox(height: AppSpacing.md),
          AppComponents.activityItem(
            icon: Icons.check_circle,
            title: 'Completed "Learn React Native"',
            subtitle: '2 hours ago',
            iconColor: AppColors.successColor,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppComponents.activityItem(
            icon: Icons.add_circle,
            title: 'Added new goal: "Master Flutter"',
            subtitle: '1 day ago',
            iconColor: AppColors.activeColor,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppComponents.activityItem(
            icon: Icons.stars,
            title: 'Earned "Code Master" badge',
            subtitle: '3 days ago',
            iconColor: AppColors.warningColor,
          ),
        ],
      ),
    );
  }

  // This method is no longer needed as we're using AppComponents.activityItem

  Widget _buildQuickActions() {
    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTypography.heading4),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Add Goal',
                  icon: Icons.add,
                  onPressed: () {
                    Navigator.pushNamed(context, '/my_goal_workspace');
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'View Progress',
                  icon: Icons.bar_chart,
                  onPressed: () {
                    Navigator.pushNamed(context, '/progress_visuals');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Leaderboard',
                  icon: Icons.leaderboard,
                  onPressed: () {
                    Navigator.pushNamed(context, '/leaderboard');
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Badges',
                  icon: Icons.workspace_premium,
                  onPressed: () {
                    Navigator.pushNamed(context, '/badges_points');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // This method is no longer needed as we're using AppComponents.primaryButton

  Widget _buildUpcomingGoals() {
    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Upcoming Goals', style: AppTypography.heading4),
          const SizedBox(height: AppSpacing.md),
          _buildGoalItem(
            title: 'Complete Flutter Certification',
            deadline: 'Due in 5 days',
            progress: 0.7,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildGoalItem(
            title: 'Learn Advanced React Patterns',
            deadline: 'Due in 12 days',
            progress: 0.3,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildGoalItem(
            title: 'Build Portfolio Project',
            deadline: 'Due in 20 days',
            progress: 0.1,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem({
    required String title,
    required String deadline,
    required double progress,
  }) {
    return AppComponents.card(
      padding: const EdgeInsets.all(12),
      backgroundColor: AppColors.elevatedBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(deadline, style: AppTypography.muted),
          const SizedBox(height: 8),
          AppComponents.progressBar(
            value: progress,
            label: '${(progress * 100).toInt()}% Complete',
          ),
        ],
      ),
    );
  }
}
