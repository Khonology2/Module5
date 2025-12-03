import 'package:flutter/material.dart';
import 'package:pdh/services/profile_completion_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';

/// Banner widget that displays profile completion status
/// Shows a prominent banner when profile is incomplete
class ProfileCompletionBanner extends StatefulWidget {
  const ProfileCompletionBanner({super.key});

  @override
  State<ProfileCompletionBanner> createState() =>
      _ProfileCompletionBannerState();
}

class _ProfileCompletionBannerState extends State<ProfileCompletionBanner> {
  ProfileCompletionStatus? _completionStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompletionStatus();
  }

  Future<void> _loadCompletionStatus() async {
    try {
      final status =
          await ProfileCompletionService.getCurrentUserCompletionStatus();
      if (mounted) {
        setState(() {
          _completionStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _completionStatus == null) {
      return const SizedBox.shrink();
    }

    // Only show banner if profile is incomplete
    if (_completionStatus!.isComplete) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.activeColor.withValues(alpha: 0.2),
            AppColors.activeColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.activeColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.activeColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_add_alt_1,
              color: AppColors.activeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Your Profile',
                  style: AppTypography.heading4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_completionStatus!.completionPercentage}% complete. Add ${_completionStatus!.missingFields.length} more field${_completionStatus!.missingFields.length == 1 ? '' : 's'} to unlock all features.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_completionStatus!.missingFields.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _completionStatus!.missingFields
                        .take(3)
                        .map(
                          (field) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.activeColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              field,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.activeColor,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/my_profile');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}
