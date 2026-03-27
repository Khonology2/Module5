import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/utils/firestore_web_circuit_breaker.dart';
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
import 'package:pdh/widgets/ai_generation_indicator.dart';

/// Theme-local colors for [MyGoalWorkspaceScreen] (light vs dark surfaces and text).
class _GoalWorkspacePalette {
  const _GoalWorkspacePalette({
    required this.widgetBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.borderColor,
    required this.chipBg,
    required this.chipDisabledBg,
    required this.dropdownMenuBg,
    required this.smartBadgeBg,
    required this.iconMuted,
  });

  final Color widgetBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color borderColor;
  final Color chipBg;
  final Color chipDisabledBg;
  final Color dropdownMenuBg;
  final Color smartBadgeBg;
  final Color iconMuted;

  static const Color _darkWidget = Color(0xFF3D3F40);

  static _GoalWorkspacePalette of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return _GoalWorkspacePalette(
        widgetBg: _darkWidget,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        borderColor: Colors.white.withValues(alpha: 0.2),
        chipBg: _darkWidget,
        chipDisabledBg: _darkWidget,
        dropdownMenuBg: _darkWidget,
        smartBadgeBg: _darkWidget,
        iconMuted: AppColors.textSecondary,
      );
    }
    return _GoalWorkspacePalette(
      widgetBg: Colors.white.withValues(alpha: 0.92),
      textPrimary: Colors.black,
      textSecondary: Colors.black,
      borderColor: Colors.black.withValues(alpha: 0.15),
      chipBg: Colors.grey.shade300,
      chipDisabledBg: Colors.grey.shade400,
      dropdownMenuBg: Colors.white,
      smartBadgeBg: Colors.white.withValues(alpha: 0.95),
      iconMuted: Colors.black54,
    );
  }
}

class MyGoalWorkspaceScreen extends StatefulWidget {
  final bool embedded;

  /// When true, use manager sidebar and [managerGwMenuRoute] (for manager Goal Workspace menu).
  final bool forManagerGwMenu;
  final String? managerGwMenuRoute;
  final bool forAdminOversight;
  final String? selectedManagerId;

  const MyGoalWorkspaceScreen({
    super.key,
    this.embedded = false,
    this.forManagerGwMenu = false,
    this.managerGwMenuRoute,
    this.forAdminOversight = false,
    this.selectedManagerId,
  });

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
  bool _smartScoresGenerated = false; // Track if AI has generated scores

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
  String? _kpa; // 'operational' | 'customer' | 'financial' | 'organisational' | 'people'
  String? _customCategory; // For "Other" category custom input
  bool _isOtherCategorySelected = false;
  bool _isSavingGoal = false;

  // Lists for dropdowns
  final List<String> _goalCategories = [
    'Career',
    'Skills',
    'Wellness',
    'Finance',
    'Other',
  ];
  final List<String> _kpaOptions = Goal.kpaKeys
      .map((k) => Goal.kpaKeyToLabel[k] ?? k)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    // Ensure role is loaded before building
    RoleService.instance.ensureRoleLoaded();
    // Precache heavy assets to avoid initial jank/spinner when opening the workspace
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        precacheImage(const AssetImage('assets/khono_bg.png'), context);
        precacheImage(
          const AssetImage('assets/light_mode_bg.png'),
          context,
        );
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
    // For Target Date (End Date), restrict selection to dates after Start Date
    DateTime? firstDate;
    DateTime? initialDate;

    if (!isStartDate && _startDate != null) {
      // End date must be after start date - set firstDate to the day after start date
      firstDate = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      ).add(const Duration(days: 1));
      // Set initial date to be a reasonable default after start date
      initialDate = firstDate.isBefore(DateTime.now())
          ? DateTime.now()
          : firstDate;
    } else {
      firstDate = DateTime(2000);
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(2101),
      builder: (BuildContext context, Widget? child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        const darkSurface = Color(0xFF3D3F40);
        return Theme(
          data: isDark
              ? ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(
                    primary: AppColors.activeColor,
                    onPrimary: Colors.white,
                    surface: darkSurface,
                    onSurface: AppColors.textPrimary,
                  ),
                  dialogTheme: const DialogThemeData(
                    backgroundColor: darkSurface,
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.activeColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
                  dialogTheme: const DialogThemeData(
                    backgroundColor: Colors.white,
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
          // If target date is already set and is before or equal to the new start date,
          // clear it so user must select a new target date
          if (_targetDate != null && !_targetDate!.isAfter(picked)) {
            _targetDate = null;
          }
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
      initialData: RoleService.instance.cachedRole ?? 'employee',
      builder: (context, roleSnapshot) {
        final role =
            roleSnapshot.data ?? RoleService.instance.cachedRole ?? 'employee';
        final items = widget.forManagerGwMenu && widget.managerGwMenuRoute != null
            ? SidebarConfig.managerItems
            : SidebarConfig.getItemsForRole(role);
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

        final routeName = widget.forManagerGwMenu && widget.managerGwMenuRoute != null
            ? widget.managerGwMenuRoute!
            : '/my_goal_workspace';
        final gw = _GoalWorkspacePalette.of(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AppScaffold(
          title: 'Goal Workspace',
          showAppBar: false,
          embedded: widget.embedded,
          items: items,
          currentRouteName: routeName,
          tutorialStepIndex: tutorialParams['tutorialStepIndex'] as int?,
          sidebarTutorialKeys: null,
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
            imagePath: isDark
                ? 'assets/khono_bg.png'
                : 'assets/light_mode_bg.png',
            blurSigma: 0,
            gradientColors: isDark
                ? null
                : [Colors.transparent, Colors.transparent],
            child: SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Personal Development Goal',
                    style: AppTypography.heading2.copyWith(
                      color: gw.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionCard(
                    gw,
                    children: [
                      _buildTextFieldWithGenerate(
                        gw,
                        controller: _goalTitleController,
                        hintText: 'Enter your development goal title (required)',
                        onGenerate: () =>
                            _showGenerateDescriptionDialog(context),
                      ),
                      _buildTextField(
                        gw,
                        controller: _goalDescriptionController,
                        hintText: 'Describe your goal in detail (optional)...',
                        maxLines: 5,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader('Goal Details', gw),
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
                    gw,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateInput(
                              gw,
                              context,
                              'Start Date',
                              _startDate,
                              isStartDate: true,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _buildDateInput(
                              gw,
                              context,
                              'Target Date (required)',
                              _targetDate,
                              isStartDate: false,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildCategoryDropdown(gw),
                      _buildDropdownField(
                        gw,
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
                        gw,
                        hintText: 'Select Key Performance Area',
                        value: Goal.kpaLabel(_kpa),
                        items: _kpaOptions,
                        onChanged: (String? newValue) {
                          setState(() {
                            _kpa = Goal.normalizeKpaKey(newValue);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSmartCriteriaSection(gw),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader('Dependencies & Prerequisites', gw),
                  _buildSectionCard(
                    gw,
                    children: [
                      _buildTextField(
                        gw,
                        controller: _dependenciesController,
                        hintText:
                            'List any dependencies or prerequisites needed to achieve this goal\n\ne.g., Complete certification course, Save \$5000, Learn specific skills...',
                        maxLines: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSectionHeader('Success Metrics', gw),
                  _buildSectionCard(
                    gw,
                    children: [
                      _buildTextField(
                        gw,
                        controller: _successMetricsController,
                        hintText: 'Define specific metrics or milestones...',
                        maxLines: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'You can create a goal with just a title and target date. '
                      'Suggest and Generate are optional.',
                      style: AppTypography.bodySmall.copyWith(
                        color: gw.textSecondary,
                      ),
                    ),
                  ),
                  _buildSectionCard(gw, children: [_buildActionButtons(gw)]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, _GoalWorkspacePalette gw) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        style: AppTypography.heading4.copyWith(color: gw.textPrimary),
      ),
    );
  }

  Widget _buildSectionCard(
    _GoalWorkspacePalette gw, {
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gw.widgetBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gw.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField(
    _GoalWorkspacePalette gw, {
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: gw.widgetBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: gw.borderColor,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          style: AppTypography.bodyMedium.copyWith(
            color: gw.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: gw.textSecondary,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFieldWithGenerate(
    _GoalWorkspacePalette gw, {
    required TextEditingController controller,
    required String hintText,
    required VoidCallback onGenerate,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: gw.widgetBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: gw.borderColor,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: TextField(
          controller: controller,
          style: AppTypography.bodyMedium.copyWith(
            color: gw.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: gw.textSecondary,
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
    String currentPhase = '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final gw = _GoalWorkspacePalette.of(context);
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

              setDialogState(() {
                isGenerating = true;
                currentPhase = 'Generating description...';
              });

              // Simulate phase progression with delays
              Future<void> updatePhase(String phase) async {
                setDialogState(() {
                  currentPhase = phase;
                });
                await Future.delayed(const Duration(milliseconds: 800));
              }

              try {
                await updatePhase('Generating description...');

                // Initialize Firebase AI model
                final model = FirebaseAI.googleAI().generativeModel(
                  model: 'gemini-2.5-flash',
                  systemInstruction: Content.text(
                    'You are an AI assistant specialized in creating comprehensive personal development goal plans and evaluating SMART criteria. '
                    'When given a goal title, you must generate four components:\n\n'
                    '1. DESCRIPTION: A detailed and actionable description of the goal (no more than 5 sentences). '
                    'Be concise but thorough, making it comprehensive, motivating, and including specific steps or considerations.\n\n'
                    '2. DEPENDENCIES AND PREREQUISITES: Exactly 5 dependencies or prerequisites needed to achieve this goal. '
                    'Format each as a bullet point starting with "-" or "•". Be specific and actionable.\n\n'
                    '3. SUCCESS METRICS: Specific, measurable metrics or milestones that indicate successful completion of this goal. '
                    'Provide a substantial amount of detail with clear, quantifiable indicators.\n\n'
                    '4. SMART SCORES: Based on the goal title, description, dependencies, prerequisites, and success metrics, evaluate and assign a score from 1-5 for each SMART criterion:\n'
                    '   - clarity (Specific): How clear and well-defined is the goal? (1=vague, 3=some detail, 5=precise deliverable & scope)\n'
                    '   - measurability (Measurable): Can progress be tracked? (1=no KPI, 3=KPI w/o baseline/target, 5=KPI+baseline+target+source)\n'
                    '   - achievability (Achievable): Is the goal realistic? (1=unlikely, 3=stretch, 5=realistic with resources)\n'
                    '   - relevance (Relevant): Does it align with values/role/OKR? (1=not aligned, 3=indirect, 5=direct OKR/competency fit)\n'
                    '   - timeline (Time-bound): Is there a clear deadline? (1=no date, 3=date tight, 5=realistic + milestones)\n\n'
                    'Respond in this EXACT JSON format (no other text):\n'
                    '{"description": "the goal description here", "dependencies": "• First dependency\\n• Second dependency\\n• Third dependency\\n• Fourth dependency\\n• Fifth dependency", "successMetrics": "the success metrics here", "smartScores": {"clarity": 3, "measurability": 4, "achievability": 4, "relevance": 5, "timeline": 3}}',
                  ),
                );

                final prompt = [
                  Content.text(
                    'Generate a comprehensive plan for this personal development goal: $goalTitle\n\n'
                    'First, create the description, 5 dependencies/prerequisites, and success metrics. '
                    'Then, based on the complete goal information (title, description, dependencies, prerequisites, and success metrics you generated), '
                    'evaluate and assign SMART criteria scores (1-5 for each: clarity, measurability, achievability, relevance, timeline). '
                    'The SMART scores should reflect how well the goal meets each criterion based on all the information provided.',
                  ),
                ];

                await updatePhase(
                  'Generating dependencies and prerequisites...',
                );

                final response = await model.generateContent(prompt);
                final responseText =
                    response.text?.replaceAll('*', '').trim() ?? '';

                await updatePhase('Selecting SMART verification scores...');

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

                    await updatePhase('Generating success metrics...');

                    // Extract and set SMART scores
                    final smartScores = generatedData['smartScores'];
                    if (smartScores is Map<String, dynamic>) {
                      setState(() {
                        _clarity = _parseSmartScore(smartScores['clarity'], 3);
                        _measurability = _parseSmartScore(
                          smartScores['measurability'],
                          3,
                        );
                        _achievability = _parseSmartScore(
                          smartScores['achievability'],
                          3,
                        );
                        _relevance = _parseSmartScore(
                          smartScores['relevance'],
                          3,
                        );
                        _timeline = _parseSmartScore(
                          smartScores['timeline'],
                          3,
                        );
                        _smartScoresGenerated =
                            true; // Mark that AI has generated scores
                      });
                    } else {
                      // If no SMART scores in response, mark as not generated
                      setState(() {
                        _smartScoresGenerated = false;
                      });
                    }

                    await updatePhase('Complete!');
                    await Future.delayed(const Duration(milliseconds: 500));

                    // Close the dialog
                    // ignore: use_build_context_synchronously
                    Navigator.of(dialogContext).pop();

                    // Show success message in centered dialog
                    if (mounted) {
                      await _showCenteredSuccessDialog(
                        // ignore: use_build_context_synchronously
                        context,
                        'Goal description, dependencies, success metrics, and SMART scores generated successfully!',
                      );
                    }
                  } else {
                    // Fallback: if JSON parsing fails, try to extract description only
                    _goalDescriptionController.text = responseText;
                    // Don't set SMART scores if parsing fails - keep them unselected
                    setState(() {
                      _smartScoresGenerated = false;
                    });

                    // Close the dialog
                    // ignore: use_build_context_synchronously
                    Navigator.of(dialogContext).pop();

                    // Show success message
                    if (mounted) {
                      await _showCenteredSuccessDialog(
                        // ignore: use_build_context_synchronously
                        context,
                        'Goal description generated. Dependencies, metrics, and SMART scores could not be parsed.',
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
              backgroundColor: gw.widgetBg,
              title: Text(
                'Generate Goal Description',
                style: AppTypography.heading4.copyWith(
                  color: gw.textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: AppTypography.bodyMedium.copyWith(
                        color: gw.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Goal Title',
                        labelStyle: AppTypography.bodyMedium.copyWith(
                          color: gw.textSecondary,
                        ),
                        hintText: 'Enter the goal title',
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color: gw.textSecondary,
                        ),
                        filled: true,
                        fillColor: gw.widgetBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: gw.borderColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: gw.borderColor,
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
                      AIGenerationIndicator(
                        currentPhase: currentPhase,
                        onPhaseChange: (phase) {
                          setDialogState(() => currentPhase = phase);
                        },
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
                    style: TextStyle(color: gw.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: isGenerating ? null : generateDescription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
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
    _GoalWorkspacePalette gw,
    BuildContext context,
    String hintText,
    DateTime? date, {
    required bool isStartDate,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: gw.widgetBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: gw.borderColor,
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
                      ? gw.textPrimary
                      : gw.textSecondary,
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

  Widget _buildCategoryDropdown(_GoalWorkspacePalette gw) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isOtherCategorySelected) ...[
            TextField(
              controller: _customCategoryController,
              style: AppTypography.bodyMedium.copyWith(
                color: gw.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Category (Other)',
                labelStyle: AppTypography.bodyMedium.copyWith(
                  color: gw.textSecondary,
                ),
                hintText: 'Enter custom category',
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: gw.textSecondary,
                ),
                filled: true,
                fillColor: gw.widgetBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: gw.borderColor,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: gw.borderColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
                contentPadding: const EdgeInsets.all(16),
                suffixIcon: IconButton(
                  icon: Icon(Icons.close, color: gw.iconMuted),
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
              gw,
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

  Widget _buildDropdownField(
    _GoalWorkspacePalette gw, {
    required String hintText,
    required String? value,
    required List<String>? items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: gw.widgetBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: gw.borderColor,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: gw.dropdownMenuBg,
          style: AppTypography.bodyMedium.copyWith(
            color: gw.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: gw.textSecondary,
            ),
            border: InputBorder.none,
          ),
          icon: Icon(Icons.keyboard_arrow_down, color: gw.iconMuted),
          onChanged: onChanged,
          items: (items ?? const <String>[]).map<DropdownMenuItem<String>>((
            String value,
          ) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: gw.textPrimary,
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
        final gw = _GoalWorkspacePalette.of(dialogContext);
        return AlertDialog(
          backgroundColor: gw.widgetBg,
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
                    color: gw.textPrimary,
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
        final gw = _GoalWorkspacePalette.of(dialogContext);
        return AlertDialog(
          backgroundColor: gw.widgetBg,
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
                    color: gw.textPrimary,
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
      builder: (ctx) {
        final gw = _GoalWorkspacePalette.of(ctx);
        return Center(
          child: Material(
            color: gw.widgetBg,
            borderRadius: BorderRadius.circular(12),
            elevation: 4,
            child: const Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.activeColor,
                ),
              ),
            ),
          ),
        );
      },
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
          '3. Key Performance Area (KPA): Choose ONE from these exact options: Operational Excellence, Customer Excellence, Financial Excellence, Organisational Excellence, or People Excellence.\n\n'
          'Respond ONLY with a JSON object in this exact format (no other text):\n'
          '{"category": "Career|Skills|Wellness|Finance|Other", "priority": "High|Medium|Low", "kpa": "Operational Excellence|Customer Excellence|Financial Excellence|Organisational Excellence|People Excellence"}',
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
          final normalizedKpa = Goal.normalizeKpaKey(kpa);
          if (normalizedKpa != null) _kpa = normalizedKpa;
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

  Widget _buildSmartCriteriaSection(_GoalWorkspacePalette gw) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: gw.widgetBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gw.borderColor),
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
                    color: gw.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: gw.smartBadgeBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: gw.borderColor),
                  ),
                  child: Text(
                    _smartScoresGenerated
                        ? 'SMART: ${_computeSmartTotal()}/25'
                        : 'SMART: Not evaluated',
                    style: AppTypography.bodySmall.copyWith(
                      color: _smartScoresGenerated
                          ? gw.textPrimary
                          : gw.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildScoreSelector(
              gw,
              title: 'Specific - Goal is clear and well-defined',
              value: _smartScoresGenerated ? _clarity : 0, // 0 means unselected
              onChanged: null, // Disabled - AI will set scores
              helper: '1=vague, 3=some detail, 5=precise deliverable & scope',
              enabled: false,
              aiGenerated: _smartScoresGenerated,
            ),
            _buildScoreSelector(
              gw,
              title: 'Measurable - Progress can be tracked',
              value: _smartScoresGenerated
                  ? _measurability
                  : 0, // 0 means unselected
              onChanged: null, // Disabled - AI will set scores
              helper:
                  '1=no KPI, 3=KPI w/o baseline/target, 5=KPI+baseline+target+source',
              enabled: false,
              aiGenerated: _smartScoresGenerated,
            ),
            _buildScoreSelector(
              gw,
              title: 'Achievable - Goal is realistic and attainable',
              value: _smartScoresGenerated
                  ? _achievability
                  : 0, // 0 means unselected
              onChanged: null, // Disabled - AI will set scores
              helper: '1=unlikely, 3=stretch, 5=realistic with resources',
              enabled: false,
              aiGenerated: _smartScoresGenerated,
            ),
            _buildScoreSelector(
              gw,
              title: 'Relevant - Goal aligns with your values/role/OKR',
              value: _smartScoresGenerated
                  ? _relevance
                  : 0, // 0 means unselected
              onChanged: null, // Disabled - AI will set scores
              helper: '1=not aligned, 3=indirect, 5=direct OKR/competency fit',
              enabled: false,
              aiGenerated: _smartScoresGenerated,
            ),
            _buildScoreSelector(
              gw,
              title: 'Time-bound - Goal has a clear deadline',
              value: _smartScoresGenerated
                  ? _timeline
                  : 0, // 0 means unselected
              onChanged: null, // Disabled - AI will set scores
              helper: '1=no date, 3=date tight, 5=realistic + milestones',
              enabled: false,
              aiGenerated: _smartScoresGenerated,
            ),
          ],
        ),
      ),
    );
  }

  int _computeSmartTotal() {
    if (!_smartScoresGenerated) {
      return 0; // Return 0 if scores haven't been generated
    }
    return _clarity + _measurability + _achievability + _relevance + _timeline;
  }

  int _parseSmartScore(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) {
      return value.clamp(1, 5);
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed.clamp(1, 5);
      }
    }
    return defaultValue;
  }

  Widget _buildScoreSelector(
    _GoalWorkspacePalette gw, {
    required String title,
    required int value,
    required ValueChanged<int>? onChanged,
    String? helper,
    bool enabled = true,
    bool aiGenerated = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyLarge.copyWith(
              color: gw.textPrimary,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(
              helper,
              style: AppTypography.bodySmall.copyWith(
                color: gw.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(5, (index) {
              final score = index + 1;
              final selected =
                  value == score && value > 0; // Only selected if value > 0
              // Use red color #C10D00 for AI-generated selections
              final selectedColor = aiGenerated && selected
                  ? const Color(0xFFC10D00)
                  : AppColors.activeColor;
              return ChoiceChip(
                label: Text(
                  '$score',
                  style: AppTypography.bodyMedium.copyWith(
                    color: enabled
                        ? (selected
                              ? Colors.white
                              : gw.textSecondary)
                        : (selected
                              ? Colors.white
                              : gw.textSecondary.withValues(alpha: 0.5)),
                  ),
                ),
                selected: selected,
                onSelected: enabled ? (_) => onChanged?.call(score) : null,
                selectedColor: selectedColor,
                backgroundColor: gw.chipBg,
                disabledColor: gw.chipDisabledBg,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: selected
                        ? selectedColor
                        : (enabled
                              ? gw.borderColor
                              : gw.borderColor.withValues(alpha: 0.5)),
                    width: selected ? 2 : 1,
                  ),
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
    if (_isSavingGoal) return;
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
      setState(() {
        _isSavingGoal = true;
      });
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
        builder: (ctx) {
          final gw = _GoalWorkspacePalette.of(ctx);
          return AlertDialog(
            backgroundColor: gw.widgetBg,
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
                      color: gw.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );

      await DatabaseService.createGoal(goal);

      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        // Navigate back to dashboard; managers go to manager portal to avoid "Access restricted"
        final targetRoute = widget.forManagerGwMenu
            ? '/manager_portal'
            : '/employee_dashboard';
        navigator.pushNamedAndRemoveUntil(
          targetRoute,
          (route) => false,
        );
      }
    } catch (e) {
      // Close dialog first; unfocus to avoid focus traversal null errors when tree updates.
      try {
        if (mounted) {
          FocusScope.of(context).unfocus();
          Navigator.of(context).pop();
        }
      } catch (_) {}

      if (mounted) {
        final msg = e.toString();
        String userMsg = 'Couldn\'t create goal. Please try again.';
        final isFirestoreInternalState =
            msg.contains('INTERNAL ASSERTION') || msg.contains('Unexpected state');
        if (msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED')) {
          userMsg = 'Permission denied. Make sure you\'re signed in and try again.';
        } else if (msg.contains('unavailable') || msg.contains('network')) {
          userMsg = 'Network issue. Check your connection and try again.';
        } else if (isFirestoreInternalState) {
          if (kIsWeb) {
            userMsg = 'Temporary Firestore issue on web. Reload the page and try creating the goal again.';
            FirestoreWebCircuitBreaker.maybeReload(e);
          } else {
            userMsg = 'Temporary issue. Wait a moment and try again.';
          }
        }
        final message = userMsg;
        // Defer SnackBar to next frame so focus traversal doesn't see a partially updated tree.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 6),
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingGoal = false;
        });
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

  Widget _buildActionButtons(_GoalWorkspacePalette gw) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: gw.textPrimary,
              side: BorderSide(color: gw.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSavingGoal ? null : _saveGoal,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(_isSavingGoal ? 'Creating...' : 'Create Goal'),
          ),
        ),
      ],
    );
  }
}
