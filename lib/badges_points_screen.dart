import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/services/streak_service.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/badge.dart' as badge_model;

class BadgesPointsScreen extends StatefulWidget {
  final bool embedded;

  const BadgesPointsScreen({super.key, this.embedded = false});

  @override
  State<BadgesPointsScreen> createState() => _BadgesPointsScreenState();
}

class _BadgesPointsScreenState extends State<BadgesPointsScreen>
    with TickerProviderStateMixin {
  UserProfile? userProfile;
  List<Map<String, dynamic>> leaderboard = <Map<String, dynamic>>[];
  int userRank = 1;
  int currentStreak = 0;
  bool hasActivityToday = false;
  bool _attemptedInitBadges = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Initialize default values to prevent null issues
    setState(() {
      currentStreak = 0;
      hasActivityToday = false;
      userRank = 0;
      leaderboard = [];
    });

    _loadData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Ensure badge progress is up to date for this user
        await BadgeService.checkAndAwardBadges(user.uid);

        final profile = await DatabaseService.getUserProfile(user.uid);
        final leaderboardData = await BadgeService.getLeaderboard();
        final rank = await BadgeService.getUserRank(user.uid);
        final streak = await StreakService.getCurrentStreak(user.uid);
        final activityToday = await StreakService.hasActivityToday(user.uid);

        if (mounted) {
          setState(() {
            userProfile = profile;
            leaderboard = leaderboardData;
            userRank = rank > 0 ? rank : 1;
            currentStreak = streak >= 0 ? streak : 0;
            hasActivityToday = activityToday;
          });
        }
      } catch (e) {
        developer.log('Error loading data: $e', name: 'BadgesPointsScreen');
        // Set safe default values on error
        if (mounted) {
          setState(() {
            userProfile = null;
            leaderboard = [];
            userRank = 1;
            currentStreak = 0;
            hasActivityToday = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Badges & Points',
      showAppBar: false,
      embedded: widget.embedded,
      items: SidebarConfig.employeeItems,
      currentRouteName: '/badges_points',
      onNavigate: (route) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        if (mounted) {
          navigator.pushNamedAndRemoveUntil('/sign_in', (route) => false);
        }
      },
      content: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundColor,
              AppColors.backgroundColor.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Badges & Points',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildPointsAndLevelCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildUserRankCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader('Your Badges'),
                  _buildBadgesSection(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader('Leaderboard'),
                  _buildLeaderboard(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader('Progress Stats'),
                  _buildProgressStats(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildPointsAndLevelCard() {
    final points = userProfile?.totalPoints ?? 0;
    final level = userProfile?.level ?? 1;
    final nextLevelPoints = level * 500;
    final currentLevelPoints = (level - 1) * 500;
    final progressToNext = nextLevelPoints - points;
    final progressPercentage = level > 1
        ? ((points - currentLevelPoints) /
                  (nextLevelPoints - currentLevelPoints))
              .clamp(0.0, 1.0)
        : (points / 500).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.activeColor, // Red
            Color(0xFF8B0000), // Dark red
            Color(0xFF2D1B1B), // Very dark red/brown
            Color(0xFF1A1A1A), // Almost black
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.activeColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatNumber(points),
                    style: AppTypography.heading1.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Total Points',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Level $level',
                    style: AppTypography.heading1.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _getLevelTitle(level),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress to Level ${level + 1}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    '$progressToNext XP to go',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progressPercentage,
                backgroundColor: AppColors.textPrimary.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.textPrimary,
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserRankCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.activeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.activeColor, width: 2),
            ),
            child: Center(
              child: Text(
                '#$userRank',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.activeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Global Rank',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getRankDescription(userRank),
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.emoji_events, color: AppColors.warningColor, size: 32),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Please sign in to view badges',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return StreamBuilder<List<badge_model.Badge>>(
      stream: BadgeService.getUserBadgesStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Error loading badges',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.dangerColor,
              ),
            ),
          );
        }

        final badges = snapshot.data ?? [];
        // Filter out any placeholder docs like 'init'
        final visibleBadges = badges.where((b) => b.id != 'init').toList();

        if (visibleBadges.isEmpty) {
          // Initialize a user's badge catalog on first visit if missing
          if (!_attemptedInitBadges) {
            _attemptedInitBadges = true;
            final u = FirebaseAuth.instance.currentUser;
            if (u != null) {
              Future.microtask(() async {
                try {
                  await BadgeService.initializeUserBadges(u.uid);
                  await BadgeService.checkAndAwardBadges(u.uid);
                } catch (_) {}
              });
            }
          }
          return _buildEmptyBadgesState();
        }

        return Column(
          children: visibleBadges
              .map(
                (badge) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _buildBadgeCard(badge),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyBadgesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No badges yet',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start completing goals and activities to earn your first badges!',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, '/my_goal_workspace');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(badge_model.Badge badge) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBadgeDetail(badge),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: badge.isEarned
                  ? AppColors.elevatedBackground
                  : AppColors.elevatedBackground.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: badge.isEarned
                    ? _getBadgeRarityColor(badge.rarity)
                    : AppColors.borderColor,
                width: badge.isEarned ? 2 : 1,
              ),
              boxShadow: badge.isEarned
                  ? [
                      BoxShadow(
                        color: _getBadgeRarityColor(
                          badge.rarity,
                        ).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _getBadgeRarityColor(
                      badge.rarity,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _getBadgeRarityColor(badge.rarity),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _getBadgeIcon(badge.iconName),
                    color: badge.isEarned
                        ? _getBadgeRarityColor(badge.rarity)
                        : AppColors.textSecondary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              badge.name,
                              style: AppTypography.bodyLarge.copyWith(
                                color: badge.isEarned
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getBadgeRarityColor(
                                badge.rarity,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              badge.rarity.name.toUpperCase(),
                              style: AppTypography.bodySmall.copyWith(
                                color: _getBadgeRarityColor(badge.rarity),
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badge.description,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!badge.isEarned) ...[
                        Row(
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: badge.progressPercentage,
                                backgroundColor: AppColors.borderColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getBadgeRarityColor(badge.rarity),
                                ),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${badge.progress}/${badge.maxProgress}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppColors.successColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Earned ${_formatDate(badge.earnedAt!)}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.successColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (badge.isEarned ? Colors.red : AppColors.textSecondary)
                            .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge.isEarned ? 'Earned' : 'Locked',
                    style: AppTypography.bodySmall.copyWith(
                      color: badge.isEarned
                          ? Colors.red
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStats() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Container();

    // Ensure all values are safely initialized
    final safeUserProfile = userProfile;
    final safeCurrentStreak = currentStreak;
    final safeUserRank = userRank;
    final safeHasActivityToday = hasActivityToday;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Progress',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Points',
                  _formatNumber(safeUserProfile?.totalPoints ?? 0),
                  Icons.stars,
                  AppColors.warningColor,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Current Level',
                  'Level ${(safeUserProfile?.level ?? 1).toString()}',
                  Icons.military_tech,
                  AppColors.activeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Current Streak',
                  '${safeCurrentStreak.toString()} days',
                  safeHasActivityToday
                      ? Icons.local_fire_department
                      : Icons.local_fire_department_outlined,
                  safeHasActivityToday
                      ? AppColors.warningColor
                      : AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Global Rank',
                  '#${safeUserRank.toString()}',
                  Icons.emoji_events,
                  AppColors.warningColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    // Ensure all parameters are safe
    final safeLabel = label.isNotEmpty ? label : 'Unknown';
    final safeValue = value.isNotEmpty ? value : '0';
    final safeIcon = icon;
    final safeColor = color;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: safeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: safeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(safeIcon, color: safeColor, size: 24),
          const SizedBox(height: 8),
          Text(
            safeValue,
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            safeLabel,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboard() {
    if (leaderboard.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Loading leaderboard...',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      children: leaderboard.asMap().entries.map((entry) {
        final user = entry.value;
        final currentUser = FirebaseAuth.instance.currentUser;
        final isYou = currentUser != null && user['userId'] == currentUser.uid;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _buildLeaderboardEntry(
            rank: user['rank'],
            name: isYou ? 'You' : user['name'],
            points: user['points'],
            level: user['level'],
            badges: user['badges'],
            isYou: isYou,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaderboardEntry({
    required int rank,
    required String name,
    required int points,
    required int level,
    required int badges,
    required bool isYou,
  }) {
    Color rankColor = AppColors.textSecondary;
    if (rank == 1) rankColor = Color(0xFFFFD700); // Gold
    if (rank == 2) rankColor = Color(0xFFC0C0C0); // Silver
    if (rank == 3) rankColor = Color(0xFFCD7F32); // Bronze

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isYou
            ? AppColors.activeColor.withValues(alpha: 0.1)
            : AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isYou ? AppColors.activeColor : AppColors.borderColor,
          width: isYou ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: rankColor, width: 2),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: AppTypography.bodyLarge.copyWith(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.military_tech,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Level $level',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.workspace_premium,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$badges badges',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatNumber(points),
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'points',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _getLevelTitle(int level) {
    if (level >= 50) return 'Legend';
    if (level >= 25) return 'Master';
    if (level >= 15) return 'Expert';
    if (level >= 10) return 'Champion';
    if (level >= 5) return 'Rising Star';
    return 'Beginner';
  }

  String _getRankDescription(int rank) {
    if (rank == 1) return 'You\'re #1! 🏆';
    if (rank <= 10) return 'Top 10 Player! 🔥';
    if (rank <= 50) return 'Top 50 Achiever! ⭐';
    if (rank <= 100) return 'Top 100 Member! 💪';
    return 'Keep climbing! 🚀';
  }

  Color _getBadgeRarityColor(badge_model.BadgeRarity rarity) {
    switch (rarity) {
      case badge_model.BadgeRarity.common:
        return AppColors.textSecondary;
      case badge_model.BadgeRarity.rare:
        return AppColors.activeColor;
      case badge_model.BadgeRarity.epic:
        return AppColors.warningColor;
      case badge_model.BadgeRarity.legendary:
        return Color(0xFFFFD700); // Gold
    }
  }

  IconData _getBadgeIcon(String iconName) {
    switch (iconName) {
      case 'emoji_events':
        return Icons.emoji_events;
      case 'track_changes':
        return Icons.track_changes;
      case 'check_circle':
        return Icons.check_circle;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'stars':
        return Icons.stars;
      case 'star':
        return Icons.star;
      case 'workspace_premium':
        return Icons.workspace_premium;
      case 'military_tech':
        return Icons.military_tech;
      case 'shield':
        return Icons.shield;
      case 'explore':
        return Icons.explore;
      case 'priority_high':
        return Icons.priority_high;
      case 'trending_up':
        return Icons.trending_up;
      default:
        return Icons.emoji_events;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'today';
    if (difference == 1) return 'yesterday';
    if (difference < 7) return '${difference}d ago';
    if (difference < 30) return '${(difference / 7).floor()}w ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showBadgeDetail(badge_model.Badge badge) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.elevatedBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              _getBadgeIcon(badge.iconName),
              color: _getBadgeRarityColor(badge.rarity),
              size: 32,
            ),
            const SizedBox(width: 12),
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
                color: _getBadgeRarityColor(
                  badge.rarity,
                ).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                badge.rarity.name.toUpperCase(),
                style: AppTypography.bodySmall.copyWith(
                  color: _getBadgeRarityColor(badge.rarity),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge.description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (badge.isEarned) ...[
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.successColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Earned ${_formatDate(badge.earnedAt!)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Progress: ${badge.progress}/${badge.maxProgress}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: badge.progressPercentage,
                backgroundColor: AppColors.borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getBadgeRarityColor(badge.rarity),
                ),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: AppColors.activeColor),
            ),
          ),
        ],
      ),
    );
  }
}
