// ignore_for_file: unnecessary_underscores, deprecated_member_use, use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/learning_assignment.dart';
import 'package:pdh/models/learning_tutorial.dart';
import 'package:pdh/services/learning_assignment_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/widgets/custom_logo_loader.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ManagerLearningAssignmentsScreen extends StatefulWidget {
  final bool embedded;

  const ManagerLearningAssignmentsScreen({super.key, this.embedded = false});

  @override
  State<ManagerLearningAssignmentsScreen> createState() =>
      _ManagerLearningAssignmentsScreenState();
}

class _ManagerLearningAssignmentsScreenState
    extends State<ManagerLearningAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  final _learningService = LearningAssignmentService.instance;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _durationController = TextEditingController();
  final _pointsController = TextEditingController(text: '10');
  final _notesController = TextEditingController();

  late TabController _tabController;
  String? _managerId;
  String? _selectedEmployeeId;
  String? _selectedTutorialId;
  DateTime? _assignDueDate;
  String _assignmentStatusFilter = 'all';
  bool _isSavingTutorial = false;
  bool _isAssigning = false;
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _managerId = AuthService().currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _durationController.dispose();
    _pointsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _bumpReload() => setState(() => _reloadToken++);

  Future<void> _showNotice(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DashboardChrome.cardFill,
        content: Text(
          message,
          style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.activeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTutorial() async {
    final managerId = _managerId;
    if (managerId == null) return;
    final title = _titleController.text.trim();
    final url = _urlController.text.trim();
    if (title.isEmpty || url.isEmpty) {
      await _showNotice('Title and Udemy URL are required.');
      return;
    }
    setState(() => _isSavingTutorial = true);
    try {
      final duration = int.tryParse(_durationController.text.trim());
      await _learningService.createTutorial(
        LearningTutorial(
          id: '',
          managerId: managerId,
          title: title,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          videoUrl: url,
          durationMinutes: duration,
        ),
      );
      _titleController.clear();
      _descriptionController.clear();
      _urlController.clear();
      _durationController.clear();
      _bumpReload();
      await _showNotice('Tutorial saved to your library.');
    } catch (e) {
      await _showNotice('Could not create tutorial: $e');
    } finally {
      if (mounted) setState(() => _isSavingTutorial = false);
    }
  }

  Future<void> _assignTutorial() async {
    final managerId = _managerId;
    if (managerId == null) return;
    if (_selectedEmployeeId == null || _selectedTutorialId == null) {
      await _showNotice('Select an employee and a tutorial.');
      return;
    }
    final due = _assignDueDate ?? DateTime.now().add(const Duration(days: 14));
    final points = int.tryParse(_pointsController.text.trim()) ?? 10;
    setState(() => _isAssigning = true);
    try {
      await _learningService.assignTutorialToEmployee(
        managerId: managerId,
        tutorialId: _selectedTutorialId!,
        employeeUserId: _selectedEmployeeId!,
        dueDate: due,
        points: points,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      _notesController.clear();
      _bumpReload();
      await _showNotice('Tutorial assigned. A learning goal and alert were created.');
    } catch (e) {
      await _showNotice('Assignment failed: $e');
    } finally {
      if (mounted) setState(() => _isAssigning = false);
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _assignDueDate ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _assignDueDate = picked);
  }

  int _columnsForWidth(double width) {
    if (width >= 920) return 4;
    if (width >= 640) return 2;
    return 1;
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DashboardChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardChrome.border),
      ),
      child: child,
    );
  }

  Widget _statTile(String title, String value, IconData icon) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.activeColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.heading2.copyWith(color: DashboardChrome.fg),
          ),
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: DashboardChrome.fg.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'completed':
        color = AppColors.successColor;
        break;
      case 'in_progress':
        color = AppColors.warningColor;
        break;
      case 'overdue':
        color = AppColors.activeColor;
        break;
      case 'cancelled':
        color = Colors.grey;
        break;
      default:
        color = AppColors.infoColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTypography.bodySmall.copyWith(
        color: DashboardChrome.fg.withValues(alpha: 0.7),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: DashboardChrome.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.activeColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final managerId = _managerId;
    if (managerId == null) {
      return const Center(child: CustomLogoLoader());
    }

    return ValueListenableBuilder<bool>(
      valueListenable: employeeDashboardLightModeNotifier,
      builder: (context, light, _) {
        return EmployeeDashboardThemeScope(
          light: light,
          child: AppScaffold(
            title: '',
            embedded: widget.embedded,
            items: const [],
            currentRouteName: '/manager_learning_assignments',
            onNavigate: (route) => Navigator.pushNamed(context, route),
            onLogout: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/sign_in', (_) => false);
              }
            },
            content: LayoutBuilder(
              builder: (context, constraints) {
                final cols = _columnsForWidth(constraints.maxWidth);
                final twoCol = constraints.maxWidth >= 920;

                return StreamBuilder<List<LearningTutorial>>(
                  key: ValueKey('tutorials_$_reloadToken'),
                  stream: backendPollingStream<List<LearningTutorial>>(
                    fetch: () => _learningService.listTutorials(managerId),
                    initialValue: const [],
                  ),
                  builder: (context, tutorialSnap) {
                    final tutorials = tutorialSnap.data ?? const [];
                    return StreamBuilder<List<LearningAssignment>>(
                      key: ValueKey('assignments_$_reloadToken'),
                      stream: backendPollingStream<List<LearningAssignment>>(
                        fetch: () =>
                            _learningService.listAssignments(managerId),
                        initialValue: const [],
                      ),
                      builder: (context, assignSnap) {
                        final assignments = assignSnap.data ?? const [];
                        final activeAssignments = assignments
                            .where((a) =>
                                a.effectiveStatus != 'completed' &&
                                a.effectiveStatus != 'cancelled')
                            .length;
                        final completedCount = assignments
                            .where((a) => a.effectiveStatus == 'completed')
                            .length;
                        final completedPct = assignments.isEmpty
                            ? 0
                            : ((completedCount / assignments.length) * 100)
                                .round();
                        final weekEnd = DateTime.now().add(const Duration(days: 7));
                        final dueThisWeek = assignments.where((a) {
                          final due = a.dueDate;
                          return due != null &&
                              due.isBefore(weekEnd) &&
                              a.effectiveStatus != 'completed';
                        }).length;

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _card(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Learning Assignments',
                                            style: AppTypography.heading2
                                                .copyWith(
                                              color: DashboardChrome.fg,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Create Udemy-style tutorials and assign them to your team. Each assignment creates a linked learning goal.',
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                              color: DashboardChrome.fg
                                                  .withValues(alpha: 0.85),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        _tabController.animateTo(1);
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.assignment_ind),
                                      label: const Text('Assign tutorial'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.activeColor,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              GridView.count(
                                crossAxisCount: cols,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 2.2,
                                children: [
                                  _statTile(
                                    'Total tutorials',
                                    '${tutorials.where((t) => t.isActive).length}',
                                    Icons.menu_book,
                                  ),
                                  _statTile(
                                    'Active assignments',
                                    '$activeAssignments',
                                    Icons.pending_actions,
                                  ),
                                  _statTile(
                                    'Completed',
                                    '$completedPct%',
                                    Icons.check_circle_outline,
                                  ),
                                  _statTile(
                                    'Due this week',
                                    '$dueThisWeek',
                                    Icons.event,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              if (twoCol)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildCreateTutorialCard()),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildQuickAssignCard(tutorials),
                                    ),
                                  ],
                                )
                              else ...[
                                _buildCreateTutorialCard(),
                                const SizedBox(height: 16),
                                _buildQuickAssignCard(tutorials),
                              ],
                              const SizedBox(height: AppSpacing.lg),
                              _card(
                                child: Column(
                                  children: [
                                    TabBar(
                                      controller: _tabController,
                                      labelColor: AppColors.activeColor,
                                      unselectedLabelColor: DashboardChrome.fg
                                          .withValues(alpha: 0.6),
                                      indicatorColor: AppColors.activeColor,
                                      tabs: const [
                                        Tab(text: 'Tutorial library'),
                                        Tab(text: 'Assignments'),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 420,
                                      child: TabBarView(
                                        controller: _tabController,
                                        children: [
                                          _buildTutorialLibrary(tutorials),
                                          _buildAssignmentsList(
                                            assignments,
                                            tutorials,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateTutorialCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create tutorial',
            style: AppTypography.heading3.copyWith(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: _fieldDecoration('Title'),
            style: TextStyle(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: _fieldDecoration('Udemy / video URL'),
            style: TextStyle(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 2,
            decoration: _fieldDecoration('Description (optional)'),
            style: TextStyle(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: _fieldDecoration('Duration (minutes, optional)'),
            style: TextStyle(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isSavingTutorial ? null : _createTutorial,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
              ),
              child: _isSavingTutorial
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save tutorial'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAssignCard(List<LearningTutorial> tutorials) {
    final activeTutorials =
        tutorials.where((t) => t.isActive).toList(growable: false);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick assign',
            style: AppTypography.heading3.copyWith(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<EmployeeData>>(
            stream: ManagerRealtimeService.getTeamDataStream(),
            builder: (context, snap) {
              final employees = snap.data ?? const <EmployeeData>[];
              return DropdownButtonFormField<String>(
                value: _selectedEmployeeId,
                decoration: _fieldDecoration('Employee'),
                dropdownColor: DashboardChrome.cardFill,
                style: TextStyle(color: DashboardChrome.fg),
                items: employees
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.profile.uid,
                        child: Text(
                          e.profile.displayName.isNotEmpty
                              ? e.profile.displayName
                              : e.profile.email,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedEmployeeId = v),
              );
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTutorialId,
            decoration: _fieldDecoration('Tutorial'),
            dropdownColor: DashboardChrome.cardFill,
            style: TextStyle(color: DashboardChrome.fg),
            items: activeTutorials
                .map(
                  (t) => DropdownMenuItem(
                    value: t.id,
                    child: Text(t.title, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedTutorialId = v),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _assignDueDate == null
                  ? 'Due date (default: 14 days)'
                  : 'Due: ${DateFormat.yMMMd().format(_assignDueDate!)}',
              style: AppTypography.bodyMedium.copyWith(
                color: DashboardChrome.fg,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              color: AppColors.activeColor,
              onPressed: _pickDueDate,
            ),
          ),
          TextField(
            controller: _pointsController,
            keyboardType: TextInputType.number,
            decoration: _fieldDecoration('Points'),
            style: TextStyle(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: _fieldDecoration('Note to employee (optional)'),
            style: TextStyle(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isAssigning ? null : _assignTutorial,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
              ),
              child: _isAssigning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Assign'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialLibrary(List<LearningTutorial> tutorials) {
    final active = tutorials.where((t) => t.isActive).toList();
    if (active.isEmpty) {
      return Center(
        child: Text(
          'No tutorials yet. Create one above.',
          style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.only(top: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: active.length,
      itemBuilder: (context, index) {
        final t = active[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: DashboardChrome.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.title,
                style: AppTypography.bodyLarge.copyWith(
                  color: DashboardChrome.fg,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (t.durationMinutes != null)
                Text(
                  '${t.durationMinutes} min',
                  style: AppTypography.bodySmall.copyWith(
                    color: DashboardChrome.fg.withValues(alpha: 0.7),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await launchUrlString(t.videoUrl);
                },
                child: const Text('Open URL'),
              ),
              TextButton(
                onPressed: () => _archiveTutorial(t),
                child: const Text('Archive'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _archiveTutorial(LearningTutorial tutorial) async {
    try {
      await _learningService.updateTutorial(tutorial.id, {'status': 'archived'});
      _bumpReload();
    } catch (e) {
      await _showNotice('Could not archive: $e');
    }
  }

  Widget _buildAssignmentsList(
    List<LearningAssignment> assignments,
    List<LearningTutorial> tutorials,
  ) {
    final tutorialTitles = {
      for (final t in tutorials) t.id: t.title,
    };

    var filtered = assignments;
    if (_assignmentStatusFilter != 'all') {
      filtered = assignments
          .where((a) => a.effectiveStatus == _assignmentStatusFilter)
          .toList();
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final status in ['all', 'assigned', 'in_progress', 'completed', 'overdue'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    selected: _assignmentStatusFilter == status,
                    onSelected: (_) =>
                        setState(() => _assignmentStatusFilter = status),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No assignments match this filter.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: DashboardChrome.fg,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final a = filtered[index];
                    final due = a.dueDate;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: DashboardChrome.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.title,
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: DashboardChrome.fg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  tutorialTitles[a.tutorialId] ?? a.tutorialId,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: DashboardChrome.fg.withValues(alpha: 0.7),
                                  ),
                                ),
                                if (due != null)
                                  Text(
                                    'Due ${DateFormat.yMMMd().format(due)}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: DashboardChrome.fg.withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _statusChip(a.effectiveStatus),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Future<void> launchUrlString(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
