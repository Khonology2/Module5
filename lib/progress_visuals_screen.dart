import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/goal.dart';

class ProgressVisualsScreen extends StatefulWidget {
  const ProgressVisualsScreen({super.key});

  @override
  State<ProgressVisualsScreen> createState() => _ProgressVisualsScreenState();
}

class _ProgressVisualsScreenState extends State<ProgressVisualsScreen> {
  UserProfile? userProfile;
  List<Goal> userGoals = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await DatabaseService.getUserProfile(user.uid);
        final goals = await DatabaseService.getUserGoals(user.uid);
        
        setState(() {
          userProfile = profile;
          userGoals = goals;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Stream<UserProfile?> _getUserProfileStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    });
  }

  Stream<List<Goal>> _getUserGoalsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);
    
    return FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final goals = snapshot.docs.map((doc) {
        final data = doc.data();
        return Goal(
          id: doc.id,
          userId: data['userId'] ?? user.uid,
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          category: GoalCategory.values.firstWhere(
              (e) => e.name == (data['category'] ?? 'personal'),
              orElse: () => GoalCategory.personal,
          ),
          priority: GoalPriority.values.firstWhere(
              (e) => e.name == (data['priority'] ?? 'medium'),
              orElse: () => GoalPriority.medium,
          ),
          status: GoalStatus.values.firstWhere(
              (e) => e.name == (data['status'] ?? 'notStarted'),
              orElse: () => GoalStatus.notStarted,
          ),
          progress: (data['progress'] ?? 0) as int,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          targetDate: (data['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
          points: (data['points'] ?? 0) as int,
        );
      }).toList();
      
      goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return goals;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Progress Visuals',
      showAppBar: false,
      items: SidebarConfig.employeeItems,
      currentRouteName: '/progress_visuals',
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
          navigator.pushNamedAndRemoveUntil(
            '/sign_in',
            (route) => false,
          );
        }
      },
      content: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundColor,
              AppColors.backgroundColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: StreamBuilder<UserProfile?>(
          stream: _getUserProfileStream(),
          builder: (context, profileSnapshot) {
            return StreamBuilder<List<Goal>>(
              stream: _getUserGoalsStream(),
              builder: (context, goalsSnapshot) {
                if (profileSnapshot.connectionState == ConnectionState.waiting ||
                    goalsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                    ),
                  );
                }

                if (profileSnapshot.hasError || goalsSnapshot.hasError) {
                  final error = profileSnapshot.error ?? goalsSnapshot.error;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.dangerColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading progress data',
                          style: AppTypography.heading4,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {}); // Trigger rebuild
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                userProfile = profileSnapshot.data;
                userGoals = goalsSnapshot.data ?? [];

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {}); // Trigger rebuild
                  },
                  child: _ProgressVisualsContent(
                    userProfile: userProfile,
                    userGoals: userGoals,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProgressVisualsContent extends StatelessWidget {
  final UserProfile? userProfile;
  final List<Goal> userGoals;

  const _ProgressVisualsContent({
    required this.userProfile,
    required this.userGoals,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Visuals',
            style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xl),
          _buildPortfolioOverview(),
          const SizedBox(height: AppSpacing.xxl),
          _buildGoalsProgress(context),
          const SizedBox(height: AppSpacing.xxl),
          _buildAIInsights(),
        ],
      ),
    );
  }

  // Profile handled by MainLayout

  Widget _buildPortfolioOverview() {
    // Calculate real statistics
    final totalGoals = userGoals.length;
    final completedGoals = userGoals.where((goal) => goal.status == GoalStatus.completed).length;
    final activeGoals = userGoals.where((goal) => goal.status == GoalStatus.inProgress).length;
    final overallProgress = totalGoals > 0 ? (completedGoals / totalGoals) : 0.0;
    
    // Calculate next deadline
    final activeGoalsWithDeadlines = userGoals
        .where((goal) => goal.status != GoalStatus.completed)
        .toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    
    final nextDeadline = activeGoalsWithDeadlines.isNotEmpty 
        ? activeGoalsWithDeadlines.first.targetDate
        : null;
    
    final daysUntilNext = nextDeadline != null 
        ? nextDeadline.difference(DateTime.now()).inDays
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Portfolio Overview',
          style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                title: 'Completion Rate',
                value: '${(overallProgress * 100).toInt()}%',
                progress: overallProgress,
                color: AppColors.successColor,
                icon: Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildOverviewCard(
                title: 'Active Goals',
                value: activeGoals.toString(),
                progress: totalGoals > 0 ? (activeGoals / totalGoals) : 0.0,
                color: AppColors.activeColor,
                icon: Icons.track_changes,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: _buildOverviewCard(
                title: 'Total Points',
                value: _formatNumber(userProfile?.totalPoints ?? 0),
                progress: (userProfile?.totalPoints ?? 0) / 1000.0, // Normalize to 1000 points
                color: AppColors.warningColor,
                icon: Icons.stars,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildOverviewCard(
                title: 'Level',
                value: 'Level ${userProfile?.level ?? 1}',
                progress: ((userProfile?.level ?? 1) % 10) / 10.0, // Progress to next level
                color: AppColors.infoColor,
                icon: Icons.military_tech,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildNextDeadlineCard(daysUntilNext, nextDeadline),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required double progress,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      height: 120,
                decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
                ),
      padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildNextDeadlineCard(int daysUntil, DateTime? nextDeadline) {
    String deadlineText;
    Color deadlineColor;
    IconData deadlineIcon;

    if (nextDeadline == null) {
      deadlineText = 'No upcoming deadlines';
      deadlineColor = AppColors.textSecondary;
      deadlineIcon = Icons.check_circle;
    } else if (daysUntil < 0) {
      deadlineText = 'Overdue by ${(-daysUntil)} day${(-daysUntil) == 1 ? '' : 's'}';
      deadlineColor = AppColors.dangerColor;
      deadlineIcon = Icons.warning;
    } else if (daysUntil == 0) {
      deadlineText = 'Due today!';
      deadlineColor = AppColors.warningColor;
      deadlineIcon = Icons.today;
    } else if (daysUntil <= 7) {
      deadlineText = 'Due in $daysUntil day${daysUntil == 1 ? '' : 's'}';
      deadlineColor = AppColors.warningColor;
      deadlineIcon = Icons.schedule;
    } else {
      deadlineText = 'Next deadline in $daysUntil days';
      deadlineColor = AppColors.successColor;
      deadlineIcon = Icons.event;
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: deadlineColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
              color: deadlineColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(deadlineIcon, color: deadlineColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  'Next Deadline',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deadlineText,
                  style: AppTypography.bodyMedium.copyWith(
                    color: deadlineColor,
                    fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
              ),
            ),
          ],
        ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  Widget _buildGoalsProgress(BuildContext context) {
    // Filter and sort goals for display
    final activeGoals = userGoals
        .where((goal) => goal.status != GoalStatus.completed)
        .toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Goals Progress',
              style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
            ),
            if (activeGoals.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/my_goal_workspace');
                },
                icon: Icon(Icons.add, color: AppColors.activeColor, size: 18),
                label: Text(
                  'Add Goal',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.activeColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (activeGoals.isEmpty)
          _buildEmptyGoalsState(context)
        else
          ...activeGoals.take(5).map((goal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildGoalProgressCard(
                context,
                goal: goal,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildEmptyGoalsState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
      children: [
          Icon(
            Icons.flag_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Goals',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first goal to start tracking your progress!',
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
            label: const Text('Create Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgressCard(
    BuildContext context, {
    required Goal goal,
  }) {
    final now = DateTime.now();
    final daysUntilDeadline = goal.targetDate.difference(now).inDays;
    final progress = goal.progress / 100.0;
    
    String deadlineText;
    Color deadlineColor;
    
    if (daysUntilDeadline < 0) {
      deadlineText = 'Overdue by ${(-daysUntilDeadline)} day${(-daysUntilDeadline) == 1 ? '' : 's'}';
      deadlineColor = AppColors.dangerColor;
    } else if (daysUntilDeadline == 0) {
      deadlineText = 'Due today';
      deadlineColor = AppColors.warningColor;
    } else if (daysUntilDeadline <= 7) {
      deadlineText = 'Due in $daysUntilDeadline day${daysUntilDeadline == 1 ? '' : 's'}';
      deadlineColor = AppColors.warningColor;
    } else {
      deadlineText = 'Due in $daysUntilDeadline days';
      deadlineColor = AppColors.textSecondary;
    }

    Color progressColor = _getPriorityColor(goal.priority);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 30.0,
            lineWidth: 6.0,
            percent: progress.clamp(0.0, 1.0),
            center: Text(
              "${goal.progress}%",
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            progressColor: progressColor,
            backgroundColor: AppColors.borderColor,
            circularStrokeCap: CircularStrokeCap.round,
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
                        goal.title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: progressColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: progressColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        goal.priority.name.toUpperCase(),
                        style: AppTypography.bodySmall.copyWith(
                          color: progressColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  deadlineText,
                  style: AppTypography.bodySmall.copyWith(
                    color: deadlineColor,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 3,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Icon(
                _getStatusIcon(goal.status),
                color: _getStatusColor(goal.status),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                '${goal.points}pts',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return AppColors.dangerColor;
      case GoalPriority.medium:
        return AppColors.warningColor;
      case GoalPriority.low:
        return AppColors.successColor;
    }
  }

  IconData _getStatusIcon(GoalStatus status) {
    switch (status) {
      case GoalStatus.notStarted:
        return Icons.play_circle_outline;
      case GoalStatus.inProgress:
        return Icons.play_circle;
      case GoalStatus.completed:
        return Icons.check_circle;
    }
  }

  Color _getStatusColor(GoalStatus status) {
    switch (status) {
      case GoalStatus.notStarted:
        return AppColors.textSecondary;
      case GoalStatus.inProgress:
        return AppColors.activeColor;
      case GoalStatus.completed:
        return AppColors.successColor;
    }
  }

  Widget _buildAIInsights() {
    final insights = _generateInsights();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Smart Insights',
              style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.activeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.activeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology,
                    color: AppColors.activeColor,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'AI Powered',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.activeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (insights.isEmpty)
          _buildNoInsightsState()
        else
          ...insights.map((insight) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildInsightCard(
                insight['text'] as String,
                insight['color'] as Color,
                insight['icon'] as IconData,
                insight['type'] as String,
              ),
            );
          }),
      ],
    );
  }

  List<Map<String, dynamic>> _generateInsights() {
    final insights = <Map<String, dynamic>>[];
    
    if (userGoals.isEmpty) {
      insights.add({
        'text': 'Start your journey by creating your first goal! Setting clear objectives is the first step to success.',
        'color': AppColors.activeColor,
        'icon': Icons.rocket_launch,
        'type': 'motivation',
      });
      return insights;
    }

    final totalGoals = userGoals.length;
    final completedGoals = userGoals.where((goal) => goal.status == GoalStatus.completed).length;
    final activeGoals = userGoals.where((goal) => goal.status == GoalStatus.inProgress).length;
    final overdueGoals = userGoals.where((goal) {
      return goal.status != GoalStatus.completed && 
             goal.targetDate.isBefore(DateTime.now());
    }).length;

    // Completion rate insight
    if (completedGoals > 0) {
      final completionRate = (completedGoals / totalGoals * 100).round();
      if (completionRate >= 70) {
        insights.add({
          'text': 'Excellent! You have a $completionRate% completion rate. You\'re crushing your goals!',
          'color': AppColors.successColor,
          'icon': Icons.trending_up,
          'type': 'success',
        });
      } else if (completionRate >= 40) {
        insights.add({
          'text': 'Good progress with $completionRate% completion rate. Keep up the momentum!',
          'color': AppColors.warningColor,
          'icon': Icons.thumb_up,
          'type': 'encouragement',
        });
      }
    }

    // Overdue goals warning
    if (overdueGoals > 0) {
      insights.add({
        'text': 'You have $overdueGoals overdue goal${overdueGoals == 1 ? '' : 's'}. Consider reviewing deadlines or breaking them into smaller tasks.',
        'color': AppColors.dangerColor,
        'icon': Icons.warning,
        'type': 'warning',
      });
    }

    // Active goals motivation
    if (activeGoals > 0) {
      insights.add({
        'text': 'You\'re actively working on $activeGoals goal${activeGoals == 1 ? '' : 's'}. Focus on one at a time for better results!',
        'color': AppColors.activeColor,
        'icon': Icons.psychology,
        'type': 'tip',
      });
    }

    // Points and level insight
    final totalPoints = userProfile?.totalPoints ?? 0;
    if (totalPoints > 0) {
      insights.add({
        'text': 'You\'ve earned $totalPoints points! You\'re at Level ${userProfile?.level ?? 1}. Keep going to unlock the next level!',
        'color': AppColors.warningColor,
        'icon': Icons.stars,
        'type': 'achievement',
      });
    }

    // Goal diversity insight
    final categories = userGoals.map((goal) => goal.category).toSet();
    if (categories.length >= 3) {
      insights.add({
        'text': 'Great balance! You\'re working on goals across ${categories.length} different areas of your life.',
        'color': AppColors.infoColor,
        'icon': Icons.balance,
        'type': 'balance',
      });
    }

    return insights.take(4).toList(); // Limit to 4 insights
  }

  Widget _buildNoInsightsState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 40,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'No insights available yet',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create some goals to get personalized insights!',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String text, Color iconColor, IconData icon, String type) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
            child: Text(
                    type.toUpperCase(),
                    style: AppTypography.bodySmall.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                    ),
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
