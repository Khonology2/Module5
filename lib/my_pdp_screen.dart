// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/audit_service.dart';
import 'package:pdh/services/evidence_upload_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdh/services/cloudinary_service.dart';
// Drawer removed in favor of persistent sidebar

class MyPdpScreen extends StatefulWidget {
  const MyPdpScreen({super.key});

  @override
  State<MyPdpScreen> createState() => _MyPdpScreenState();
}

class _MyPdpScreenState extends State<MyPdpScreen> {
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
    final next = (goal.progress + 10).clamp(0, 100);
    await DatabaseService.updateGoalProgress(goal.id, next);
  }

  Future<void> _markModuleComplete(Goal goal) async {
    final next = (goal.progress + 25).clamp(0, 100);
    await DatabaseService.updateGoalProgress(goal.id, next);
  }

  Future<void> _attachEvidence(BuildContext context, Goal goal) async {
    // If evidence already exists, show what's submitted with option to change
    if (goal.evidence.isNotEmpty) {
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
                          print('Starting file picker...');
                        final picked = await FilePicker.platform.pickFiles(
                            type: FileType.any,
                          withData: true,
                        );
                          
                          print('File picker result: ${picked?.files.length} files');
                          
                        if (picked != null && picked.files.isNotEmpty) {
                          final file = picked.files.first;
                            print('Selected file: ${file.name}, size: ${file.bytes?.length} bytes');
                            
                          final bytes = file.bytes;
                          if (bytes != null) {
                              // Show loading
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Uploading file...'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              
                              print('Starting Cloudinary upload...');
                              try {
                                // Upload to Cloudinary
                                final cloudinaryUrl = await CloudinaryService.uploadFileUnsigned(
                                  bytes: bytes,
                                  fileName: file.name,
                                  goalId: goal.id,
                                );
                                
                                print('Cloudinary upload successful: $cloudinaryUrl');
                                
                                // Store the Cloudinary URL as evidence
                                final fileInfo = '📎 File: ${file.name} (${(bytes.length / 1024).toStringAsFixed(1)} KB) - Uploaded to Cloudinary';
                                
                                await DatabaseService.attachGoalEvidence(
                              goalId: goal.id,
                                  evidence: [fileInfo, cloudinaryUrl],
                                );
                                
                                print('File uploaded and attached to goal: $fileInfo');
                                
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('File uploaded successfully to Cloudinary!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.of(ctx).pop('uploaded');
                                  // Refresh the screen to show the new evidence
                                  setState(() {});
                                }
                              } catch (error) {
                                print('Error uploading to Cloudinary: $error');
                                
                                // Fallback: store file info without upload
                                try {
                                  final fileInfo = '📎 File: ${file.name} (${(bytes.length / 1024).toStringAsFixed(1)} KB) - Upload failed, but file was selected';
                                  
                            await DatabaseService.attachGoalEvidence(
                              goalId: goal.id,
                                    evidence: [fileInfo],
                            );
                                  
                            if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('File selected but upload failed. File info saved: ${file.name}'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                              Navigator.of(ctx).pop('uploaded');
                                    setState(() {});
                                  }
                                } catch (fallbackError) {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $error'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            } else {
                              print('No file bytes available');
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Error: No file data available'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            print('No files selected');
                          }
                        } catch (e) {
                          print('Error during file upload: $e');
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Error uploading file: $e'),
                                backgroundColor: Colors.red,
                              ),
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
        await DatabaseService.attachGoalEvidence(
          goalId: goal.id,
          evidence: [result],
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Evidence added')));
        // Refresh the screen to show the new evidence
        setState(() {});
      }
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
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
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
                  ...goal.evidence.map((evidence) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          evidence.startsWith('https://res.cloudinary.com/') 
                              ? Icons.cloud_upload 
                              : Icons.description,
                          color: evidence.startsWith('https://res.cloudinary.com/') 
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
                              color: evidence.startsWith('https://res.cloudinary.com/') 
                                  ? Colors.blue 
                                  : Colors.white70,
                              fontSize: 12,
                              decoration: evidence.startsWith('https://res.cloudinary.com/') 
                                  ? TextDecoration.underline 
                                  : null,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'What would you like to do?',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
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
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                  ...goal.evidence.map((evidence) => Text(
                    '• ${evidence.length > 50 ? "${evidence.substring(0, 50)}..." : evidence}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  )),
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
              // Clear existing evidence
              await DatabaseService.clearGoalEvidence(goalId: goal.id);
              // Refresh the screen
              setState(() {});
              // Open new evidence dialog
              _attachEvidence(context, goal);
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

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _requestManagerAcknowledgement(Goal goal) async {
    // Submit to audit with any existing evidence field if present; here we just let user add a note quickly
    await AuditService.submitGoalForAudit(goal, const []);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acknowledgement requested')),
      );
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
      child: FocusScope(
        node: FocusScopeNode(), // Create a new FocusScopeNode
        child: AppComponents.backgroundWithImage(
          imagePath:
              'assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0), // Adjust padding as needed
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back to portal button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pushReplacementNamed('/employee_dashboard');
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text(
                      'Back to Portal',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                Text(
                  'My Personal Development Plan',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
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
          color: const Color(0xFF1F2840), // App's card background color
          borderRadius: BorderRadius.circular(10),
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
          stream: DatabaseService.getUserGoalsStream(user.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
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
                return Card(
                  color: const Color(0xFF26324F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
                              border: Border.all(color: Colors.green.withOpacity(0.3)),
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
                                ...goal.evidence.map((evidence) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: InkWell(
                                    onTap: () {
                                      // If it's a Cloudinary URL, open it
                                      if (evidence.startsWith('https://res.cloudinary.com/')) {
                                        // You can implement opening the URL in a browser
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('File URL: $evidence'),
                                            duration: const Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          evidence.startsWith('https://res.cloudinary.com/') 
                                              ? Icons.cloud_upload 
                                              : Icons.description,
                                          color: evidence.startsWith('https://res.cloudinary.com/') 
                                              ? Colors.blue 
                                              : Colors.white70,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            evidence.startsWith('https://res.cloudinary.com/') 
                                                ? '📁 Cloudinary File (Click to view URL)'
                                                : evidence,
                                            style: TextStyle(
                                              color: evidence.startsWith('https://res.cloudinary.com/') 
                                                  ? Colors.blue 
                                                  : Colors.white70,
                                              fontSize: 12,
                                              decoration: evidence.startsWith('https://res.cloudinary.com/') 
                                                  ? TextDecoration.underline 
                                                  : null,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (evidence.startsWith('https://res.cloudinary.com/'))
                                          const Icon(
                                            Icons.open_in_new,
                                            color: Colors.blue,
                                            size: 12,
                                          ),
                                      ],
                                    ),
                                  ),
                                )),
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
                              onPressed: () => _attachEvidence(context, goal),
                              icon: Icon(
                                goal.evidence.isNotEmpty ? Icons.check_circle : Icons.attach_file, 
                                size: 18
                              ),
                              label: Text(
                                goal.evidence.isNotEmpty ? 'Evidence submitted' : 'Attach evidence'
                              ),
                              style: goal.evidence.isNotEmpty 
                                  ? OutlinedButton.styleFrom(
                                      backgroundColor: Colors.green.withOpacity(0.1),
                                      foregroundColor: Colors.green,
                                      side: const BorderSide(color: Colors.green),
                                    )
                                  : null,
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _requestManagerAcknowledgement(goal),
                              icon: const Icon(Icons.verified_user, size: 18),
                              label: const Text('Request acknowledgement'),
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
