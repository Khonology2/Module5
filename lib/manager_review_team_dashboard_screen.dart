// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdh/manager_employee_detail_screen.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/audit_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/one_on_one_meeting_service.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/one_on_one_meeting.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

class ManagerReviewTeamDashboardScreen extends StatefulWidget {
  /// When true, admin is viewing; show managers only (no employees).
  final bool forAdminOversight;
  /// When set with [forAdminOversight], show data for this manager only.
  final String? selectedManagerId;

  const ManagerReviewTeamDashboardScreen({
    super.key,
    this.forAdminOversight = false,
    this.selectedManagerId,
  });

  @override
  State<ManagerReviewTeamDashboardScreen> createState() =>
      _ManagerReviewTeamDashboardScreenState();
}

class _ManagerReviewTeamDashboardScreenState
    extends State<ManagerReviewTeamDashboardScreen> {
  final TimeFilter _selectedTimeFilter = TimeFilter.month;
  String? _selectedDepartment;

  late Stream<List<EmployeeData>> _employeesStream;
  List<EmployeeData> _lastEmployees = const [];

  final TextEditingController _employeeSearchController =
      TextEditingController();
  Timer? _employeeSearchDebounce;
  String _employeeSearchQuery = '';

  // Optional deep-link from manager alerts: open the 1:1 sheet for a specific meeting.
  String? _initialEmployeeId;
  String? _initialMeetingId;
  bool _initialMeetingHandled = false;

  /// When set, only employees matching this KPI filter are shown (from dashboard drill-down).
  String? _statusFilter;
  bool _routeFilterApplied = false;

  @override
  void initState() {
    super.initState();
    _rebuildStreams();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final employeeId = args['employeeId']?.toString().trim();
      final meetingId = args['meetingId']?.toString().trim();
      if (employeeId != null && employeeId.isNotEmpty && !_initialMeetingHandled) {
        _initialEmployeeId = employeeId;
        if (meetingId != null && meetingId.isNotEmpty) {
          _initialMeetingId = meetingId;
        }
      }
      if (!_routeFilterApplied) {
        final statusFilter = args['statusFilter']?.toString().trim();
        if (statusFilter != null && statusFilter.isNotEmpty) {
          _statusFilter = statusFilter;
          _routeFilterApplied = true;
        }
      }
    }
  }

  void _maybeOpenInitialMeeting(List<EmployeeData> employees) {
    if (_initialMeetingHandled) return;
    final employeeId = _initialEmployeeId;
    if (employeeId == null || employeeId.isEmpty) return;

    final match = employees.where((e) => e.profile.uid == employeeId).toList();
    if (match.isEmpty) return;

    _initialMeetingHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scheduleOneOnOne(match.first, meetingId: _initialMeetingId);
    });
  }

  void _rebuildStreams() {
    // IMPORTANT: keep the stream instance stable.
    // Creating new streams during build (especially inside nested StreamBuilders)
    // causes unsubscribe/resubscribe flicker where employees "show then disappear".
    if (widget.forAdminOversight) {
      _employeesStream = ManagerRealtimeService.getManagersDataStreamForAdmin(
        timeFilter: _selectedTimeFilter,
        selectedManagerId: widget.selectedManagerId,
      );
    } else {
      _employeesStream = ManagerRealtimeService.getTeamDataStream(
        department: _selectedDepartment,
        timeFilter: _selectedTimeFilter,
      );
    }
  }

  @override
  void dispose() {
    _employeeSearchDebounce?.cancel();
    _employeeSearchController.dispose();
    super.dispose();
  }

  void _onEmployeeSearchChanged(String raw) {
    // Rebuild immediately to keep suffix icon (clear button) in sync with input.
    if (mounted) setState(() {});

    _employeeSearchDebounce?.cancel();
    _employeeSearchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _employeeSearchQuery = raw.trim().toLowerCase();
      });
    });
  }

  List<EmployeeData> _filterEmployees(List<EmployeeData> employees) {
    final q = _employeeSearchQuery.trim();
    if (q.isEmpty) return employees;

    final terms = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return employees;

    return employees.where((e) {
      final name = e.profile.displayName.toLowerCase();
      final email = e.profile.email.toLowerCase();
      final haystack = '$name $email';
      return terms.every(haystack.contains);
    }).toList();
  }

  /// Applies the KPI drill-down filter (from dashboard). Returns [employees] unchanged if [_statusFilter] is null.
  List<EmployeeData> _filterByStatus(List<EmployeeData> employees) {
    final filter = _statusFilter;
    if (filter == null || filter.isEmpty) return employees;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    switch (filter) {
      case 'inactive':
        return employees
            .where((e) => e.status == EmployeeStatus.inactive)
            .toList();
      case 'onTrack':
        return employees
            .where((e) => e.status == EmployeeStatus.onTrack)
            .toList();
      case 'atRisk':
        return employees
            .where((e) => e.status == EmployeeStatus.atRisk)
            .toList();
      case 'overdue':
        return employees
            .where((e) => e.status == EmployeeStatus.overdue)
            .toList();
      case 'active7d':
        return employees
            .where((e) => e.lastActivity.isAfter(sevenDaysAgo))
            .toList();
      case 'activeToday':
        return employees
            .where((e) => e.lastActivity.isAfter(today))
            .toList();
      default:
        return employees;
    }
  }

  String? _statusFilterLabel() {
    switch (_statusFilter) {
      case 'inactive':
        return 'Inactive';
      case 'onTrack':
        return 'On Track';
      case 'atRisk':
        return 'At Risk';
      case 'overdue':
        return 'Overdue';
      case 'active7d':
        return 'Active (7d)';
      case 'activeToday':
        return 'Active Today';
      default:
        return null;
    }
  }

  List<TeamInsight> _computeInsights(List<EmployeeData> employees) {
    final insights = <TeamInsight>[];
    final now = DateTime.now();

    for (final employee in employees) {
      if (employee.overdueGoalsCount > 0) {
        insights.add(
          TeamInsight(
            title: 'Overdue Goals Detected',
            description:
                '${employee.profile.displayName} has ${employee.overdueGoalsCount} overdue goal${employee.overdueGoalsCount > 1 ? 's' : ''}.',
            employeeName: employee.profile.displayName,
            actionRequired:
                'Schedule 1:1 meeting to discuss blockers and provide support',
            priority: InsightPriority.urgent,
            createdAt: now,
          ),
        );
      }

      if (employee.avgProgress < 30 && employee.goals.isNotEmpty) {
        insights.add(
          TeamInsight(
            title: 'Low Progress Alert',
            description:
                '${employee.profile.displayName} has average goal progress of ${employee.avgProgress.toStringAsFixed(1)}%.',
            employeeName: employee.profile.displayName,
            actionRequired:
                'Send motivational nudge or offer additional resources',
            priority: InsightPriority.high,
            createdAt: now,
          ),
        );
      }

      final daysSinceActivity = now.difference(employee.lastActivity).inDays;
      if (daysSinceActivity > 7) {
        insights.add(
          TeamInsight(
            title: 'Employee Inactive',
            description:
                '${employee.profile.displayName} has been inactive for $daysSinceActivity days.',
            employeeName: employee.profile.displayName,
            actionRequired: 'Reach out to check on engagement and well-being',
            priority: InsightPriority.medium,
            createdAt: now,
          ),
        );
      }

      if (employee.avgProgress > 80 && employee.completedGoalsCount > 2) {
        insights.add(
          TeamInsight(
            title: 'High Performer',
            description:
                '${employee.profile.displayName} is excelling with ${employee.avgProgress.toStringAsFixed(1)}% average progress.',
            employeeName: employee.profile.displayName,
            actionRequired: 'Consider offering stretch goals or recognition',
            priority: InsightPriority.low,
            createdAt: now,
          ),
        );
      }
    }

    insights.sort((a, b) {
      final priorityOrder = {
        InsightPriority.urgent: 0,
        InsightPriority.high: 1,
        InsightPriority.medium: 2,
        InsightPriority.low: 3,
      };
      return priorityOrder[a.priority]!.compareTo(priorityOrder[b.priority]!);
    });

    return insights.take(10).toList();
  }

  Widget _buildEmployeeSearchBar({
    required int totalCount,
    required int filteredCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _employeeSearchController,
            onChanged: _onEmployeeSearchChanged,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search employees by name or email...',
              hintStyle: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textSecondary,
              ),
              suffixIcon: _employeeSearchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close),
                      color: AppColors.textSecondary,
                      onPressed: () {
                        _employeeSearchController.clear();
                        _employeeSearchDebounce?.cancel();
                        setState(() {
                          _employeeSearchQuery = '';
                        });
                      },
                    ),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.activeColor),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filteredCount == totalCount
                ? '$totalCount employee${totalCount == 1 ? '' : 's'}'
                : '$filteredCount of $totalCount employees',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Text(
          _statusFilter != null
              ? 'No employees match the current filter.'
              : 'No employees match your search.',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip() {
    final label = _statusFilterLabel();
    if (label == null) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _statusFilter = null),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.activeColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.activeColor.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Showing: $label',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.close,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: DashboardChrome.fg,
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const SizedBox.shrink(),
        centerTitle: false,
        actions: const [],
      ),
      body: DashboardThemedBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 400
                ? 12.0
                : constraints.maxWidth < 700
                    ? 16.0
                    : 24.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                MediaQuery.of(context).padding.top + kToolbarHeight + 16.0,
                horizontalPadding,
                16.0,
              ),
              child: StreamBuilder<List<EmployeeData>>(
                stream: _employeesStream,
                builder: (context, employeesSnapshot) {
                        final incoming = employeesSnapshot.data;
                        final hasPlaceholderBatch =
                            incoming != null &&
                            incoming.isNotEmpty &&
                            incoming.every((e) => e.isPlaceholder);

                        // Keep last known-good list so the UI doesn't "flash empty"
                        // when the stream re-emits (or rebuilds) during first entry.
                        //
                        // Also: ignore the initial placeholder emission (employees with
                        // empty goals/metrics) and wait for the enriched payload.
                        if (employeesSnapshot.hasData &&
                            (employeesSnapshot.data?.isNotEmpty ?? false) &&
                            !hasPlaceholderBatch) {
                          _lastEmployees = employeesSnapshot.data!;
                        }

                        if (employeesSnapshot.hasError &&
                            _lastEmployees.isEmpty) {
                          return _buildErrorState(employeesSnapshot.error!);
                        }

                        // If we only have placeholders and no enriched cache yet,
                        // still show employees immediately (for "Last active"),
                        // but render goal/metrics sections as "Loading..." in each card.
                        final employees = hasPlaceholderBatch
                            ? incoming
                            : (employeesSnapshot.data ?? _lastEmployees);

                        if (employees.isEmpty) {
                          if (employeesSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return _buildLoadingState();
                          }
                          return _buildEmptyState();
                        }

                        final insights =
                            hasPlaceholderBatch ? const <TeamInsight>[] : _computeInsights(employees);

                        // Deep-link from alerts (if provided) once we have a real employee list.
                        if (!hasPlaceholderBatch) {
                          _maybeOpenInitialMeeting(employees);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 20),

                            const Text(
                              'Team Overview',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildEmployeeSearchBar(
                              totalCount: employees.length,
                              filteredCount: _filterByStatus(
                                    _filterEmployees(employees),
                                  ).length,
                            ),
                            if (_statusFilter != null) ...[
                              const SizedBox(height: 8),
                              _buildStatusFilterChip(),
                            ],
                            const SizedBox(height: 12),
                            if (_filterByStatus(
                                  _filterEmployees(employees),
                                ).isNotEmpty)
                              _buildRealTimeEmployeeList(
                                _filterByStatus(
                                  _filterEmployees(employees),
                                ),
                              )
                            else
                              _buildNoSearchResults(),

                            const SizedBox(height: 20),
                            _buildAIManagerInsights(
                              insights,
                              isLoading: hasPlaceholderBatch,
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                  },
                ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const SizedBox.shrink();
  }

  Widget _buildAIManagerInsights(
    List<TeamInsight> insights, {
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_outline, color: Color(0xFFC10D00), size: 20),
              SizedBox(width: 8),
              Text(
                'AI Manager Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (isLoading)
            _buildInsightBullet('Analyzing team performance and goals...')
          else if (insights.isEmpty)
            _buildInsightBullet(
              'All team members are performing well. No immediate action needed.',
            )
          else
            ...insights
                .take(3)
                .map(
                  (insight) => Column(
                    children: [
                      _buildInsightItem(insight),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
          const SizedBox(height: 15),
          if (!isLoading)
            GestureDetector(
              onTap: () {
                _showFullInsights(insights);
              },
              child: const Text(
                'View Full Analysis',
                style: TextStyle(
                  color: Color(0xFFC10D00),
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightItem(TeamInsight insight) {
    Color priorityColor;
    IconData priorityIcon;

    switch (insight.priority) {
      case InsightPriority.urgent:
        priorityColor = Colors.redAccent;
        priorityIcon = Icons.priority_high;
        break;
      case InsightPriority.high:
        priorityColor = Colors.orange;
        priorityIcon = Icons.warning;
        break;
      case InsightPriority.medium:
        priorityColor = Colors.yellow;
        priorityIcon = Icons.info;
        break;
      case InsightPriority.low:
        priorityColor = Colors.green;
        priorityIcon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: priorityColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(priorityIcon, color: priorityColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  insight.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                if (insight.actionRequired.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Action: ${insight.actionRequired}',
                    style: TextStyle(color: priorityColor, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeEmployeeList(List<EmployeeData> employees) {
    if (employees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: Text(
            'No employees found in this department',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Sort employees by activity (most active first) and then by points (most points first)
    final sortedEmployees = List<EmployeeData>.from(employees);
    sortedEmployees.sort((a, b) {
      // Primary sort: by last activity (most recent first)
      final activityComparison = b.lastActivity.compareTo(a.lastActivity);
      if (activityComparison != 0) {
        return activityComparison;
      }
      // Secondary sort: by total points (most points first)
      return b.totalPoints.compareTo(a.totalPoints);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sortedEmployees.map(
          (employee) => Column(
            children: [
              _buildEmployeeCard(employee),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(EmployeeData employee) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (employee.status) {
      case EmployeeStatus.onTrack:
        statusColor = AppColors.successColor;
        statusIcon = Icons.check_circle;
        statusText = 'On Track';
        break;
      case EmployeeStatus.atRisk:
        statusColor = AppColors.warningColor;
        statusIcon = Icons.warning;
        statusText = 'At Risk';
        break;
      case EmployeeStatus.overdue:
        statusColor = AppColors.dangerColor;
        statusIcon = Icons.error_outline;
        statusText = 'Overdue';
        break;
      case EmployeeStatus.inactive:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.pause_circle_outline;
        statusText = 'Inactive';
        break;
    }

    final approvedGoals = employee.goals
        .where((g) => g.approvalStatus == GoalApprovalStatus.approved)
        .toList();

    // Determine active status
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // Avoid misleading "activity" chips while we're still showing placeholders.
    bool isActiveToday =
        !employee.isPlaceholder && employee.lastActivity.isAfter(today);
    bool isActiveThisWeek =
        !employee.isPlaceholder && employee.lastActivity.isAfter(sevenDaysAgo);

    Color activeStatusColor;
    IconData activeStatusIcon;
    String activeStatusText;

    if (isActiveToday) {
      activeStatusColor = AppColors.successColor;
      activeStatusIcon = Icons.circle;
      activeStatusText = 'Active Today';
    } else if (isActiveThisWeek) {
      activeStatusColor = AppColors.warningColor;
      activeStatusIcon = Icons.circle;
      activeStatusText = 'Active This Week';
    } else {
      activeStatusColor = AppColors.textSecondary;
      activeStatusIcon = Icons.circle_outlined;
      activeStatusText = 'Inactive';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Text(
                  employee.profile.displayName.isNotEmpty
                      ? employee.profile.displayName[0].toUpperCase()
                      : '?',
                  style: AppTypography.bodyMedium.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.profile.displayName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      employee.profile.jobTitle.isNotEmpty
                          ? employee.profile.jobTitle
                          : employee.profile.department,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: AppTypography.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: activeStatusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activeStatusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activeStatusIcon,
                          color: activeStatusColor,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          activeStatusText,
                          style: AppTypography.bodySmall.copyWith(
                            color: activeStatusColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildEmployeeMetricChip(
                  icon: Icons.track_changes,
                  iconWidget: const ImageIcon(
                    AssetImage('assets/Approved_Tick/Approved_White.png'),
                  ),
                  label: 'Active Goals',
                  value: employee.isPlaceholder
                      ? '...'
                      : employee.goals
                            .where(
                              (g) =>
                                  g.approvalStatus ==
                                      GoalApprovalStatus.approved &&
                                  !_isGoalCompleted(g),
                            )
                            .length
                            .toString(),
                  color: AppColors.activeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEmployeeMetricChip(
                  icon: Icons.check_circle_outline,
                  iconWidget: const ImageIcon(
                    AssetImage('assets/Process_Flows_Automation/points2.png'),
                  ),
                  label: 'Completed',
                  value: employee.isPlaceholder
                      ? '...'
                      : employee.completedGoalsCount.toString(),
                  color: AppColors.successColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEmployeeMetricChip(
                  icon: Icons.access_time,
                  iconWidget: const ImageIcon(
                    AssetImage(
                      'assets/Time_Allocation_Approval/Approval_Whie.png',
                    ),
                  ),
                  label: 'Progress',
                  value: employee.isPlaceholder
                      ? '...'
                      : '${employee.avgProgress.toStringAsFixed(1)}%',
                  color: employee.avgProgress >= 70
                      ? AppColors.successColor
                      : employee.avgProgress >= 40
                      ? AppColors.warningColor
                      : AppColors.dangerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show last activity information
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppColors.textSecondary, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Last active: ${employee.isPlaceholder ? 'Loading...' : _formatLastActivity(employee.lastActivity)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${employee.weeklyActivityCount} activities this week',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (approvedGoals.isNotEmpty) ...[
            Text(
              'Goals',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...approvedGoals
                .take(3)
                .map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildGoalRow(goal),
                  ),
                ),
            if (approvedGoals.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${approvedGoals.length - 3} more goals',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.activeColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ] else if (employee.isPlaceholder) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_top,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading goals...',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No approved goals yet',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Management Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showSendNudgeDialog(employee: employee),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Send Nudge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _scheduleOneOnOne(employee),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('1:1'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _giveRecognition(employee),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Kudos'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _viewActivities(employee),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Activity'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ManagerEmployeeDetailScreen(employee: employee),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.activeColor,
                    side: BorderSide(color: AppColors.activeColor),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('View Details'),
                ),
              ),
            ],
          ),
          // Upcoming Deadlines Section
          if (_getUpcomingDeadlines(employee).isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildUpcomingDeadlinesSection(employee),
          ],
          // Completed Goals Review Section
          if (employee.completedGoalsCount > 0) ...[
            const SizedBox(height: 12),
            _buildCompletedGoalsReviewSection(employee),
          ],
        ],
      ),
    );
  }

  List<Goal> _getUpcomingDeadlines(EmployeeData employee) {
    final now = DateTime.now();
    final next14Days = now.add(const Duration(days: 14));

    return employee.goals.where((goal) {
      if (_isGoalCompleted(goal)) return false;
      return goal.targetDate.isAfter(now) &&
          goal.targetDate.isBefore(next14Days);
    }).toList()..sort((a, b) => a.targetDate.compareTo(b.targetDate));
  }

  Widget _buildUpcomingDeadlinesSection(EmployeeData employee) {
    final upcomingGoals = _getUpcomingDeadlines(employee);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Text(
                'Upcoming Deadlines',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...upcomingGoals.take(3).map((goal) {
            final daysUntil = goal.targetDate.difference(DateTime.now()).inDays;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    daysUntil == 0
                        ? 'Due today'
                        : '$daysUntil day${daysUntil == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: daysUntil <= 3 ? Colors.red : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (upcomingGoals.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${upcomingGoals.length - 3} more',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedGoalsReviewSection(EmployeeData employee) {
    final completedGoals = employee.goals.where(_isGoalCompleted).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Completed Goals (${completedGoals.length})',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _reviewCompletedGoals(employee),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Review & Acknowledge',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _reviewCompletedGoals(EmployeeData employee) {
    final completedGoals = employee.goals.where(_isGoalCompleted).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0x80000000),
        title: Text(
          'Review Completed Goals - ${employee.profile.displayName}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: completedGoals.isEmpty
              ? const Center(
                  child: Text(
                    'No completed goals to review',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: completedGoals.length,
                  itemBuilder: (context, index) {
                    final goal = completedGoals[index];
                    return _buildCompletedGoalReviewItem(goal, employee);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedGoalReviewItem(Goal goal, EmployeeData employee) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.check_circle, color: Colors.green, size: 20),
            ],
          ),
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              goal.description,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _viewGoalNotes(goal, employee),
                  icon: const Icon(Icons.note_outlined, size: 16),
                  label: const Text('Check Notes'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _acknowledgeGoal(goal, employee),
                icon: const Icon(Icons.thumb_up, size: 16),
                label: const Text('Acknowledge'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _viewGoalNotes(Goal goal, EmployeeData employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0x80000000),
        title: Text(
          'Goal Notes: ${goal.title}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (goal.description.isNotEmpty) ...[
                const Text(
                  'Description:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  goal.description,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
              ],
              if (goal.evidence.isNotEmpty) ...[
                const Text(
                  'Evidence:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                ...goal.evidence.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $e',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ] else
                const Text(
                  'No additional notes or evidence available.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  void _acknowledgeGoal(Goal goal, EmployeeData employee) async {
    try {
      if (!_isGoalCompleted(goal)) {
        await _showCenterNotice(
          context,
          'Only completed goals can be acknowledged.',
        );
        return;
      }

      await AuditService.acknowledgeCompletedGoal(
        goal: goal,
        employeeId: employee.profile.uid,
        employeeName: employee.profile.displayName,
        employeeDepartment: employee.profile.department,
      );
      Navigator.pop(context); // Close review dialog
      await _showCenterNotice(
        context,
        'Goal "${goal.title}" acknowledged for ${employee.profile.displayName}',
      );
    } catch (e) {
      await _showCenterNotice(context, 'Error acknowledging goal: $e');
    }
  }

  Widget _buildEmployeeMetricChip({
    required IconData icon,
    Widget? iconWidget,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          iconWidget ?? Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow(Goal goal) {
    Color priorityColor = _getPriorityColor(goal.priority);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  goal.title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: LinearProgressIndicator(
                  value: goal.progress / 100.0,
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(priorityColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${goal.progress}%',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return AppColors.dangerColor;
      case GoalPriority.medium:
        return AppColors.warningColor;
      case GoalPriority.low:
        return AppColors.successColor;
    }
  }

  bool _isGoalCompleted(Goal goal) {
    return goal.status == GoalStatus.completed || goal.progress >= 100;
  }

  String _formatLastActivity(DateTime? lastActivity) {
    if (lastActivity == null) return 'Never';

    try {
      final now = DateTime.now();

      // Check if the date is valid (not in the future or too far in the past)
      if (lastActivity.year < 2000) return 'Unknown';
      if (lastActivity.isAfter(now)) {
        // Allow small clock skew (server timestamp slightly ahead of device).
        if (lastActivity.difference(now) <= const Duration(minutes: 10)) {
          return 'Just now';
        }
        return 'Unknown';
      }

      final difference = now.difference(lastActivity);

      if (difference.inDays > 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      // Handle any unexpected errors when formatting the date
      return 'Unknown';
    }
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFC10D00)),
            SizedBox(height: 12),
            Text(
              'Loading team data...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  void _showSendNudgeDialog({EmployeeData? employee, String? presetMessage}) {
    showDialog(
      context: context,
      builder: (context) => _NudgeDialog(
        employee: employee,
        presetMessage: presetMessage,
        onSendNudge: (employeeId, goalId, message) =>
            _sendNudgeToEmployee(employeeId, goalId, message),
      ),
    );
  }

  void _sendNudgeToEmployee(
    String employeeId,
    String goalId,
    String message,
  ) async {
    try {
      await ManagerRealtimeService.sendNudgeToEmployee(
        employeeId: employeeId,
        goalId: goalId,
        message: message,
        recipientActionRoute: widget.forAdminOversight
            ? '/manager_gw_menu_alerts'
            : null,
      );
      if (mounted) {
        await _showCenterNotice(context, 'Nudge sent successfully!');
      }
    } catch (e) {
      if (mounted) {
        await _showCenterNotice(context, 'Error sending nudge: $e');
      }
    }
  }

  void _scheduleOneOnOne(EmployeeData employee, {String? meetingId}) async {
    final managerId = FirebaseAuth.instance.currentUser?.uid;
    // If a meetingId was provided via deep-link, prefer that exact meeting.
    // Otherwise fall back to the latest active thread between manager+employee.
    OneOnOneMeeting? existing;
    final requestedMeetingId = meetingId?.trim();
    if (requestedMeetingId != null && requestedMeetingId.isNotEmpty) {
      try {
        final m = await OneOnOneMeetingService.getMeeting(requestedMeetingId);
        final sameEmployee = m?.employeeId == employee.profile.uid;
        final sameManager = managerId == null || m?.managerId == managerId;
        if (m != null && sameEmployee && sameManager) {
          existing = m;
        }
      } catch (_) {
        // Fall through to latest-between lookup
      }
    }

    if (existing == null && managerId != null) {
      existing = await OneOnOneMeetingService.getLatestBetween(
          managerId: managerId, employeeId: employee.profile.uid);
    }

    final agendaController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1:1 with ${employee.profile.displayName}',
                style: AppTypography.heading3.copyWith(color: Colors.white),
              ),
              if (existing != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Current status: ${existing.status.name} (waiting on: ${existing.waitingOn.name})',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                ),
                if (existing.proposedStartDateTime != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    existing.proposedEndDateTime != null
                        ? 'Time: ${existing.proposedStartDateTime!.toLocal().toString()} - ${existing.proposedEndDateTime!.toLocal().toString()}'
                        : 'Time: ${existing.proposedStartDateTime!.toLocal().toString()}',
                    style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                  ),
                ],
              ],
              const SizedBox(height: 8),
              Text(
                'Start with intent. You can request first, or propose a time.',
                style: AppTypography.bodySmall.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: agendaController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Message / agenda (optional)',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      if (existing != null &&
                          existing.status != OneOnOneMeetingStatus.cancelled &&
                          existing.status != OneOnOneMeetingStatus.accepted) {
                        await _showCenterNotice(
                          context,
                          'There is already an active 1:1 thread for this employee. Propose a time instead.',
                        );
                        return;
                      }
                      await ManagerRealtimeService.requestOneOnOne(
                        employeeId: employee.profile.uid,
                        agenda: agendaController.text.trim(),
                        recipientActionRoute: widget.forAdminOversight
                            ? '/manager_gw_menu_alerts'
                            : null,
                      );
                      if (!mounted) return;
                      Navigator.pop(sheetContext);
                      await _showCenterNotice(
                        context,
                        'Request sent to ${employee.profile.displayName}.',
                      );
                    } catch (e) {
                      if (!mounted) return;
                      await _showCenterNotice(
                        context,
                        'Error requesting 1:1: $e',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Request a 1:1'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    try {
                      final now = DateTime.now();
                      final pickedDate = await showDatePicker(
                        context: sheetContext,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                        initialDate: now.add(const Duration(days: 1)),
                      );
                      if (pickedDate == null) return;

                      final pickedStartTime = await showTimePicker(
                        context: sheetContext,
                        initialTime: TimeOfDay.fromDateTime(
                          now.add(const Duration(hours: 1)),
                        ),
                      );
                      if (pickedStartTime == null) return;

                      final proposedStart = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedStartTime.hour,
                        pickedStartTime.minute,
                      );

                      final suggestedEnd = proposedStart.add(
                        const Duration(minutes: 60),
                      );
                      final pickedEndTime = await showTimePicker(
                        context: sheetContext,
                        initialTime: TimeOfDay.fromDateTime(suggestedEnd),
                      );
                      if (pickedEndTime == null) return;

                      final proposedEnd = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedEndTime.hour,
                        pickedEndTime.minute,
                      );

                      if (!proposedEnd.isAfter(proposedStart)) {
                        await _showCenterNotice(
                          context,
                          'End time must be after start time.',
                        );
                        return;
                      }

                      final agenda = agendaController.text.trim();
                      // If there is an existing active thread, update it; otherwise create a new proposal.
                      final canUpdateExisting = existing != null &&
                          existing.status != OneOnOneMeetingStatus.cancelled &&
                          existing.status != OneOnOneMeetingStatus.accepted;

                      if (canUpdateExisting) {
                        await OneOnOneMeetingService.managerProposeNewTime(
                          meetingId: existing.meetingId,
                          proposedStartDateTime: proposedStart,
                          proposedEndDateTime: proposedEnd,
                          agenda: agenda.isEmpty ? null : agenda,
                        );
                        if (managerId != null) {
                          await AlertService.createOneOnOneProposedAlert(
                            employeeId: employee.profile.uid,
                            managerId: managerId,
                            meetingId: existing.meetingId,
                            proposedStartDateTime: proposedStart,
                            proposedEndDateTime: proposedEnd,
                            agenda: agenda.isEmpty ? null : agenda,
                            actionRouteOverride: widget.forAdminOversight
                                ? '/manager_gw_menu_alerts'
                                : null,
                          );
                        }
                      } else {
                        await ManagerRealtimeService.scheduleMeeting(
                          employeeId: employee.profile.uid,
                          scheduledStartTime: proposedStart,
                          scheduledEndTime: proposedEnd,
                          purpose: agenda.isEmpty ? '1:1' : agenda,
                          recipientActionRoute: widget.forAdminOversight
                              ? '/manager_gw_menu_alerts'
                              : null,
                        );
                      }

                      if (!mounted) return;
                      Navigator.pop(sheetContext);
                      await _showCenterNotice(
                        context,
                        'Time proposed to ${employee.profile.displayName}.',
                      );
                    } catch (e) {
                      if (!mounted) return;
                      await _showCenterNotice(
                        context,
                        'Error proposing time: $e',
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Propose a time'),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() => agendaController.dispose());
  }

  void _giveRecognition(EmployeeData employee) {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0x80000000),
        title: Text(
          'Give Recognition to ${employee.profile.displayName}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Recognition reason...',
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final typedReason = reasonController.text.trim();
                        await ManagerRealtimeService.giveRecognition(
                          employeeId: employee.profile.uid,
                          reason: typedReason.isNotEmpty
                              ? typedReason
                              : 'Outstanding performance this week!',
                          points: 50,
                          recipientActionRoute: widget.forAdminOversight
                              ? '/manager_gw_menu_alerts'
                              : null,
                        );
                        Navigator.pop(dialogContext); // Use dialogContext
                        if (!mounted) return;
                        await _showCenterNotice(
                          context,
                          'Recognition sent to ${employee.profile.displayName}',
                        );
                      } catch (e) {
                        if (!mounted) return; // Add this line back
                        await _showCenterNotice(
                          context,
                          'Error giving recognition: $e',
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Send Kudos'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // Use dialogContext
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    ).whenComplete(() => reasonController.dispose());
  }

  void _viewActivities(EmployeeData employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _EmployeeActivityScreen(employee: employee),
      ),
    );
  }

  void _showFullInsights(List<TeamInsight> insights) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0x80000000),
        title: const Text(
          'Full Team Insights',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: insights.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildInsightItem(insights[index]),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Icon(Icons.people_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 12),
          const Text(
            'No Team Members Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This could mean:\n• No employees in your department\n• You don\'t have manager role\n• Database connection issues',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/landing', (r) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC10D00),
            ),
            child: const Text('Check Authentication'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.withValues(alpha: 0.7),
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Error Loading Team Data',
            style: TextStyle(
              color: Colors.red,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Error: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmployeeActivityScreen extends StatelessWidget {
  final EmployeeData employee;

  const _EmployeeActivityScreen({required this.employee});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${employee.profile.displayName} - Activity',
          style: AppTypography.heading2.copyWith(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/khono_bg.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          StreamBuilder<List<EmployeeActivity>>(
            stream: ManagerRealtimeService.getEmployeeActivitiesStream(
              employeeId: employee.profile.uid,
              limit: 50,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC10D00)),
                );
              }

              final activities = snapshot.data!;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 80), // Space for AppBar
                    _buildActivitySummary(),
                    const SizedBox(height: 20),
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: activities.isEmpty
                          ? const Center(
                              child: Text(
                                'No recent activity',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ListView.builder(
                              itemCount: activities.length,
                              itemBuilder: (context, index) {
                                return _buildActivityItem(activities[index]);
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryTile(
              'Weekly Activities',
              '${employee.weeklyActivityCount}',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryTile(
              'Engagement Score',
              '${employee.engagementScore.toStringAsFixed(0)}%',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildSummaryTile(
              'Motivation Level',
              employee.motivationLevel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActivityItem(EmployeeActivity activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x80000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFC10D00),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.activityType.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          Text(
            _formatTimestamp(activity.timestamp),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// Nudge Dialog Widget
class _NudgeDialog extends StatefulWidget {
  final EmployeeData? employee;
  final String? presetMessage;
  final Function(String employeeId, String goalId, String message) onSendNudge;

  const _NudgeDialog({
    this.employee,
    this.presetMessage,
    required this.onSendNudge,
  });

  @override
  State<_NudgeDialog> createState() => _NudgeDialogState();
}

class _NudgeDialogState extends State<_NudgeDialog> {
  late TextEditingController _messageController;
  Goal? _selectedGoal;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: widget.presetMessage ?? '',
    );
    if (widget.employee?.goals.isNotEmpty == true) {
      _selectedGoal = widget.employee!.goals.first;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0x80000000),
      title: Text(
        widget.employee != null
            ? 'Send Nudge to ${widget.employee!.profile.displayName}'
            : 'Send Nudge',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.employee != null &&
                widget.employee!.goals.isNotEmpty) ...[
              const Text(
                'Related Goal:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: DropdownButton<Goal>(
                  value: _selectedGoal,
                  underline: const SizedBox(),
                  isExpanded: true,
                  dropdownColor: Colors.black.withValues(alpha: 0.9),
                  hint: const Text(
                    'Select Goal',
                    style: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  onChanged: (goal) => setState(() => _selectedGoal = goal),
                  items: widget.employee!.goals.map((goal) {
                    return DropdownMenuItem<Goal>(
                      value: goal,
                      child: Text(
                        goal.title,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Quick Presets:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetButton(
                  'Check Progress',
                  Icons.trending_up,
                  'Hope you\'re doing well! How is your progress on your current goals?',
                ),
                _buildPresetButton(
                  'Need Help?',
                  Icons.support_agent,
                  'Is there anything I can help you with regarding your goals or work?',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Message:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter your nudge message or use a preset above...',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFC10D00)),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _sendNudge,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC10D00),
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }

  Widget _buildPresetButton(String label, IconData icon, String message) {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() {
          _messageController.text = message;
        });
      },
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFC10D00),
        side: BorderSide(color: const Color(0xFFC10D00).withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  void _sendNudge() {
    if (_messageController.text.trim().isEmpty) {
      showDialog<void>(
        context: context,
        barrierColor: Colors.black54,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0x80000000),
            content: const Text(
              'Please enter a message',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          );
        },
      );
      return;
    }

    if (widget.employee == null) {
      return;
    }

    final goalId = _selectedGoal?.id ?? 'general';
    widget.onSendNudge(
      widget.employee!.profile.uid,
      goalId,
      _messageController.text.trim(),
    );
    Navigator.pop(context);
  }
}
