import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:web/web.dart' as web;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/milestone_evidence_service.dart';
import 'package:pdh/services/activity_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/cloudinary_service.dart';
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
  String _requiredApproverRole = 'manager';

  @override
  void initState() {
    super.initState();
    currentGoal = widget.goal;
    // Listen for live updates so approval status changes reflect immediately
    _goalSub = FirebaseFirestore.instance
        .collection('goals')
        .doc(widget.goal.id)
        .snapshots()
        .handleError((error) {
          // Silently handle errors to prevent unmount errors
          developer.log('Error in goal detail stream: $error');
        })
        .listen(
          (doc) {
            if (!mounted) return;
            try {
              final updated = Goal.fromFirestore(doc);
              setState(() {
                currentGoal = updated;
                final data = doc.data();
                _isSeasonGoal = (data?['isSeasonGoal'] == true);
                final requiredApprover = (data?['requiredApproverRole'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
                if (requiredApprover == 'admin' || requiredApprover == 'manager') {
                  _requiredApproverRole = requiredApprover;
                } else {
                  final viewerRole =
                      (RoleService.instance.cachedRole ?? 'employee')
                          .trim()
                          .toLowerCase();
                  _requiredApproverRole = viewerRole == 'manager'
                      ? 'admin'
                      : 'manager';
                }
              });
            } catch (_) {}
          },
          onError: (error) {
            // Additional error handling for listen
            developer.log('Error in goal detail listener: $error');
          },
        );
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
          SnackBar(
            content: Text(
              _requiredApproverRole == 'admin'
                  ? 'Submitted for admin approval'
                  : 'Submitted for manager approval',
            ),
          ),
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
    final String? formattedKpa =
        Goal.kpaLabel(currentGoal.kpa) ??
        ((currentGoal.kpa != null && currentGoal.kpa!.isNotEmpty)
            ? currentGoal.kpa![0].toUpperCase() + currentGoal.kpa!.substring(1)
            : null);

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

    // Block updates on paused/burnout/completed goals at UI level for clarity
    if (currentGoal.status == GoalStatus.paused ||
        currentGoal.status == GoalStatus.burnout ||
        currentGoal.status == GoalStatus.completed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentGoal.status == GoalStatus.paused
                  ? 'This goal is paused. Ask your manager to resume it before updating progress.'
                  : 'Cannot update progress on this goal.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

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
        ? (_requiredApproverRole == 'admin'
              ? 'This goal is awaiting admin approval.'
              : 'This goal is awaiting manager approval.')
        : (_requiredApproverRole == 'admin'
              ? 'This goal was rejected by an admin.'
              : 'This goal was rejected by your manager.');
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
      final approverLabel = _requiredApproverRole == 'admin'
          ? 'admin'
          : 'manager';
      // Keep manual submit available for retries/resends in case the original
      // request alert was missed or failed due to transient issues.
      final bool showSubmitForApproval = isPending;
      if (showSubmitForApproval) {
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
                'Your goal needs $approverLabel approval before you can start updating progress.',
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
                        : (hasRequested
                              ? 'Resend Approval Request'
                              : 'Submit for Approval'),
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
                    ? (_requiredApproverRole == 'admin'
                          ? 'Awaiting admin approval. You will be notified once approved.'
                          : 'Awaiting manager approval. You will be notified once approved.')
                    : (_requiredApproverRole == 'admin'
                          ? 'This goal was rejected by an admin.${currentGoal.rejectionReason != null && currentGoal.rejectionReason!.isNotEmpty ? ' Reason: ${currentGoal.rejectionReason}' : ''}'
                          : 'This goal was rejected by your manager.${currentGoal.rejectionReason != null && currentGoal.rejectionReason!.isNotEmpty ? ' Reason: ${currentGoal.rejectionReason}' : ''}'),
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
      case GoalStatus.acknowledged:
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
      case GoalStatus.acknowledged:
        return 'ACKNOWLEDGED';
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
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
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
                          goalId: currentGoal.id, // NEW: Add goalId
                          canEdit:
                              isOwner &&
                              !(isGoalCompleted &&
                                  milestone.status ==
                                      GoalMilestoneStatus.completed),
                          isLocked:
                              isGoalCompleted &&
                              milestone.status == GoalMilestoneStatus.completed,
                          onEdit: () =>
                              _showMilestoneDialog(milestone: milestone),
                          onUpdateStatus: (status) =>
                              _updateMilestoneStatus(milestone, status),
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
        const SnackBar(
          content: Text('You must be signed in to manage milestones.'),
        ),
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
    final descController = TextEditingController(
      text: milestone?.description ?? '',
    );
    DateTime? dueDate =
        milestone?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    GoalMilestoneStatus status;
    if (milestone != null) {
      // For existing milestones, map system-managed statuses to appropriate employee options
      switch (milestone.status) {
        case GoalMilestoneStatus.notStarted:
        case GoalMilestoneStatus.pendingManagerReview:
        case GoalMilestoneStatus.blocked:
          status = GoalMilestoneStatus.inProgress; // Map to In Progress
          break;
        case GoalMilestoneStatus.completedAcknowledged:
          status = GoalMilestoneStatus.completed; // Map to Completed
          break;
        case GoalMilestoneStatus.inProgress:
        case GoalMilestoneStatus.completed:
          status = milestone.status; // Keep as-is
          break;
      }
    } else {
      // For new milestones, default to Not Started
      status = GoalMilestoneStatus.notStarted;
    }
    bool saving = false;
    String? successMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDueDate() async {
              final now = DateTime.now();
              // Restrict milestone due date to be after the goal's start date (createdAt)
              // or after today if goal was created today
              final goalStartDate = currentGoal.createdAt;
              final minDate = goalStartDate.isBefore(now)
                  ? now
                  : DateTime(
                      goalStartDate.year,
                      goalStartDate.month,
                      goalStartDate.day,
                    ).add(const Duration(days: 1));

              final selected = await showDatePicker(
                context: context,
                initialDate: dueDate ?? (minDate.isBefore(now) ? now : minDate),
                firstDate: minDate,
                lastDate: DateTime(now.year + 5),
              );
              if (selected != null) {
                setDialogState(() {
                  dueDate = DateTime(
                    selected.year,
                    selected.month,
                    selected.day,
                  );
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
                GoalMilestone? createdMilestone;
                if (milestone == null) {
                  // For new milestones, if status is "Completed", create as "In Progress" first
                  // since evidence will be required to actually complete it
                  final initialStatus = status == GoalMilestoneStatus.completed
                      ? GoalMilestoneStatus.inProgress
                      : status;

                  final milestoneId = await DatabaseService.addGoalMilestone(
                    goalId: currentGoal.id,
                    title: trimmedTitle,
                    description: trimmedDesc,
                    dueDate: dueDate!,
                    createdBy: user.uid,
                    createdByName: user.displayName ?? user.email ?? 'You',
                    status: initialStatus,
                    // REMOVED: requiresEvidence parameter - no longer needed
                  );

                  // Create the milestone object for evidence submission
                  createdMilestone = GoalMilestone(
                    id: milestoneId,
                    goalId: currentGoal.id,
                    title: trimmedTitle,
                    description: trimmedDesc,
                    dueDate: dueDate!,
                    createdBy: user.uid,
                    createdByName: user.displayName ?? user.email ?? 'You',
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    status: initialStatus,
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
                // Show success message in the center of the dialog
                setDialogState(() {
                  successMessage = milestone == null
                      ? 'Milestone created successfully!'
                      : 'Milestone updated successfully!';
                });

                // If this was a new milestone created with "Completed" status intent, trigger evidence submission
                if (milestone == null &&
                    status == GoalMilestoneStatus.completed &&
                    createdMilestone != null) {
                  // Auto-close dialog after a short delay to show success message, then open evidence submission
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      // Trigger evidence submission for the newly created milestone
                      _showEvidenceSubmissionDialog(createdMilestone!);
                    }
                  });
                } else {
                  // Auto-close dialog after a short delay to show success message
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  });
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
                    // REMOVED: Evidence requirement checkbox - no longer needed
                    const SizedBox(height: 12),
                    DropdownButtonFormField<GoalMilestoneStatus>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items:
                          const [
                                GoalMilestoneStatus.notStarted,
                                GoalMilestoneStatus.inProgress,
                                GoalMilestoneStatus.completed,
                              ]
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

                          // If user selects "Completed", show a message that evidence will be required
                          if (value == GoalMilestoneStatus.completed) {
                            if (milestone == null) {
                              // For new milestones, show a message that evidence will be required after saving
                              setDialogState(() {
                                successMessage =
                                    '⚠️ Evidence will be required to mark this milestone as completed. Please save first, then add evidence.';
                              });
                            } else {
                              // For existing milestones, close dialog and trigger evidence submission
                              Navigator.of(dialogContext).pop();
                              _showEvidenceSubmissionDialog(milestone);
                            }
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Success message display
                    if (successMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                successMessage!,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
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
                      : Text(
                          milestone == null
                              ? 'Create Milestone'
                              : 'Save Changes',
                        ),
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
      // NEW WORKFLOW: Intercept completion attempts
      if (status == GoalMilestoneStatus.completed) {
        // Always require evidence for completion - no configuration needed
        _showEvidenceSubmissionDialog(milestone);
        return; // Don't complete directly, go through evidence workflow
      }

      // For other status changes, proceed normally
      await DatabaseService.updateGoalMilestone(
        goalId: currentGoal.id,
        milestoneId: milestone.id,
        status: status,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update milestone: $e')),
        );
      }
    }
  }

  // NEW: Evidence submission dialog for workflow-based system
  Future<void> _showEvidenceSubmissionDialog(GoalMilestone milestone) async {
    final TextEditingController fileNameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    bool uploading = false;
    List<PlatformFile> attachedFiles = [];
    String? validationError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Submit Evidence for Completion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This milestone requires evidence before it can be marked as completed. Please submit your evidence below.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Evidence Description *',
                  hintText:
                      'Describe what you accomplished and provide any relevant details...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fileNameController,
                decoration: const InputDecoration(
                  labelText: 'File Name (optional)',
                  hintText: 'e.g., Certificate.pdf',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // NEW: Replace file URL text field with Attach Evidence button
              ElevatedButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                          allowMultiple: true,
                        );

                        if (result != null && result.files.isNotEmpty) {
                          setDialogState(() {
                            attachedFiles = result.files;
                            if (fileNameController.text.trim().isEmpty &&
                                result.files.length == 1) {
                              fileNameController.text = result.files.first.name;
                            }
                          });
                        }
                      },
                icon: const Icon(Icons.attach_file, size: 16),
                label: Text(
                  attachedFiles.isEmpty
                      ? 'Attach Evidence'
                      : '${attachedFiles.length} file(s) attached',
                  style: const TextStyle(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              if (attachedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Attached Files:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...attachedFiles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        // File icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _getFileIcon(file.extension),
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // File info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _getFileSize(file.size),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Preview button
                            if (file.bytes != null || file.path != null)
                              IconButton(
                                onPressed: () => _previewFile(file),
                                icon: const Icon(Icons.visibility, size: 18),
                                tooltip: 'Preview',
                                padding: const EdgeInsets.all(8),
                              ),
                            // Remove button
                            IconButton(
                              onPressed: () {
                                setDialogState(() {
                                  attachedFiles.removeAt(index);
                                });
                              },
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Remove',
                              padding: const EdgeInsets.all(8),
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 8),
              // Validation error message
              if (validationError != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          validationError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Text(
                'Note: At least a description is required. File upload is optional.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: uploading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: uploading
                  ? null
                  : () async {
                      // Clear previous validation error
                      setDialogState(() => validationError = null);

                      if (descriptionController.text.trim().isEmpty) {
                        setDialogState(() {
                          validationError = 'Evidence description is required';
                        });
                        return;
                      }

                      // Capture BEFORE any async gaps to avoid using BuildContext
                      // across awaits (use_build_context_synchronously).
                      final navigator = Navigator.of(dialogContext);
                      final messenger = ScaffoldMessenger.of(dialogContext);

                      setDialogState(() => uploading = true);
                      try {
                        // Create a single evidence entry combining file and description
                        final List<MilestoneEvidence> evidenceList = [];

                        for (final file in attachedFiles) {
                          String cloudinaryUrl = '';

                          // Upload to Cloudinary if file has bytes
                          if (file.bytes != null) {
                            try {
                              cloudinaryUrl =
                                  await CloudinaryService.uploadFileUnsigned(
                                    bytes: file.bytes!,
                                    fileName: file.name,
                                    goalId: currentGoal
                                        .id, // Use goal ID for organization
                                  );
                            } catch (e) {
                              // If Cloudinary fails, fall back to local path
                              cloudinaryUrl =
                                  file.path ?? 'uploaded_file_${file.name}';
                              developer.log(
                                'Cloudinary upload failed for ${file.name}: $e',
                              );
                            }
                          } else {
                            // For web files without bytes, use path
                            cloudinaryUrl =
                                file.path ?? 'uploaded_file_${file.name}';
                          }

                          // Use description as file name if provided, otherwise use actual file name
                          final displayName =
                              descriptionController.text.trim().isNotEmpty
                              ? descriptionController.text.trim()
                              : file.name;

                          final evidence = MilestoneEvidence(
                            id: FirebaseFirestore.instance
                                .collection('milestone_evidence')
                                .doc()
                                .id,
                            fileUrl: cloudinaryUrl,
                            fileName: displayName,
                            fileType: file.extension ?? 'unknown',
                            fileSize: file.size,
                            uploadedBy: FirebaseAuth.instance.currentUser!.uid,
                            uploadedByName:
                                FirebaseAuth
                                    .instance
                                    .currentUser!
                                    .displayName ??
                                'User',
                            uploadedAt: DateTime.now(),
                            status: MilestoneEvidenceStatus.pendingReview,
                          );
                          evidenceList.add(evidence);
                        }

                        // If only text evidence (no files), create single text entry
                        if (attachedFiles.isEmpty &&
                            descriptionController.text.trim().isNotEmpty) {
                          final textEvidence = MilestoneEvidence(
                            id: FirebaseFirestore.instance
                                .collection('milestone_evidence')
                                .doc()
                                .id,
                            fileUrl: '',
                            fileName: descriptionController.text.trim(),
                            fileType: 'text',
                            fileSize: descriptionController.text.length,
                            uploadedBy: FirebaseAuth.instance.currentUser!.uid,
                            uploadedByName:
                                FirebaseAuth
                                    .instance
                                    .currentUser!
                                    .displayName ??
                                'User',
                            uploadedAt: DateTime.now(),
                            status: MilestoneEvidenceStatus.pendingReview,
                          );
                          evidenceList.add(textEvidence);
                        }

                        // Capture the context we want to use later BEFORE the async gap.
                        final appContext = context;

                        // Submit all evidence in a single batch operation
                        await DatabaseService.submitMultipleMilestoneEvidence(
                          goalId: currentGoal.id,
                          milestoneId: milestone.id,
                          evidenceList: evidenceList,
                        );

                        if (!mounted || !appContext.mounted) return;
                        navigator.pop();

                        // Show centered success dialog instead of SnackBar
                        showDialog(
                          context: appContext,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1F2840),
                            title: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.orange.shade400,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Evidence Submitted!',
                                  style: TextStyle(
                                    color: Colors.orange.shade400,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            content: Text(
                              'Your evidence has been submitted successfully. The milestone is now pending manager review.',
                              style: const TextStyle(color: Colors.white),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: Text(
                                  'OK',
                                  style: TextStyle(
                                    color: Colors.orange.shade400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => uploading = false);

                        // Handle different types of errors with user-friendly messages
                        String errorMessage = 'Submission failed';
                        if (e.toString().contains('permission-denied') ||
                            e.toString().contains('permission denied') ||
                            e.toString().contains('insufficient permissions')) {
                          errorMessage =
                              'You do not have permission to submit evidence for this milestone. Please contact your manager.';
                        } else if (e.toString().contains('not-found') ||
                            e.toString().contains('could not be found')) {
                          errorMessage =
                              'The milestone could not be found. It may have been deleted. Please refresh the page.';
                        } else if (e.toString().contains(
                          'INTERNAL ASSERTION FAILED',
                        )) {
                          errorMessage =
                              'A temporary error occurred. Please try again in a moment.';
                        } else if (e.toString().contains('network') ||
                            e.toString().contains('connection')) {
                          errorMessage =
                              'Network error. Please check your connection and try again.';
                        } else {
                          errorMessage = 'Submission failed: ${e.toString()}';
                        }

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                            action: SnackBarAction(
                              label: 'Retry',
                              textColor: Colors.white,
                              onPressed: () {
                                // Allow retry by keeping dialog open
                                setDialogState(() => uploading = false);
                              },
                            ),
                          ),
                        );
                      }
                    },
              child: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Evidence'),
            ),
          ],
        ),
      ),
    );
  }

  String _milestoneStatusLabel(GoalMilestoneStatus status) {
    switch (status) {
      case GoalMilestoneStatus.notStarted:
        return 'Not Started';
      case GoalMilestoneStatus.inProgress:
        return 'In Progress';
      case GoalMilestoneStatus.pendingManagerReview:
        return 'Pending Review';
      case GoalMilestoneStatus.completed:
        return 'Completed';
      case GoalMilestoneStatus.completedAcknowledged:
        return 'Completed & Acknowledged';
      case GoalMilestoneStatus.blocked:
        return 'Blocked';
    }
  }

  String _formatShortDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  // Helper methods for file handling
  IconData _getFileIcon(String? extension) {
    if (extension == null) return Icons.insert_drive_file;

    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _previewFile(PlatformFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Preview: ${file.name}'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              // File info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getFileIcon(file.extension),
                      size: 32,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Size: ${_getFileSize(file.size)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Preview area
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                  child: _buildFilePreview(file),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview(PlatformFile file) {
    final extension = file.extension?.toLowerCase();

    // For images
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp'].contains(extension)) {
      if (file.bytes != null) {
        return Image.memory(file.bytes!, fit: BoxFit.contain);
      } else if (file.path != null) {
        return Image.network(
          file.path!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: Text('Cannot preview this file')),
        );
      }
    }

    // For PDFs and other documents
    if (['pdf', 'doc', 'docx', 'txt'].contains(extension)) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Document preview not available',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'File will be available for download after submission',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // For other file types
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Preview not available for this file type',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _GoalMilestoneTile extends StatelessWidget {
  final GoalMilestone milestone;
  final bool canEdit;
  final bool isLocked;
  final VoidCallback onEdit;
  final Future<void> Function(GoalMilestoneStatus status) onUpdateStatus;
  final String goalId; // NEW: Add goalId parameter

  const _GoalMilestoneTile({
    required this.milestone,
    required this.canEdit,
    required this.isLocked,
    required this.onEdit,
    required this.onUpdateStatus,
    required this.goalId, // NEW: Required parameter
  });

  @override
  Widget build(BuildContext context) {
    final bool isOverdue =
        milestone.status != GoalMilestoneStatus.completed &&
        milestone.dueDate.isBefore(DateTime.now());
    final Color statusColor = _statusColor(milestone.status);

    // NEW: Evidence dialog method
    void showEvidenceDialog(GoalMilestone milestone) {
      final TextEditingController fileNameController = TextEditingController();
      final TextEditingController fileUrlController = TextEditingController();
      bool uploading = false;

      showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Upload Evidence'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fileNameController,
                  decoration: const InputDecoration(
                    labelText: 'File Name',
                    hintText: 'e.g., Certificate.pdf',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fileUrlController,
                  decoration: const InputDecoration(
                    labelText: 'File URL',
                    hintText: 'https://example.com/file.pdf',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: In production, this would open a file picker. For demo, enter file details manually.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: uploading
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: uploading
                    ? null
                    : () async {
                        if (fileNameController.text.trim().isEmpty ||
                            fileUrlController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all fields'),
                            ),
                          );
                          return;
                        }

                        // Capture BEFORE async gap to avoid using BuildContext after awaits.
                        final navigator = Navigator.of(dialogContext);
                        final messenger = ScaffoldMessenger.of(dialogContext);

                        setDialogState(() => uploading = true);
                        try {
                          await MilestoneEvidenceService.uploadEvidence(
                            goalId: goalId,
                            milestoneId: milestone.id,
                            fileUrl: fileUrlController.text.trim(),
                            fileName: fileNameController.text.trim(),
                            fileType: 'application/pdf', // Default for demo
                            fileSize: 1024, // Default for demo
                          );

                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Evidence uploaded successfully'),
                            ),
                          );
                        } catch (e) {
                          setDialogState(() => uploading = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text('Upload failed: $e')),
                          );
                        }
                      },
                child: uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Upload'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverdue
              ? AppColors.dangerColor
              : Colors.white.withValues(alpha: 0.1),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
                  onSelected: (value) async {
                    // Added async
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'not_started':
                        await onUpdateStatus(GoalMilestoneStatus.notStarted);
                        break;
                      case 'progress':
                        await onUpdateStatus(GoalMilestoneStatus.inProgress);
                        break;
                      case 'complete':
                        await onUpdateStatus(GoalMilestoneStatus.completed);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit details'),
                    ),
                    // Only show employee-appropriate options
                    if (RoleService.instance.cachedRole != 'manager') ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'not_started',
                        child: Text('Mark Not Started'),
                      ),
                      const PopupMenuItem(
                        value: 'progress',
                        child: Text('Mark In Progress'),
                      ),
                      const PopupMenuItem(
                        value: 'complete',
                        child: Text('Mark Completed'),
                      ),
                    ],
                  ],
                ),
              if (!canEdit && isLocked)
                Tooltip(
                  message:
                      'This milestone is locked because the goal is completed.',
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
          // NEW: Evidence section for workflow-based system
          if (milestone.evidence.isNotEmpty ||
              milestone.status == GoalMilestoneStatus.pendingManagerReview) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    milestone.status == GoalMilestoneStatus.pendingManagerReview
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      milestone.status ==
                          GoalMilestoneStatus.pendingManagerReview
                      ? Colors.orange.withValues(alpha: 0.3)
                      : Colors.blue.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        milestone.status ==
                                GoalMilestoneStatus.pendingManagerReview
                            ? Icons.pending_actions
                            : Icons.attachment,
                        size: 16,
                        color:
                            milestone.status ==
                                GoalMilestoneStatus.pendingManagerReview
                            ? Colors.orange
                            : Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        milestone.status ==
                                GoalMilestoneStatus.pendingManagerReview
                            ? 'Evidence Submitted - Pending Review'
                            : 'Evidence Attached',
                        style: AppTypography.bodySmall.copyWith(
                          color:
                              milestone.status ==
                                  GoalMilestoneStatus.pendingManagerReview
                              ? Colors.orange
                              : Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (canEdit &&
                          milestone.status != GoalMilestoneStatus.completed &&
                          milestone.status !=
                              GoalMilestoneStatus.pendingManagerReview)
                        TextButton(
                          onPressed: () => showEvidenceDialog(milestone),
                          child: Text(
                            'Add Evidence',
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.blue,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<MilestoneEvidence>>(
                    future: MilestoneEvidenceService.getMilestoneEvidence(
                      goalId: goalId,
                      milestoneId: milestone.id,
                    ),
                    builder: (context, snapshot) {
                      final evidence = snapshot.data ?? [];
                      if (evidence.isEmpty) {
                        return Text(
                          milestone.status ==
                                  GoalMilestoneStatus.pendingManagerReview
                              ? 'Processing evidence submission...'
                              : 'No evidence attached yet',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _deduplicateEvidence(evidence)
                            .map(
                              (e) => Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      e.status ==
                                              MilestoneEvidenceStatus.approved
                                          ? Icons.check_circle
                                          : e.status ==
                                                MilestoneEvidenceStatus.rejected
                                          ? Icons.cancel
                                          : Icons.pending,
                                      size: 16,
                                      color:
                                          e.status ==
                                              MilestoneEvidenceStatus.approved
                                          ? Colors.green
                                          : e.status ==
                                                MilestoneEvidenceStatus.rejected
                                          ? Colors.red
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        e.fileName,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (e.fileUrl.isNotEmpty)
                                      IconButton(
                                        onPressed: () =>
                                            _previewEvidence(e, context),
                                        icon: const Icon(
                                          Icons.visibility,
                                          size: 18,
                                        ),
                                        tooltip: 'Preview Evidence',
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
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
      case GoalMilestoneStatus.pendingManagerReview:
        return 'Pending Review';
      case GoalMilestoneStatus.completed:
        return 'Completed';
      case GoalMilestoneStatus.completedAcknowledged:
        return 'Completed & Acknowledged';
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
      case GoalMilestoneStatus.pendingManagerReview:
        return Colors.orange; // Orange for pending review
      case GoalMilestoneStatus.completed:
        return AppColors.successColor;
      case GoalMilestoneStatus.completedAcknowledged:
        return AppColors.successColor; // Changed from purple to successColor
      case GoalMilestoneStatus.blocked:
        return AppColors.warningColor;
    }
  }

  // NEW: Preview evidence method for employees
  void _previewEvidence(MilestoneEvidence evidence, BuildContext context) {
    if (evidence.fileUrl.isEmpty) return;

    final isUrl =
        evidence.fileUrl.startsWith('http://') ||
        evidence.fileUrl.startsWith('https://');
    final isImage =
        evidence.fileType.toLowerCase().endsWith('png') ||
        evidence.fileType.toLowerCase().endsWith('jpg') ||
        evidence.fileType.toLowerCase().endsWith('jpeg') ||
        evidence.fileType.toLowerCase().endsWith('gif');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2840),
        title: Text(
          isImage ? 'Evidence Preview' : 'Evidence Details',
          style: const TextStyle(color: Colors.white),
        ),
        content: isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  evidence.fileUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.broken_image,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.red.shade300),
                        ),
                      ],
                    );
                  },
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'File Name:',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    Text(
                      evidence.fileName,
                      style: const TextStyle(color: Colors.lightBlueAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'File Type:',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    Text(
                      evidence.fileType,
                      style: const TextStyle(color: Colors.lightBlueAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'File Size:',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    Text(
                      '${(evidence.fileSize / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(color: Colors.lightBlueAccent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status:',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    Text(
                      evidence.status.name,
                      style: TextStyle(
                        color:
                            evidence.status == MilestoneEvidenceStatus.approved
                            ? Colors.green
                            : evidence.status ==
                                  MilestoneEvidenceStatus.rejected
                            ? Colors.red
                            : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload Date:',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    Text(
                      _formatDate(evidence.uploadedAt),
                      style: const TextStyle(color: Colors.lightBlueAccent),
                    ),
                    if (isUrl) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          try {
                            // For web, open in new tab
                            // ignore: undefined_prefixed_name
                            web.window.open(evidence.fileUrl, '_blank');
                          } catch (_) {
                            // On non-web platforms, just close the dialog
                            Navigator.of(ctx).pop();
                          }
                        },
                        child: const Text('Open in Browser'),
                      ),
                    ],
                  ],
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper method for formatting dates
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Helper method to deduplicate evidence entries
  List<MilestoneEvidence> _deduplicateEvidence(
    List<MilestoneEvidence> evidence,
  ) {
    final seen = <String>{};
    final deduplicated = <MilestoneEvidence>[];

    for (final e in evidence) {
      // Create a unique key based on file name and file URL
      final key = '${e.fileName}_${e.fileUrl}';
      if (!seen.contains(key)) {
        seen.add(key);
        deduplicated.add(e);
      }
    }

    return deduplicated;
  }
}
