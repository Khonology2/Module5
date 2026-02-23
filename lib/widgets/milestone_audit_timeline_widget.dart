import 'package:flutter/material.dart';
import 'package:pdh/models/milestone_audit_entry.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';

class MilestoneAuditTimelineWidget extends StatelessWidget {
  final List<MilestoneAuditEntry> auditEntries;
  final bool isLoading;

  const MilestoneAuditTimelineWidget({
    super.key,
    required this.auditEntries,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
        ),
      );
    }

    if (auditEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No audit history available',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemCount: auditEntries.length,
      itemBuilder: (context, index) {
        final entry = auditEntries[index];
        return _AuditEntryCard(entry: entry);
      },
    );
  }
}

class _AuditEntryCard extends StatelessWidget {
  final MilestoneAuditEntry entry;

  const _AuditEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with action and timestamp
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: _getActionColor(),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(
                    entry.action.name.toUpperCase(),
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(entry.timestamp),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // User info
            Row(
              children: [
                Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  entry.userName ?? 'Unknown User',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (entry.userRole != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.activeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                    ),
                    child: Text(
                      entry.userRole!.toUpperCase(),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.activeColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Goal and milestone info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Goal: ${entry.goalTitle}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Milestone ID: ${entry.milestoneId}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Field changes
            if (entry.fieldChanges.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Changes Made:',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ...entry.fieldChanges.entries.map((fieldEntry) {
                return _FieldChangeWidget(
                  field: fieldEntry.key,
                  change: fieldEntry.value,
                );
              }),
            ],

            // Change reason
            if (entry.changeReason != null &&
                entry.changeReason!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.infoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  border: Border.all(
                    color: AppColors.infoColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reason:',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.infoColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      entry.changeReason!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getActionColor() {
    switch (entry.action) {
      case MilestoneAuditAction.created:
        return AppColors.successColor;
      case MilestoneAuditAction.updated:
        return AppColors.activeColor;
      case MilestoneAuditAction.statusChanged:
        return AppColors.warningColor;
      case MilestoneAuditAction.deleted:
        return AppColors.dangerColor;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}

class _FieldChangeWidget extends StatelessWidget {
  final MilestoneFieldChanged field;
  final FieldChange change;

  const _FieldChangeWidget({required this.field, required this.change});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border(left: BorderSide(color: _getFieldColor(), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _getFieldDisplayName(),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                _getFieldType(),
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatValue(change.oldValue),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppColors.activeColor,
                ),
              ),
              Expanded(
                child: Text(
                  _formatValue(change.newValue),
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getFieldDisplayName() {
    switch (field) {
      case MilestoneFieldChanged.title:
        return 'Title';
      case MilestoneFieldChanged.description:
        return 'Description';
      case MilestoneFieldChanged.dueDate:
        return 'Due Date';
      case MilestoneFieldChanged.status:
        return 'Status';
      case MilestoneFieldChanged.weight:
        return 'Weight';
      case MilestoneFieldChanged.goalId:
        return 'Goal';
    }
  }

  String _getFieldType() {
    switch (change.fieldType) {
      case FieldType.string:
        return 'Text';
      case FieldType.number:
        return 'Number';
      case FieldType.boolean:
        return 'Boolean';
      case FieldType.dateTime:
        return 'Date';
      case FieldType.list:
        return 'List';
      case FieldType.map:
        return 'Object';
    }
  }

  Color _getFieldColor() {
    switch (field) {
      case MilestoneFieldChanged.title:
        return AppColors.activeColor;
      case MilestoneFieldChanged.description:
        return AppColors.activeColor;
      case MilestoneFieldChanged.dueDate:
        return AppColors.warningColor;
      case MilestoneFieldChanged.status:
        return AppColors.successColor;
      case MilestoneFieldChanged.weight:
        return AppColors.infoColor;
      case MilestoneFieldChanged.goalId:
        return AppColors.dangerColor;
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'null';

    switch (change.fieldType) {
      case FieldType.dateTime:
        if (value is DateTime) {
          return value.toIso8601String().split('T')[0];
        }
        return value.toString();
      case FieldType.boolean:
        return value.toString();
      case FieldType.list:
      case FieldType.map:
        return value.toString();
      case FieldType.number:
        return value.toString();
      case FieldType.string:
        return value.toString();
    }
  }
}
