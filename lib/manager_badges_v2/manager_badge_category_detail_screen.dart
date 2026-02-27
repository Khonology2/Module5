import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/models/badge.dart' as badge_model;
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/utils/firestore_web_circuit_breaker.dart';
import 'package:pdh/widgets/app_scaffold.dart';

Color _categoryAccent(badge_model.BadgeCategory _) => AppColors.activeColor;

class ManagerBadgeCategoryDetailScreen extends StatefulWidget {
  final badge_model.BadgeCategory category;
  final String title;
  final bool embedded;
  final String? initialBadgeId;

  const ManagerBadgeCategoryDetailScreen({
    super.key,
    required this.category,
    required this.title,
    this.embedded = false,
    this.initialBadgeId,
  });

  @override
  State<ManagerBadgeCategoryDetailScreen> createState() =>
      _ManagerBadgeCategoryDetailScreenState();
}

class _ManagerBadgeCategoryDetailScreenState
    extends State<ManagerBadgeCategoryDetailScreen> {
  bool _didAutoOpen = false;

  Color _rarityColor(badge_model.BadgeRarity r) {
    switch (r) {
      case badge_model.BadgeRarity.common:
        return AppColors.textSecondary;
      case badge_model.BadgeRarity.rare:
        return AppColors.activeColor;
      case badge_model.BadgeRarity.epic:
        return AppColors.warningColor;
      case badge_model.BadgeRarity.legendary:
        return const Color(0xFFFFD700);
    }
  }

  void _maybeAutoOpenBadge(List<badge_model.Badge> list) {
    if (_didAutoOpen) return;
    final targetId = widget.initialBadgeId?.trim();
    if (targetId == null || targetId.isEmpty) return;

    badge_model.Badge? target;
    for (final b in list) {
      if (b.id == targetId) {
        target = b;
        break;
      }
      final criteriaId = (b.criteria['badgeId'] ?? '').toString().trim();
      if (criteriaId.isNotEmpty && criteriaId == targetId) {
        target = b;
        break;
      }
    }
    if (target == null) return;

    _didAutoOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showBadgeDetail(target!, _rarityColor(target.rarity));
    });
  }

  void _showBadgeDetail(
    badge_model.Badge badge,
    Color accent,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.elevatedBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                badge.name,
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                badge.rarity.name.toUpperCase(),
                style: AppTypography.bodySmall.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              badge.description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (badge.isEarned)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.successColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Earned',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.successColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                'Progress: ${badge.progress}/${badge.maxProgress}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: badge.progressPercentage,
                  minHeight: 8,
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.activeColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final accent = _categoryAccent(widget.category);
    return AppScaffold(
      title: widget.title,
      showAppBar: false,
      embedded: widget.embedded,
      items: SidebarConfig.getItemsForRole('manager'),
      currentRouteName: '/manager_badges_points',
      onNavigate: (route) {
        if (widget.embedded) return;
        Navigator.pushReplacementNamed(
          context,
          '/manager_portal',
          arguments: {'initialRoute': route},
        );
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        if (context.mounted) {
          navigator.pushNamedAndRemoveUntil('/landing', (route) => false);
        }
      },
      content: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/khono_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: ClipRRect(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  _BackButton(accentColor: accent, onPressed: () {
                    final nav = Navigator.of(context);
                    if (nav.canPop()) {
                      nav.pop();
                    } else {
                      nav.pushReplacementNamed('/manager_badges_points');
                    }
                  }),
                  const SizedBox(height: AppSpacing.md),
                  _Header(title: widget.title, accentColor: accent),
                  const SizedBox(height: AppSpacing.lg),
                  if (user == null)
                    const _EmptyState(
                      message: 'Please sign in to view badges',
                      icon: Icons.lock_outline,
                    )
                  else
                    StreamBuilder<List<badge_model.Badge>>(
                      stream: BadgeService.getUserBadgesStream(user.uid),
                      initialData: const [],
                      builder: (context, snap) {
                        if (FirestoreWebCircuitBreaker.isBroken) {
                          return _FirestoreBrokenState(
                            onReload: FirestoreWebCircuitBreaker.forceReload,
                          );
                        }

                        final all = (snap.data ?? const <badge_model.Badge>[])
                            .where((b) => b.id != 'init')
                            .where(BadgeService.isManagerBadge)
                            .toList();
                        final list = all
                          .where((b) => b.category == widget.category)
                          .toList()
                          ..sort((a, b) {
                            if (a.isEarned != b.isEarned) {
                              return a.isEarned ? -1 : 1;
                            }
                            final p = b.progressPercentage.compareTo(
                              a.progressPercentage,
                            );
                            if (p != 0) return p;
                            return a.name.compareTo(b.name);
                          });

                        if (snap.connectionState == ConnectionState.waiting &&
                            list.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.activeColor,
                                ),
                              ),
                            ),
                          );
                        }

                        if (list.isEmpty) {
                          return const _EmptyState(
                            message:
                                'No badges in this category yet. Keep going!',
                            icon: Icons.emoji_events_outlined,
                          );
                        }

                        _maybeAutoOpenBadge(list);
                        return _BadgeGrid(badges: list);
                      },
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

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color accentColor;
  const _BackButton({required this.onPressed, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accentColor, width: 2),
              color: Colors.black.withValues(alpha: 0.10),
            ),
            child: Center(
              child: Icon(
                Icons.arrow_back,
                color: accentColor,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final Color accentColor;
  const _Header({required this.title, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.category, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppTypography.heading3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FirestoreBrokenState extends StatelessWidget {
  final VoidCallback onReload;
  const _FirestoreBrokenState({required this.onReload});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 56,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Badges are temporarily unavailable',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'We hit a Firestore web connection issue. Reloading the page fixes it.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: onReload,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.activeColor,
                side: const BorderSide(color: AppColors.activeColor, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(
                'Reload',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  final List<badge_model.Badge> badges;
  const _BadgeGrid({required this.badges});

  Color _rarityColor(badge_model.BadgeRarity r) {
    switch (r) {
      case badge_model.BadgeRarity.common:
        return AppColors.textSecondary;
      case badge_model.BadgeRarity.rare:
        return AppColors.activeColor;
      case badge_model.BadgeRarity.epic:
        return AppColors.warningColor;
      case badge_model.BadgeRarity.legendary:
        return const Color(0xFFFFD700);
    }
  }

  Widget _iconForBadge(String iconName) {
    switch (iconName) {
      case 'verified':
        return const Icon(Icons.verified, color: Colors.white, size: 18);
      case 'chat':
        return const Icon(Icons.chat, color: Colors.white, size: 18);
      case 'flag':
        return const Icon(Icons.flag, color: Colors.white, size: 18);
      case 'bolt':
        return const Icon(Icons.bolt, color: Colors.white, size: 18);
      case 'build':
        return const Icon(Icons.build, color: Colors.white, size: 18);
      case 'calendar_today':
        return const Icon(Icons.calendar_today, color: Colors.white, size: 18);
      case 'groups':
        return const Icon(Icons.groups, color: Colors.white, size: 18);
      case 'workspace_premium':
        return const Icon(Icons.workspace_premium, color: Colors.white, size: 18);
      case 'emoji_events':
        return const Icon(Icons.emoji_events, color: Colors.white, size: 18);
      case 'trophy':
        return const Icon(Icons.emoji_events, color: Colors.white, size: 18);
      case 'diversity_3':
        return const Icon(Icons.diversity_3, color: Colors.white, size: 18);
      case 'check_circle':
        return const Icon(Icons.check_circle, color: Colors.white, size: 18);
      default:
        return const Icon(Icons.emoji_events, color: Colors.white, size: 18);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 900
            ? 4
            : width >= 600
                ? 3
                : 2;
        final childAspectRatio = crossAxisCount >= 4
            ? 0.86
            : crossAxisCount == 3
                ? 0.9
                : 0.95;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: badges.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) {
            final b = badges[i];
            final accent = _rarityColor(b.rarity);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showBadgeDetail(context, b, accent),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: b.isEarned
                          ? accent.withValues(alpha: 0.8)
                          : Colors.white.withValues(alpha: 0.18),
                      width: b.isEarned ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Center(child: _iconForBadge(b.iconName)),
                          ),
                          const Spacer(),
                          Icon(
                            b.isEarned ? Icons.check_circle : Icons.lock_outline,
                            color: b.isEarned
                                ? AppColors.successColor
                                : AppColors.textSecondary,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        b.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        b.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          height: 1.2,
                        ),
                      ),
                      const Spacer(),
                      if (!b.isEarned)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: b.progressPercentage,
                                minHeight: 5,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${b.progress}/${b.maxProgress}',
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          'Earned',
                          style: AppTypography.bodySmall.copyWith(
                            fontSize: 11,
                            color: AppColors.successColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBadgeDetail(
    BuildContext context,
    badge_model.Badge badge,
    Color accent,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.elevatedBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                badge.name,
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                badge.rarity.name.toUpperCase(),
                style: AppTypography.bodySmall.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              badge.description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (badge.isEarned)
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.successColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Earned',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.successColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                'Progress: ${badge.progress}/${badge.maxProgress}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: badge.progressPercentage,
                  minHeight: 8,
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.activeColor),
            ),
          ),
        ],
      ),
    );
  }
}

