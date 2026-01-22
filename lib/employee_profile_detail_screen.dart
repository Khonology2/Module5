import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/goal.dart';

class EmployeeProfileDetailScreen extends StatefulWidget {
  final String employeeId;
  
  const EmployeeProfileDetailScreen({
    super.key,
    required this.employeeId,
  });

  @override
  State<EmployeeProfileDetailScreen> createState() => _EmployeeProfileDetailScreenState();
}

class _EmployeeProfileDetailScreenState extends State<EmployeeProfileDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
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
      title: 'Employee Profile',
      showAppBar: false,
      embedded: false,
      items: SidebarConfig.getItemsForRole('manager'),
      currentRouteName: '/employee_profile_detail',
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
            child: StreamBuilder<UserProfile?>(
              stream: _getEmployeeProfileStream(),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                    ),
                  );
                }

                if (profileSnapshot.hasError) {
                  return _buildErrorState(profileSnapshot.error.toString());
                }

                final profile = profileSnapshot.data;
                if (profile == null) {
                  return _buildNotFoundState();
                }

                return Column(
                  children: [
                    Padding(
                      padding: AppSpacing.screenPadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            color: AppColors.textPrimary,
                            tooltip: 'Back',
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          _buildEmployeeHeader(profile),
                          const SizedBox(height: AppSpacing.lg),
                          _buildActionButtons(),
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
                          Tab(text: 'Overview', icon: Icon(Icons.person_outline, size: 20)),
                          Tab(text: 'Action', icon: Icon(Icons.insert_emoticon, size: 20)),
                          Tab(text: 'Goals & History', icon: Icon(Icons.history_outlined, size: 20)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(profile),
                          _buildActivityTab(),
                          _buildGoalsHistoryTab(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      }

      Stream<UserProfile?> _getEmployeeProfileStream() {
        final viewerId = FirebaseAuth.instance.currentUser?.uid;
        if (viewerId == null) {
          return Stream.value(null);
        }
        return FirebaseFirestore.instance
            .collection('users')
            .doc(widget.employeeId)
            .snapshots()
            .asyncMap((doc) async {
          if (!doc.exists) return null;
          final allowed = await DatabaseService.canViewerSeeUserProfile(
            viewerId: viewerId,
            targetUserId: widget.employeeId,
          );
          if (!allowed) return null;
          return UserProfile.fromFirestore(doc);
        });
      }

      Widget _buildEmployeeHeader(UserProfile profile) {
        return Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.activeColor.withValues(alpha: 0.1),
              child: Text(
                profile.displayName.isNotEmpty 
                    ? profile.displayName[0].toUpperCase()
                    : '?',
                style: AppTypography.heading2.copyWith(
                  color: AppColors.activeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName,
                    style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.jobTitle,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          profile.department,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.activeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppColors.activeColor.withValues(alpha: 0.1),
                        side: BorderSide(color: AppColors.activeColor.withValues(alpha: 0.3)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Chip(
                        label: Text(
                          profile.email,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        backgroundColor: AppColors.textSecondary.withValues(alpha: 0.1),
                        side: BorderSide(color: AppColors.borderColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      }

      Widget _buildActionButtons() {
        return Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showSendNudgeDialog(),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Send Nudge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: () => _showScheduleMeetingDialog(),
              icon: const Icon(Icons.calendar_today, size: 16),
              label: const Text('Schedule Meeting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.infoColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: () => _showRecognitionDialog(),
              icon: const Icon(Icons.celebration, size: 16),
              label: const Text('Give Recognition'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warningColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      }

      Widget _buildOverviewTab(UserProfile profile) {
        return SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileCard(profile),
              const SizedBox(height: AppSpacing.lg),
              _buildSkillsCard(profile),
              const SizedBox(height: AppSpacing.lg),
              _buildCareerGoalsCard(profile),
            ],
          ),
        );
      }

      Widget _buildProfileCard(UserProfile profile) {
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
              Text(
                'Profile Information',
                style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _buildProfileField('Phone', profile.phoneNumber.isEmpty ? 'Not provided' : profile.phoneNumber),
                  ),
                  Expanded(
                    child: _buildProfileField('Level', 'Level ${profile.level}'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _buildProfileField('Total Points', '${profile.totalPoints} pts'),
                  ),
                  Expanded(
                    child: _buildProfileField('Badge Name',profile.badgeName.isEmpty ? 'Not assigned' : profile.badgeName),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (profile.skills.isNotEmpty) ...[
                Text(
                  'Skills',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  children: profile.skills.map((skill) => Chip(
                    label: Text(skill),
                    backgroundColor: AppColors.successColor.withValues(alpha: 0.1),
                    side: BorderSide(color: AppColors.successColor.withValues(alpha: 0.3)),
                  )).toList(),
                ),
              ],
            ],
          ),
        );
      }

      Widget _buildProfileField(String label, String value) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        );
      }

      Widget _buildSkillsCard(UserProfile profile) {
        if (profile.developmentAreas.isEmpty) {
          return const SizedBox.shrink();
        }

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
              Text(
                'Development Areas',
                style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                children: profile.developmentAreas.map((area) => Chip(
                  label: Text(area),
                  backgroundColor: AppColors.warningColor.withValues(alpha: 0.1),
                  side: BorderSide(color: AppColors.warningColor.withValues(alpha: 0.3)),
                )).toList(),
              ),
            ],
          ),
        );
      }

      Widget _buildCareerGoalsCard(UserProfile profile) {
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
              Text(
                'Career Aspirations',
                style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  profile.careerAspirations.isEmpty 
                      ? 'No career aspirations recorded'
                      : profile.careerAspirations,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      }

      Widget _buildActivityTab() {
        return StreamBuilder<List<EmployeeActivity>>(
          stream: ManagerRealtimeService.getEmployeeActivitiesStream(employeeId: widget.employeeId),
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

            final activities = snapshot.data ?? [];
            
            if (activities.isEmpty) {
              return _buildNoActivitiesState();
            }

            return SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity (${activities.length})',
                    style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...activities.map((activity) => _buildActivityItem(activity)),
                ],
              ),
            );
          },
        );
      }

      Widget _buildActivityItem(EmployeeActivity activity) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.elevatedBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getActivityTypeColor(activity.activityType).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getActivityTypeIcon(activity.activityType),
                  color: _getActivityTypeColor(activity.activityType),
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.description,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTimeAgo(activity.timestamp),
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
                  color: _getActivityTypeColor(activity.activityType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  activity.activityType.toUpperCase(),
                  style: AppTypography.bodySmall.copyWith(
                    color: _getActivityTypeColor(activity.activityType),
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      Widget _buildGoalsHistoryTab() {
        return StreamBuilder<List<Goal>>(
          stream: _getEmployeeGoalsStream(),
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

            final goals = snapshot.data ?? [];
            
            if (goals.isEmpty) {
              return _buildNoGoalsState();
            }

            return SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Goals (${goals.length})',
                        style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAssignGoalDialog(),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Assign Goal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.activeColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...goals.map((goal) => _buildGoalItem(goal)),
                ],
              ),
            );
          },
        );
      }

      Widget _buildGoalItem(Goal goal) {
        final daysUntilDeadline = goal.targetDate.difference(DateTime.now()).inDays;
        final progress = goal.progress / 100.0;
        final priorityColor = _getPriorityColor(goal.priority);
        
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                  Expanded(
                    child: Text(
                      goal.title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      goal.priority.name.toUpperCase(),
                      style: AppTypography.bodySmall.copyWith(
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                goal.description,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: AppColors.borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(priorityColor),
                minHeight: 6,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: ${goal.progress}%',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    daysUntilDeadline < 0 
                        ? 'Overdue by ${(-daysUntilDeadline)} days'
                        : 'Due in $daysUntilDeadline days',
                    style: AppTypography.bodySmall.copyWith(
                      color: daysUntilDeadline < 0 ? AppColors.dangerColor : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      Widget _buildNoActivitiesState() {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.elevatedBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timeline_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Recent Activity',
                  style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'This employee hasn\'t recorded any recent activities.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      Widget _buildNoGoalsState() {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.elevatedBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Goals Found',
                  style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'This employee doesn\'t have any assigned goals yet.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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

      Widget _buildNotFoundState() {
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
                Icons.person_off_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Employee Not Found',
                style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'The requested employee profile could not be found.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      // Data streams
      Stream<List<Goal>> _getEmployeeGoalsStream() {
        final viewerId = FirebaseAuth.instance.currentUser?.uid ?? widget.employeeId;
        return DatabaseService.getUserGoalsStreamForViewer(
          viewerId: viewerId,
          targetUserId: widget.employeeId,
        );
      }

      // Helper methods
      Color _getActivityTypeColor(String activityType) {
        switch (activityType.toLowerCase()) {
          case 'goal_created':
            return AppColors.activeColor;
          case 'goal_completed':
            return AppColors.successColor;
          case 'goal_updated':
            return AppColors.infoColor;
          case 'nudge_received':
            return AppColors.warningColor;
          case 'meeting_scheduled':
            return AppColors.warningColor;
          default:
            return AppColors.textSecondary;
        }
      }

      IconData _getActivityTypeIcon(String activityType) {
        switch (activityType.toLowerCase()) {
          case 'goal_created':
            return Icons.flag;
          case 'goal_completed':
            return Icons.check_circle;
          case 'goal_updated':
            return Icons.update;
          case 'nudge_received':
            return Icons.message;
          case 'meeting_scheduled':
            return Icons.calendar_today;
          default:
            return Icons.casino;
        }
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

      String _getTimeAgo(DateTime dateTime) {
        final now = DateTime.now();
        final difference = now.difference(dateTime);
        
        if (difference.inDays > 0) return '${difference.inDays}d ago';
        if (difference.inHours > 0) return '${difference.inHours}h ago';
        if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
        return 'Just now';
      }

      // Action dialogs (placeholder methods)
      void _showSendNudgeDialog() {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Send Nudge'),
            content: const Text('Nudge functionality will be implemented here'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }

      void _showScheduleMeetingDialog() {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Schedule Meeting'),
            content: const Text('Meeting scheduling functionality will be implemented here'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }

      void _showRecognitionDialog() {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Give Recognition'),
            content: const Text('Recognition functionality will be implemented here'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }

      void _showAssignGoalDialog() {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Assign Goal'),
            content: const Text('Goal assignment functionality will be implemented here'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    }
