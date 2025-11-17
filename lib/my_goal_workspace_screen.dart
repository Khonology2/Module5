import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'dart:convert';
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
import 'package:pdh/services/employee_tutorial_service.dart';
import 'package:pdh/widgets/employee_sidebar_tutorial.dart';

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
  final _customCategoryController = TextEditingController();

  // Date variables
  DateTime? _startDate;
  DateTime? _targetDate;

  // Dropdown selected values
  String? _goalCategory;
  String? _currentStatus;
  String? _kpa; // 'operational' | 'customer' | 'financial'
  String? _customCategory; // For "Other" category custom input
  bool _isOtherCategorySelected = false;

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

  @override
  void dispose() {
    _goalTitleController.dispose();
    _goalDescriptionController.dispose();
    _dependenciesController.dispose();
    _successMetricsController.dispose();
    _customCategoryController.dispose();
    super.dispose();
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
        // Get tutorial state from global service (only for employees)
        final tutorialService = EmployeeTutorialService.instance;
        if (role == 'employee' && tutorialService.isTutorialActive) {
          tutorialService.setCurrentContext(context);

          // Check if we should show tutorial popup for this screen
          // This happens after navigation when the new screen builds
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !tutorialService.isTutorialActive) return;

            // Check if current route matches the tutorial step
            final currentRoute = ModalRoute.of(context)?.settings.name;
            if (currentRoute != null &&
                tutorialService.currentTutorialStep <
                    EmployeeSidebarTutorialConfig.steps.length) {
              final step = EmployeeSidebarTutorialConfig
                  .steps[tutorialService.currentTutorialStep];
              if (step.route == currentRoute ||
                  (step.route == '__collapse_toggle__' &&
                      tutorialService.currentTutorialStep ==
                          SidebarConfig.employeeItems.length)) {
                // This screen matches the current tutorial step, show popup
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && tutorialService.isTutorialActive) {
                    // ignore: use_build_context_synchronously
                    tutorialService.showTutorialPopup(context);
                  }
                });
              }
            }
          });
        }
        final tutorialParams = role == 'employee'
            ? tutorialService.getTutorialParams()
            : {
                'tutorialStepIndex': null,
                'sidebarTutorialKeys': null,
                'onTutorialNext': null,
                'onTutorialSkip': null,
              };

        return AppScaffold(
          title: 'Goal Workspace',
          showAppBar: false,
          embedded: widget.embedded,
          items: items,
          currentRouteName: '/my_goal_workspace',
          tutorialStepIndex: tutorialParams['tutorialStepIndex'] as int?,
          sidebarTutorialKeys:
              tutorialParams['sidebarTutorialKeys'] as List<GlobalKey>?,
          onTutorialNext: tutorialParams['onTutorialNext'] as VoidCallback?,
          onTutorialSkip: tutorialParams['onTutorialSkip'] as VoidCallback?,
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
                      _buildTextFieldWithGenerate(
                        controller: _goalTitleController,
                        hintText: 'Enter your development goal title',
                        onGenerate: () =>
                            _showGenerateDescriptionDialog(context),
                      ),
                      _buildTextField(
                        controller: _goalDescriptionController,
                        hintText: 'Describe your goal in detail...',
                        maxLines: 5,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('Goal Details'),
                      ElevatedButton.icon(
                        onPressed:
                            _goalDescriptionController.text.trim().isEmpty
                            ? null
                            : () => _suggestGoalDetails(context),
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('Suggest'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.activeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      _buildCategoryDropdown(),
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

  Widget _buildTextFieldWithGenerate({
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onGenerate,
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
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.auto_awesome,
                color: AppColors.activeColor,
              ),
              onPressed: onGenerate,
              tooltip: 'Generate description',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showGenerateDescriptionDialog(BuildContext context) async {
    final titleController = TextEditingController(
      text: _goalTitleController.text.trim(),
    );
    bool isGenerating = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> generateDescription() async {
              final goalTitle = titleController.text.trim();
              if (goalTitle.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a goal title'),
                    backgroundColor: AppColors.dangerColor,
                  ),
                );
                return;
              }

              setDialogState(() => isGenerating = true);

              try {
                // Initialize Firebase AI model
                final model = FirebaseAI.googleAI().generativeModel(
                  model: 'gemini-2.5-flash',
                  systemInstruction: Content.text(
                    'You are an AI assistant specialized in creating comprehensive personal development goal plans. '
                    'When given a goal title, you must generate three components:\n\n'
                    '1. DESCRIPTION: A detailed and actionable description of the goal (no more than 5 sentences). '
                    'Be concise but thorough, making it comprehensive, motivating, and including specific steps or considerations.\n\n'
                    '2. DEPENDENCIES AND PREREQUISITES: Exactly 5 dependencies or prerequisites needed to achieve this goal. '
                    'Format each as a bullet point starting with "-" or "•". Be specific and actionable.\n\n'
                    '3. SUCCESS METRICS: Specific, measurable metrics or milestones that indicate successful completion of this goal. '
                    'Provide a substantial amount of detail with clear, quantifiable indicators.\n\n'
                    'Respond in this EXACT JSON format (no other text):\n'
                    '{"description": "the goal description here", "dependencies": "• First dependency\\n• Second dependency\\n• Third dependency\\n• Fourth dependency\\n• Fifth dependency", "successMetrics": "the success metrics here"}',
                  ),
                );

                final prompt = [
                  Content.text(
                    'Generate a comprehensive plan for this personal development goal: $goalTitle\n\n'
                    'Provide the description, 5 dependencies/prerequisites in point form, and success metrics.',
                  ),
                ];

                final response = await model.generateContent(prompt);
                final responseText =
                    response.text?.replaceAll('*', '').trim() ?? '';

                if (mounted) {
                  // Update the goal title if it was changed in the dialog
                  if (titleController.text.trim() !=
                      _goalTitleController.text.trim()) {
                    _goalTitleController.text = titleController.text.trim();
                  }

                  // Parse JSON response
                  String jsonText = responseText.trim();
                  // Remove markdown code blocks if present
                  if (jsonText.contains('```json')) {
                    jsonText = jsonText
                        .split('```json')[1]
                        .split('```')[0]
                        .trim();
                  } else if (jsonText.contains('```')) {
                    jsonText = jsonText.split('```')[1].split('```')[0].trim();
                  }

                  // Extract JSON object
                  final jsonMatch = RegExp(
                    r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}',
                  ).firstMatch(jsonText);

                  if (jsonMatch != null) {
                    final jsonString = jsonMatch.group(0) ?? '{}';
                    Map<String, dynamic> generatedData;

                    try {
                      generatedData =
                          jsonDecode(jsonString) as Map<String, dynamic>;
                    } catch (e) {
                      // Fallback parsing with multiline support
                      final descMatch = RegExp(
                        r'"description"\s*:\s*"((?:[^"\\]|\\.)*)"',
                        dotAll: true,
                      ).firstMatch(jsonString);
                      final depsMatch = RegExp(
                        r'"dependencies"\s*:\s*"((?:[^"\\]|\\.)*)"',
                        dotAll: true,
                      ).firstMatch(jsonString);
                      final metricsMatch = RegExp(
                        r'"successMetrics"\s*:\s*"((?:[^"\\]|\\.)*)"',
                        dotAll: true,
                      ).firstMatch(jsonString);

                      generatedData = {};
                      if (descMatch != null) {
                        generatedData['description'] = descMatch
                            .group(1)!
                            .replaceAll('\\n', '\n')
                            .replaceAll('\\"', '"');
                      }
                      if (depsMatch != null) {
                        generatedData['dependencies'] = depsMatch
                            .group(1)!
                            .replaceAll('\\n', '\n')
                            .replaceAll('\\"', '"');
                      }
                      if (metricsMatch != null) {
                        generatedData['successMetrics'] = metricsMatch
                            .group(1)!
                            .replaceAll('\\n', '\n')
                            .replaceAll('\\"', '"');
                      }
                    }

                    // Fill all three fields
                    final description =
                        generatedData['description']?.toString() ?? '';
                    final dependencies =
                        generatedData['dependencies']?.toString() ?? '';
                    final successMetrics =
                        generatedData['successMetrics']?.toString() ?? '';

                    _goalDescriptionController.text = description;
                    _dependenciesController.text = dependencies;
                    _successMetricsController.text = successMetrics;

                    // Close the dialog
                    // ignore: use_build_context_synchronously
                    Navigator.of(dialogContext).pop();

                    // Show success message in centered dialog
                    if (mounted) {
                      await _showCenteredSuccessDialog(
                        // ignore: use_build_context_synchronously
                        context,
                        'Goal description, dependencies, and success metrics generated successfully!',
                      );
                    }
                  } else {
                    // Fallback: if JSON parsing fails, try to extract description only
                    _goalDescriptionController.text = responseText;

                    // Close the dialog
                    // ignore: use_build_context_synchronously
                    Navigator.of(dialogContext).pop();

                    // Show success message
                    if (mounted) {
                      await _showCenteredSuccessDialog(
                        // ignore: use_build_context_synchronously
                        context,
                        'Goal description generated. Dependencies and metrics could not be parsed.',
                      );
                    }
                  }
                }
              } catch (e) {
                setDialogState(() => isGenerating = false);
                if (mounted) {
                  // Show error in centered dialog
                  await _showCenteredErrorDialog(
                    // ignore: use_build_context_synchronously
                    context,
                    'Error generating description: $e',
                  );
                }
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.elevatedBackground,
              title: Text(
                'Generate Goal Description',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Goal Title',
                        labelStyle: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        hintText: 'Enter the goal title',
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: Colors.black.withValues(alpha: 0.4),
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
                          borderSide: BorderSide(color: AppColors.activeColor),
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    if (isGenerating) ...[
                      const SizedBox(height: 16),
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.activeColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generating description...',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isGenerating
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isGenerating ? null : generateDescription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
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

  Widget _buildCategoryDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isOtherCategorySelected) ...[
            TextField(
              controller: _customCategoryController,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Category (Other)',
                labelStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                hintText: 'Enter custom category',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.4),
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
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
                contentPadding: const EdgeInsets.all(16),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () {
                    setState(() {
                      _isOtherCategorySelected = false;
                      _goalCategory = null;
                      _customCategory = null;
                      _customCategoryController.clear();
                    });
                  },
                  tooltip: 'Clear and select from dropdown',
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _customCategory = value;
                });
              },
            ),
          ] else
            _buildDropdownField(
              hintText: 'Select category',
              value: _goalCategory,
              items: _goalCategories,
              onChanged: (String? newValue) {
                setState(() {
                  if (newValue == 'Other') {
                    _isOtherCategorySelected = true;
                    _goalCategory = 'Other';
                    _customCategory = null;
                    _customCategoryController.clear();
                  } else {
                    _goalCategory = newValue;
                    _isOtherCategorySelected = false;
                    _customCategory = null;
                    _customCategoryController.clear();
                  }
                });
              },
            ),
        ],
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

  Future<void> _showCenteredSuccessDialog(
    BuildContext context,
    String message,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.elevatedBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle, color: AppColors.successColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('OK', style: TextStyle(color: AppColors.activeColor)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCenteredErrorDialog(
    BuildContext context,
    String message,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.elevatedBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: AppColors.dangerColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('OK', style: TextStyle(color: AppColors.activeColor)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _suggestGoalDetails(BuildContext context) async {
    final description = _goalDescriptionController.text.trim();
    if (description.isEmpty) {
      await _showCenteredErrorDialog(
        context,
        'Please generate a goal description first',
      );
      return;
    }

    // Check if start date and target date are selected
    if (_startDate == null || _targetDate == null) {
      await _showCenteredErrorDialog(
        context,
        'Please select both Start Date and Target Date before generating suggestions.',
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
        ),
      ),
    );

    try {
      // Initialize Firebase AI model
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: Content.text(
          'You are an AI assistant that analyzes personal development goal descriptions and suggests appropriate categories, priorities, and key performance areas. '
          'Based on the goal description provided, you must suggest:\n'
          '1. Category: Choose ONE from these exact options: Career, Skills, Wellness, Finance, or Other. If it does not fit any of the first four, suggest "Other".\n'
          '2. Priority: Choose ONE from these exact options: High, Medium, or Low.\n'
          '3. Key Performance Area (KPA): Choose ONE from these exact options: Operational, Customer, or Financial.\n\n'
          'Respond ONLY with a JSON object in this exact format (no other text):\n'
          '{"category": "Career|Skills|Wellness|Finance|Other", "priority": "High|Medium|Low", "kpa": "Operational|Customer|Financial"}',
        ),
      );

      final prompt = [
        Content.text(
          'Analyze this goal description and suggest the category, priority, and key performance area:\n\n$description',
        ),
      ];

      final response = await model.generateContent(prompt);
      final responseText = response.text?.replaceAll('*', '').trim() ?? '';

      // Parse JSON response
      String jsonText = responseText.trim();
      // Remove markdown code blocks if present
      if (jsonText.contains('```json')) {
        jsonText = jsonText.split('```json')[1].split('```')[0].trim();
      } else if (jsonText.contains('```')) {
        jsonText = jsonText.split('```')[1].split('```')[0].trim();
      }

      // Extract JSON object using regex
      final jsonMatch = RegExp(
        r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}',
      ).firstMatch(jsonText);
      if (jsonMatch == null) {
        throw Exception('Could not find JSON object in AI response');
      }

      final jsonString = jsonMatch.group(0) ?? '{}';
      Map<String, dynamic> suggestions;

      try {
        suggestions = jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        // Fallback: try to parse manually if JSON decode fails
        final categoryMatch = RegExp(
          r'"category"\s*:\s*"([^"]+)"',
        ).firstMatch(jsonString);
        final priorityMatch = RegExp(
          r'"priority"\s*:\s*"([^"]+)"',
        ).firstMatch(jsonString);
        final kpaMatch = RegExp(
          r'"kpa"\s*:\s*"([^"]+)"',
        ).firstMatch(jsonString);

        suggestions = {};
        if (categoryMatch != null) {
          suggestions['category'] = categoryMatch.group(1);
        }
        if (priorityMatch != null) {
          suggestions['priority'] = priorityMatch.group(1);
        }
        if (kpaMatch != null) {
          suggestions['kpa'] = kpaMatch.group(1);
        }
      }

      // Close loading dialog
      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
      }

      // Apply suggestions
      if (mounted) {
        setState(() {
          final category = suggestions['category']?.toString().trim();
          if (category != null) {
            if (category == 'Other') {
              _isOtherCategorySelected = true;
              _goalCategory = 'Other';
              _customCategory = null;
              _customCategoryController.clear();
            } else if (_goalCategories.contains(category)) {
              _goalCategory = category;
              _isOtherCategorySelected = false;
              _customCategory = null;
              _customCategoryController.clear();
            }
          }

          final priority = suggestions['priority']?.toString().trim();
          if (priority != null &&
              ['High', 'Medium', 'Low'].contains(priority)) {
            _currentStatus = priority;
          }

          final kpa = suggestions['kpa']?.toString().trim();
          if (kpa != null && _kpaOptions.contains(kpa)) {
            _kpa = kpa.toLowerCase();
          }
        });

        // Show success message in centered dialog
        if (mounted) {
          await _showCenteredSuccessDialog(
            // ignore: use_build_context_synchronously
            context,
            'Suggestions applied successfully!',
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
      }

      if (mounted) {
        await _showCenteredErrorDialog(
          // ignore: use_build_context_synchronously
          context,
          'Error generating suggestions: $e',
        );
      }
    }
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
      // Use custom category if "Other" is selected, otherwise use selected category
      final categoryValue =
          _isOtherCategorySelected &&
              _customCategory != null &&
              _customCategory!.isNotEmpty
          ? _customCategory!.toLowerCase()
          : _goalCategory?.toLowerCase() ?? '';

      GoalCategory category;
      switch (categoryValue) {
        case 'career':
          category = GoalCategory.work;
          break;
        case 'skills':
        case 'learning':
          category = GoalCategory.learning;
          break;
        case 'wellness':
        case 'health':
          category = GoalCategory.health;
          break;
        case 'finance':
        case 'financial':
          category = GoalCategory.personal; // Map finance to personal
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
