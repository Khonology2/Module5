import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/alert_service.dart';

class TeamGoalsScreen extends StatefulWidget {
  const TeamGoalsScreen({super.key});

  @override
  State<TeamGoalsScreen> createState() => _TeamGoalsScreenState();
}

class _TeamGoalsScreenState extends State<TeamGoalsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _showCenterNotice(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          content: Text(
            message,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      appBar: AppBar(
        title: Text(
          'Team Goals',
          style: AppTypography.heading2.copyWith(color: Colors.white),
        ),
        backgroundColor: AppColors.activeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team Collaboration Hub',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Join team goals created by managers and collaborate with your colleagues to achieve common objectives.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Available Team Goals',
              style: AppTypography.heading3.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('team_goals')
                    .where('status', isEqualTo: 'active')
                    .orderBy('createdAt', descending: true)
                    .snapshots()
                    .handleError((error) {
                      // Silently handle errors to prevent unmount errors
                      developer.log('Error in team_goals stream: $error');
                    }),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.activeColor,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
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
                            'Error loading team goals',
                            style: AppTypography.heading4,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  final teamGoals = snapshot.data?.docs ?? [];
                  if (teamGoals.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.group_work_outlined,
                            size: 64,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Team Goals Available',
                            style: AppTypography.heading4,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later for team goals created by managers.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: teamGoals.length,
                    itemBuilder: (context, index) {
                      final teamGoal = teamGoals[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _buildTeamGoalCard(teamGoal),
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

  Widget _buildTeamGoalCard(QueryDocumentSnapshot teamGoalDoc) {
    final data = teamGoalDoc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Untitled Goal';
    final description =
        data['description'] as String? ?? 'No description available';
    final points = data['points'] as int? ?? 0;
    final deadline =
        (data['targetDate'] as Timestamp?)?.toDate() ?? DateTime.now();
    final managerName = data['managerName'] as String? ?? 'Manager';
    final participantCount = data['participantCount'] as int? ?? 0;
    // final status = data['status'] as String? ?? 'active'; // Unused variable removed
    final createdAt =
        (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

    final now = DateTime.now();
    final daysLeft = deadline.difference(now).inDays;
    final isExpired = daysLeft < 0;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isExpired) {
      statusColor = AppColors.dangerColor;
      statusIcon = Icons.schedule;
      statusText = 'Expired';
    } else if (daysLeft <= 3) {
      statusColor = AppColors.warningColor;
      statusIcon = Icons.schedule;
      statusText = '$daysLeft days left';
    } else {
      statusColor = AppColors.successColor;
      statusIcon = Icons.check_circle_outline;
      statusText = '$daysLeft days left';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.group_work, color: AppColors.activeColor, size: 24),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.heading4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: AppTypography.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              _buildInfoChip(
                icon: Icons.person,
                label: 'Created by',
                value: managerName,
                color: AppColors.activeColor,
              ),
              const SizedBox(width: AppSpacing.md),
              _buildInfoChip(
                icon: Icons.people,
                label: 'Participants',
                value: '$participantCount joined',
                color: AppColors.infoColor,
              ),
              const Spacer(),
              _buildInfoChip(
                icon: Icons.stars,
                label: 'Points',
                value: '$points',
                color: AppColors.warningColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: AppColors.textSecondary,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Deadline: ${deadline.day}/${deadline.month}/${deadline.year}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                'Created ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isExpired ? null : () => _joinTeamGoal(teamGoalDoc.id),
              icon: const Icon(Icons.group_add, size: 16),
              label: Text(isExpired ? 'Goal Expired' : 'Join Team Goal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isExpired
                    ? AppColors.textSecondary
                    : AppColors.activeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: AppTypography.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _joinTeamGoal(String teamGoalId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Team Goal'),
        content: const Text(
          'Are you sure you want to join this team goal? '
          'You\'ll be able to track your participation and earn points when completed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Join Team'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Get team goal details first
        final teamGoalDoc = await _firestore
            .collection('team_goals')
            .doc(teamGoalId)
            .get();
        final teamGoalData = teamGoalDoc.data();
        final teamGoalTitle = teamGoalData?['title'] as String? ?? 'Team Goal';
        final managerId = teamGoalData?['managerId'] as String? ?? '';

        // Increment participant count
        await _firestore.collection('team_goals').doc(teamGoalId).update({
          'participantCount': FieldValue.increment(1),
        });

        // Create a personal goal for the employee based on the team goal
        final currentUser = AuthService().currentUser;
        if (currentUser != null) {
          await _firestore.collection('goals').add({
            'userId': currentUser.uid,
            'title': 'Team Goal Contribution',
            'description': 'Participation in team goal collaboration',
            'category': 'work',
            'priority': 'medium',
            'status': 'inProgress',
            'progress': 0,
            'points': 10, // Base participation points
            'createdAt': FieldValue.serverTimestamp(),
            'targetDate': FieldValue.serverTimestamp(),
            'teamGoalId': teamGoalId, // Link to the team goal
          });

          // Create activity record
          await _firestore.collection('activities').add({
            'userId': currentUser.uid,
            'activityType': 'team_goal_joined',
            'description': 'Joined a team goal in the collaboration hub',
            'metadata': {'teamGoalId': teamGoalId},
            'timestamp': FieldValue.serverTimestamp(),
          });

          // Notify the manager that someone joined their team goal
          await AlertService.createEmployeeJoinedTeamGoalAlert(
            managerId: managerId,
            employeeName: currentUser.displayName ?? 'Employee',
            teamGoalTitle: teamGoalTitle,
            teamGoalId: teamGoalId,
          );

          if (!mounted) return; // Add this line here
          await _showCenterNotice(
            context,
            'Successfully joined the team goal!',
          );
        } // Close currentUser null check
      } catch (e) {
        if (!mounted) return; // Add this line
        await _showCenterNotice(context, 'Error joining team goal: $e');
      }
    }
  }
}
