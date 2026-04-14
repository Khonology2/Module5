import 'package:flutter/material.dart';
import 'package:pdh/services/profile_completion_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';

/// A widget that blocks actions until profile is complete
/// Shows a dialog guiding users to complete their profile
class ProfileCompletionGate extends StatelessWidget {
  final Widget child;
  final VoidCallback? onActionAttempted;
  final String?
  actionName; // Name of the action being blocked (e.g., "create goals")

  const ProfileCompletionGate({
    super.key,
    required this.child,
    this.onActionAttempted,
    this.actionName,
  });

  /// Check if profile is complete and show dialog if not
  /// Returns true if profile is complete, false otherwise
  static Future<bool> checkAndShowDialog(
    BuildContext context, {
    String? actionName,
  }) async {
    try {
      final completionStatus =
          await ProfileCompletionService.getCurrentUserCompletionStatus();
      if (!context.mounted) return true;
      if (!completionStatus.isComplete) {
        await _showProfileCompletionDialog(
          context,
          completionStatus,
          actionName,
        );
        return false;
      }
      return true;
    } catch (e) {
      // If check fails, allow action to proceed (fail open)
      return true;
    }
  }

  /// Show dialog guiding user to complete their profile
  static Future<void> _showProfileCompletionDialog(
    BuildContext context,
    ProfileCompletionStatus status,
    String? actionName,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.elevatedBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.activeColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Complete Your Profile',
                  style: AppTypography.heading4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionName != null
                      ? 'Before you can $actionName, please complete your profile with the following required information:'
                      : 'Before you can perform this action, please complete your profile with the following required information:',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ...status.missingFields.map(
                  (field) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: AppColors.activeColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            field,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                      Icon(
                        Icons.lightbulb_outline,
                        color: AppColors.activeColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Profile completion: ${status.completionPercentage}%',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.activeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Navigate to profile screen
                Navigator.pushNamed(context, '/my_profile');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Complete Profile'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
