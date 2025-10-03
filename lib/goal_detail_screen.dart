import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/alert.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal goal;

  const GoalDetailScreen({
    super.key,
    required this.goal,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late Goal currentGoal;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentGoal = widget.goal;
  }

  Future<void> _startGoal() async {
    if (isLoading) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DatabaseService.startGoal(currentGoal.id, user.uid);
        
        // Create alerts
        await AlertService.createGoalAlert(
          userId: user.uid,
          goal: currentGoal.copyWith(status: GoalStatus.inProgress),
          type: AlertType.goalCreated,
        );
        
        await AlertService.createPointsAlert(
          userId: user.uid,
          pointsEarned: 20,
          reason: 'starting "${currentGoal.title}"',
        );

        if (mounted) {
          setState(() {
            currentGoal = currentGoal.copyWith(status: GoalStatus.inProgress);
          });

          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Goal started! +20 points earned 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error starting goal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _completeGoal() async {
    if (isLoading) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DatabaseService.completeGoal(currentGoal.id, user.uid);
        
        // Create completion alerts
        await AlertService.createGoalAlert(
          userId: user.uid,
          goal: currentGoal.copyWith(
            status: GoalStatus.completed,
            progress: 100,
          ),
          type: AlertType.goalCompleted,
        );
        
        await AlertService.createPointsAlert(
          userId: user.uid,
          pointsEarned: 100,
          reason: 'completing "${currentGoal.title}"',
        );

        if (mounted) {
          setState(() {
            currentGoal = currentGoal.copyWith(
              status: GoalStatus.completed,
              progress: 100,
            );
          });

          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Goal completed! +100 points earned 🏆'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error completing goal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _updateProgress(int newProgress) async {
    if (isLoading) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() {
      isLoading = true;
    });

    try {
      await DatabaseService.updateGoalProgress(currentGoal.id, newProgress);
      
      if (mounted) {
        setState(() {
          currentGoal = currentGoal.copyWith(progress: newProgress);
        });

        // Award points for progress milestones
        if (newProgress >= 25 && currentGoal.progress < 25) {
          _awardMilestonePoints(25, '25% progress milestone');
        } else if (newProgress >= 50 && currentGoal.progress < 50) {
          _awardMilestonePoints(50, '50% progress milestone');
        } else if (newProgress >= 75 && currentGoal.progress < 75) {
          _awardMilestonePoints(75, '75% progress milestone');
        }

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Progress updated to $newProgress%'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error updating progress: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _awardMilestonePoints(int milestone, String reason) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Update user points and then create an alert so points reflect immediately
      await DatabaseService.updateUserPoints(user.uid, 10, reason);
      await AlertService.createPointsAlert(
        userId: user.uid,
        pointsEarned: 10,
        reason: reason,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Goal Details',
      showAppBar: false,
      items: SidebarConfig.employeeItems,
      currentRouteName: '/goal_detail',
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
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: AppSpacing.xl),
              _buildGoalInfo(),
              const SizedBox(height: AppSpacing.xl),
              _buildProgressSection(),
              const SizedBox(height: AppSpacing.xl),
              _buildActionButtons(),
              const SizedBox(height: AppSpacing.xl),
              _buildMilestoneTracker(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            currentGoal.title,
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor().withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getStatusColor()),
          ),
          child: Text(
            _getStatusText(),
            style: AppTypography.bodySmall.copyWith(
              color: _getStatusColor(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalInfo() {
    final daysLeft = currentGoal.targetDate.difference(DateTime.now()).inDays;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goal Information',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (currentGoal.description.isNotEmpty) ...[
            Text(
              'Description',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currentGoal.description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Category',
                  currentGoal.category.name.toUpperCase(),
                  Icons.category,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  'Priority',
                  currentGoal.priority.name.toUpperCase(),
                  Icons.flag,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Target Date',
                  '${currentGoal.targetDate.day}/${currentGoal.targetDate.month}/${currentGoal.targetDate.year}',
                  Icons.calendar_today,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoItem(
                  'Days Left',
                  daysLeft > 0 ? '$daysLeft days' : 'Overdue',
                  Icons.schedule,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${currentGoal.progress}%',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.activeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: currentGoal.progress / 100,
            backgroundColor: AppColors.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            minHeight: 8,
          ),
          const SizedBox(height: 16),
          if (currentGoal.status != GoalStatus.completed) ...[
            Text(
              'Update Progress',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [25, 50, 75, 100].map((progress) {
                final isDisabled = progress <= currentGoal.progress;
                return ElevatedButton(
                  onPressed: isDisabled ? null : () => _updateProgress(progress),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDisabled 
                        ? AppColors.borderColor 
                        : AppColors.activeColor,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text('$progress%'),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (currentGoal.status == GoalStatus.completed) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.successColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.successColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: AppColors.successColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Congratulations! You completed this goal! 🎉',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        if (currentGoal.status == GoalStatus.notStarted) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _startGoal,
              icon: isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(isLoading ? 'Starting...' : 'Start Goal (+20 pts)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ] else if (currentGoal.status == GoalStatus.inProgress) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _completeGoal,
              icon: isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(isLoading ? 'Completing...' : 'Complete Goal (+100 pts)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.successColor,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMilestoneTracker() {
    final milestones = [
      {'progress': 0, 'label': 'Started', 'points': 20, 'icon': Icons.play_arrow},
      {'progress': 25, 'label': '25% Complete', 'points': 10, 'icon': Icons.trending_up},
      {'progress': 50, 'label': '50% Complete', 'points': 10, 'icon': Icons.trending_up},
      {'progress': 75, 'label': '75% Complete', 'points': 10, 'icon': Icons.trending_up},
      {'progress': 100, 'label': 'Completed', 'points': 100, 'icon': Icons.check_circle},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Milestone Tracker',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...milestones.map((milestone) {
            final progress = milestone['progress'] as int;
            final isCompleted = (currentGoal.status == GoalStatus.inProgress && progress == 0) ||
                               currentGoal.progress >= progress;
            final isCurrent = currentGoal.progress >= progress && 
                             (milestones.indexOf(milestone) == milestones.length - 1 || 
                              currentGoal.progress < (milestones[milestones.indexOf(milestone) + 1]['progress'] as int));

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted 
                          ? AppColors.successColor.withValues(alpha: 0.2)
                          : isCurrent
                              ? AppColors.activeColor.withValues(alpha: 0.2)
                              : AppColors.borderColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCompleted 
                            ? AppColors.successColor
                            : isCurrent
                                ? AppColors.activeColor
                                : AppColors.borderColor,
                      ),
                    ),
                    child: Icon(
                      milestone['icon'] as IconData,
                      color: isCompleted 
                          ? AppColors.successColor
                          : isCurrent
                              ? AppColors.activeColor
                              : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          milestone['label'] as String,
                          style: AppTypography.bodyMedium.copyWith(
                            color: isCompleted 
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        Text(
                          '+${milestone['points']} points',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.warningColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    Icon(
                      Icons.check,
                      color: AppColors.successColor,
                      size: 20,
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (currentGoal.status) {
      case GoalStatus.notStarted:
        return AppColors.textSecondary;
      case GoalStatus.inProgress:
        return AppColors.activeColor;
      case GoalStatus.completed:
        return AppColors.successColor;
    }
  }

  String _getStatusText() {
    switch (currentGoal.status) {
      case GoalStatus.notStarted:
        return 'NOT STARTED';
      case GoalStatus.inProgress:
        return 'IN PROGRESS';
      case GoalStatus.completed:
        return 'COMPLETED';
    }
  }
}
