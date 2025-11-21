import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/activity_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/goal_milestone.dart';
import 'package:pdh/models/alert.dart';

class GoalDetailScreen extends StatefulWidget {
  final Goal goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late Goal currentGoal;
  bool isLoading = false;
  StreamSubscription<DocumentSnapshot>? _goalSub;
  bool _submittingApproval = false;
  bool _isSeasonGoal = false;

  @override
  void initState() {
    super.initState();
    currentGoal = widget.goal;
    // Listen for live updates so approval status changes reflect immediately
    _goalSub = FirebaseFirestore.instance
        .collection('goals')
        .doc(widget.goal.id)
        .snapshots()
        .listen((doc) {
          if (!mounted) return;
          try {
            final updated = Goal.fromFirestore(doc);
            setState(() {
              currentGoal = updated;
              final data = doc.data();
              _isSeasonGoal = (data?['isSeasonGoal'] == true);
            });
          } catch (_) {}
        });
  }

  Future<void> _submitForApproval() async {
    if (_submittingApproval) return;
    setState(() {
      _submittingApproval = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      await DatabaseService.requestGoalApproval(
        goalId: currentGoal.id,
        userId: user.uid,
        goalTitle: currentGoal.title,
      );
      if (mounted) {
        setState(() {
          currentGoal = currentGoal.copyWith(
            approvalRequestedAt: DateTime.now(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for manager approval')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit for approval: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submittingApproval = false;
        });
      }
    }
  }

  Widget _buildKpaSelector() {
    final String? formattedKpa = (currentGoal.kpa != null && currentGoal.kpa!.isNotEmpty)
        ? currentGoal.kpa![0].toUpperCase() + currentGoal.kpa!.substring(1)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Performance Area',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.elevatedBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formattedKpa ?? 'Not assigned',
                  style: AppTypography.bodyMedium.copyWith(
                    color: formattedKpa != null
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'KPA is set when the goal is created. Contact your manager if it needs to change.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndDeleteGoal() async {
    if (isLoading) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal'),
        content: const Text(
          'Are you sure you want to permanently delete this goal? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      isLoading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      await DatabaseService.deleteGoal(
        goalId: currentGoal.id,
        requesterId: user.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goal deleted'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete goal: $e'),
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

  Future<void> _startGoal() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DatabaseService.startGoal(currentGoal.id, user.uid);
        // Record activity: goal started
        await ActivityService.recordGoalActivity(
          goalId: currentGoal.id,
          goalTitle: currentGoal.title,
          activityType: 'goal_started',
          description: 'Started goal',
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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Goal started! +20 points earned 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

    // Guard: ensure started and at 100% before attempting to complete
    if (currentGoal.status != GoalStatus.inProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please start the goal before completing it.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (currentGoal.progress < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set progress to 100% to complete.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await DatabaseService.completeGoal(currentGoal.id, user.uid);
        // Record activity: goal completed
        await ActivityService.recordGoalActivity(
          goalId: currentGoal.id,
          goalTitle: currentGoal.title,
          activityType: 'goal_completed',
          description: 'Completed goal',
        );

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

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Goal completed! +100 points earned 🏆'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back to previous screen after a short delay
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

    setState(() {
      isLoading = true;
    });

    try {
      await DatabaseService.updateGoalProgress(currentGoal.id, newProgress);
      // Record activity: goal progress update (non-blocking for UX)
      try {
        await ActivityService.recordGoalActivity(
          goalId: currentGoal.id,
          goalTitle: currentGoal.title,
          activityType: 'goal_progress',
          description: 'Updated progress to $newProgress%',
          metadata: {'progress': newProgress},
        );
      } catch (_) {
        // Swallow activity write errors so progress UX isn't interrupted
      }

      if (mounted) {
        setState(() {
          // If progress moves above 0 and we were not started, reflect auto-transition to inProgress
          final nextStatus =
              (newProgress > 0 && currentGoal.status == GoalStatus.notStarted)
              ? GoalStatus.inProgress
              : currentGoal.status;
          currentGoal = currentGoal.copyWith(
            progress: newProgress,
            status: nextStatus,
          );
        });

        // Award points for progress milestones (backend handles 50% with +20 and motivational alert)
        if (newProgress >= 25 && currentGoal.progress < 25) {
          _awardMilestonePoints(25, '25% progress milestone');
        } else if (newProgress >= 75 && currentGoal.progress < 75) {
          _awardMilestonePoints(75, '75% progress milestone');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Progress updated to $newProgress%'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, roleSnapshot) {
        final role =
            roleSnapshot.data ?? RoleService.instance.cachedRole ?? 'employee';
        final items = SidebarConfig.getItemsForRole(role);
        return AppScaffold(
          title: 'Goal Details',
          showAppBar: false,
          items: items,
          currentRouteName: '/goal_detail',
          onNavigate: (route) {
            final current = ModalRoute.of(context)?.settings.name;
            if (current != route) {
              Navigator.pushNamed(context, route);
            }
          },
          onLogout: () async {
            await AuthService().signOut();
            if (!context.mounted) return;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/sign_in', (route) => false);
          },
          content: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/khono_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildApprovalNotice(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildGoalInfo(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildProgressSection(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildActionButtons(),
                  const SizedBox(height: AppSpacing.xl),
          _buildGoalMilestonesSection(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildMilestoneTracker(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _goalSub?.cancel();
    super.dispose();
  }

  Widget _buildApprovalNotice() {
    if (_isSeasonGoal ||
        currentGoal.approvalStatus == GoalApprovalStatus.approved) {
      return const SizedBox.shrink();
    }
    final isPending = currentGoal.approvalStatus == GoalApprovalStatus.pending;
    final color = isPending ? AppColors.warningColor : AppColors.dangerColor;
    final icon = isPending ? Icons.hourglass_empty : Icons.cancel_outlined;
    final text = isPending
        ? 'This goal is awaiting manager approval.'
        : 'This goal was rejected by your manager.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
        IconButton(
          tooltip: 'Delete Goal',
          onPressed: isLoading ? null : _confirmAndDeleteGoal,
          icon: Icon(Icons.delete_outline, color: AppColors.dangerColor),
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
    final createdText = _fmtDateTime(currentGoal.createdAt);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  'Created',
                  createdText,
                  Icons.access_time,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 16),
          _buildKpaSelector(),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
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
          if (currentGoal.status != GoalStatus.completed &&
              (currentGoal.approvalStatus == GoalApprovalStatus.approved ||
                  _isSeasonGoal)) ...[
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
              children: List.generate(10, (i) => (i + 1) * 10).map((progress) {
                final bool overEvidenceCap =
                    (!_isSeasonGoal &&
                    currentGoal.evidence.isEmpty &&
                    progress > 90);
                final isDisabled =
                    progress <= currentGoal.progress || overEvidenceCap;
                return ElevatedButton(
                  onPressed: isDisabled
                      ? null
                      : () => _updateProgress(progress),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDisabled
                        ? AppColors.borderColor
                        : AppColors.activeColor,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text('$progress%'),
                );
              }).toList(),
            ),
            if (currentGoal.progress >= 90 &&
                currentGoal.progress < 100 &&
                (_isSeasonGoal || currentGoal.evidence.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : () => _updateProgress(100),
                  icon: const Icon(Icons.trending_up),
                  label: const Text('Set to 100%'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.activeColor),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
            if (!_isSeasonGoal &&
                currentGoal.progress >= 90 &&
                currentGoal.progress < 100 &&
                currentGoal.evidence.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Submit evidence to unlock the final 10% and complete.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
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
          border: Border.all(
            color: AppColors.successColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.successColor, size: 24),
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

    // If not approved yet, either allow submission or show status banner
    if (!_isSeasonGoal &&
        currentGoal.approvalStatus != GoalApprovalStatus.approved) {
      final isPending =
          currentGoal.approvalStatus == GoalApprovalStatus.pending;
      final hasRequested = currentGoal.approvalRequestedAt != null;
      // Permanently hide the submit-for-approval UI (auto-request happens on create)
      final bool showSubmitForApproval = UniqueKey() == UniqueKey();
      if (showSubmitForApproval && isPending && !hasRequested) {
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
                children: [
                  Icon(Icons.verified_outlined, color: AppColors.activeColor),
                  const SizedBox(width: 8),
                  Text('Submit for Approval', style: AppTypography.heading4),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Your goal needs manager approval before you can start updating progress.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submittingApproval ? null : _submitForApproval,
                  icon: _submittingApproval
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _submittingApproval
                        ? 'Submitting...'
                        : 'Submit for Approval',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      // Otherwise show current status (pending after request, or rejected)
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: (isPending ? AppColors.warningColor : AppColors.dangerColor)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isPending ? AppColors.warningColor : AppColors.dangerColor)
                .withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isPending ? Icons.hourglass_top : Icons.cancel,
              color: isPending ? AppColors.warningColor : AppColors.dangerColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isPending
                    ? 'Awaiting manager approval. You will be notified once approved.'
                    : 'This goal was rejected by your manager.${currentGoal.rejectionReason != null && currentGoal.rejectionReason!.isNotEmpty ? ' Reason: ${currentGoal.rejectionReason}' : ''}',
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
              onPressed:
                  (isLoading ||
                      currentGoal.progress < 100 ||
                      (!_isSeasonGoal && currentGoal.evidence.isEmpty))
                  ? null
                  : _completeGoal,
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
              label: Text(
                isLoading ? 'Completing...' : 'Complete Goal (+100 pts)',
              ),
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
    final List<int> steps = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
    final Map<int, int> pointsByStep = {
      0: 20, // start
      50: 20, // halfway bonus
      100: 100, // completion
    };
    final milestones = steps
        .map(
          (p) => {
            'progress': p,
            'label': p == 0 ? 'Started' : '$p% Complete',
            'points': pointsByStep[p] ?? 0,
            'icon': p == 0
                ? Icons.play_arrow
                : p == 100
                ? Icons.check_circle
                : Icons.trending_up,
          },
        )
        .toList();

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
            final isCompleted =
                (currentGoal.status == GoalStatus.inProgress &&
                    progress == 0) ||
                currentGoal.progress >= progress;
            final isCurrent =
                currentGoal.progress >= progress &&
                (milestones.indexOf(milestone) == milestones.length - 1 ||
                    currentGoal.progress <
                        (milestones[milestones.indexOf(milestone) +
                                1]['progress']
                            as int));

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
                            fontWeight: isCompleted
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if ((milestone['points'] as int) > 0)
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
                    Icon(Icons.check, color: AppColors.successColor, size: 20),
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
      case GoalStatus.paused:
        return AppColors.textSecondary;
      case GoalStatus.burnout:
        return AppColors.dangerColor;
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
      case GoalStatus.paused:
        return 'PAUSED';
      case GoalStatus.burnout:
        return 'BURNOUT';
    }
  }

  String _fmtDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }

  Widget _buildGoalMilestonesSection() {
    if (_isSeasonGoal) {
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
              'Season Challenge Milestones',
              style: AppTypography.heading4.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This goal is linked to a Season Challenge. Milestones are predefined by your manager. '
              'Use the Season Challenges → My Seasons screen to update milestone progress.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    final bool isOwner = user?.uid == currentGoal.userId;
    final bool isGoalCompleted = currentGoal.status == GoalStatus.completed;
    final bool canAddMilestones = isOwner && !isGoalCompleted;
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Goal Milestones',
                      style: AppTypography.heading4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isOwner
                          ? 'Break this goal into concrete steps with target dates.'
                          : 'View the employee-defined checkpoints for this goal.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (isGoalCompleted)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Completed milestones are locked because this goal is closed.',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (canAddMilestones)
                TextButton.icon(
                  onPressed: () => _showMilestoneDialog(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.activeColor,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Milestone'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<GoalMilestone>>(
            stream: DatabaseService.getGoalMilestonesStream(currentGoal.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final milestones = snapshot.data ?? const [];
              if (milestones.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    canAddMilestones
                        ? 'No milestones yet. Use “Add Milestone” to map the steps for this goal.'
                        : 'Milestones will appear here once the employee adds them.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              return Column(
                children: milestones
                    .map(
                      (milestone) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GoalMilestoneTile(
                          milestone: milestone,
                          canEdit: isOwner &&
                              !(isGoalCompleted &&
                                  milestone.status == GoalMilestoneStatus.completed),
                          isLocked: isGoalCompleted &&
                              milestone.status == GoalMilestoneStatus.completed,
                          onEdit: () => _showMilestoneDialog(milestone: milestone),
                          onUpdateStatus: (status) =>
                              _updateMilestoneStatus(milestone, status),
                          onDelete: () => _deleteMilestone(milestone),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showMilestoneDialog({GoalMilestone? milestone}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to manage milestones.')),
      );
      return;
    }
    if (milestone == null && currentGoal.status == GoalStatus.completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completed goals can no longer accept new milestones.'),
        ),
      );
      return;
    }
    final titleController = TextEditingController(text: milestone?.title ?? '');
    final descController =
        TextEditingController(text: milestone?.description ?? '');
    DateTime? dueDate =
        milestone?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    GoalMilestoneStatus status =
        milestone?.status ?? GoalMilestoneStatus.notStarted;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDueDate() async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                initialDate: dueDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );
              if (selected != null) {
                setDialogState(() {
                  dueDate = DateTime(selected.year, selected.month, selected.day);
                });
              }
            }

            Future<void> submit() async {
              final trimmedTitle = titleController.text.trim();
              final trimmedDesc = descController.text.trim();
              if (trimmedTitle.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Title is required.')),
                );
                return;
              }
              if (dueDate == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Select a due date.')),
                );
                return;
              }
              setDialogState(() => saving = true);
              try {
                if (milestone == null) {
                  await DatabaseService.addGoalMilestone(
                    goalId: currentGoal.id,
                    title: trimmedTitle,
                    description: trimmedDesc,
                    dueDate: dueDate!,
                    createdBy: user.uid,
                    createdByName: user.displayName ?? user.email ?? 'You',
                    status: status,
                  );
                } else {
                  await DatabaseService.updateGoalMilestone(
                    goalId: currentGoal.id,
                    milestoneId: milestone.id,
                    title: trimmedTitle,
                    description: trimmedDesc,
                    dueDate: dueDate!,
                    status: status,
                  );
                }
                // Try to close dialog and show success message
                // Use try-catch to handle if dialog context is no longer valid
                try {
                  // ignore: use_build_context_synchronously
                  // dialogContext is from dialog builder, checked with try-catch
                  // ignore: use_build_context_synchronously
                  Navigator.of(dialogContext).pop();
                  // Use dialogContext for ScaffoldMessenger since we're in dialog scope
                  // ignore: use_build_context_synchronously
                  // dialogContext is from dialog builder, checked with try-catch
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        milestone == null
                            ? 'Milestone created.'
                            : 'Milestone updated.',
                      ),
                    ),
                  );
                } catch (_) {
                  // Dialog context is no longer valid, ignore
                }
              } catch (e) {
                setDialogState(() => saving = false);
                // Try to show error message if dialog context is still valid
                try {
                  // ignore: use_build_context_synchronously
                  // dialogContext is from dialog builder, checked with try-catch
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed to save milestone: $e')),
                  );
                } catch (_) {
                  // Dialog context is no longer valid, ignore
                }
              }
            }

            return AlertDialog(
              title: Text(
                milestone == null ? 'Add Milestone' : 'Edit Milestone',
                style: AppTypography.heading4,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Milestone title',
                        hintText: 'e.g., Complete basics course',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        hintText:
                            'Add more context or link to learning resources.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      onTap: pickDueDate,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: Text(
                        dueDate != null
                            ? _formatShortDate(dueDate!)
                            : 'Select due date',
                      ),
                      subtitle: const Text('Tap to choose deadline'),
                      trailing: TextButton(
                        onPressed: pickDueDate,
                        child: const Text('Change'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<GoalMilestoneStatus>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                      ),
                      items: GoalMilestoneStatus.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_milestoneStatusLabel(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => status = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(milestone == null ? 'Create Milestone' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateMilestoneStatus(
    GoalMilestone milestone,
    GoalMilestoneStatus status,
  ) async {
    try {
      await DatabaseService.updateGoalMilestone(
        goalId: currentGoal.id,
        milestoneId: milestone.id,
        status: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked as ${_milestoneStatusLabel(status)}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update milestone: $e')),
        );
      }
    }
  }

  Future<void> _deleteMilestone(GoalMilestone milestone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Milestone'),
        content: const Text('Remove this milestone from the goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await DatabaseService.deleteGoalMilestone(
        goalId: currentGoal.id,
        milestoneId: milestone.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Milestone deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete milestone: $e')),
        );
      }
    }
  }

  String _milestoneStatusLabel(GoalMilestoneStatus status) {
    switch (status) {
      case GoalMilestoneStatus.notStarted:
        return 'Not Started';
      case GoalMilestoneStatus.inProgress:
        return 'In Progress';
      case GoalMilestoneStatus.completed:
        return 'Completed';
      case GoalMilestoneStatus.blocked:
        return 'Blocked';
    }
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _GoalMilestoneTile extends StatelessWidget {
  final GoalMilestone milestone;
  final bool canEdit;
  final bool isLocked;
  final VoidCallback onEdit;
  final Future<void> Function(GoalMilestoneStatus status) onUpdateStatus;
  final VoidCallback onDelete;

  const _GoalMilestoneTile({
    required this.milestone,
    required this.canEdit,
    required this.isLocked,
    required this.onEdit,
    required this.onUpdateStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOverdue = milestone.status != GoalMilestoneStatus.completed &&
        milestone.dueDate.isBefore(DateTime.now());
    final Color statusColor = _statusColor(milestone.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue ? AppColors.dangerColor : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      milestone.title,
                      style: AppTypography.heading4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatShortDate(milestone.dueDate),
                          style: AppTypography.bodySmall.copyWith(
                            color: isOverdue
                                ? AppColors.dangerColor
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(milestone.status),
                  style: AppTypography.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (canEdit)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'start':
                        onUpdateStatus(GoalMilestoneStatus.notStarted);
                        break;
                      case 'progress':
                        onUpdateStatus(GoalMilestoneStatus.inProgress);
                        break;
                      case 'blocked':
                        onUpdateStatus(GoalMilestoneStatus.blocked);
                        break;
                      case 'complete':
                        onUpdateStatus(GoalMilestoneStatus.completed);
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit details')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'start',
                      child: Text('Mark Not Started'),
                    ),
                    const PopupMenuItem(
                      value: 'progress',
                      child: Text('Mark In Progress'),
                    ),
                    const PopupMenuItem(
                      value: 'blocked',
                      child: Text('Mark Blocked'),
                    ),
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark Completed'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.dangerColor),
                      ),
                    ),
                  ],
                ),
              if (!canEdit && isLocked)
                Tooltip(
                  message: 'This milestone is locked because the goal is completed.',
                  child: Icon(
                    Icons.lock_outline,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          if (milestone.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              milestone.description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                milestone.createdByName ?? 'Employee',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (milestone.completedAt != null) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: AppColors.successColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Completed ${_formatShortDate(milestone.completedAt!)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.successColor,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String _statusLabel(GoalMilestoneStatus status) {
    switch (status) {
      case GoalMilestoneStatus.notStarted:
        return 'Not Started';
      case GoalMilestoneStatus.inProgress:
        return 'In Progress';
      case GoalMilestoneStatus.completed:
        return 'Completed';
      case GoalMilestoneStatus.blocked:
        return 'Blocked';
    }
  }

  Color _statusColor(GoalMilestoneStatus status) {
    switch (status) {
      case GoalMilestoneStatus.notStarted:
        return AppColors.textSecondary;
      case GoalMilestoneStatus.inProgress:
        return AppColors.activeColor;
      case GoalMilestoneStatus.completed:
        return AppColors.successColor;
      case GoalMilestoneStatus.blocked:
        return AppColors.warningColor;
    }
  }
}
