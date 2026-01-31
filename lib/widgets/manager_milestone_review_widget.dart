import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/models/goal_milestone.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/milestone_evidence_service.dart';
import 'package:pdh/services/cloudinary_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:file_picker/file_picker.dart';

class ManagerMilestoneReviewWidget extends StatefulWidget {
  final String goalId;
  final String employeeId;
  final GoalMilestone milestone;

  const ManagerMilestoneReviewWidget({
    super.key,
    required this.goalId,
    required this.employeeId,
    required this.milestone,
  });

  @override
  State<ManagerMilestoneReviewWidget> createState() =>
      _ManagerMilestoneReviewWidgetState();
}

class _ManagerMilestoneReviewWidgetState
    extends State<ManagerMilestoneReviewWidget> {
  final TextEditingController _notesController = TextEditingController();
  bool _isAcknowledging = false;
  bool _isUploading = false;
  List<MilestoneEvidence> _evidence = [];

  @override
  void initState() {
    super.initState();
    _loadEvidence();
  }

  Future<void> _loadEvidence() async {
    try {
      final evidence = await MilestoneEvidenceService.getMilestoneEvidence(
        goalId: widget.goalId,
        milestoneId: widget.milestone.id,
      );
      setState(() {
        _evidence = evidence;
      });
    } catch (e) {
      debugPrint('Error loading evidence: $e');
    }
  }

  Future<void> _attachEvidence() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _isUploading = true;
        });

        for (final file in result.files) {
          String cloudinaryUrl = '';

          // Upload to Cloudinary if file has bytes
          if (file.bytes != null) {
            try {
              cloudinaryUrl = await CloudinaryService.uploadFileUnsigned(
                bytes: file.bytes!,
                fileName: file.name,
                goalId: widget.goalId, // Use goal ID for organization
              );
            } catch (e) {
              // If Cloudinary fails, fall back to local path
              cloudinaryUrl = file.path ?? 'manager_file_${file.name}';
              debugPrint('Cloudinary upload failed for ${file.name}: $e');
            }
          } else {
            // For web files without bytes, use path
            cloudinaryUrl = file.path ?? 'manager_file_${file.name}';
          }

          // Create evidence record
          final evidence = MilestoneEvidence(
            id: FirebaseFirestore.instance
                .collection('milestone_evidence')
                .doc()
                .id,
            fileUrl: cloudinaryUrl,
            fileName: file.name,
            fileType: file.extension ?? 'unknown',
            fileSize: file.size,
            uploadedBy: FirebaseAuth.instance.currentUser!.uid,
            uploadedByName:
                FirebaseAuth.instance.currentUser!.displayName ?? 'Manager',
            uploadedAt: DateTime.now(),
            status: MilestoneEvidenceStatus.pendingReview,
          );

          // Save evidence to Firestore
          await FirebaseFirestore.instance
              .collection('milestone_evidence')
              .doc(evidence.id)
              .set(evidence.toMap());
        }

        await _loadEvidence();

        setState(() {
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Evidence attached successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to attach evidence: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acknowledgeMilestone() async {
    if (_isAcknowledging) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to acknowledge milestones'),
        ),
      );
      return;
    }

    setState(() => _isAcknowledging = true);

    try {
      await DatabaseService.acknowledgeMilestone(
        goalId: widget.goalId,
        milestoneId: widget.milestone.id,
        managerId: user.uid,
        managerName: user.displayName ?? user.email ?? 'Manager',
        checkInNotes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone acknowledged successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        // Handle different types of errors with user-friendly messages
        String errorMessage = 'Failed to acknowledge milestone';
        if (e.toString().contains('permission') ||
            e.toString().contains('access rights')) {
          errorMessage =
              'You do not have permission to acknowledge this milestone. Please check your access rights.';
        } else if (e.toString().contains('not found') ||
            e.toString().contains('deleted')) {
          errorMessage =
              'The milestone could not be found. It may have been deleted. Please refresh the page.';
        } else if (e.toString().contains('temporary error') ||
            e.toString().contains('try again')) {
          errorMessage =
              'A temporary error occurred. Please try again in a moment.';
        } else {
          errorMessage = 'Failed to acknowledge milestone: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                // Allow retry by resetting the acknowledging state
                setState(() => _isAcknowledging = false);
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAcknowledging = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.milestone.title,
                      style: AppTypography.heading4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted for review',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Pending Review',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Milestone Description
          if (widget.milestone.description.isNotEmpty) ...[
            Text(
              'Description',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.milestone.description,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Evidence Section
          Text(
            'Evidence Submitted',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (_evidence.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'No evidence files found',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ..._evidence.map(
              (evidence) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            evidence.fileName,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getEvidenceStatusColor(
                              evidence.status,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getEvidenceStatusLabel(evidence.status),
                            style: AppTypography.bodySmall.copyWith(
                              color: _getEvidenceStatusColor(evidence.status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (evidence.fileUrl.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _attachEvidence,
                        icon: _isUploading
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
                            : const Icon(Icons.attach_file, size: 16),
                        label: Text(
                          _isUploading ? 'Attaching...' : 'Attach Evidence',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                    if (evidence.reviewNotes?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Review Notes: ${evidence.reviewNotes}',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Check-in Notes Section
          Text(
            'Check-in Notes',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'Add your check-in notes or feedback for the employee...',
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
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppColors.borderColor),
                  ),
                  child: Text(
                    'Cancel',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isAcknowledging ? null : _acknowledgeMilestone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isAcknowledging
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          'Acknowledge Completion',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getEvidenceStatusLabel(MilestoneEvidenceStatus status) {
    switch (status) {
      case MilestoneEvidenceStatus.pendingReview:
        return 'Pending';
      case MilestoneEvidenceStatus.approved:
        return 'Approved';
      case MilestoneEvidenceStatus.rejected:
        return 'Rejected';
    }
  }

  Color _getEvidenceStatusColor(MilestoneEvidenceStatus status) {
    switch (status) {
      case MilestoneEvidenceStatus.pendingReview:
        return Colors.orange;
      case MilestoneEvidenceStatus.approved:
        return Colors.green;
      case MilestoneEvidenceStatus.rejected:
        return Colors.red;
    }
  }
}
