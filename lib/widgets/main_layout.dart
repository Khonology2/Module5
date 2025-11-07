import 'package:flutter/material.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    return AppScaffold(
      title: title,
      showAppBar: false,
      items: SidebarConfig.employeeItems,
      currentRouteName: currentRouteName,
      topRightAction: _ProfileButton(),
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
        imagePath:
            'assets/khono_bg.png',
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
        String userName = 'User';
        if (user?.displayName != null && user!.displayName!.isNotEmpty) {
          userName = user.displayName!.split(' ').first;
        } else if (user?.email != null && user!.email!.isNotEmpty) {
          userName = user.email!.split('@').first;
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
