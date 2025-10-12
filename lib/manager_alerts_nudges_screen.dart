import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/models/alert.dart';
import 'package:pdh/models/goal.dart';

class ManagerAlertsNudgesScreen extends StatefulWidget {
  final bool embedded;
  
  const ManagerAlertsNudgesScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<ManagerAlertsNudgesScreen> createState() => _ManagerAlertsNudgesScreenState();
}

class _ManagerAlertsNudgesScreenState extends State<ManagerAlertsNudgesScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  AlertPriority? _selectedPriority;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Team Alerts & Nudges',
      showAppBar: false,
      embedded: widget.embedded,
      items: SidebarConfig.getItemsForRole('manager'),
      currentRouteName: '/manager_alerts_nudges',
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
          navigator.pushNamedAndRemoveUntil(
            '/sign_in',
            (route) => false,
          );
        }
      },
      content: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundColor,
              AppColors.backgroundColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Team Alerts & Nudges',
                          style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showSendNudgeDialog(),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Send Nudge'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.activeColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildStatsRow(),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.elevatedBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.activeColor,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Team Alerts', icon: Icon(Icons.notifications, size: 20)),
                  Tab(text: 'Send Nudges', icon: Icon(Icons.message_outlined, size: 20)),
                  Tab(text: 'Analytics', icon: Icon(Icons.analytics_outlined, size: 20)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTeamAlertsTab(),
                  _buildSendNudgesTab(),
                  _buildAnalyticsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<List<EmployeeData>>(
      stream: ManagerRealtimeService.getTeamDataStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }

        final employees = snapshot.data ?? [];
        final totalAlerts = employees.fold<int>(0, (sum, emp) => sum + emp.recentAlerts.length);
        final urgentAlerts = employees.fold<int>(0, (sum, emp) => 
          sum + emp.recentAlerts.where((a) => a.priority == AlertPriority.urgent).length);
        final overdueGoals = employees.fold<int>(0, (sum, emp) => sum + emp.overdueGoalsCount);

        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Alerts',
                totalAlerts.toString(),
                AppColors.activeColor,
                Icons.notifications,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildStatCard(
                'Urgent',
                urgentAlerts.toString(),
                AppColors.dangerColor,
                Icons.priority_high,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildStatCard(
                'Overdue Goals',
                overdueGoals.toString(),
                AppColors.warningColor,
                Icons.schedule,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _buildStatCard(
                'Team Members',
                employees.length.toString(),
                AppColors.successColor,
                Icons.people_outline,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamAlertsTab() {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterRow(),
          const SizedBox(height: AppSpacing.lg),
          StreamBuilder<List<EmployeeData>>(
            stream: ManagerRealtimeService.getTeamDataStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              final employees = snapshot.data ?? [];
              final allAlerts = <Alert>[];
              
              for (final employee in employees) {
                allAlerts.addAll(employee.recentAlerts);
              }

              final filteredAlerts = _filterAlerts(allAlerts);

              if (filteredAlerts.isEmpty) {
                return _buildEmptyAlertsState();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Team Alerts (${filteredAlerts.length})',
                        style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
                      ),
                      if (filteredAlerts.any((alert) => !alert.isRead))
                        TextButton(
                          onPressed: () => _markAllAlertsAsRead(filteredAlerts),
                          child: Text(
                            'Mark All Read',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.activeColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...filteredAlerts.map((alert) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _buildTeamAlertCard(alert, employees),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search alerts...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
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
                borderSide: BorderSide(color: AppColors.activeColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.elevatedBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: DropdownButton<AlertPriority?>(
            value: _selectedPriority,
            underline: const SizedBox(),
            hint: Text('Priority', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
            onChanged: (priority) => setState(() => _selectedPriority = priority),
            items: [
              DropdownMenuItem(value: null, child: Text('All Priorities')),
              ...AlertPriority.values.map((priority) => 
                DropdownMenuItem(value: priority, child: Text(priority.name.toUpperCase())),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamAlertCard(Alert alert, List<EmployeeData> employees) {
    final employee = employees.firstWhere((emp) => 
      emp.recentAlerts.any((a) => a.id == alert.id),
      orElse: () => employees.first);
    final alertColor = _getAlertColor(alert.priority);
    final alertIcon = _getAlertIcon(alert.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert.isRead ? AppColors.borderColor : alertColor.withValues(alpha: 0.3),
          width: alert.isRead ? 1 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: alertColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(alertIcon, color: alertColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!alert.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.activeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.activeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 6,
                                backgroundColor: alertColor.withValues(alpha: 0.1),
                                child: Text(
                                  employee.profile.displayName.isNotEmpty 
                                      ? employee.profile.displayName[0].toUpperCase()
                                      : '?',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: alertColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                employee.profile.displayName,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _getTimeAgo(alert.createdAt),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: alertColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            alert.priority.name.toUpperCase(),
                            style: AppTypography.bodySmall.copyWith(
                              color: alertColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (alert.actionText != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAlertAction(alert, employee),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alertColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(alert.actionText!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _markAlertAsRead(alert.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: AppColors.borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Mark Read'),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showSendNudgeDialog(employee: employee),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Nudge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSendNudgesTab() {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Send Team Nudges',
            style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          StreamBuilder<List<EmployeeData>>(
            stream: ManagerRealtimeService.getTeamDataStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              final employees = snapshot.data ?? [];
              final filteredEmployees = _filterEmployees(employees);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search team members...',
                            prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
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
                              borderSide: BorderSide(color: AppColors.activeColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      ElevatedButton.icon(
                        onPressed: () => _showBulkNudgeDialog(employees),
                        icon: const Icon(Icons.group, size: 18),
                        label: const Text('Bulk Nudge'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warningColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (filteredEmployees.isEmpty)
                    _buildNoEmployeesState()
                  else
                    ...filteredEmployees.map((employee) => 
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _buildEmployeeNudgeCard(employee),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeNudgeCard(EmployeeData employee) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getStatusColor(employee.status).withValues(alpha: 0.1),
                child: Text(
                  employee.profile.displayName.isNotEmpty 
                      ? employee.profile.displayName[0].toUpperCase()
                      : '?',
                  style: AppTypography.bodyMedium.copyWith(
                    color: _getStatusColor(employee.status),
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
                      '${employee.goals.where((g) => g.status == GoalStatus.inProgress).length} active goals • ${employee.avgProgress.toStringAsFixed(1)}% progress',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(employee.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(employee.status).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getStatusIcon(employee.status), color: _getStatusColor(employee.status), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _getStatusText(employee.status),
                      style: AppTypography.bodySmall.copyWith(
                        color: _getStatusColor(employee.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildQuickNudgeButtons(employee),
        ],
      ),
    );
  }

  Widget _buildQuickNudgeButtons(EmployeeData employee) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Nudges:',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _buildQuickNudgeButton(
              'Check Progress',
              Icons.trending_up,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage: 'Hope you\'re doing well! How is your progress on your current goals?',
              ),
            ),
            _buildQuickNudgeButton(
              'Need Help?',
              Icons.support_agent,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage: 'Is there anything I can help you with regarding your goals or work?',
              ),
            ),
            _buildQuickNudgeButton(
              'Great Work!',
              Icons.celebration,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage: 'Great work on your recent progress! Keep it up!',
              ),
            ),
            _buildQuickNudgeButton(
              'Schedule Chat',
              Icons.chat,
              () => _showSendNudgeDialog(
                employee: employee,
                presetMessage: 'Let\'s catch up about your goals and any challenges you might be facing.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickNudgeButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(text, style: AppTypography.bodySmall),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.activeColor.withValues(alpha: 0.1),
        foregroundColor: AppColors.activeColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nudge Analytics',
            style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Coming Soon',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.elevatedBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Analytics Dashboard',
                  style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track nudge effectiveness, response rates, and team engagement patterns.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAlertsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
       children: [
         Icon(
           Icons.notifications_off,
           size: 48,
           color: AppColors.textSecondary,
         ),
         const SizedBox(height: 16),
         Text(
           'No Team Alerts',
           style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
         ),
         const SizedBox(height: 8),
         Text(
           'Your team doesn\'t have any alerts right now.',
           style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
           textAlign: TextAlign.center,
         ),
       ],
     ),
   );
 }

 Widget _buildNoEmployeesState() {
   return Container(
     padding: const EdgeInsets.all(32),
     decoration: BoxDecoration(
       color: AppColors.elevatedBackground,
       borderRadius: BorderRadius.circular(12),
       border: Border.all(color: AppColors.borderColor),
     ),
     child: Column(
       children: [
         Icon(
           Icons.people_outline,
           size: 48,
           color: AppColors.textSecondary,
         ),
         const SizedBox(height: 16),
         Text(
           'No Team Members',
           style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
         ),
         const SizedBox(height: 8),
         Text(
           'You don\'t have any team members to send nudges to.',
           style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
           textAlign: TextAlign.center,
         ),
      ],
     ),
   );
 }

 Widget _buildErrorState(String error) {
   return Container(
     padding: const EdgeInsets.all(32),
     decoration: BoxDecoration(
       color: AppColors.elevatedBackground,
       borderRadius: BorderRadius.circular(12),
       border: Border.all(color: AppColors.borderColor),
     ),
     child: Column(
       children: [
         Icon(
           Icons.error_outline,
           size: 48,
           color: AppColors.dangerColor,
         ),
         const SizedBox(height: 16),
         Text(
           'Error loading data',
           style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
         ),
         const SizedBox(height: 8),
         Text(
           error,
           style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
           textAlign: TextAlign.center,
         ),
       ],
     ),
   );
 }

 // Helper methods
 List<Alert> _filterAlerts(List<Alert> alerts) {
   var filtered = alerts.where((alert) {
     bool matchesSearch = _searchQuery.isEmpty || 
         alert.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
         alert.message.toLowerCase().contains(_searchQuery.toLowerCase());
     
     bool matchesPriority = _selectedPriority == null || alert.priority == _selectedPriority;
     
     return matchesSearch && matchesPriority;
   }).toList();

   // Sort by priority and date
   filtered.sort((a, b) {
     if (a.priority != b.priority) {
       return b.priority.index.compareTo(a.priority.index);
     }
     return b.createdAt.compareTo(a.createdAt);
   });

   return filtered;
 }

 List<EmployeeData> _filterEmployees(List<EmployeeData> employees) {
   if (_searchQuery.isEmpty) return employees;
   
   return employees.where((emp) => 
     emp.profile.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
     emp.profile.jobTitle.toLowerCase().contains(_searchQuery.toLowerCase())
   ).toList();
 }

 Color _getAlertColor(AlertPriority priority) {
   switch (priority) {
     case AlertPriority.urgent: return AppColors.dangerColor;
     case AlertPriority.high: return AppColors.warningColor;
     case AlertPriority.medium: return AppColors.activeColor;
     case AlertPriority.low: return AppColors.successColor;
   }
 }

 IconData _getAlertIcon(AlertType type) {
   switch (type) {
     case AlertType.managerNudge: return Icons.message;
     case AlertType.goalOverdue: return Icons.warning;
     case AlertType.goalDueSoon: return Icons.schedule;
     case AlertType.goalCompleted: return Icons.check_circle;
     default: return Icons.notifications;
   }
 }

 Color _getStatusColor(EmployeeStatus status) {
   switch (status) {
     case EmployeeStatus.onTrack: return AppColors.successColor;
     case EmployeeStatus.atRisk: return AppColors.warningColor;
     case EmployeeStatus.overdue: return AppColors.dangerColor;
     case EmployeeStatus.inactive: return AppColors.textSecondary;
   }
 }

 IconData _getStatusIcon(EmployeeStatus status) {
   switch (status) {
     case EmployeeStatus.onTrack: return Icons.check_circle;
     case EmployeeStatus.atRisk: return Icons.warning;
     case EmployeeStatus.overdue: return Icons.error_outline;
     case EmployeeStatus.inactive: return Icons.pause_circle_outline;
   }
 }

 String _getStatusText(EmployeeStatus status) {
   switch (status) {
     case EmployeeStatus.onTrack: return 'On Track';
     case EmployeeStatus.atRisk: return 'At Risk';
     case EmployeeStatus.overdue: return 'Overdue';
     case EmployeeStatus.inactive: return 'Inactive';
   }
 }

 String _getTimeAgo(DateTime dateTime) {
   final now = DateTime.now();
   final difference = now.difference(dateTime);
   
   if (difference.inDays > 0) return '${difference.inDays}d ago';
   if (difference.inHours > 0) return '${difference.inHours}h ago';
   if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
   return 'Just now';
 }

 // Action methods
 void _handleAlertAction(Alert alert, EmployeeData employee) async {
   try {
     await AlertService.markAsRead(alert.id);
     
     if (alert.actionRoute != null && mounted) {
       Navigator.pushNamed(context, alert.actionRoute!);
     }
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error: $e'),
           backgroundColor: AppColors.dangerColor,
         ),
       );
     }
   }
 }

 void _markAlertAsRead(String alertId) async {
   try {
     await AlertService.markAsRead(alertId);
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error: $e'),
           backgroundColor: AppColors.dangerColor,
         ),
       );
     }
   }
 }

 void _markAllAlertsAsRead(List<Alert> alerts) async {
   try {
     for (final alert in alerts.where((a) => !a.isRead)) {
       await AlertService.markAsRead(alert.id);
     }
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error: $e'),
           backgroundColor: AppColors.dangerColor,
         ),
       );
     }
   }
 }

 void _showSendNudgeDialog({EmployeeData? employee, String? presetMessage}) {
   showDialog(
     context: context,
     builder: (context) => _NudgeDialog(
       employee: employee,
       presetMessage: presetMessage,
       onSendNudge: (employeeId, goalId, message) => _sendNudgeToEmployee(employeeId, goalId, message),
     ),
   );
 }

 void _showBulkNudgeDialog(List<EmployeeData> employees) {
   showDialog(
     context: context,
     builder: (context) => _BulkNudgeDialog(
       employees: employees,
       onSendBulkNudge: (message) => _sendBulkNudge(employees, message),
     ),
   );
 }

 void _sendNudgeToEmployee(String employeeId, String goalId, String message) async {
   try {
     await ManagerRealtimeService.sendNudgeToEmployee(
       employeeId: employeeId,
       goalId: goalId,
       message: message,
     );

     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: const Text('Nudge sent successfully!'),
           backgroundColor: AppColors.successColor,
         ),
       );
     }
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Error sending nudge: $e'),
           backgroundColor: AppColors.dangerColor,
         ),
       );
     }
   }
 }

 void _sendBulkNudge(List<EmployeeData> employees, String message) async {
   int successCount = 0;
   int errorCount = 0;

   for (final employee in employees) {
     try {
       // Use first active goal or create a general nudge
       final goalId = employee.goals.isNotEmpty ? employee.goals.first.id : 'general';
       await ManagerRealtimeService.sendNudgeToEmployee(
         employeeId: employee.profile.uid,
         goalId: goalId,
         message: message,
       );
       successCount++;
     } catch (e) {
       errorCount++;
     }
   }

   if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: Text('Bulk nudge sent: $successCount successes, $errorCount errors'),
         backgroundColor: successCount > errorCount ? AppColors.successColor : AppColors.warningColor,
       ),
     );
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
    _messageController = TextEditingController(text: widget.presetMessage ?? '');
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
      title: Text(
        widget.employee != null 
            ? 'Send Nudge to ${widget.employee!.profile.displayName}'
            : 'Send Nudge'
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.employee != null && widget.employee!.goals.isNotEmpty) ...[
              Text(
                'Related Goal:',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.elevatedBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: DropdownButton<Goal>(
                  value: _selectedGoal,
                  underline: const SizedBox(),
                  isExpanded: true,
                  hint: const Text('Select Goal'),
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  onChanged: (goal) => setState(() => _selectedGoal = goal),
                  items: widget.employee!.goals.map((goal) {
                    return DropdownMenuItem<Goal>(
                      value: goal,
                      child: Text(goal.title),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Message:',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter your nudge message...',
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
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sendNudge,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.activeColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send'),
        ),
      ],
    );
  }

  void _sendNudge() {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: AppColors.warningColor,
        ),
      );
      return;
    }

    final goalId = _selectedGoal?.id ?? 'general';
    widget.onSendNudge(widget.employee!.profile.uid, goalId, _messageController.text.trim());
    Navigator.pop(context);
  }
}

// Bulk Nudge Dialog Widget
class _BulkNudgeDialog extends StatefulWidget {
  final List<EmployeeData> employees;
  final Function(String message) onSendBulkNudge;

  const _BulkNudgeDialog({
    required this.employees,
    required this.onSendBulkNudge,
  });

  @override
  State<_BulkNudgeDialog> createState() => _BulkNudgeDialogState();
}

class _BulkNudgeDialogState extends State<_BulkNudgeDialog> {
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Bulk Nudge'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipients (${widget.employees.length} team members):',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevatedBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: ListView.builder(
                itemCount: widget.employees.length,
                itemBuilder: (context, index) {
                  final employee = widget.employees[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.activeColor.withValues(alpha: 0.1),
                          child: Text(
                            employee.profile.displayName.isNotEmpty 
                                ? employee.profile.displayName[0].toUpperCase()
                                : '?',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.activeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            employee.profile.displayName,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Message:',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter your message for all team members...',
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
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _sendBulkNudge,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.activeColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send to All'),
        ),
      ],
    );
  }

  void _sendBulkNudge() {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a message'),
          backgroundColor: AppColors.warningColor,
        ),
      );
      return;
    }

    widget.onSendBulkNudge(_messageController.text.trim());
    Navigator.pop(context);
  }
}
