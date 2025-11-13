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
// import 'package:pdh/services/alert_service.dart';
import 'package:pdh/models/goal.dart';
// import 'package:pdh/models/alert.dart';
import 'package:pdh/services/role_service.dart';

class MyGoalWorkspaceScreen extends StatefulWidget {
  final bool embedded;

  const MyGoalWorkspaceScreen({super.key, this.embedded = false});

  @override
  State<MyGoalWorkspaceScreen> createState() => _MyGoalWorkspaceScreenState();
}

class _MyGoalWorkspaceScreenState extends State<MyGoalWorkspaceScreen> {
  // SMART scoring (1-5)
  int _clarity = 3; // Specific
  int _measurability = 3; // Measurable
  int _achievability = 3; // Achievable
  int _relevance = 3; // Relevant
  int _timeline = 3; // Time-bound

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
  String? _kpa; // 'operational' | 'customer' | 'financial'

  // Lists for dropdowns
  final List<String> _goalCategories = [
    'Career',
    'Skills',
    'Wellness',
    'Finance',
    'Other',
  ];
  final List<String> _kpaOptions = ['Operational', 'Customer', 'Financial'];

  @override
  void initState() {
    super.initState();
    // Precache heavy assets to avoid initial jank/spinner when opening the workspace
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        precacheImage(const AssetImage('assets/khono_bg.png'), context);
        precacheImage(
          const AssetImage(
            'Calendar_Date_Picker/Date_Picker_White_Badge_Red.png',
          ),
          context,
        );
        precacheImage(
          const AssetImage(
            'Innovation_Brainstorm/Innovation_Brainstorm_White_Badge_Red.png',
          ),
          context,
        );
      } catch (_) {}
    });
  }

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
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, roleSnapshot) {
        final role =
            roleSnapshot.data ?? RoleService.instance.cachedRole ?? 'employee';
        final items = SidebarConfig.getItemsForRole(role);
        return AppScaffold(
          title: 'Goal Workspace',
          showAppBar: false,
          embedded: widget.embedded,
          items: items,
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
              navigator.pushNamedAndRemoveUntil('/sign_in', (route) => false);
            }
          },
          content: AppComponents.backgroundWithImage(
            imagePath: 'assets/khono_bg.png',
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Personal Development Goal',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionCard(
                    children: [
                      _buildTextField(
                        controller: _goalTitleController,
                        hintText: 'Enter your development goal title',
                      ),
                      _buildTextField(
                        controller: _goalDescriptionController,
                        hintText: 'Describe your goal in detail...',
                        maxLines: 5,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader('Goal Details'),
                  _buildSectionCard(
                    children: [
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
                      _buildDropdownField(
                        hintText: 'Select Key Performance Area',
                        value: _kpa != null
                            ? (_kpa![0].toUpperCase() + _kpa!.substring(1))
                            : null,
                        items: _kpaOptions,
                        onChanged: (String? newValue) {
                          setState(() {
                            _kpa = newValue?.toLowerCase();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSmartCriteriaSection(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader('Dependencies & Prerequisites'),
                  _buildSectionCard(
                    children: [
                      _buildTextField(
                        controller: _dependenciesController,
                        hintText:
                            'List any dependencies or prerequisites needed to achieve this goal\n\ne.g., Complete certification course, Save \$5000, Learn specific skills...',
                        maxLines: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader('Success Metrics'),
                  _buildSectionCard(
                    children: [
                      _buildTextField(
                        controller: _successMetricsController,
                        hintText: 'Define specific metrics or milestones...',
                        maxLines: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildSectionCard(children: [_buildActionButtons()]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
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
                date != null
                    ? '${date.day}/${date.month}/${date.year}'
                    : hintText,
                style: AppTypography.bodyMedium.copyWith(
                  color: date != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              SizedBox(
                width: 30,
                height: 30,
                child: Image.asset(
                  'Calendar_Date_Picker/Date_Picker_White_Badge_Red.png',
                  fit: BoxFit.contain,
                ),
              ), // Replaced Icon with Image.asset
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String hintText,
    required String? value,
    required List<String>? items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: Colors.black.withValues(alpha: 0.8),
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            border: InputBorder.none,
          ),
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          onChanged: onChanged,
          items: (items ?? const <String>[]).map<DropdownMenuItem<String>>((
            String value,
          ) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Image.asset(
                    'Innovation_Brainstorm/Innovation_Brainstorm_White_Badge_Red.png',
                    fit: BoxFit.contain,
                  ),
                ), // Replaced Icon with Image.asset
                const SizedBox(width: 10),
                Text(
                  'SMART Criteria Verification',
                  style: AppTypography.heading4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.elevatedBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderColor),
                  ),
                  child: Text(
                    'SMART: ${_computeSmartTotal()}/25',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildScoreSelector(
              title: 'Specific - Goal is clear and well-defined',
              value: _clarity,
              onChanged: (v) => setState(() => _clarity = v),
              helper: '1=vague, 3=some detail, 5=precise deliverable & scope',
            ),
            _buildScoreSelector(
              title: 'Measurable - Progress can be tracked',
              value: _measurability,
              onChanged: (v) => setState(() => _measurability = v),
              helper:
                  '1=no KPI, 3=KPI w/o baseline/target, 5=KPI+baseline+target+source',
            ),
            _buildScoreSelector(
              title: 'Achievable - Goal is realistic and attainable',
              value: _achievability,
              onChanged: (v) => setState(() => _achievability = v),
              helper: '1=unlikely, 3=stretch, 5=realistic with resources',
            ),
            _buildScoreSelector(
              title: 'Relevant - Goal aligns with your values/role/OKR',
              value: _relevance,
              onChanged: (v) => setState(() => _relevance = v),
              helper: '1=not aligned, 3=indirect, 5=direct OKR/competency fit',
            ),
            _buildScoreSelector(
              title: 'Time-bound - Goal has a clear deadline',
              value: _timeline,
              onChanged: (v) => setState(() => _timeline = v),
              helper: '1=no date, 3=date tight, 5=realistic + milestones',
            ),
          ],
        ),
      ),
    );
  }

  int _computeSmartTotal() {
    return _clarity + _measurability + _achievability + _relevance + _timeline;
  }

  Widget _buildScoreSelector({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(5, (index) {
              final score = index + 1;
              final selected = value == score;
              return ChoiceChip(
                label: Text(
                  '$score',
                  style: AppTypography.bodyMedium.copyWith(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                selected: selected,
                onSelected: (_) => onChanged(score),
                selectedColor: AppColors.activeColor,
                backgroundColor: Colors.black.withValues(alpha: 0.3),
                shape: StadiumBorder(
                  side: BorderSide(color: AppColors.borderColor),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
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
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
          ),
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

    // SMART criteria are advisory; goal approval will be handled by managers

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
        kpa: _kpa,
      );

      // Show loading dialog while creating goal
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.elevatedBackground,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.activeColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Creating your goal... Please wait',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      await DatabaseService.createGoal(goal);

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        // Navigate back to dashboard immediately to minimize waiting
        navigator.pushNamedAndRemoveUntil(
          '/employee_dashboard',
          (route) => false,
        );
      }
    } catch (e) {
      try {
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (_) {}

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
