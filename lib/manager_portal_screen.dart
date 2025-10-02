import 'package:flutter/material.dart';
import 'package:pdh/dashboard_screen.dart'; // Import DashboardScreen
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth for logout
import 'package:pdh/widgets/app_scaffold.dart'; // Import AppScaffold
import 'package:pdh/design_system/sidebar_config.dart'; // Import SidebarConfig
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/manager_profile_screen.dart'; // Import ManagerProfileScreen
import 'package:pdh/auth_service.dart';


class ManagerPortalScreen extends StatefulWidget {
  const ManagerPortalScreen({super.key});

  @override
  State<ManagerPortalScreen> createState() => _ManagerPortalScreenState();
}

class _ManagerPortalScreenState extends State<ManagerPortalScreen> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Manager Portal',
      showAppBar: false,
      items: SidebarConfig.managerItems,
      currentRouteName: '/manager_portal',
      topRightAction: _profileButton(context),
      onNavigate: (route) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        await AuthService().signOut();
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
              const DashboardScreen(), // Embed the dashboard content
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileButton(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String userName = 'User';
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      userName = user.displayName!.split(' ').first;
    } else if (user?.email != null && user!.email!.isNotEmpty) {
      userName = user.email!.split('@').first;
    }
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const ManagerProfileScreen(),
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
    String userName = 'Manager';
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
                  'Ready to lead your team to success today?',
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
}
