import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:pdh/rarity_badges_list_screen.dart';
import 'package:pdh/services/role_service.dart';

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

  // Interactive features
  late AnimationController _levelUpController;
  late AnimationController _badgeEarnedController;
  late AnimationController _pointsAnimationController;
  late Animation<double> _levelUpScale;
  late Animation<double> _badgeEarnedScale;
  late Animation<double> _pointsCountAnimation;

  bool _showLevelUpDialog = false;
  bool _showBadgeEarnedDialog = false;
  int _previousLevel = 1;
  int _previousPoints = 0;
  List<badge_model.Badge> _newlyEarnedBadges = [];
  bool _didInitialProfileLoad = false;
  @override
  void initState() {
    super.initState();
    _redirectIfManager();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Initialize interactive animation controllers
    _levelUpController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _levelUpScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _levelUpController, curve: Curves.elasticOut),
    );

    _badgeEarnedController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _badgeEarnedScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _badgeEarnedController, curve: Curves.bounceOut),
    );

    _pointsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pointsCountAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pointsAnimationController,
        curve: Curves.easeOut,
      ),
    );
    // Initialize default values to prevent null issues
    setState(() {
      currentStreak = 0;
      hasActivityToday = false;
      userRank = 0;
      leaderboard = [];
      _previousLevel = 1;
      _previousPoints = 0;
    });

    _loadData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _levelUpController.dispose();
    _badgeEarnedController.dispose();
    _pointsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _redirectIfManager() async {
    try {
      final role = await RoleService.instance.getRole();
      if (!mounted) return;
      if (role == 'manager') {
        if (widget.embedded) {
          // Already inside Manager Portal; stay put.
          return;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final current = ModalRoute.of(context)?.settings.name;
          // Avoid redundant navigation loops
          if (current != '/manager_portal') {
            Navigator.pushReplacementNamed(
              context,
              '/manager_portal',
              arguments: {'initialRoute': '/badges_points'},
            );
          }
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // First, retroactively award badges and update level based on existing accomplishments
        await BadgeService.retroactivelyAwardBadgesAndUpdateLevel(user.uid);

        // Then ensure badge progress is up to date for this user
        await BadgeService.checkAndAwardBadges(user.uid);

        final profile = await DatabaseService.getUserProfile(user.uid);
        final leaderboardData = await BadgeService.getLeaderboard();
        final rank = await BadgeService.getUserRank(user.uid);
        final streak = await StreakService.getCurrentStreak(user.uid);
        final activityToday = await StreakService.hasActivityToday(user.uid);

        // On first profile load during this screen session, initialize baselines
        if (!_didInitialProfileLoad) {
          _previousLevel = profile.level;
          _previousPoints = profile.totalPoints;
          _didInitialProfileLoad = true;
        } else {
          // Check for level up only after initial baseline
          if (profile.level > _previousLevel) {
            _showLevelUpAnimation();
          }

          // Check for points increase only after initial baseline
          if (profile.totalPoints > _previousPoints) {
            try {
              _pointsAnimationController.forward();
            } catch (e) {
              developer.log('Points animation error: $e');
            }
          }
        }

        // Check for newly earned badges
        await _checkForNewBadges(user.uid);

        if (mounted) {
          setState(() {
            userProfile = profile;
            leaderboard = leaderboardData;
            userRank = rank > 0 ? rank : 1;
            currentStreak = streak >= 0 ? streak : 0;
            hasActivityToday = activityToday;
            _previousLevel = profile.level;
            _previousPoints = profile.totalPoints;
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

  // Helper methods for interactive features
  void _showLevelUpAnimation() {
    _levelUpController.forward();
    setState(() {
      _showLevelUpDialog = true;
    });

    // Auto-hide after animation
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showLevelUpDialog = false;
        });
        _levelUpController.reset();
      }
    });
  }

  Future<void> _checkForNewBadges(String userId) async {
    try {
      final badgesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('badges')
          .where('isEarned', isEqualTo: true)
          .where(
            'earnedAt',
            isGreaterThan: DateTime.now().subtract(const Duration(minutes: 5)),
          )
          .get();

      final newBadges = badgesSnapshot.docs
          .map((doc) => badge_model.Badge.fromFirestore(doc))
          .toList();

      if (newBadges.isNotEmpty) {
        setState(() {
          _newlyEarnedBadges = newBadges;
          _showBadgeEarnedDialog = true;
        });

        _badgeEarnedController.forward();

        // Auto-hide after animation
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showBadgeEarnedDialog = false;
              _newlyEarnedBadges.clear();
            });
            _badgeEarnedController.reset();
          }
        });
      }
    } catch (e) {
      developer.log('Error checking for new badges: $e');
    }
  }

  void _displayLevelUpDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AnimatedBuilder(
        animation: _levelUpScale,
        builder: (context, child) => Transform.scale(
          scale: _levelUpScale.value,
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            content: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.activeColor,
                    AppColors.warningColor,
                    Color(0xFFFFD700),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.activeColor.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.military_tech, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'LEVEL UP!',
                    style: AppTypography.heading1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You reached Level ${userProfile?.level ?? 1}!',
                    style: AppTypography.heading3.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getLevelRewardText(userProfile?.level ?? 1),
                    style: AppTypography.bodyLarge.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Auto-close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _displayBadgeEarnedDialog() {
    if (_newlyEarnedBadges.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AnimatedBuilder(
        animation: _badgeEarnedScale,
        builder: (context, child) => Transform.scale(
          scale: _badgeEarnedScale.value,
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            content: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getBadgeRarityColor(_newlyEarnedBadges.first.rarity),
                    _getBadgeRarityColor(
                      _newlyEarnedBadges.first.rarity,
                    ).withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _getBadgeRarityColor(
                      _newlyEarnedBadges.first.rarity,
                    ).withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _getBadgeIcon(
                    _newlyEarnedBadges.first.iconName,
                  ), // Directly use the returned widget
                  const SizedBox(height: 16),
                  Text(
                    'BADGE EARNED!',
                    style: AppTypography.heading1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _newlyEarnedBadges.first.name,
                    style: AppTypography.heading3.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _newlyEarnedBadges.first.description,
                    style: AppTypography.bodyLarge.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Auto-close after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  String _getLevelRewardText(int level) {
    if (level >= 20) {
      return 'You\'re a true legend! Unlock exclusive features and rewards.';
    }
    if (level >= 15) {
      return 'Master level achieved! You\'ve unlocked advanced badges.';
    }
    if (level >= 10) return 'Expert level! New challenges and rewards await.';
    if (level >= 5) return 'Rising star! You\'re making great progress.';
    return 'Keep going! You\'re on the right track.';
  }

  void _showLevelDetails() {
    final level = userProfile?.level ?? 1;
    final points = userProfile?.totalPoints ?? 0;
    final nextLevelPoints = level * 500;
    final currentLevelPoints = (level - 1) * 500;
    final progressPercentage = level > 1
        ? ((points - currentLevelPoints) /
                  (nextLevelPoints - currentLevelPoints))
              .clamp(0.0, 1.0)
        : (points / 500).clamp(0.0, 1.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.elevatedBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.military_tech, color: AppColors.activeColor, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Level $level Details',
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.activeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.activeColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _getLevelTitle(level),
                    style: AppTypography.heading4.copyWith(
                      color: AppColors.activeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getLevelRewardText(level),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Progress to Level ${level + 1}',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progressPercentage,
              backgroundColor: AppColors.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${points - currentLevelPoints} / ${nextLevelPoints - currentLevelPoints} XP',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${(progressPercentage * 100).toStringAsFixed(1)}%',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.activeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Next Level Rewards:',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildLevelRewards(level + 1),
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

  Widget _buildLevelRewards(int level) {
    List<String> rewards = [];

    if (level >= 5) rewards.add('• Unlock new badge categories');
    if (level >= 10) rewards.add('• Access to exclusive challenges');
    if (level >= 15) rewards.add('• Advanced analytics dashboard');
    if (level >= 20) rewards.add('• Legendary badge opportunities');
    if (level >= 25) rewards.add('• Mentor other users');
    if (level >= 30) rewards.add('• Create custom challenges');

    if (rewards.isEmpty) {
      rewards.add('• Continue your journey!');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rewards
          .map(
            (reward) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                reward,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show dialogs when needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showLevelUpDialog) {
        _displayLevelUpDialog();
      }
      if (_showBadgeEarnedDialog) {
        _displayBadgeEarnedDialog();
      }
    });

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
      content: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Container(
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
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                FadeTransition(
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
                      _buildSectionHeader('Your Badges'),
                      _buildBadgesSection(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildProgressStats(),
                      const SizedBox(height: AppSpacing.xl),
                      _buildRetroactiveUpdateButton(),
                    ],
                  ),
                ),
              ],
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

    return GestureDetector(
      onTap: () => _showLevelDetails(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
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
                    Builder(
                      builder: (context) {
                        try {
                          // Check if animation is properly initialized
                          return AnimatedBuilder(
                            animation: _pointsCountAnimation,
                            builder: (context, child) {
                              try {
                                final animatedPoints =
                                    _pointsCountAnimation.isCompleted
                                    ? points
                                    : (_previousPoints +
                                              (points - _previousPoints) *
                                                  _pointsCountAnimation.value)
                                          .round();
                                return Text(
                                  _formatNumber(animatedPoints),
                                  style: AppTypography.heading1.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              } catch (e) {
                                return Text(
                                  _formatNumber(points),
                                  style: AppTypography.heading1.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }
                            },
                          );
                        } catch (e) {
                          return Text(
                            _formatNumber(points),
                            style: AppTypography.heading1.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                      },
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
                    Builder(
                      builder: (context) {
                        try {
                          // Check if animation is properly initialized
                          return AnimatedBuilder(
                            animation: _levelUpScale,
                            builder: (context, child) {
                              try {
                                return Transform.scale(
                                  scale: _showLevelUpDialog
                                      ? _levelUpScale.value
                                      : 1.0,
                                  child: Text(
                                    'Level $level',
                                    style: AppTypography.heading1.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                return Text(
                                  'Level $level',
                                  style: AppTypography.heading1.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }
                            },
                          );
                        } catch (e) {
                          return Text(
                            'Level $level',
                            style: AppTypography.heading1.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                      },
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
                Stack(
                  children: [
                    LinearProgressIndicator(
                      value: progressPercentage,
                      backgroundColor: AppColors.textPrimary.withValues(
                        alpha: 0.2,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.textPrimary,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    if (progressPercentage >= 1.0)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              colors: [
                                Colors.yellow.withValues(alpha: 0.8),
                                Colors.orange.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.stars,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tap for level details',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(
                      width: 35,
                      height: 35,
                      child: Image.asset(
                        'Information_Detail/Information_Red_Badge_White.png', // Corrected path and filename
                        fit: BoxFit.contain,
                      ),
                    ), // Replaced Icon with Image.asset
                  ],
                ),
              ],
            ),
          ],
        ),
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

        // Group badges by rarity in fixed order: Common -> Rare -> Epic -> Legendary
        final Map<badge_model.BadgeRarity, List<badge_model.Badge>> byRarity = {
          badge_model.BadgeRarity.common: [],
          badge_model.BadgeRarity.rare: [],
          badge_model.BadgeRarity.epic: [],
          badge_model.BadgeRarity.legendary: [],
        };
        for (final b in visibleBadges) {
          byRarity[b.rarity]?.add(b);
        }

        // Determine the active rarity based on user's current level
        final level = userProfile?.level ?? 1;
        bool isInRange(badge_model.BadgeRarity r) {
          if (r == badge_model.BadgeRarity.common) return level >= 1 && level <= 5;
          if (r == badge_model.BadgeRarity.rare) return level >= 6 && level <= 10;
          if (r == badge_model.BadgeRarity.epic) return level >= 11 && level <= 15;
          return level >= 16; // legendary
        }
        return Column(
          children: [
            _buildRarityOvalSection(
              title: 'Common Goals',
              subtitle: 'Levels 1–5',
              rarity: badge_model.BadgeRarity.common,
              badges: byRarity[badge_model.BadgeRarity.common]!..sort((a, b) => a.name.compareTo(b.name)),
              isActive: isInRange(badge_model.BadgeRarity.common),
              onTap: () => _openRarityList(badge_model.BadgeRarity.common),
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
        );
      },
    );
  }

  // Empty state shown when the user has no visible badges yet
  Widget _buildEmptyBadgesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Image.asset(
              'Goal_Target/Goal_Target_White_Badge_Red_Badge_White.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No badges yet',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start completing goals and activities to earn your first badges.',
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

  // Compact oval section to present a badge rarity group entry point
  Widget _buildRarityOvalSection({
    required String title,
    required String subtitle,
    required badge_model.BadgeRarity rarity,
    required List<badge_model.Badge>? badges,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final color = _getBadgeRarityColor(rarity);
    final total = (badges ?? const <badge_model.Badge>[]).length;
    final earned = (badges ?? const <badge_model.Badge>[]).where((b) => b.isEarned).length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.elevatedBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color : AppColors.borderColor,
            width: isActive ? 2 : 1,
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
                border: Border.all(color: color.withValues(alpha: 0.6)),
              ),
              child: Icon(Icons.workspace_premium, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$earned / $total earned',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openRarityList(badge_model.BadgeRarity rarity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RarityBadgesListScreen(rarity: rarity),
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
                  iconWidget: SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'Process_Flows_Automation/Points.png', // Corrected path and filename
                      fit: BoxFit.contain,
                    ),
                  ), // Replaced IconData with iconWidget
                  color: AppColors.warningColor,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Current Level',
                  'Level ${(safeUserProfile?.level ?? 1).toString()}',
                  iconWidget: SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'Business_Growth_Development/Growth_Development_Red.png', // Corrected path and filename
                      fit: BoxFit.contain,
                    ),
                  ), // Replaced IconData with iconWidget
                  color: AppColors.activeColor,
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
                  iconWidget: SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'Like_Thumbs_Up/Okay.png', // Replaced IconData with iconWidget
                      fit: BoxFit.contain,
                    ),
                  ), // Replaced IconData with iconWidget
                  color: safeHasActivityToday
                      ? AppColors.warningColor
                      : AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Global Rank',
                  '#${safeUserRank.toString()}',
                  iconWidget: SizedBox(
                    width: 40,
                    height: 40,
                    child: Image.asset(
                      'Project_Direction_Acceleration/Global_Rank.png', // Corrected path and filename
                      fit: BoxFit.contain,
                    ),
                  ), // Replaced IconData with iconWidget
                  color: AppColors.warningColor,
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
    String value, {
    IconData? icon, // Make icon an optional named parameter
    Widget? iconWidget, // Keep existing iconWidget parameter
    Color color = AppColors.textPrimary,
  }) {
    // Ensure all parameters are safe
    final safeLabel = label.isNotEmpty ? label : 'Unknown';
    final safeValue = value.isNotEmpty ? value : '0';
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
          if (iconWidget != null) // Prioritize iconWidget if provided
            iconWidget
          else if (icon != null) // Use IconData if provided as named parameter
            Icon(icon, color: safeColor, size: 24)
          else // Fallback if neither is provided
            Icon(
              Icons.help_outline,
              color: safeColor,
              size: 24,
            ), // Default icon
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

  // Leaderboard removed

  Widget _buildRetroactiveUpdateButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update Badges & Level',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manually update your badges and level based on your current accomplishments.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    await BadgeService.retroactivelyAwardBadgesAndUpdateLevel(
                      user.uid,
                    );
                    await _loadData(); // Reload data to show updates

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Badges and level updated successfully!',
                          ),
                          backgroundColor: AppColors.successColor,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating badges: $e'),
                          backgroundColor: AppColors.dangerColor,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Update Now',
                style: AppTypography.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Leaderboard removed

  // Leaderboard entry removed
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

  Widget _getBadgeIcon(String iconName) {
    developer.log(
      'Fetching icon for badge with iconName: $iconName',
      name: 'BadgesPointsScreen',
    );
    switch (iconName) {
      case 'emoji_events':
        return SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            'Goal_Target/Goal_Target_White_Badge_Red_Badge_White.png',
            fit: BoxFit.contain,
          ),
        ); // Replaced Icon with Image.asset
      case 'track_changes':
        return Icon(Icons.track_changes);
      case 'check_circle':
        return SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            'Approved_Tick/approved_red_badge_white.png',
            fit: BoxFit.contain,
          ),
        ); // Replaced Icon with Image.asset
      case 'local_fire_department':
        return Icon(Icons.local_fire_department);
      case 'stars':
        return SizedBox(
          width: 40,
          height: 40,
          child: Image.asset(
            'Process_Flows_Automation/Points.png',
            fit: BoxFit.contain,
          ),
        ); // Replaced Icon with Image.asset
      case 'star':
        return Icon(Icons.star);
      case 'workspace_premium':
        return Icon(Icons.workspace_premium);
      case 'military_tech':
        return Icon(Icons.military_tech);
      case 'shield':
        return Icon(Icons.shield);
      case 'explore':
        return Icon(Icons.explore);
      case 'priority_high':
        return Icon(Icons.priority_high);
      case 'trending_up':
        return Icon(Icons.trending_up);
      default:
        return Icon(Icons.emoji_events);
    }
  }


}
