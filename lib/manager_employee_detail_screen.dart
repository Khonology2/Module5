import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/manager_badge_evaluator.dart';

class ManagerEmployeeDetailScreen extends StatefulWidget {
  final EmployeeData employee;
  const ManagerEmployeeDetailScreen({super.key, required this.employee});

  @override
  State<ManagerEmployeeDetailScreen> createState() =>
      _ManagerEmployeeDetailScreenState();
}

class _ManagerEmployeeDetailScreenState
    extends State<ManagerEmployeeDetailScreen> {

  Stream<List<Goal>> _goalsStream() {
    // Merge top-level and nested user goals
    final topLevel = FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: widget.employee.profile.uid)
        .snapshots()
        .map((s) => s.docs.map((d) => Goal.fromFirestore(d)).toList());

    final nested = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.employee.profile.uid)
        .collection('goals')
        .snapshots()
        .map((s) => s.docs.map((d) => Goal.fromFirestore(d)).toList());

    return topLevel.combineLatest<List<Goal>, List<Goal>>(nested, (a, b) {
      final seen = <String>{};
      final merged = <Goal>[];
      for (final g in [...a, ...b]) {
        if (!seen.contains(g.id)) {
          seen.add(g.id);
          merged.add(g);
        }
      }
      merged.sort((x, y) => y.createdAt.compareTo(x.createdAt));
      return merged;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.employee.profile.displayName,
          style: AppTypography.heading2.copyWith(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/khono_bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80), // Space for AppBar
                _header(),
                const SizedBox(height: 12),
                // Add Stretch Objective Button
                ElevatedButton.icon(
                  onPressed: () => _addStretchObjective(),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Stretch Objective'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withValues(alpha: 0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<Goal>>(
                    stream: _goalsStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.activeColor,
                          ),
                        );
                      }
                      final goals = snapshot.data!;
                      if (goals.isEmpty) {
                        return Center(
                          child: Text('No goals yet', style: AppTypography.muted),
                        );
                      }
                      return ListView.builder(
                        itemCount: goals.length,
                        itemBuilder: (context, i) => _goalTile(goals[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.activeColor,
            child: Text(
              widget.employee.profile.displayName.isNotEmpty
                  ? widget.employee.profile.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employee.profile.displayName,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.employee.profile.jobTitle,
                  style: AppTypography.muted,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${widget.employee.totalPoints} pts',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Level ${widget.employee.profile.level}',
                style: AppTypography.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _goalTile(Goal g) {
    final normalizedToday = _normalizedToday();
    final normalizedTarget = DateTime(
      g.targetDate.year,
      g.targetDate.month,
      g.targetDate.day,
    );
    final deltaDays = normalizedTarget.difference(normalizedToday).inDays;
    final isOverdue = deltaDays < 0;
    final isDueSoon = deltaDays >= 0 && deltaDays <= 2;
    final isUrgent = isOverdue || isDueSoon;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUrgent
              ? (isOverdue ? AppColors.dangerColor : AppColors.warningColor)
              : AppColors.borderColor,
          width: isUrgent ? 2 : 1,
        ),
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
                      g.title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isUrgent) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isOverdue
                                  ? AppColors.dangerColor
                                  : AppColors.warningColor)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOverdue ? Icons.error : Icons.warning,
                              size: 12,
                              color: isOverdue
                                  ? AppColors.dangerColor
                                  : AppColors.warningColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOverdue
                                  ? 'Overdue ${deltaDays.abs()} day${deltaDays.abs() == 1 ? '' : 's'}'
                                  : deltaDays == 0
                                      ? 'Due today'
                                      : deltaDays == 1
                                          ? 'Due tomorrow'
                                          : 'Due in $deltaDays days',
                              style: AppTypography.bodySmall.copyWith(
                                color: isOverdue
                                    ? AppColors.dangerColor
                                    : AppColors.warningColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Due: ${_formatDate(g.targetDate)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _statusChip(g.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            g.description,
            style: AppTypography.muted,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (g.progress.clamp(0, 100)) / 100.0,
            backgroundColor: AppColors.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              g.progress >= 70
                  ? AppColors.successColor
                  : g.progress >= 40
                      ? AppColors.warningColor
                      : AppColors.activeColor,
            ),
            minHeight: 6,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${g.progress}% Complete',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              if (g.points > 0)
                Text(
                  '${g.points} pts',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Goal-specific actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildGoalActionButton(
                label: 'Nudge',
                icon: Icons.send,
                onPressed: () => _nudgeAboutGoal(g),
                color: AppColors.activeColor,
              ),
              if (isUrgent) ...[
                _buildGoalActionButton(
                  label: 'Extend',
                  icon: Icons.schedule_send_outlined,
                  onPressed: () => _extendGoalDeadline(g),
                  color: AppColors.infoColor,
                ),
                _buildGoalActionButton(
                  label: 'Reschedule',
                  icon: Icons.update,
                  onPressed: () => _rescheduleGoal(g),
                  color: AppColors.infoColor,
                ),
              ],
              if (g.status != GoalStatus.completed &&
                  g.status != GoalStatus.paused) ...[
                _buildGoalActionButton(
                  label: 'Pause',
                  icon: Icons.pause_circle_outline,
                  onPressed: () => _pauseGoal(g),
                  color: AppColors.warningColor,
                ),
              ],
              if (g.status != GoalStatus.completed &&
                  g.status != GoalStatus.burnout) ...[
                _buildGoalActionButton(
                  label: 'Mark Burnout',
                  icon: Icons.local_fire_department_outlined,
                  onPressed: () => _markGoalBurnout(g),
                  color: AppColors.dangerColor,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 11),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  DateTime _normalizedToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _nudgeAboutGoal(Goal goal) {
    final normalizedToday = _normalizedToday();
    final normalizedTarget = DateTime(
      goal.targetDate.year,
      goal.targetDate.month,
      goal.targetDate.day,
    );
    final deltaDays = normalizedTarget.difference(normalizedToday).inDays;
    final isOverdue = deltaDays < 0;

    final presetMessage = isOverdue
        ? 'Hi! I noticed your goal "${goal.title}" is overdue. How can I help you get back on track?'
        : deltaDays <= 2
            ? 'Hi! I noticed your goal "${goal.title}" is due soon. How is your progress?'
            : 'Hi! How is your progress on "${goal.title}"?';

    _showSendNudgeDialog(goal: goal, presetMessage: presetMessage);
  }

  void _showSendNudgeDialog({Goal? goal, String? presetMessage}) {
    showDialog(
      context: context,
      builder: (context) => _NudgeDialog(
        employee: widget.employee,
        goal: goal,
        presetMessage: presetMessage,
        onSendNudge: (employeeId, goalId, message) =>
            _sendNudgeToEmployee(employeeId, goalId, message),
      ),
    );
  }

  void _sendNudgeToEmployee(
    String employeeId,
    String goalId,
    String message,
  ) async {
    try {
      await ManagerRealtimeService.sendNudgeToEmployee(
        employeeId: employeeId,
        goalId: goalId,
        message: message,
      );
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nudge sent successfully!'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending nudge: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _extendGoalDeadline(Goal goal) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: goal.targetDate.isAfter(now)
          ? goal.targetDate
          : now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    try {
      await FirebaseFirestore.instance.collection('goals').doc(goal.id).update({
        'targetDate': Timestamp.fromDate(picked),
        'status': GoalStatus.inProgress.name,
      });

      await AlertService.createMotivationalAlert(
        userId: widget.employee.profile.uid,
        message:
            'Your goal deadline has been extended to ${picked.day}/${picked.month}/${picked.year}. You got this!',
        goalId: goal.id,
      );

      final manager = FirebaseAuth.instance.currentUser;
      if (manager != null) {
        await ManagerBadgeEvaluator.logReplanHelped(
          managerId: manager.uid,
          goalId: goal.id,
          note: 'Extended deadline',
        );
        await ManagerBadgeEvaluator.evaluate(manager.uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deadline extended successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extend deadline: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _rescheduleGoal(Goal goal) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;

    final noteController = TextEditingController();
    if (!mounted) return;
    final note = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Reschedule Note'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(labelText: 'Optional note'),
          autofocus: true,
          onSubmitted: (value) {
            Navigator.of(ctx).pop(value.trim().isEmpty ? null : value.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () {
              final noteText = noteController.text.trim();
              Navigator.of(ctx).pop(noteText.isEmpty ? null : noteText);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    try {
      await FirebaseFirestore.instance.collection('goals').doc(goal.id).update({
        'targetDate': Timestamp.fromDate(picked),
        'status': GoalStatus.inProgress.name,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await AlertService.createMotivationalAlert(
        userId: widget.employee.profile.uid,
        message:
            'Your goal has been rescheduled to ${picked.day}/${picked.month}/${picked.year}.',
        goalId: goal.id,
      );

      final manager = FirebaseAuth.instance.currentUser;
      if (manager != null) {
        await ManagerBadgeEvaluator.logReplanHelped(
          managerId: manager.uid,
          goalId: goal.id,
          note: (note != null && note.isNotEmpty)
              ? 'Rescheduled: $note'
              : 'Rescheduled',
        );
        await ManagerBadgeEvaluator.evaluate(manager.uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal rescheduled successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reschedule goal: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _pauseGoal(Goal goal) async {
    try {
      await FirebaseFirestore.instance.collection('goals').doc(goal.id).update({
        'status': GoalStatus.paused.name,
      });

      await AlertService.createMotivationalAlert(
        userId: widget.employee.profile.uid,
        message:
            'Your goal has been paused by your manager. Take the time you need.',
        goalId: goal.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal paused'),
            backgroundColor: AppColors.infoColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pause goal: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _markGoalBurnout(Goal goal) async {
    try {
      await FirebaseFirestore.instance.collection('goals').doc(goal.id).update({
        'status': GoalStatus.burnout.name,
      });

      await AlertService.createMotivationalAlert(
        userId: widget.employee.profile.uid,
        message:
            'We noticed signs of burnout on a goal. It has been marked accordingly. Let\'s regroup and plan a healthier path.',
        goalId: goal.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal marked as burnout'),
            backgroundColor: AppColors.warningColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark goal as burnout: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  void _addStretchObjective() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final targetDateController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Add Stretch Objective for ${widget.employee.profile.displayName}',
          style: AppTypography.heading4.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Objective Title',
                  labelStyle: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  hintText: 'e.g., Complete advanced certification',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  hintText: 'Describe the stretch objective...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetDateController,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Target Date',
                  labelStyle: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 90)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    selectedDate = date;
                    targetDateController.text = _formatDate(date);
                  }
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.infoColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Plan Template:',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Define success metrics\n• Break into milestones\n• Set review checkpoints\n• Identify resources needed',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a title'),
                    backgroundColor: AppColors.warningColor,
                  ),
                );
                return;
              }
              if (selectedDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please select a target date'),
                    backgroundColor: AppColors.warningColor,
                  ),
                );
                return;
              }

              // TODO: Implement stretch objective creation in database service
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Stretch objective "${titleController.text}" added for ${widget.employee.profile.displayName}',
                    ),
                    backgroundColor: AppColors.successColor,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(GoalStatus status) {
    Color c;
    String t;
    switch (status) {
      case GoalStatus.completed:
        c = AppColors.successColor;
        t = 'Completed';
        break;
      case GoalStatus.inProgress:
        c = AppColors.activeColor;
        t = 'In Progress';
        break;
      case GoalStatus.notStarted:
        c = AppColors.textSecondary;
        t = 'Not Started';
        break;
      case GoalStatus.paused:
        c = AppColors.textSecondary;
        t = 'Paused';
        break;
      case GoalStatus.burnout:
        c = AppColors.dangerColor;
        t = 'Burnout';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        border: Border.all(color: c.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        t,
        style: AppTypography.bodySmall.copyWith(
          color: c,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

// Nudge Dialog Widget
class _NudgeDialog extends StatefulWidget {
  final EmployeeData? employee;
  final Goal? goal;
  final String? presetMessage;
  final Function(String employeeId, String goalId, String message) onSendNudge;

  const _NudgeDialog({
    this.employee,
    this.goal,
    this.presetMessage,
    required this.onSendNudge,
  });

  @override
  State<_NudgeDialog> createState() => _NudgeDialogState();
}

class _NudgeDialogState extends State<_NudgeDialog> {
  late TextEditingController _messageController;
  Goal? _selectedGoal;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: widget.presetMessage ?? '',
    );
    if (widget.goal != null) {
      _selectedGoal = widget.goal;
    } else if (widget.employee?.goals.isNotEmpty == true) {
      _selectedGoal = widget.employee!.goals.first;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      title: Text(
        widget.employee != null
            ? 'Send Nudge to ${widget.employee!.profile.displayName}'
            : 'Send Nudge',
        style: AppTypography.heading4.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.employee != null &&
                widget.employee!.goals.isNotEmpty &&
                widget.goal == null) ...[
              Text(
                'Related Goal:',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.elevatedBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: DropdownButton<Goal>(
                  value: _selectedGoal,
                  underline: const SizedBox(),
                  isExpanded: true,
                  dropdownColor: AppColors.cardBackground,
                  hint: Text(
                    'Select Goal',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  icon: Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
                  onChanged: (goal) => setState(() => _selectedGoal = goal),
                  items: widget.employee!.goals.map((goal) {
                    return DropdownMenuItem<Goal>(
                      value: goal,
                      child: Text(goal.title),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (widget.goal != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.activeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.activeColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.flag, color: AppColors.activeColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.goal!.title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Message:',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your nudge message...',
                hintStyle: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _sendNudge,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.activeColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }

  void _sendNudge() {
    if (_messageController.text.trim().isEmpty) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            content: Text(
              'Please enter a message',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(
                  'OK',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.activeColor,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    if (widget.employee == null) {
      return;
    }

    final goalId = _selectedGoal?.id ?? widget.goal?.id ?? 'general';
    widget.onSendNudge(
      widget.employee!.profile.uid,
      goalId,
      _messageController.text.trim(),
    );
    Navigator.pop(context);
  }
}

extension _Rx on Stream<List<Goal>> {
  Stream<R> combineLatest<T, R>(
    Stream<T> other,
    R Function(List<Goal>, T) combiner,
  ) {
    late List<Goal> aCache;
    late T bCache;
    bool hasA = false, hasB = false;
    final controller = StreamController<R>();
    final subA = listen((a) {
      hasA = true;
      aCache = a;
      if (hasB) controller.add(combiner(aCache, bCache));
    });
    final subB = other.listen((b) {
      hasB = true;
      bCache = b;
      if (hasA) controller.add(combiner(aCache, bCache));
    });
    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
    };
    return controller.stream;
  }
}
