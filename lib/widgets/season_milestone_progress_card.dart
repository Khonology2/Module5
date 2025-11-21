import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/season_service.dart';

class SeasonMilestoneProgressCard extends StatefulWidget {
  final Season season;
  final SeasonChallenge challenge;
  final SeasonParticipation? participation;
  final String userId;
  final bool showHeader;
  final EdgeInsetsGeometry? margin;

  const SeasonMilestoneProgressCard({
    super.key,
    required this.season,
    required this.challenge,
    required this.userId,
    this.participation,
    this.showHeader = true,
    this.margin,
  });

  @override
  State<SeasonMilestoneProgressCard> createState() =>
      _SeasonMilestoneProgressCardState();
}

class _SeasonMilestoneProgressCardState
    extends State<SeasonMilestoneProgressCard> {
  final Set<String> _updatingMilestoneIds = {};

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    if (challenge.milestones.isEmpty) {
      return Card(
        margin: widget.margin,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'This challenge has no milestones to update.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final participation =
        widget.season.participations[widget.userId] ?? widget.participation;

    return Card(
      margin: widget.margin,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showHeader) ...[
              Text(
                'Milestone Progress',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Update each step so your manager can track real-time progress.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            ...challenge.milestones.map(
              (milestone) => _buildMilestoneRow(
                challenge: challenge,
                milestone: milestone,
                participation: participation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneRow({
    required SeasonChallenge challenge,
    required SeasonMilestone milestone,
    SeasonParticipation? participation,
  }) {
    final status = _resolveMilestoneStatus(
      challenge: challenge,
      milestone: milestone,
      participation: participation,
    );
    final isUpdating = _updatingMilestoneIds.contains(milestone.id);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
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
              Icon(
                _challengeTypeIcon(challenge.type),
                color: _challengeTypeColor(challenge.type),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  milestone.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildStatusChip(status),
            ],
          ),
          if (milestone.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              milestone.description,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '+${milestone.points} pts',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<MilestoneStatus>(
                  value: status,
                  onChanged: isUpdating
                      ? null
                      : (value) {
                          if (value == null || value == status) return;
                          _onMilestoneStatusChange(milestone.id, value);
                        },
                  items: MilestoneStatus.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(_milestoneStatusLabel(s)),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
          if (isUpdating)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.activeColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(MilestoneStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _milestoneStatusColor(status).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _milestoneStatusLabel(status),
        style: AppTypography.bodySmall.copyWith(
          color: _milestoneStatusColor(status),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  MilestoneStatus _resolveMilestoneStatus({
    required SeasonChallenge challenge,
    required SeasonMilestone milestone,
    SeasonParticipation? participation,
  }) {
    if (participation == null) return MilestoneStatus.notStarted;
    final statuses = participation.milestoneProgress;
    final keyDot = '${challenge.id}.${milestone.id}';
    return statuses[keyDot] ??
        statuses[milestone.id] ??
        MilestoneStatus.notStarted;
  }

  String _milestoneStatusLabel(MilestoneStatus status) {
    switch (status) {
      case MilestoneStatus.notStarted:
        return 'Not Started';
      case MilestoneStatus.inProgress:
        return 'In Progress';
      case MilestoneStatus.completed:
        return 'Completed';
      case MilestoneStatus.overdue:
        return 'Overdue';
    }
  }

  Color _milestoneStatusColor(MilestoneStatus status) {
    switch (status) {
      case MilestoneStatus.notStarted:
        return AppColors.textSecondary;
      case MilestoneStatus.inProgress:
        return AppColors.activeColor;
      case MilestoneStatus.completed:
        return AppColors.successColor;
      case MilestoneStatus.overdue:
        return AppColors.dangerColor;
    }
  }

  IconData _challengeTypeIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.learning:
        return Icons.school;
      case ChallengeType.skill:
        return Icons.build;
      case ChallengeType.collaboration:
        return Icons.people_alt;
      case ChallengeType.innovation:
        return Icons.lightbulb;
      case ChallengeType.wellness:
        return Icons.favorite;
    }
  }

  Color _challengeTypeColor(ChallengeType type) {
    switch (type) {
      case ChallengeType.learning:
        return AppColors.infoColor;
      case ChallengeType.skill:
        return AppColors.warningColor;
      case ChallengeType.collaboration:
        return AppColors.activeColor;
      case ChallengeType.innovation:
        return AppColors.successColor;
      case ChallengeType.wellness:
        return AppColors.dangerColor;
    }
  }

  Future<void> _onMilestoneStatusChange(
    String milestoneId,
    MilestoneStatus status,
  ) async {
    if (!mounted) return;
    setState(() {
      _updatingMilestoneIds.add(milestoneId);
    });
    try {
      await SeasonService.updateMilestoneProgress(
        seasonId: widget.season.id,
        userId: widget.userId,
        milestoneId: milestoneId,
        status: status,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Milestone marked as ${_milestoneStatusLabel(status)}.',
            ),
            backgroundColor: AppColors.activeColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to update milestone: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingMilestoneIds.remove(milestoneId);
        });
      }
    }
  }
}

