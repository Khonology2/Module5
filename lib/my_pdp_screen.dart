// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/audit_service.dart';
import 'package:pdh/models/audit_entry.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdh/services/cloudinary_service.dart';
// Drawer removed in favor of persistent sidebar

class MyPdpScreen extends StatefulWidget {
  const MyPdpScreen({super.key});

  @override
  State<MyPdpScreen> createState() => _MyPdpScreenState();
}

Future<void> _showCenterNotice(BuildContext context, String message) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF0E1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFC10D00)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFFC10D00))),
          ),
        ],
      );
    },
  );
}

void _showLoadingDialog(BuildContext context, {String message = 'Loading...'}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF0E1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(
        children: [
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MyPdpScreenState extends State<MyPdpScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // State for toggling expansion of sections
  bool _isOperationalExpanded = true;
  bool _isCustomerExpanded = true;
  bool _isFinancialExpanded = true;

  String _mapGoalToExcellence(Goal goal) {
    // Prefer explicit kpa if available
    final kpa = (goal.kpa ?? '').toLowerCase();
    if (kpa == 'operational') return 'Operational Excellence';
    if (kpa == 'customer') return 'Customer Excellence';
    if (kpa == 'financial') return 'Financial Excellence';
    // Temporary mapping based on category/title keywords
    final title = goal.title.toLowerCase();
    switch (goal.category) {
      case GoalCategory.work:
        if (title.contains('cost') ||
            title.contains('budget') ||
            title.contains('revenue') ||
            title.contains('profit')) {
          return 'Financial Excellence';
        }
        return 'Operational Excellence';
      case GoalCategory.learning:
        if (title.contains('customer') ||
            title.contains('nps') ||
            title.contains('csat')) {
          return 'Customer Excellence';
        }
        return 'Operational Excellence';
      case GoalCategory.health:
        return 'Operational Excellence';
      case GoalCategory.personal:
        if (title.contains('customer')) {
          return 'Customer Excellence';
        }
        if (title.contains('cost') ||
            title.contains('budget') ||
            title.contains('revenue')) {
          return 'Financial Excellence';
        }
        return 'Operational Excellence';
    }
  }

  Future<void> _quickIncrementSession(Goal goal) async {
    try {
      final next = (goal.progress + 10).clamp(0, 100);
      await DatabaseService.updateGoalProgress(goal.id, next);
      // Don't call setState - StreamBuilder will automatically update
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('Goal is not approved yet')
          ? 'You can only update progress once your manager has approved this goal.'
          : 'We could not update your progress right now. Please try again, and contact your manager if this keeps happening.';
      await _showCenterNotice(context, message);
    }
  }

  Future<void> _handleDeleteGoal(Goal goal) async {
    final userId = _auth.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      await _showCenterNotice(context, 'User not authenticated');
      return;
    }

    if (goal.approvalStatus != GoalApprovalStatus.approved) {
      // Direct delete flow
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F2840),
          title: const Text('Delete Goal', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Are you sure you want to delete this goal? This cannot be undone.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        _showLoadingDialog(context, message: 'Deleting goal...');
        await DatabaseService.deleteGoal(goalId: goal.id, requesterId: userId);
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          await _showCenterNotice(context, 'Goal deleted');
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          await _showCenterNotice(context, 'Failed to delete: $e');
        }
      }
    } else {
      // Request deletion flow
      final reasonController = TextEditingController();
      final submitted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F2840),
          title: const Text('Request Goal Deletion', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Provide a reason for deleting this approved goal. Your manager will need to approve this request.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Reason',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Submit'),
            ),
          ],
        ),
      );
      if (submitted != true) return;
      final reason = reasonController.text.trim();
      if (reason.isEmpty) {
        await _showCenterNotice(context, 'Please provide a reason');
        return;
      }
      try {
        _showLoadingDialog(context, message: 'Submitting request...');
        await DatabaseService.requestGoalDeletion(
          goalId: goal.id,
          reason: reason,
          requesterId: userId,
        );
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          await _showCenterNotice(
            context,
            'Deletion request submitted for manager approval',
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
          await _showCenterNotice(context, 'Failed to submit request: $e');
        }
      }
    }
  }

  Future<void> _markModuleComplete(Goal goal) async {
    try {
      final next = (goal.progress + 25).clamp(0, 100);
      await DatabaseService.updateGoalProgress(goal.id, next);
      // Don't call setState - StreamBuilder will automatically update
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().contains('Goal is not approved yet')
          ? 'You can only mark this module complete once your manager has approved the goal.'
          : 'We could not update your progress right now. Please try again, and contact your manager if this keeps happening.';
      await _showCenterNotice(context, message);
    }
  }

  Future<void> _attachEvidence(
    BuildContext context,
    Goal goal, {
    bool bypassExisting = false,
    bool replaceExisting = false,
  }) async {
    // If evidence already exists, show what's submitted with option to change unless bypassed
    if (goal.evidence.isNotEmpty && !bypassExisting) {
      _showEvidenceManagementDialog(context, goal);
      return;
    }

    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2840),
          title: const Text(
            'Add Evidence',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Paste link or short note',
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final picked = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                            withData: true,
                          );
                          if (picked != null && picked.files.isNotEmpty) {
                            final file = picked.files.first;
                            final bytes = file.bytes;
                            if (bytes != null) {
                              // Close the Add Evidence dialog before starting upload
                              if (ctx.mounted) {
                                Navigator.of(ctx).pop();
                              }
                              // Show a blocking loading dialog while uploading
                              _showLoadingDialog(
                                context,
                                message: 'Uploading file...',
                              );
                              try {
                                final cloudinaryUrl =
                                    await CloudinaryService.uploadFileUnsigned(
                                      bytes: bytes,
                                      fileName: file.name,
                                      goalId: goal.id,
                                    );
                                final fileInfo =
                                    '📎 File: ${file.name} (${(bytes.length / 1024).toStringAsFixed(1)} KB)';
                                if (replaceExisting) {
                                  await DatabaseService.clearGoalEvidence(
                                    goalId: goal.id,
                                  );
                                }
                                await DatabaseService.attachGoalEvidence(
                                  goalId: goal.id,
                                  evidence: [fileInfo, cloudinaryUrl],
                                );
                                if (mounted) {
                                  // Ensure loading dialog is fully closed (definite pop)
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  // Don't call setState - StreamBuilder will automatically update
                                  // Show success message
                                  await _showCenterNotice(
                                    context,
                                    'File uploaded successfully',
                                  );
                                }
                              } catch (cloudErr) {
                                // Close loading and show error
                                if (mounted) {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).pop();
                                  await _showCenterNotice(
                                    context,
                                    'Upload failed: $cloudErr',
                                  );
                                }
                              }
                            } else {
                              await _showCenterNotice(
                                ctx,
                                'Error: No file data available',
                              );
                            }
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            await _showCenterNotice(
                              ctx,
                              'Error picking file: $e',
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload file (PDF/Word/Image)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save note/link'),
            ),
          ],
        );
      },
    );
    if (result != null && result.isNotEmpty) {
      if (result != 'uploaded') {
        if (replaceExisting) {
          await DatabaseService.clearGoalEvidence(goalId: goal.id);
        }
        await DatabaseService.attachGoalEvidence(
          goalId: goal.id,
          evidence: [result],
        );
      }
      if (mounted) {
        // Don't call setState - StreamBuilder will automatically update
        await _showCenterNotice(context, 'Evidence added');
      }
    }
  }

  void _openEvidenceFromPdp(String evidence) {
    final isUrl =
        evidence.startsWith('http://') || evidence.startsWith('https://');

    if (isUrl) {
      final lower = evidence.toLowerCase();
      final isImage =
          lower.endsWith('.png') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.gif') ||
          lower.endsWith('.webp');
      final isPdf = lower.endsWith('.pdf');

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F2840),
          title: Text(
            isImage
                ? 'Evidence Image'
                : isPdf
                ? 'Evidence PDF'
                : 'Evidence Details',
            style: const TextStyle(color: Colors.white),
          ),
          content: isImage
              ? SizedBox(
                  width: 480,
                  height: 360,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      evidence,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Could not load image preview.',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              evidence,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.lightBlueAccent,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPdf)
                      const Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'PDF evidence file',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (isPdf) const SizedBox(height: 8),
                    SelectableText(
                      evidence,
                      style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    if (isPdf) const SizedBox(height: 8),
                    if (isPdf)
                      const Text(
                        'Use "Open PDF in new tab" to view this document in your browser.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                try {
                  web.window.open(evidence, '_blank');
                } catch (_) {
                  // On non-web platforms, just close the dialog
                  Navigator.of(ctx).pop();
                }
              },
              child: Text(
                isPdf ? 'Open PDF in new tab' : 'Open in new tab',
                style: const TextStyle(color: Colors.lightBlueAccent),
              ),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1F2840),
          title: const Text(
            'Evidence Details',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              evidence,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showEvidenceManagementDialog(BuildContext context, Goal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2840),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Evidence Submitted',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Evidence for: ${goal.title}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Submitted Evidence:',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...goal.evidence.map(
                    (evidence) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            evidence.startsWith('https://res.cloudinary.com/')
                                ? Icons.cloud_upload
                                : Icons.description,
                            color:
                                evidence.startsWith(
                                  'https://res.cloudinary.com/',
                                )
                                ? Colors.blue
                                : Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              evidence.startsWith('https://res.cloudinary.com/')
                                  ? '📁 Cloudinary File (Click to view)'
                                  : evidence,
                              style: TextStyle(
                                color:
                                    evidence.startsWith(
                                      'https://res.cloudinary.com/',
                                    )
                                    ? Colors.blue
                                    : Colors.white70,
                                fontSize: 12,
                                decoration:
                                    evidence.startsWith(
                                      'https://res.cloudinary.com/',
                                    )
                                    ? TextDecoration.underline
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'What would you like to do?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showChangeEvidenceDialog(context, goal);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
            child: const Text('Change Evidence'),
          ),
        ],
      ),
    );
  }

  void _showChangeEvidenceDialog(BuildContext context, Goal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F2840),
        title: const Text(
          'Change Evidence',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Are you sure you want to change the evidence for this goal?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Current Evidence:',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...goal.evidence.map(
                    (evidence) => Text(
                      '• ${evidence.length > 50 ? "${evidence.substring(0, 50)}..." : evidence}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              // Open add evidence dialog directly; existing evidence will be replaced on save
              _attachEvidence(
                context,
                goal,
                bypassExisting: true,
                replaceExisting: true,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Change Evidence'),
          ),
        ],
      ),
    );
  }

  // Ensure user's department is set; otherwise block submission and prompt to update profile
  Future<bool> _ensureDepartmentIsSet({int retryCount = 0}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Add retry logic for Firestore internal assertion failures
      if (retryCount > 0) {
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }

      final userDoc = await DatabaseService.getUserProfile(user.uid);
      final department = userDoc.department.trim();
      final hasDept =
          department.isNotEmpty && department.toLowerCase() != 'unknown';

      if (!hasDept) {
        if (!mounted) return false;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0E1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Department Required',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Your department information is missing. Please update your profile before submitting.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Navigate to settings where profile can be updated
                  if (mounted) {
                    Navigator.pushNamed(context, '/settings');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Go to Settings'),
              ),
            ],
          ),
        );
        return false;
      }
      return true;
    } catch (e) {
      // Retry up to 2 times for Firestore internal assertion failures
      final errorString = e.toString();
      if (errorString.contains('INTERNAL ASSERTION FAILED') && retryCount < 2) {
        // Retry with exponential backoff
        return _ensureDepartmentIsSet(retryCount: retryCount + 1);
      }

      // If we cannot validate after retries, show error and block submission
      if (mounted) {
        await _showCenterNotice(
          context,
          'Failed to load profile: $e\n\nPlease try again or contact support if this persists.',
        );
      }
      return false;
    }
  }

  Future<void> _requestManagerAcknowledgement(Goal goal) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          await _showCenterNotice(
            context,
            'Please sign in to request acknowledgement',
          );
        }
        return;
      }

      // Check if already submitted
      final alreadySubmitted = await AuditService.hasGoalBeenSubmittedForAudit(
        goal.id,
        user.uid,
      );
      if (alreadySubmitted) {
        if (mounted) {
          await _showCenterNotice(
            context,
            'This goal has already been submitted for acknowledgement',
          );
        }
        return;
      }

      // Only allow acknowledgement for approved goals
      if (goal.approvalStatus != GoalApprovalStatus.approved) {
        if (mounted) {
          await _showCenterNotice(
            context,
            'You can only request acknowledgement for approved goals',
          );
        }
        return;
      }

      // Ensure the user has a department set before allowing submission
      final proceed = await _ensureDepartmentIsSet();
      if (!proceed) {
        return; // User has been informed; do not proceed
      }

      // Submit to audit along with attached evidence so managers can review
      await AuditService.submitGoalForAudit(goal, goal.evidence);
      if (mounted) {
        await _showCenterNotice(context, 'Acknowledgement requested');
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().contains('already been submitted')
            ? 'This goal has already been submitted for acknowledgement'
            : 'Failed to request acknowledgement. Please try again.';
        await _showCenterNotice(context, errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevents popping if we handle it explicitly
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          Navigator.of(context).pushReplacementNamed('/employee_dashboard');
        }
      },
      child: AppComponents.backgroundWithImage(
        imagePath: 'assets/khono_bg.png',
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Personal Development Plan',
                style: AppTypography.heading2.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 20),
              _buildExcellenceArea(
                title: 'Operational Excellence',
                expanded: _isOperationalExpanded,
                onToggle: (v) => setState(() => _isOperationalExpanded = v),
              ),
              const SizedBox(height: 20),
              _buildExcellenceArea(
                title: 'Customer Excellence',
                expanded: _isCustomerExpanded,
                onToggle: (v) => setState(() => _isCustomerExpanded = v),
              ),
              const SizedBox(height: 20),
              _buildExcellenceArea(
                title: 'Financial Excellence',
                expanded: _isFinancialExpanded,
                onToggle: (v) => setState(() => _isFinancialExpanded = v),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExcellenceArea({
    required String title,
    required bool expanded,
    required ValueChanged<bool> onToggle,
  }) {
    return Material(
      // Moved Material widget here
      color: Colors.transparent, // Ensure it's transparent
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            ListTile(
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'Key Performance Area/Key Performance Indicator',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              trailing: Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white,
              ),
              onTap: () => onToggle(!expanded),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: _buildGoalsForExcellence(title),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsForExcellence(String excellence) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          );
        }
        final user = authSnap.data;
        if (user == null) {
          return const Text(
            'Please sign in',
            style: TextStyle(color: Colors.white),
          );
        }
        return StreamBuilder<List<Goal>>(
          stream: DatabaseService.getUserGoalsStream(user.uid).handleError((
            error,
          ) {
            // Silently handle errors to prevent unmount errors
            // The error will be caught by hasError check below
            return;
          }),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              );
            }

            // Handle errors gracefully
            if (snapshot.hasError) {
              final error = snapshot.error;
              final errorString = error.toString();

              // Check if it's a Firestore internal assertion failure
              if (errorString.contains('INTERNAL ASSERTION FAILED')) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.orange,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Temporary loading issue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please refresh the page or try again in a moment.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Trigger a rebuild by calling setState
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              // For other errors, show a generic error message
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Error loading goals',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try refreshing the page.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final goals = (snapshot.data ?? [])
                .where((g) => _mapGoalToExcellence(g) == excellence)
                .toList();
            if (goals.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'No goals yet',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            return Column(
              children: goals.map((goal) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                goal.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${goal.progress}%',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: (goal.progress.clamp(0, 100)) / 100.0,
                          backgroundColor: Colors.white12,
                          color: const Color(0xFFC10D00),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 12),

                        // Show attached evidence if any
                        if (goal.evidence.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A3441),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.attachment,
                                      color: Colors.green,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Attached Evidence (${goal.evidence.length})',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...goal.evidence.map((evidence) {
                                  final allEvidence = goal.evidence;
                                  final isDirectUrl =
                                      evidence.startsWith('http://') ||
                                      evidence.startsWith('https://');
                                  final isFileLabel = evidence.startsWith('📎');

                                  String targetEvidence = evidence;
                                  if (!isDirectUrl && isFileLabel) {
                                    // Try to find a matching URL evidence in the list
                                    final linkedUrl = allEvidence.firstWhere(
                                      (e) =>
                                          e.startsWith('http://') ||
                                          e.startsWith('https://'),
                                      orElse: () => evidence,
                                    );
                                    targetEvidence = linkedUrl;
                                  }

                                  final hasPreviewUrl =
                                      targetEvidence.startsWith('http://') ||
                                      targetEvidence.startsWith('https://');

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: InkWell(
                                      onTap: () =>
                                          _openEvidenceFromPdp(targetEvidence),
                                      child: Row(
                                        children: [
                                          Icon(
                                            hasPreviewUrl
                                                ? Icons.cloud_upload
                                                : Icons.description,
                                            color: hasPreviewUrl
                                                ? Colors.blue
                                                : Colors.white70,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              evidence,
                                              style: TextStyle(
                                                color: hasPreviewUrl
                                                    ? Colors.blue
                                                    : Colors.white70,
                                                fontSize: 12,
                                                decoration: hasPreviewUrl
                                                    ? TextDecoration.underline
                                                    : null,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (hasPreviewUrl)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.open_in_new,
                                                color: Colors.blue,
                                                size: 12,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () =>
                                                  _openEvidenceFromPdp(
                                                    targetEvidence,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _quickIncrementSession(goal),
                              icon: const Icon(Icons.add_task, size: 18),
                              label: const Text('+1 session'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _markModuleComplete(goal),
                              icon: const Icon(Icons.check_circle, size: 18),
                              label: const Text('Module complete'),
                              style:
                                  (goal.status == GoalStatus.completed ||
                                      goal.progress >= 100)
                                  ? OutlinedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: Colors.green,
                                      ),
                                    )
                                  : null,
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _handleDeleteGoal(goal),
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              label: const Text('Delete'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                bool isHovered = false;
                                return StatefulBuilder(
                                  builder: (context, localSetState) =>
                                      MouseRegion(
                                        onEnter: (_) {
                                          if (goal.evidence.isNotEmpty) {
                                            localSetState(() {
                                              isHovered = true;
                                            });
                                          }
                                        },
                                        onExit: (_) {
                                          if (goal.evidence.isNotEmpty) {
                                            localSetState(() {
                                              isHovered = false;
                                            });
                                          }
                                        },
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              goal.evidence.isNotEmpty
                                              ? _showChangeEvidenceDialog(
                                                  context,
                                                  goal,
                                                )
                                              : _attachEvidence(context, goal),
                                          icon: Icon(
                                            goal.evidence.isNotEmpty
                                                ? Icons.check_circle
                                                : Icons.attach_file,
                                            size: 18,
                                          ),
                                          label: Text(
                                            goal.evidence.isNotEmpty
                                                ? (isHovered
                                                      ? 'Change evidence'
                                                      : 'Evidence submitted')
                                                : 'Attach evidence',
                                          ),
                                          style: goal.evidence.isNotEmpty
                                              ? OutlinedButton.styleFrom(
                                                  backgroundColor: Colors.green
                                                      .withValues(alpha: 0.1),
                                                  foregroundColor: Colors.green,
                                                  side: const BorderSide(
                                                    color: Colors.green,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                );
                              },
                            ),
                            StreamBuilder<List<AuditEntry>>(
                              stream: AuditService.getEmployeeAuditEntriesStream()
                                  .handleError((error) {
                                    // Silently handle errors to prevent unmount errors
                                    return;
                                  }),
                              builder: (context, auditSnapshot) {
                                final hasAuditEntry =
                                    auditSnapshot.hasData &&
                                    auditSnapshot.data!.any(
                                      (entry) => entry.goalId == goal.id,
                                    );
                                final isApproved =
                                    goal.approvalStatus ==
                                    GoalApprovalStatus.approved;
                                final canRequest = isApproved && !hasAuditEntry;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: canRequest
                                          ? () =>
                                                _requestManagerAcknowledgement(
                                                  goal,
                                                )
                                          : null,
                                      icon: Icon(
                                        hasAuditEntry
                                            ? Icons.check_circle
                                            : (isApproved
                                                  ? Icons.verified_user
                                                  : Icons.lock_clock),
                                        size: 18,
                                      ),
                                      label: Text(
                                        hasAuditEntry
                                            ? 'Acknowledgement requested'
                                            : (isApproved
                                                  ? 'Request acknowledgement'
                                                  : 'Waiting for manager approval'),
                                      ),
                                      style: hasAuditEntry
                                          ? OutlinedButton.styleFrom(
                                              // ignore: deprecated_member_use
                                              backgroundColor: Colors.orange
                                                  .withValues(alpha: 0.1),
                                              foregroundColor: Colors.orange,
                                              side: const BorderSide(
                                                color: Colors.orange,
                                              ),
                                            )
                                          : null,
                                    ),
                                    if (!hasAuditEntry && !isApproved)
                                      const SizedBox(height: 4),
                                    if (!hasAuditEntry && !isApproved)
                                      const Text(
                                        'You can request acknowledgement once your manager approves this goal.',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
