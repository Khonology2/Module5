import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/models/badge.dart' as badge_model;
import 'package:pdh/services/role_service.dart';

class RarityBadgesListScreen extends StatelessWidget {
  final badge_model.BadgeRarity rarity;
  final bool useManagerSidebar;
  const RarityBadgesListScreen({
    super.key,
    required this.rarity,
    this.useManagerSidebar = false,
  });

  String _titleForRarity(badge_model.BadgeRarity r) {
    switch (r) {
      case badge_model.BadgeRarity.common:
        return 'Common Goals';
      case badge_model.BadgeRarity.rare:
        return 'Rare Goals';
      case badge_model.BadgeRarity.epic:
        return 'Epic Goals';
      case badge_model.BadgeRarity.legendary:
        return 'Legendary Goals';
    }
  }

  String _subtitleForRarity(badge_model.BadgeRarity r) {
    switch (r) {
      case badge_model.BadgeRarity.common:
        return 'Levels 1–5';
      case badge_model.BadgeRarity.rare:
        return 'Levels 6–10';
      case badge_model.BadgeRarity.epic:
        return 'Levels 11–15';
      case badge_model.BadgeRarity.legendary:
        return 'Levels 16+';
    }
  }

  Color _colorForRarity(badge_model.BadgeRarity r) {
    switch (r) {
      case badge_model.BadgeRarity.common:
        return AppColors.textSecondary; // neutral
      case badge_model.BadgeRarity.rare:
        return AppColors.warningColor;
      case badge_model.BadgeRarity.epic:
        return AppColors.activeColor; // app accent
      case badge_model.BadgeRarity.legendary:
        return AppColors.successColor; // green/gold-ish
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (useManagerSidebar) {
      return _buildScaffold(context, true, user);
    }
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      initialData: useManagerSidebar
          ? 'manager'
          : RoleService.instance.cachedRole,
      builder: (context, snap) {
        final roleRaw =
            snap.data ??
            (useManagerSidebar ? 'manager' : RoleService.instance.cachedRole) ??
            '';
        final isManager = roleRaw.toLowerCase() == 'manager';
        return _buildScaffold(context, isManager, user);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, bool isManager, User? user) {
    return AppScaffold(
      title: _titleForRarity(rarity),
      showAppBar: false,
      items: isManager
          ? SidebarConfig.getItemsForRole('manager')
          : SidebarConfig.employeeItems,
      currentRouteName: isManager ? '/manager_badges_points' : '/badges_points',
      onNavigate: (route) {
        if (isManager) {
          Navigator.pushReplacementNamed(
            context,
            '/manager_portal',
            arguments: {'initialRoute': route},
          );
          return;
        }

        final current = ModalRoute.of(context)?.settings.name;
        if (current != route) Navigator.pushNamed(context, route);
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        navigator.pushNamedAndRemoveUntil('/sign_in', (route) => false);
      },
      content: user == null
          ? Center(
              child: Text(
                'Please sign in to view badges',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          : Container(
              padding: AppSpacing.screenPadding,
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.backgroundColor,
                    AppColors.backgroundColor.withValues(alpha: 0.9),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.textPrimary,
                        ),
                        tooltip: 'Back to Badges & Points',
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Back to Badges & Points',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _colorForRarity(
                            rarity,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _colorForRarity(
                              rarity,
                            ).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Icon(
                          Icons.workspace_premium,
                          color: _colorForRarity(rarity),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titleForRarity(rarity),
                              style: AppTypography.heading3.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _subtitleForRarity(rarity),
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Expanded(
                    child: StreamBuilder<List<badge_model.Badge>>(
                      stream: BadgeService.getUserBadgesStream(user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.activeColor,
                              ),
                            ),
                          );
                        }
                        final all = (snapshot.data ?? <badge_model.Badge>[])
                          ..removeWhere((b) => b.id == 'init');
                        final visible = isManager
                            ? all
                            : all
                                .where(
                                  (b) => !BadgeService.isManagerBadge(b),
                                )
                                .toList();
                        final filtered =
                            visible.where((b) => b.rarity == rarity).toList()
                              ..sort((
                              a,
                              b,
                            ) {
                              if (a.isEarned != b.isEarned)
                                // ignore: curly_braces_in_flow_control_structures
                                return a.isEarned ? -1 : 1;
                              return a.name.compareTo(b.name);
                            });
                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              'No badges in this group yet',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final badge = filtered[index];
                            final color = _colorForRarity(rarity);
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.elevatedBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: badge.isEarned
                                      ? color
                                      : AppColors.borderColor,
                                  width: badge.isEarned ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.6),
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.workspace_premium,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          badge.name,
                                          style: AppTypography.bodyLarge
                                              .copyWith(
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          badge.description,
                                          style: AppTypography.bodySmall
                                              .copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (badge.isEarned)
                                    const Icon(
                                      Icons.check_circle,
                                      color: AppColors.successColor,
                                    )
                                  else
                                    const Icon(
                                      Icons.lock_outline,
                                      color: AppColors.textSecondary,
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
