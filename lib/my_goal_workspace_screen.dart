import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/alert.dart';

class MyGoalWorkspaceScreen extends StatefulWidget {
  final bool embedded;
  
  const MyGoalWorkspaceScreen({
    super.key,
    this.embedded = false,
  });

  @override
  State<MyGoalWorkspaceScreen> createState() => _MyGoalWorkspaceScreenState();
}

class _MyGoalWorkspaceScreenState extends State<MyGoalWorkspaceScreen> {
  // Checkbox states for SMART criteria
  bool _isSpecific = false;
  bool _isMeasurable = false;
  bool _isAchievable = false;
  bool _isRelevant = false;
  bool _isTimeBound = false;

  // Controllers for text fields
  final _goalTitleController = TextEditingController();
  final _goalDescriptionController = TextEditingController();
  final _dependenciesController = TextEditingController();
  final _successMetricsController = TextEditingController();

  // Date variables
  DateTime? _startDate;
  DateTime? _targetDate;

  // Dropdown selected values
  String? _goalCategory;
  String? _currentStatus;

  // Lists for dropdowns
  final List<String> _goalCategories = [
    'Career',
    'Skills',
    'Wellness',
    'Finance',
    'Other',
  ];

  Future<void> _selectDate(
    BuildContext context, {
    required bool isStartDate,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.activeColor,
              onPrimary: AppColors.textPrimary,
              surface: AppColors.elevatedBackground,
              onSurface: AppColors.textPrimary,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.backgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _targetDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Goal Workspace',
      showAppBar: false,
      embedded: widget.embedded,
      items: SidebarConfig.employeeItems,
      currentRouteName: '/my_goal_workspace',
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
      content: AppComponents.backgroundWithImage(
        imagePath:
            'assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png',
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Personal Development Goal',
                style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionHeader('Goal Information'),
              _buildTextField(
                controller: _goalTitleController,
                hintText: 'Enter your development goal title',
              ),
              _buildTextField(
                controller: _goalDescriptionController,
                hintText: 'Describe your goal in detail...',
                maxLines: 5,
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionHeader('Goal Details'),
              Row(
                children: [
                  Expanded(
                    child: _buildDateInput(
                      context,
                      'Start Date',
                      _startDate,
                      isStartDate: true,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _buildDateInput(
                      context,
                      'Target Date',
                      _targetDate,
                      isStartDate: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _buildDropdownField(
                hintText: 'Select category',
                value: _goalCategory,
                items: _goalCategories,
                onChanged: (String? newValue) {
                  setState(() {
                    _goalCategory = newValue;
                  });
                },
              ),
              _buildDropdownField(
                hintText: 'Select priority',
                value: _currentStatus,
                items: ['High', 'Medium', 'Low'],
                onChanged: (String? newValue) {
                  setState(() {
                    _currentStatus = newValue;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildSmartCriteriaSection(),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionHeader('Dependencies & Prerequisites'),
              _buildTextField(
                controller: _dependenciesController,
                hintText:
                    'List any dependencies or prerequisites needed to achieve this goal\n\ne.g., Complete certification course, Save \$5000, Learn specific skills...',
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionHeader('Success Metrics'),
              _buildTextField(
                controller: _successMetricsController,
                hintText: 'Define specific metrics or milestones...',
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.xxl),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: AppTypography.heading4.copyWith(
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }

  Widget _buildDateInput(
    BuildContext context,
    String hintText,
    DateTime? date, {
    required bool isStartDate,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectDate(context, isStartDate: isStartDate),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date != null ? '${date.day}/${date.month}/${date.year}' : hintText,
                style: AppTypography.bodyMedium.copyWith(
                  color: date != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              Icon(
                Icons.calendar_today,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String hintText,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: AppColors.elevatedBackground,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            border: InputBorder.none,
          ),
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSmartCriteriaSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.activeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.activeColor.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.activeColor,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'SMART Criteria Verification',
                  style: AppTypography.heading4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildSmartCheckbox(
              'Specific - Goal is clear and well-defined',
              _isSpecific,
              (value) {
                setState(() => _isSpecific = value!);
              },
            ),
            _buildSmartCheckbox(
              'Measurable - Progress can be tracked',
              _isMeasurable,
              (value) {
                setState(() => _isMeasurable = value!);
              },
            ),
            _buildSmartCheckbox(
              'Achievable - Goal is realistic and attainable',
              _isAchievable,
              (value) {
                setState(() => _isAchievable = value!);
              },
            ),
            _buildSmartCheckbox(
              'Relevant - Goal aligns with your values',
              _isRelevant,
              (value) {
                setState(() => _isRelevant = value!);
              },
            ),
            _buildSmartCheckbox(
              'Time-bound - Goal has a clear deadline',
              _isTimeBound,
              (value) {
                setState(() => _isTimeBound = value!);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartCheckbox(
    String title,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return Theme(
      data: ThemeData(unselectedWidgetColor: AppColors.textSecondary),
      child: CheckboxListTile(
        title: Text(
          title,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.activeColor,
        checkColor: AppColors.textPrimary,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Future<void> _saveGoal() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    // Validate required fields
    if (_goalTitleController.text.trim().isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Please enter a goal title'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_targetDate == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Please select a target date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Map category to GoalCategory enum
      GoalCategory category;
      switch (_goalCategory?.toLowerCase()) {
        case 'career':
          category = GoalCategory.work;
          break;
        case 'skills':
        case 'learning':
          category = GoalCategory.learning;
          break;
        case 'wellness':
          category = GoalCategory.health;
          break;
        default:
          category = GoalCategory.personal;
      }

      // Map priority to GoalPriority enum
      GoalPriority priority;
      switch (_currentStatus?.toLowerCase()) {
        case 'high':
          priority = GoalPriority.high;
          break;
        case 'low':
          priority = GoalPriority.low;
          break;
        default:
          priority = GoalPriority.medium;
      }

      final goal = Goal(
        id: '', // Will be set by Firestore
        userId: user.uid,
        title: _goalTitleController.text.trim(),
        description: _goalDescriptionController.text.trim(),
        category: category,
        priority: priority,
        status: GoalStatus.notStarted,
        progress: 0,
        createdAt: DateTime.now(),
        targetDate: _targetDate!,
        points: _calculatePoints(priority),
      );

      final goalId = await DatabaseService.createGoal(goal);
      
      // Create goal with the returned ID for alert
      final createdGoal = goal.copyWith(id: goalId);
      
      // Create alert for goal creation
      await AlertService.createGoalAlert(
        userId: user.uid,
        goal: createdGoal,
        type: AlertType.goalCreated,
      );

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Goal created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to dashboard
        navigator.pushNamedAndRemoveUntil(
          '/employee_dashboard',
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error creating goal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  int _calculatePoints(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return 100;
      case GoalPriority.medium:
        return 50;
      case GoalPriority.low:
        return 25;
    }
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveGoal,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: AppColors.textPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Create Goal'),
          ),
        ),
      ],
    );
  }
}
