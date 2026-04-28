import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/season_service.dart';
import 'package:pdh/utils/attachment_opener_io.dart';

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
  final TextEditingController _proofController = TextEditingController();
  bool _submittingProof = false;

  @override
  void dispose() {
    _proofController.dispose();
    super.dispose();
  }

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
    final submission =
        participation?.challengeSubmissions[widget.challenge.id];

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
            if (challenge.resources.isNotEmpty) ...[
              _buildLearningResourcesSection(challenge),
              const SizedBox(height: AppSpacing.md),
            ],
            if (challenge.proofRequired) ...[
              _buildProofSection(challenge, submission),
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
    final isManagerReviewStep = _isManagerReviewMilestone(milestone);

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
                isManagerReviewStep
                    ? 'Manager approval step'
                    : '+${milestone.points} pts',
                style: AppTypography.bodySmall.copyWith(
                  color: isManagerReviewStep
                      ? AppColors.infoColor
                      : AppColors.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isManagerReviewStep)
                Text(
                  status == MilestoneStatus.completed
                      ? 'Approved'
                      : 'Awaiting review',
                  style: AppTypography.bodySmall.copyWith(
                    color: status == MilestoneStatus.completed
                        ? AppColors.successColor
                        : AppColors.infoColor,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
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

  Widget _buildLearningResourcesSection(SeasonChallenge challenge) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learning Resources',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...challenge.resources.map((resource) {
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.school, color: AppColors.infoColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.title.isNotEmpty ? resource.title : challenge.title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${resource.provider.isNotEmpty ? resource.provider : 'External resource'}${resource.isFreeResource ? ' • Free' : ''}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _openCourseResource(resource.url),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Open'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProofSection(
    SeasonChallenge challenge,
    SeasonChallengeSubmission? submission,
  ) {
    final status = submission?.status ?? ChallengeSubmissionStatus.notSubmitted;
    final helperText = switch (status) {
      ChallengeSubmissionStatus.notSubmitted =>
        'Submit ${challenge.proofType ?? 'completion proof'} when you finish the course.',
      ChallengeSubmissionStatus.submitted =>
        'Your proof is pending manager review.',
      ChallengeSubmissionStatus.approved =>
        'Your proof has been approved.',
      ChallengeSubmissionStatus.rejected =>
        'Your proof needs updates. Submit a revised link or note.',
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proof of Completion',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            helperText,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (submission != null && submission.evidence.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Latest submission: ${submission.evidence}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (submission?.feedback?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Manager feedback: ${submission!.feedback}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.warningColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _proofController,
            enabled: status != ChallengeSubmissionStatus.approved,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: challenge.proofType ?? 'Proof link or note',
              hintText: 'Paste a certificate URL, screenshot link, or short note',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _submittingProof || status == ChallengeSubmissionStatus.approved
                  ? null
                  : () => _submitProof(challenge),
              icon: _submittingProof
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file, size: 16),
              label: Text(
                _submittingProof ? 'Submitting...' : 'Submit Proof',
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

  bool _isManagerReviewMilestone(SeasonMilestone milestone) {
    return milestone.criteria['managerReview'] == true ||
        milestone.criteria['proofApproval'] == true;
  }

  Future<void> _openCourseResource(String url) async {
    final opened = await openAttachmentUrl(url);
    if (!mounted) return;
    if (!opened) {
      await _showCenterNotice(context, 'Unable to open the linked course.');
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
        await _showCenterNotice(
          context,
          'Milestone marked as ${_milestoneStatusLabel(status)}.',
        );
      }
    } catch (e) {
      if (mounted) {
        await _showCenterNotice(context, 'Unable to update milestone: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingMilestoneIds.remove(milestoneId);
        });
      }
    }
  }

  Future<void> _submitProof(SeasonChallenge challenge) async {
    final evidence = _proofController.text.trim();
    if (evidence.isEmpty) {
      await _showCenterNotice(
        context,
        'Add a certificate link, screenshot link, or short completion note first.',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _submittingProof = true;
    });

    try {
      await SeasonService.submitChallengeProof(
        seasonId: widget.season.id,
        userId: widget.userId,
        challengeId: challenge.id,
        evidence: evidence,
      );
      _proofController.clear();
      if (mounted) {
        await _showCenterNotice(
          context,
          'Proof submitted. Your manager can now review it.',
        );
      }
    } catch (e) {
      if (mounted) {
        await _showCenterNotice(context, 'Unable to submit proof: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _submittingProof = false;
        });
      }
    }
  }
}
