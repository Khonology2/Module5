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
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/learning_assignment_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
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
  bool _dashboardLoading = true;
  String? _dashboardError;
  List<LearningTutorial> _tutorials = [];
  List<LearningAssignment> _assignments = [];
  List<EmployeeData> _teamEmployees = [];
  bool _teamLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _managerId = AuthService().currentUser?.uid;
    _loadDashboard();
    _loadTeamEmployees();
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

  Future<void> _loadDashboard() async {
    final managerId = _managerId;
    if (managerId == null) return;
    if (mounted) {
      setState(() {
        _dashboardLoading = true;
        _dashboardError = null;
      });
    }
    try {
      final data = await _learningService.loadManagerDashboard(managerId);
      if (!mounted) return;
      setState(() {
        _tutorials = data.tutorials;
        _assignments = data.assignments;
        _dashboardLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dashboardError = e.toString();
        _dashboardLoading = false;
      });
    }
  }

  Future<void> _loadTeamEmployees() async {
    if (mounted) setState(() => _teamLoading = true);
    try {
      final employees = await ManagerRealtimeService.getTeamDataOnce();
      if (!mounted) return;
      setState(() {
        _teamEmployees = employees;
        _teamLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _teamLoading = false);
    }
  }

  int? _parseDurationMinutes(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final direct = int.tryParse(t);
    if (direct != null) return direct;
    final parts = t.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) return h * 60 + m;
    }
    if (parts.length == 3) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final s = int.tryParse(parts[2]);
      if (h != null && m != null) {
        final totalSeconds = h * 3600 + m * 60 + (s ?? 0);
        return (totalSeconds / 60).ceil();
      }
    }
    return null;
  }

  String? _normalizeVideoUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return null;
    if (url.startsWith('//')) {
      url = 'https:$url';
    } else if (!url.contains('://')) {
      if (url.startsWith('/')) {
        url = 'https://www.udemy.com$url';
      } else {
        url = 'https://$url';
      }
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return null;
    return uri.toString();
  }

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
    final url = _normalizeVideoUrl(_urlController.text);
    if (title.isEmpty || url == null) {
      await _showNotice(
        'Title and a full Udemy URL are required (include https://...).',
      );
      return;
    }
    setState(() => _isSavingTutorial = true);
    try {
      final duration = _parseDurationMinutes(_durationController.text);
      final created = await _learningService.createTutorial(
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
      if (mounted) {
        setState(() {
          _tutorials = [created, ..._tutorials];
        });
      }
      await _showNotice('Tutorial saved to your library.');
    } on BackendAuthException catch (e) {
      final msg = e.code == 'timeout'
          ? 'The server took too long to respond. Please wait a moment and try again.'
          : e.message;
      await _showNotice('Could not create tutorial: $msg');
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
      final created = await _learningService.assignTutorialToEmployee(
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
      if (mounted) {
        setState(() {
          _assignments = [created, ..._assignments];
        });
      }
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

  int _topStatsColumnsForWidth(double width) {
    if (width >= 920) return 4;
    if (width >= 640) return 2;
    return 1;
  }

  Color _dashboardCardFill() {
    return DashboardChrome.light
        ? const Color(0x99FFFFFF)
        : const Color(0x993D3F40);
  }

  Color _dashboardCardBorder() {
    return DashboardChrome.light
        ? const Color(0x1E000000)
        : Colors.white.withValues(alpha: 0.12);
  }

  Widget _card({required Widget child, double? minHeight}) {
    return Container(
      width: double.infinity,
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _dashboardCardFill(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dashboardCardBorder()),
      ),
      child: child,
    );
  }

  Widget _assetIcon(String assetPath, {required double size}) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(width: size, height: size);
      },
    );
  }

  Widget _topStatTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required String assetPath,
    required Color accent,
  }) {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: DashboardChrome.fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: DashboardChrome.fg,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: AppTypography.heading2.copyWith(
                    color: DashboardChrome.fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _assetIcon(assetPath, size: 74),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatsGrid({
    required int columns,
    required int totalTutorials,
    required int activeAssignments,
    required int completedPct,
    required int dueThisWeek,
  }) {
    final tiles = <Widget>[
      _topStatTile(
        title: 'Total Tutorials',
        subtitle: 'Active tutorials in your library.',
        value: '$totalTutorials',
        icon: Icons.menu_book_outlined,
        assetPath: 'assets/manager_dashboard/1.png',
        accent: AppColors.activeColor,
      ),
      _topStatTile(
        title: 'Active Assignments',
        subtitle: 'Assignments in progress across the team.',
        value: '$activeAssignments',
        icon: Icons.pending_actions,
        assetPath: 'assets/manager_dashboard/2.png',
        accent: AppColors.successColor,
      ),
      _topStatTile(
        title: 'Completed',
        subtitle: 'Share of assignments marked complete.',
        value: '$completedPct%',
        icon: Icons.check_circle_outline,
        assetPath: 'assets/manager_dashboard/6.png',
        accent: AppColors.successColor,
      ),
      _topStatTile(
        title: 'Due This Week',
        subtitle: 'Open assignments due in the next 7 days.',
        value: '$dueThisWeek',
        icon: Icons.event,
        assetPath: 'assets/manager_dashboard/4.png',
        accent: AppColors.dangerColor,
      ),
    ];

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: columns == 1 ? 3.4 : 2.9,
      children: tiles,
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

  Color _fieldFillColor() {
    return DashboardChrome.light
        ? const Color(0xFFF5F5F5)
        : DashboardChrome.darkSurface;
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: _fieldFillColor(),
      labelStyle: AppTypography.bodySmall.copyWith(
        color: DashboardChrome.fg.withValues(alpha: 0.7),
      ),
      hintStyle: AppTypography.bodySmall.copyWith(
        color: DashboardChrome.fg.withValues(alpha: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: _dashboardCardBorder()),
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
                final rawW = constraints.maxWidth;
                final layoutW = rawW.isFinite
                    ? rawW
                    : MediaQuery.sizeOf(context).width;
                final horizontalPad = AppSpacing.xxl * 2;
                final width =
                    (layoutW - horizontalPad).clamp(0.0, double.infinity);
                final statsColumns = _topStatsColumnsForWidth(width);
                final twoCol = width >= 920;

                if (_dashboardLoading && _tutorials.isEmpty) {
                  return const Center(child: CustomLogoLoader());
                }
                if (_dashboardError != null && _tutorials.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Could not load learning data.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: DashboardChrome.fg,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadDashboard,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final tutorials = _tutorials;
                final assignments = _assignments;
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
                    : ((completedCount / assignments.length) * 100).round();
                final weekEnd = DateTime.now().add(const Duration(days: 7));
                final dueThisWeek = assignments.where((a) {
                  final due = a.dueDate;
                  return due != null &&
                      due.isBefore(weekEnd) &&
                      a.effectiveStatus != 'completed';
                }).length;

                return RefreshIndicator(
                  color: AppColors.activeColor,
                  onRefresh: () async {
                    await Future.wait([
                      _loadDashboard(),
                      _loadTeamEmployees(),
                    ]);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      0,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopStatsGrid(
                          columns: statsColumns,
                          totalTutorials:
                              tutorials.where((t) => t.isActive).length,
                          activeAssignments: activeAssignments,
                          completedPct: completedPct,
                          dueThisWeek: dueThisWeek,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _tabController.animateTo(1);
                              setState(() {});
                            },
                            icon: const Icon(Icons.assignment_ind),
                            label: const Text('Assign tutorial'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.activeColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                          ),
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
                  ),
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
            decoration: _fieldDecoration(
              'Duration (minutes or H:MM:SS, optional)',
            ),
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
          _teamLoading && _teamEmployees.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : DropdownButtonFormField<String>(
                  value: _selectedEmployeeId,
                  decoration: _fieldDecoration('Employee'),
                  dropdownColor: DashboardChrome.cardFill,
                  iconEnabledColor: DashboardChrome.fg,
                  style: TextStyle(color: DashboardChrome.fg),
                  items: _teamEmployees
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
                ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedTutorialId,
            decoration: _fieldDecoration('Tutorial'),
            dropdownColor: DashboardChrome.cardFill,
            iconEnabledColor: DashboardChrome.fg,
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
      if (mounted) {
        setState(() {
          _tutorials = _tutorials
              .map(
                (t) => t.id == tutorial.id
                    ? LearningTutorial(
                        id: t.id,
                        managerId: t.managerId,
                        title: t.title,
                        description: t.description,
                        videoUrl: t.videoUrl,
                        provider: t.provider,
                        durationMinutes: t.durationMinutes,
                        thumbnailUrl: t.thumbnailUrl,
                        status: 'archived',
                        createdAt: t.createdAt,
                        updatedAt: t.updatedAt,
                      )
                    : t,
              )
              .toList(growable: false);
        });
      }
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
