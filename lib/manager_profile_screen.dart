// ignore_for_file: deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:pdh/services/database_service.dart';
// import 'package:pdh/models/user_profile.dart'; // Removed as it is not directly used in this file's UI logic.
import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // Disabled - using Cloudinary
// import 'dart:io'; // Removed: use XFile.readAsBytes() for web compatibility

import 'package:pdh/services/cloudinary_service.dart';
import 'package:pdh/design_system/app_components.dart'; // Import AppComponents
import 'package:pdh/design_system/app_typography.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manager Profile',
      theme: ThemeData(
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(
          0xFF040610,
        ), // Set scaffold background color here
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFC10D00),
          secondary: Color(0xFF1F2840),
          surface: Color(0xFF2C3E50), // Ensure only one surface property
          onPrimary: Colors.white,
          onSecondary: Color(0xFFC10D00),
          onSurface: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          fillColor: Colors.white10,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const ManagerProfileScreen(),
    );
  }
}

class ManagerProfileScreen extends StatefulWidget {
  const ManagerProfileScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ManagerProfileScreen> createState() => _ManagerProfileScreenState();
}

class _ManagerProfileScreenState extends State<ManagerProfileScreen> {
  static const List<String> _jobTitleOptions = [
    'Director',
    'Developer',
    'Support Analyst',
    'Learner',
    'UX Designer',
    'AWS Cloud Engineer',
    'Tester',
    'RMB Small Talk Developer',
    'Finance',
    'Business Analyst',
    'Manager',
    'Delivery Manager',
    'Analyst',
    'Sales Person',
    'HR',
    'Junior Analyst',
  ];

  static const List<String> _departmentOptions = [
    'Management',
    'Operations',
    'Finance',
    'HR',
    'Sales',
  ];

  final TextEditingController _fullNameController = TextEditingController();
  String? _selectedJobTitle;
  String? _selectedDepartment;
  final TextEditingController _workEmailController = TextEditingController();
  final TextEditingController _skillsInputController = TextEditingController();
  final TextEditingController _developmentInputController =
      TextEditingController();
  final TextEditingController _careerAspirationsController =
      TextEditingController();
  final TextEditingController _currentProjectsController =
      TextEditingController();
  final TextEditingController _devActivitiesController =
      TextEditingController();
  final TextEditingController _shortGoalsController = TextEditingController();
  final TextEditingController _longGoalsController = TextEditingController();
  final TextEditingController _notificationPrefsController =
      TextEditingController();

  final List<String> _skills = [];
  final List<String> _developmentAreas = [];
  final List<String> _preferredDevActivities =
      []; // For preferred development activities
  String? _selectedLearningStyle;
  String? _profilePhotoUrl;
  String? _notificationFrequency = 'daily';

  bool _isGeneratingDevelopmentPlan = false;
  String _planGenerationPhase = '';
  String? _planGenerationError;
  double _saveButtonScale = 1.0;

  static const String _developmentPlanSystemInstruction =
      '''You are KhonoPal's leadership development copilot. Collaborate with managers to co-create personalized development plans anchored in the context provided (skills, growth areas, projects, aspirations, learning preferences). Always synthesize a practical, strengths-based plan.

Respond ONLY with valid JSON following this schema (no prose outside the JSON):
{
  "narrative": "Overall plan summary in 3-4 sentences.",
  "shortTermGoal": "SMART goal for the next 3-6 months.",
  "longTermGoal": "Ambitious goal or capability for 12-24 months.",
  "careerVision": "How this plan supports the manager's larger aspiration.",
  "currentFocus": "Projects or business priorities the plan reinforces.",
  "developmentAreas": ["Growth area 1", "Growth area 2"],
  "strengthsToLeverage": ["Key strength 1", "Key strength 2"],
  "recommendedActivities": ["Action or resource 1", "Action or resource 2"]
}

Guidelines:
- Keep each string concise but specific.
- Make list items actionable and unique.
- If a field has no data, return an empty string or empty array, but keep the key present.
- Do not include markdown, bullet characters, or explanations outside the JSON.''';

  @override
  void initState() {
    super.initState();
    _loadManagerProfile();
  }

  Future<void> _loadManagerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // First, try to get data from onboarding collection
      // ignore: unused_local_variable
      final onboardingData = await DatabaseService.getOnboardingData(
        userId: user.uid,
        email: user.email,
      );

      // Then get user profile for other fields
      final userProfile = await DatabaseService.getUserProfile(user.uid);

      setState(() {
        _fullNameController.text = userProfile.displayName;
        _selectedJobTitle = _jobTitleOptions.contains(userProfile.jobTitle)
            ? userProfile.jobTitle
            : null;
        _selectedDepartment =
            _departmentOptions.contains(userProfile.department)
            ? userProfile.department
            : null;
        _workEmailController.text = userProfile.email;
        _skills
          ..clear()
          ..addAll(userProfile.skills);
        _developmentAreas
          ..clear()
          ..addAll(userProfile.developmentAreas);
        _careerAspirationsController.text = userProfile.careerAspirations;
        _currentProjectsController.text = userProfile.currentProjects;
        _selectedLearningStyle = userProfile.learningStyle.isNotEmpty
            ? userProfile.learningStyle
            : null;
        _preferredDevActivities
          ..clear()
          ..addAll(userProfile.preferredDevActivities);
        _shortGoalsController.text = userProfile.shortGoals;
        _longGoalsController.text = userProfile.longGoals;
        _notificationFrequency = userProfile.notificationFrequency;
        _profilePhotoUrl =
            (userProfile.profilePhotoUrl != null &&
                userProfile.profilePhotoUrl!.isNotEmpty)
            ? userProfile.profilePhotoUrl
            : null;
        // Ensure UserProfile is recognized as used here.
      });
    } catch (e) {
      if (!mounted) return;
      _showAlertDialog('Error', 'Failed to load profile: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _workEmailController.dispose();
    _skillsInputController.dispose();
    _developmentInputController.dispose();
    _careerAspirationsController.dispose();
    _currentProjectsController.dispose();
    _devActivitiesController.dispose();
    _shortGoalsController.dispose();
    _longGoalsController.dispose();
    _notificationPrefsController.dispose();
    super.dispose();
  }

  void _addTag(TextEditingController controller, List<String> list) {
    if (controller.text.trim().isNotEmpty) {
      setState(() {
        list.add(controller.text.trim());
        controller.clear();
      });
    }
  }

  void _removeTag(List<String> list, int index) {
    setState(() {
      list.removeAt(index);
    });
  }

  void _mergeTagValues(List<String> target, List<String> additions) {
    for (final value in additions) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) continue;
      final exists = target.any(
        (existing) => existing.toLowerCase() == cleaned.toLowerCase(),
      );
      if (!exists) {
        target.add(cleaned);
      }
    }
  }

  Future<void> _showAlertDialog(String title, String message) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3E50),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFC10D00)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  List<_PlanPrepQuestion> _buildPlanPrepQuestions() {
    return [
      _PlanPrepQuestion(
        id: 'short_goals',
        prompt: 'What impact do you want to make in the next 3–6 months?',
        helper:
            'Think in terms of measurable outcomes, behavior shifts, or team health improvements.',
        placeholder:
            'e.g., "Stabilize the new onboarding program and lift CSAT to 92%"',
        controller: _shortGoalsController,
      ),
      _PlanPrepQuestion(
        id: 'long_goals',
        prompt: 'What longer-term role or capability are you building toward?',
        helper:
            'Describe the next role, scope, or leadership identity you are targeting in 12–24 months.',
        placeholder:
            'e.g., "Move into Director of Operations with mastery in data-driven decision making."',
        controller: _longGoalsController,
      ),
      _PlanPrepQuestion(
        id: 'current_projects',
        prompt:
            'Which projects or business priorities should the plan reinforce?',
        helper:
            'Include flagship initiatives, transformation efforts, or KPIs you own.',
        placeholder:
            'e.g., "Launching the AI-enabled customer triage workflow across all regions."',
        controller: _currentProjectsController,
        maxLines: 4,
      ),
      _PlanPrepQuestion(
        id: 'career_aspirations',
        prompt: 'What lights you up about the next chapter of your career?',
        helper:
            'Share personal drivers, leadership philosophies, or experiences you want more of.',
        placeholder:
            'e.g., "Coach emerging leaders and build cultures where experimentation is safe."',
        controller: _careerAspirationsController,
        maxLines: 4,
      ),
    ];
  }

  Future<bool> _showPlanPrepSheet(List<_PlanPrepQuestion> questions) async {
    if (questions.isEmpty) return true;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        int currentIndex = 0;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: StatefulBuilder(
              builder: (context, setModalState) {
                final question = questions[currentIndex];
                final bool isLast = currentIndex == questions.length - 1;

                void goTo(int Function(int) nextIndexBuilder) {
                  setModalState(() {
                    currentIndex = nextIndexBuilder(
                      currentIndex,
                    ).clamp(0, questions.length - 1);
                  });
                }

                void closeWith(bool value) {
                  FocusScope.of(context).unfocus();
                  Navigator.of(sheetContext).pop(value);
                }

                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Material(
                    color: const Color(0xFF040610),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Before we plan…',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Question ${currentIndex + 1} of ${questions.length}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(false),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                12,
                                24,
                                16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    question.prompt,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    question.helper,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: question.controller,
                                    maxLines: question.maxLines,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: question.placeholder,
                                      hintStyle: const TextStyle(
                                        color: Colors.white38,
                                      ),
                                      fillColor: Colors.white10,
                                      filled: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child: Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    if (currentIndex == 0) {
                                      Navigator.of(sheetContext).pop(false);
                                    } else {
                                      goTo((index) => index - 1);
                                    }
                                  },
                                  child: Text(
                                    currentIndex == 0 ? 'Cancel' : 'Back',
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    if (isLast) {
                                      closeWith(true);
                                    } else {
                                      goTo((index) => index + 1);
                                    }
                                  },
                                  child: const Text('Skip for now'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    if (isLast) {
                                      closeWith(true);
                                    } else {
                                      goTo((index) => index + 1);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC10D00),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    isLast ? 'Generate plan' : 'Next question',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _refinePlanResponses(List<_PlanPrepQuestion> questions) async {
    final Map<String, String> payload = {};
    for (final question in questions) {
      final value = question.controller.text.trim();
      if (value.isNotEmpty) {
        payload[question.id] = value;
      }
    }

    if (payload.isEmpty) return;

    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: Content.text(
          'You are a writing coach. Refine each entry for clarity and executive tone without changing meaning. '
          'Respond with JSON using the same keys. Keep each response under 2 sentences.',
        ),
      );

      final response = await model.generateContent([
        Content.text(
          'Refine the following responses and return JSON only:\n${jsonEncode(payload)}',
        ),
      ]);

      final rawText = response.text ?? '';
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
      if (jsonMatch == null) return;
      final decoded = jsonDecode(jsonMatch.group(0)!);
      if (decoded is! Map) return;

      for (final question in questions) {
        final updated = decoded[question.id];
        if (updated is String && updated.trim().isNotEmpty) {
          question.controller.text = updated.trim();
        }
      }
    } catch (_) {
      // If refinement fails, keep the original inputs.
    }
  }

  Future<_DevelopmentPlanResult> _requestDevelopmentPlan(String prompt) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.text(_developmentPlanSystemInstruction),
    );

    final response = await model.generateContent([Content.text(prompt)]);
    final rawText = response.text?.trim() ?? '';
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
    if (jsonMatch == null) {
      throw Exception('Plan response was not in the expected JSON format.');
    }
    final decoded = jsonDecode(jsonMatch.group(0)!);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Plan response could not be parsed.');
    }
    return _DevelopmentPlanResult.fromJson(decoded);
  }

  Future<void> _runPlanPipeline(List<_PlanPrepQuestion> questions) async {
    if (!mounted) return;

    setState(() {
      _isGeneratingDevelopmentPlan = true;
      _planGenerationError = null;
      _planGenerationPhase = 'Polishing your responses...';
    });

    try {
      await _refinePlanResponses(questions);

      if (!mounted) return;
      setState(() {
        _planGenerationPhase = 'Designing your personalized plan...';
      });

      final prompt = _buildDevelopmentPlanPrompt();
      final plan = await _requestDevelopmentPlan(prompt);

      if (!mounted) return;
      setState(() {
        if (plan.shortTermGoal.isNotEmpty) {
          _shortGoalsController.text = plan.shortTermGoal;
        }
        if (plan.longTermGoal.isNotEmpty) {
          _longGoalsController.text = plan.longTermGoal;
        }
        final aspirationText = plan.careerVision.isNotEmpty
            ? plan.careerVision
            : plan.narrative;
        if (aspirationText.isNotEmpty) {
          _careerAspirationsController.text = aspirationText;
        }
        if (plan.currentFocus.isNotEmpty) {
          _currentProjectsController.text = plan.currentFocus;
        }
        _mergeTagValues(_developmentAreas, plan.developmentAreas);
        _mergeTagValues(_skills, plan.strengthsToLeverage);
        _mergeTagValues(_preferredDevActivities, plan.recommendedActivities);
        _planGenerationPhase = '';
        _planGenerationError = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Plan suggestions added to your profile. Review & press Save when ready.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        _isGeneratingDevelopmentPlan = false;
        return;
      }
      setState(() {
        _planGenerationError = e.toString();
        _planGenerationPhase = '';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingDevelopmentPlan = false;
        });
      } else {
        _isGeneratingDevelopmentPlan = false;
      }
    }
  }

  Future<void> _regenerateDevelopmentPlan() async {
    if (_isGeneratingDevelopmentPlan) return;
    final questions = _buildPlanPrepQuestions();
    await _runPlanPipeline(questions);
  }

  String _buildDevelopmentPlanPrompt() {
    final name = _fullNameController.text.trim();
    final jobTitle = _selectedJobTitle ?? '';
    final department = _selectedDepartment ?? '';
    final shortGoals = _shortGoalsController.text.trim();
    final longGoals = _longGoalsController.text.trim();
    final aspirations = _careerAspirationsController.text.trim();
    final currentProjects = _currentProjectsController.text.trim();
    final learningStyle = (_selectedLearningStyle ?? '').trim();

    final List<String> contextLines = [];

    final roleParts = [
      if (jobTitle.isNotEmpty) jobTitle,
      if (department.isNotEmpty) department,
    ];
    if (roleParts.isNotEmpty) {
      contextLines.add('Role context: ${roleParts.join(' • ')}');
    }

    void addListLine(String label, List<String> values) {
      final cleaned = values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (cleaned.isNotEmpty) {
        contextLines.add('$label: ${cleaned.join(', ')}');
      }
    }

    void addLine(String label, String value) {
      if (value.isNotEmpty) {
        contextLines.add('$label: $value');
      }
    }

    addListLine('Key strengths', _skills);
    addListLine('Development priorities', _developmentAreas);
    addLine('Career aspirations', aspirations);
    addLine('Current focus / projects', currentProjects);
    addLine('Short-term goals (3–6 months)', shortGoals);
    addLine('Long-term goals (1–3 years)', longGoals);
    addListLine('Preferred development activities', _preferredDevActivities);
    if (learningStyle.isNotEmpty) {
      contextLines.add('Preferred learning style: $learningStyle');
    }

    if (contextLines.isEmpty) {
      contextLines.add(
        'No structured context captured yet — ask clarifying questions about goals, strengths, and support needs before proposing recommendations.',
      );
    }

    final buffer = StringBuffer();
    final displayName = name.isEmpty ? 'this manager' : name;

    buffer.writeln(
      "Collaborate with $displayName to co-design a personalized development plan that feels achievable but ambitious.",
    );
    buffer.writeln('\nProfile context to anchor on:');
    buffer.writeln(contextLines.map((line) => '- $line').join('\n'));
    buffer.writeln('\nAssistant guardrails:');
    buffer.writeln(
      '- Start by acknowledging what you understood and ask for missing details before prescribing steps.',
    );
    buffer.writeln(
      '- Propose 2–3 focus areas that cover quick wins, capability building, and leadership behaviors tied to measurable outcomes.',
    );
    buffer.writeln(
      '- For each area, outline SMART goals, suggested rituals or resources (courses, mentors, playbooks), and checkpoints (30/60/90 days or 12-week arcs).',
    );
    buffer.writeln(
      '- Suggest how to track progress (metrics, reflections, stakeholder feedback) and where the manager may need support.',
    );
    buffer.writeln(
      '- Close with a motivational nudge plus a question that invites the manager to refine the plan with you.',
    );
    buffer.writeln(
      '\nTone: strengths-based, specific, and collaborative — behave like KhonoPal’s development copilot, not a lecturer.',
    );

    return buffer.toString();
  }

  Widget _buildDevelopmentPlanSummaryCard() {
    final bool shouldShowCard =
        _isGeneratingDevelopmentPlan || _planGenerationError != null;

    if (!shouldShowCard) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI Development Plan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isGeneratingDevelopmentPlan) ...[
            LinearProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFC10D00),
              ),
              backgroundColor: Colors.white12,
            ),
            const SizedBox(height: 12),
            Text(
              _planGenerationPhase.isEmpty
                  ? 'Crafting your personalized development plan...'
                  : _planGenerationPhase,
              style: const TextStyle(color: Colors.white70),
            ),
          ] else if (_planGenerationError != null) ...[
            Text(
              'Could not generate a plan right now.',
              style: TextStyle(
                color: Colors.red.shade300,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _planGenerationError!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please adjust your inputs or try again in a moment.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isGeneratingDevelopmentPlan
                    ? null
                    : _regenerateDevelopmentPlan,
                child: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generateDevelopmentPlan() async {
    final prepQuestions = _buildPlanPrepQuestions();
    final confirmed = await _showPlanPrepSheet(prepQuestions);
    if (confirmed != true) return;
    if (!mounted) return;
    await _runPlanPipeline(prepQuestions);
  }

  Future<void> _removeProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      _showAlertDialog('Error', 'You must be logged in to remove your photo.');
      return;
    }
    try {
      setState(() {
        _profilePhotoUrl = '';
      });
      await user.updatePhotoURL(null);
      await user.reload();
      await _saveProfile(
        showDialog: true,
        successTitle: 'Photo Removed',
        successMessage: 'Your profile photo has been removed.',
      );
    } catch (e) {
      if (!mounted) return;
      _showAlertDialog('Error', 'Failed to remove photo: ${e.toString()}');
    }
  }

  Future<void> _saveProfile({
    bool showDialog = true,
    String? successTitle,
    String? successMessage,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAlertDialog('Error', 'You must be logged in to save your profile.');
      return;
    }

    try {
      final pendingSkill = _skillsInputController.text.trim();
      if (pendingSkill.isNotEmpty && !_skills.contains(pendingSkill)) {
        _skills.add(pendingSkill);
        _skillsInputController.clear();
      }
      final pendingDev = _developmentInputController.text.trim();
      if (pendingDev.isNotEmpty && !_developmentAreas.contains(pendingDev)) {
        _developmentAreas.add(pendingDev);
        _developmentInputController.clear();
      }
      // Fetch the existing user profile to preserve immutable fields
      final existingUserProfile = await DatabaseService.getUserProfile(
        user.uid,
      );

      final updatedProfile = existingUserProfile.copyWith(
        displayName: _fullNameController.text.trim(),
        jobTitle: _selectedJobTitle ?? '',
        department: _selectedDepartment ?? '',
        email: _workEmailController.text.trim(),
        skills: _skills.toList(),
        developmentAreas: _developmentAreas.toList(),
        careerAspirations: _careerAspirationsController.text.trim(),
        currentProjects: _currentProjectsController.text.trim(),
        learningStyle: _selectedLearningStyle ?? '',
        preferredDevActivities: _preferredDevActivities.toList(),
        shortGoals: _shortGoalsController.text.trim(),
        longGoals: _longGoalsController.text.trim(),
        notificationFrequency: _notificationFrequency ?? 'daily',
        goalVisibility: existingUserProfile.goalVisibility,
        leaderboardOptin: existingUserProfile.leaderboardOptin,
        badgeName: existingUserProfile.badgeName,
        celebrationConsent: existingUserProfile.celebrationConsent,
        profilePhotoUrl: _profilePhotoUrl,
      );

      await DatabaseService.updateUserProfile(updatedProfile);
      if (showDialog) {
        _showAlertDialog(
          successTitle ?? 'Profile Saved',
          successMessage ?? 'Your manager profile has been saved successfully!',
        );
      }
    } catch (e) {
      _showAlertDialog('Error', 'Failed to save profile: ${e.toString()}');
    }
  }

  Widget _buildProfileContent() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 64.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1000),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          padding: const EdgeInsets.all(40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  'Profile',
                  style: AppTypography.heading2.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'These fields allow you to set up your identity, preferences, and development context.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.0, color: Colors.white70),
              ),
              const SizedBox(height: 40.0),

              // Profile Photo Section - Centered at the top
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child:
                            (_profilePhotoUrl != null &&
                                _profilePhotoUrl!.isNotEmpty)
                            ? Image.network(
                                _profilePhotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                      'assets/Account_User_Profile/Profile.png',
                                      fit: BoxFit.cover,
                                    ),
                              )
                            : Image.asset(
                                'assets/Account_User_Profile/Profile.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _pickAndUploadImage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white10,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Upload Photo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if ((_profilePhotoUrl ?? '').isNotEmpty)
                          TextButton(
                            onPressed: _removeProfilePhoto,
                            child: const Text('Remove Photo'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40.0),

              // Basic Information Section
              _buildCardSection(
                title: 'Basic Information',
                children: [
                  _buildInputLabel('Full Name'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _fullNameController,
                    hintText: 'Enter your full name',
                  ),
                  const SizedBox(height: 16),
                  _buildJobTitleDropdown(),
                  const SizedBox(height: 16),
                  _buildDepartmentDropdown(),
                  const SizedBox(height: 16),
                  _buildInputLabel('Email Address'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _workEmailController,
                    hintText: 'Work Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),

              // Development & Skills Context Section
              _buildCardSection(
                title: 'Development & Skills Context',
                children: [
                  _buildTaggableInput(
                    label: 'Current Skills / Strengths (taggable list)',
                    controller: _skillsInputController,
                    list: _skills,
                    onAdd: () => _addTag(_skillsInputController, _skills),
                  ),
                  _buildTaggableInput(
                    label:
                        'Areas for Development (self-identified growth areas)',
                    controller: _developmentInputController,
                    list: _developmentAreas,
                    onAdd: () =>
                        _addTag(_developmentInputController, _developmentAreas),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    text: '✨ Generate Personalized Development Plan ✨',
                    onPressed: _isGeneratingDevelopmentPlan
                        ? null
                        : _generateDevelopmentPlan,
                  ),
                  const SizedBox(height: 12),
                  _buildDevelopmentPlanSummaryCard(),
                  const SizedBox(height: 16),
                  _buildTextArea(
                    controller: _careerAspirationsController,
                    hintText: 'Career Aspirations / Future Role',
                  ),
                  _buildTextArea(
                    controller: _currentProjectsController,
                    hintText: 'Current Projects / Focus Areas (optional)',
                  ),
                ],
              ),

              // Goal & Learning Preferences Section
              _buildCardSection(
                title: 'Goal & Learning Preferences',
                children: [
                  _buildLearningStyleDropdown(),
                  _buildPreferredDevActivitiesCheckboxes(),
                  const SizedBox(height: 16),
                  _buildTextArea(
                    controller: _shortGoalsController,
                    hintText: 'Short-Term Goals (next 3–6 months)',
                  ),
                  _buildTextArea(
                    controller: _longGoalsController,
                    hintText: 'Long-Term Goals (1–3 years)',
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationPreferencesDropdown(),
                ],
              ),

              // Action Buttons
              const SizedBox(height: 32.0),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: _saveButtonScale,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Pop-out animation
                          setState(() {
                            _saveButtonScale = 1.1;
                          });
                          await Future.delayed(
                            const Duration(milliseconds: 150),
                          );
                          setState(() {
                            _saveButtonScale = 1.0;
                          });
                          // Save profile after animation
                          _saveProfile();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Save Profile',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildProfileContent();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: AppComponents.backgroundWithImage(
        imagePath: 'assets/khono_bg.png',
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 64.0),
          child: _buildProfileContent(),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24.0),
          ...children.map((child) {
            // Apply bottom padding only if the child is a TextFormField
            if (child is TextFormField) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: child,
              );
            }
            return child;
          }),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(color: Colors.white70, fontSize: 14),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    Color? color,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: color ?? Color.fromARGB(13, 255, 255, 255),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFC10D00), width: 1.0),
        ),
      ),
    );
  }

  Widget _buildJobTitleDropdown() {
    return Theme(
      data: Theme.of(context).copyWith(
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF1F2840)),
          ),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedJobTitle,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'Job Title / Role',
          hintText: 'Select Job Title',
          hintStyle: TextStyle(color: Colors.white),
          filled: true,
          fillColor: Color.fromARGB(13, 255, 255, 255),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Color(0xFFC10D00), width: 1.0),
          ),
        ),
        items: _jobTitleOptions.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedJobTitle = newValue;
          });
        },
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return Theme(
      data: Theme.of(context).copyWith(
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF1F2840)),
          ),
        ),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedDepartment,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          labelText: 'Department / Team',
          hintText: 'Select Department',
          hintStyle: TextStyle(color: Colors.white),
          filled: true,
          fillColor: Color.fromARGB(13, 255, 255, 255),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Color(0xFFC10D00), width: 1.0),
          ),
        ),
        items: _departmentOptions.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedDepartment = newValue;
          });
        },
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: Color.fromARGB(13, 255, 255, 255),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFC10D00), width: 1.0),
        ),
      ),
    );
  }

  Widget _buildActionButton({required String text, VoidCallback? onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFC10D00),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTaggableInput({
    required String label,
    required TextEditingController controller,
    required List<String> list,
    required VoidCallback onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Color.fromARGB(13, 255, 255, 255),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Color.fromARGB(25, 255, 255, 255)),
          ),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              ...list.asMap().entries.map((entry) {
                final index = entry.key;
                final tag = entry.value;
                return Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(color: Color(0xFFC10D00)),
                  ),
                  backgroundColor: const Color(0xFF1F2840),
                  deleteIconColor: Colors.white70,
                  onDeleted: () => _removeTag(list, index),
                );
              }),
              IntrinsicWidth(
                child: TextFormField(
                  controller: controller,
                  onFieldSubmitted: (value) => onAdd(),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Add a tag...',
                    hintStyle: TextStyle(color: Colors.white70),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLearningStyleDropdown() {
    return Theme(
      data: Theme.of(context).copyWith(
        dropdownMenuTheme: DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(
              const Color(0xFF1F2840),
            ), // Changed to WidgetStateProperty
          ),
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue:
            _selectedLearningStyle, // Changed from value to initialValue
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Select Learning Style',
          hintStyle: TextStyle(color: Colors.white),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide.none,
          ),
        ),
        items: const [
          DropdownMenuItem(
            value: null,
            child: Text(
              'Select Learning Style',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          DropdownMenuItem(value: 'visual', child: Text('Visual')),
          DropdownMenuItem(value: 'hands-on', child: Text('Hands-on')),
          DropdownMenuItem(value: 'reading', child: Text('Reading')),
          DropdownMenuItem(
            value: 'collaborative',
            child: Text('Collaborative'),
          ),
        ],
        onChanged: (String? newValue) {
          setState(() {
            _selectedLearningStyle = newValue;
          });
        },
      ),
    );
  }

  Widget _buildPreferredDevActivitiesCheckboxes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferred Development Activities',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildCheckbox('Courses', 'courses'),
            _buildCheckbox('Mentorship', 'mentorship'),
            _buildCheckbox('Projects', 'projects'),
          ],
        ),
      ],
    );
  }

  Widget _buildCheckbox(String title, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _preferredDevActivities.contains(value),
          onChanged: (bool? newValue) {
            setState(() {
              if (newValue == true) {
                _preferredDevActivities.add(value);
              } else {
                _preferredDevActivities.remove(value);
              }
            });
          },
          fillColor: WidgetStateProperty.all(
            const Color(0xFFC10D00),
          ), // Changed to WidgetStateProperty
          checkColor: Colors.white,
        ),
        Text(title, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildNotificationPreferencesDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notification Preferences',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Color.fromARGB(13, 255, 255, 255),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: Colors.transparent),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Theme(
            data: Theme.of(context).copyWith(
              dropdownMenuTheme: DropdownMenuThemeData(
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all(
                    const Color(0xFF1F2840),
                  ),
                ),
              ),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              value: _notificationFrequency,
              hint: const Text(
                'Select frequency',
                style: TextStyle(color: Colors.white30),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              onChanged: (String? newValue) {
                setState(() {
                  _notificationFrequency = newValue;
                });
              },
              items: <String>['Daily', 'Weekly', 'Monthly', 'None']
                  .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value.toLowerCase(),
                      child: Text(value),
                    );
                  })
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      if (!mounted) return;
      _showAlertDialog('Cancelled', 'No image was selected.');
      return; // User cancelled picking
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      _showAlertDialog('Error', 'You must be logged in to upload a photo.');
      return;
    }

    try {
      // Upload to Cloudinary instead of Firebase Storage (use XFile for web compatibility)
      final fileBytes = await pickedFile.readAsBytes();
      final cloudinaryUrl = await CloudinaryService.uploadFileUnsigned(
        bytes: fileBytes,
        fileName:
            'profile_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        goalId: 'profile_photo', // Use a generic goalId for profile photos
      );

      setState(() {
        _profilePhotoUrl = cloudinaryUrl;
      });
      // Update Firebase Auth user photoURL for global usage
      await user.updatePhotoURL(cloudinaryUrl);
      await user.reload();
      await _saveProfile();
    } catch (e) {
      if (!mounted) return;
      _showAlertDialog('Error', 'Failed to upload photo: ${e.toString()}');
    }
  }
}

class _PlanPrepQuestion {
  final String id;
  final String prompt;
  final String helper;
  final String placeholder;
  final TextEditingController controller;
  final int maxLines;

  const _PlanPrepQuestion({
    required this.id,
    required this.prompt,
    required this.helper,
    required this.placeholder,
    required this.controller,
    this.maxLines = 3,
  });
}

class _DevelopmentPlanResult {
  final String narrative;
  final String shortTermGoal;
  final String longTermGoal;
  final String careerVision;
  final String currentFocus;
  final List<String> developmentAreas;
  final List<String> strengthsToLeverage;
  final List<String> recommendedActivities;

  const _DevelopmentPlanResult({
    required this.narrative,
    required this.shortTermGoal,
    required this.longTermGoal,
    required this.careerVision,
    required this.currentFocus,
    required this.developmentAreas,
    required this.strengthsToLeverage,
    required this.recommendedActivities,
  });

  factory _DevelopmentPlanResult.fromJson(Map<String, dynamic> json) {
    List<String> asStringList(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return [value.trim()];
      }
      return [];
    }

    String asString(String key) {
      final value = json[key];
      return value == null ? '' : value.toString().trim();
    }

    return _DevelopmentPlanResult(
      narrative: asString('narrative'),
      shortTermGoal: asString('shortTermGoal'),
      longTermGoal: asString('longTermGoal'),
      careerVision: asString('careerVision'),
      currentFocus: asString('currentFocus'),
      developmentAreas: asStringList(json['developmentAreas']),
      strengthsToLeverage: asStringList(json['strengthsToLeverage']),
      recommendedActivities: asStringList(json['recommendedActivities']),
    );
  }
}
