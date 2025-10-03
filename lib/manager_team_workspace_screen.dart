import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/alert_service.dart';

class ManagerTeamWorkspaceScreen extends StatefulWidget {
  final bool embedded;

  const ManagerTeamWorkspaceScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<ManagerTeamWorkspaceScreen> createState() => _ManagerTeamWorkspaceScreenState();
}

class _ManagerTeamWorkspaceScreenState extends State<ManagerTeamWorkspaceScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController();

  DateTime? _selectedDeadline;
  bool _isCreatingTeam = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Team Workspace',
      embedded: widget.embedded,
      items: const [], // Manager-specific items - we'll handle this properly
      currentRouteName: '/manager_team_workspace',
      onNavigate: (route) {
        // Handle navigation
        Navigator.pushNamed(context, route);
      },
      onLogout: () {
        // Handle logout
        Navigator.pushReplacementNamed(context, '/sign_in');
      },
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Team Management Hub',
                        style: AppTypography.heading2.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    ElevatedButton.icon(
                      onPressed: _showCreateTeamDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Team Goal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.activeColor,
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Create team goals and manage group activities. Monitor team progress and engagement.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Active Team Goals
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Team Goals',
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('team_goals')
                        .where('createdByManager', isEqualTo: true)
                        .where('managerId', isEqualTo: AuthService().currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading team goals',
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.activeColor,
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final teamGoals = snapshot.data?.docs ?? [];

                      if (teamGoals.isEmpty) {
                        return _buildEmptyState();
                      }

                      return ListView.builder(
                        itemCount: teamGoals.length,
                        itemBuilder: (context, index) {
                          final teamGoal = teamGoals[index].data() as Map<String, dynamic>;
                          final goalId = teamGoals[index].id;
                          return _buildTeamGoalCard(goalId, teamGoal);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.group_add,
            size: 80,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No Team Goals Yet',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Create your first team goal to get started',
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: _showCreateTeamDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Team Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamGoalCard(String goalId, Map<String, dynamic> teamGoal) {
    final title = teamGoal['title'] ?? 'Untitled Goal';
    final description = teamGoal['description'] ?? '';
    final status = teamGoal['status'] ?? 'active';
    final deadline = (teamGoal['targetDate'] as Timestamp?)?.toDate();
    final points = teamGoal['points'] ?? 0;
    final participantCount = teamGoal['participantCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            description,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.people,
                label: '$participantCount Members',
              ),
              SizedBox(width: AppSpacing.sm),
              _buildInfoChip(
                icon: Icons.stars,
                label: '$points Points',
              ),
              const SizedBox(width: AppSpacing.sm),
              if (deadline != null)
                _buildInfoChip(
                  icon: Icons.calendar_today,
                  label: 'Due ${_formatDate(deadline)}',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewTeamDetails(goalId),
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Details'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _manageTeamMembers(goalId),
                  icon: const Icon(Icons.manage_accounts),
                  label: const Text('Manage Team'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.activeColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.purple;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;
    
    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference > 0) {
      return '$difference days';
    } else {
      return '${-difference} days ago';
    }
  }

  void _showCreateTeamDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Team Goal'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g., Q4 Team Productivity Challenge',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the team goal and objectives...',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _pointsController,
                  decoration: const InputDecoration(
                    labelText: 'Points Reward',
                    hintText: 'Points each team member will earn',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter points';
                    }
                    final points = int.tryParse(value);
                    if (points == null || points <= 0) {
                      return 'Please enter a valid point value';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textSecondary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _selectedDeadline != null
                              ? 'Due: ${_formatDate(_selectedDeadline!)}'
                              : 'Select Deadline',
                          style: AppTypography.bodyLarge.copyWith(
                            color: _selectedDeadline != null
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.calendar_today,
                          color: AppColors.activeColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isCreatingTeam ? null : _createTeamGoal,
            child: _isCreatingTeam
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _createTeamGoal() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a deadline')),
      );
      return;
    }

    setState(() {
      _isCreatingTeam = true;
    });

    try {
      final teamGoalData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'points': int.parse(_pointsController.text),
        'targetDate': Timestamp.fromDate(_selectedDeadline!),
        'status': 'active',
        'createdByManager': true,
        'managerId': AuthService().currentUser?.uid,
        'managerName': AuthService().currentUser?.displayName ?? 'Manager',
        'participantCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'department': '', // Will be set from user profile
      };

      await FirebaseFirestore.instance.collection('team_goals').add(teamGoalData);

      // Reset form
      _titleController.clear();
      _descriptionController.clear();
      _pointsController.clear();
      _selectedDeadline = null;

      // Notify all employees about the new team goal
      await _notifyEmployeesAboutTeamGoal();

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Team goal created successfully! All employees have been notified to join the team!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating team goal: $e')),
      );
    } finally {
      setState(() {
        _isCreatingTeam = false;
      });
    }
  }

  Future<void> _notifyEmployeesAboutTeamGoal() async {
    try {
      // Get ALL employees regardless of department to ensure everyone sees team goals
      final employees = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();

      int notificationCount = 0;
      
      for (final employee in employees.docs) {
        try {
          await AlertService.createTeamGoalAlert(
            userId: employee.id,
            teamGoalTitle: _titleController.text,
            managerName: AuthService().currentUser?.displayName ?? 'Manager',
            points: int.parse(_pointsController.text),
            deadline: _selectedDeadline!,
          );
          notificationCount++;
        } catch (alertError) {
          debugPrint('Failed to create alert for employee ${employee.id}: $alertError');
          // Continue with other employees even if one fails
        }
      }

      debugPrint('Successfully sent team goal alerts to $notificationCount employees');
    } catch (e) {
      // Log error but don't show to user unless critical
      debugPrint('Error notifying employees about team goal: $e');
      
      // Show a brief error message to the user but don't fail the entire process
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Team goal created, but some employees may not receive notifications.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _viewTeamDetails(String goalId) {
    // Navigate to team details screen
    Navigator.pushNamed(context, '/team_details', arguments: goalId);
  }

  void _manageTeamMembers(String goalId) {
    // Navigate to team management screen
    Navigator.pushNamed(context, '/team_management', arguments: goalId);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }
}
