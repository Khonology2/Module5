import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/audit_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdh/services/storage_service.dart';
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
        if (title.contains('cost') || title.contains('budget') || title.contains('revenue') || title.contains('profit')) {
          return 'Financial Excellence';
        }
        return 'Operational Excellence';
      case GoalCategory.learning:
        if (title.contains('customer') || title.contains('nps') || title.contains('csat')) {
          return 'Customer Excellence';
        }
        return 'Operational Excellence';
      case GoalCategory.health:
        return 'Operational Excellence';
      case GoalCategory.personal:
        if (title.contains('customer')) return 'Customer Excellence';
        if (title.contains('cost') || title.contains('budget') || title.contains('revenue')) return 'Financial Excellence';
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
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2840),
          title: const Text('Add Evidence', style: TextStyle(color: Colors.white)),
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
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
                          withData: true,
                        );
                        if (picked != null && picked.files.isNotEmpty) {
                          final file = picked.files.first;
                          final bytes = file.bytes;
                          if (bytes != null) {
                            final ext = (file.extension ?? '').toLowerCase();
                            String contentType = 'application/octet-stream';
                            if (ext == 'pdf') contentType = 'application/pdf';
                            if (ext == 'doc') contentType = 'application/msword';
                            if (ext == 'docx') contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
                            if (ext == 'png') contentType = 'image/png';
                            if (ext == 'jpg' || ext == 'jpeg') contentType = 'image/jpeg';

                            final url = await StorageService.uploadEvidence(
                              goalId: goal.id,
                              fileName: file.name,
                              bytes: bytes,
                              contentType: contentType,
                            );
                            if (ctx.mounted) {
                              await DatabaseService.attachGoalEvidence(goalId: goal.id, evidence: [url]);
                              Navigator.of(ctx).pop('uploaded');
                            }
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
        await DatabaseService.attachGoalEvidence(goalId: goal.id, evidence: [result]);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidence added')),
        );
      }
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
    return AppScaffold(
      title: 'My PDP',
      showAppBar: false,
      items: SidebarConfig.employeeItems,
      currentRouteName: '/my_pdp',
      onNavigate: (route) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        if (mounted) {
          navigator.pushNamedAndRemoveUntil('/sign_in', (route) => false);
        }
      },
      content: FocusScope(
        node: FocusScopeNode(),
        child: ClipRect(
          child: AppComponents.backgroundWithImage(
            imagePath: 'assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png',
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/employee_dashboard');
                      },
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text('Back to Portal', style: TextStyle(color: Colors.white)),
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
      ),
    );
  }

  Widget _buildExcellenceArea({
    required String title,
    required bool expanded,
    required ValueChanged<bool> onToggle,
  }) {
    return Material( // Moved Material widget here
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
          return const Text('Please sign in', style: TextStyle(color: Colors.white));
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
            child: Text('No goals yet', style: TextStyle(color: Colors.white70)),
          );
        }

        return Column(
          children: goals.map((goal) {
            return Card(
              color: const Color(0xFF26324F),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(goal.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Text('${goal.progress}%', style: const TextStyle(color: Colors.white70)),
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
                          style: (goal.status == GoalStatus.completed || goal.progress >= 100)
                              ? OutlinedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.green),
                                )
                              : null,
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _attachEvidence(context, goal),
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Attach evidence'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _requestManagerAcknowledgement(goal),
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
