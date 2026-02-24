// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:convert';

import 'package:flutter/material.dart';
// For ImageFilter
import 'package:pdh/design_system/app_components.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:pdh/services/database_service.dart'; // Import DatabaseService
import 'package:pdh/services/performance_cache_service.dart';
import 'package:image_picker/image_picker.dart'; // Import image_picker
import 'package:pdh/services/cloudinary_service.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // Disabled - using Cloudinary
// import 'package:pdh/models/user_profile.dart'; // Removed unused import

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  // Job title and department options
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

  // Text editing controllers for input fields
  final TextEditingController _fullNameController = TextEditingController();
  String? _selectedJobTitle;
  String? _selectedDepartment;
  final TextEditingController _workEmailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _skillsInputController = TextEditingController();
  final TextEditingController _developmentInputController =
      TextEditingController();
  final TextEditingController _careerAspirationsController =
      TextEditingController();
  final TextEditingController _currentProjectsController =
      TextEditingController();
  final TextEditingController _shortGoalsController = TextEditingController();
  final TextEditingController _longGoalsController = TextEditingController();
  final TextEditingController _badgeNameController = TextEditingController();

  // AI profile helper controllers (used in the question sheet)
  final TextEditingController _aiSkillsController = TextEditingController();
  final TextEditingController _aiDevelopmentAreasController =
      TextEditingController();

  String? _learningStyle;
  String? _notificationFrequency = 'daily';
  String? _goalVisibility = 'private';
  String? _leaderboardOptin = 'no';
  String? _celebrationConsent = 'private';
  String? _profilePhotoUrl; // State variable for profile photo URL
  double _saveButtonScale = 1.0; // Animation scale for save button

  final List<String> _skills = [];
  final List<String> _developmentAreas = [];
  final List<String> _preferredDevActivities = []; // State for checkboxes

  bool _isAiHelpingProfile = false;
  String _aiHelpPhase = '';
  String? _aiHelpError;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _removeProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      await _showCenterNotice('You must be logged in to remove your photo.');
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
      await _showCenterNotice(
        'Failed to remove photo: ${e.toString()}',
        title: 'Error',
      );
    }
  }

  Future<void> _loadUserProfile({int retryCount = 0}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // User not logged in

    try {
      // Add a small delay to avoid race conditions with other Firestore operations
      if (retryCount > 0) {
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }

      final userProfile = await DatabaseService.getUserProfile(user.uid);
      final onboardingData = await DatabaseService.getOnboardingData(
        userId: user.uid,
        email: user.email,
      );
      if (!mounted) return;

      setState(() {
        // Use fullName from onboarding, fallback to displayName
        _fullNameController.text =
            onboardingData['fullName'] ?? userProfile.displayName;
        // Use designation from onboarding for jobTitle, fallback to jobTitle
        final jobTitle = onboardingData['designation'] ?? userProfile.jobTitle;
        _selectedJobTitle = _jobTitleOptions.contains(jobTitle)
            ? jobTitle
            : null;
        _selectedDepartment =
            _departmentOptions.contains(userProfile.department)
            ? userProfile.department
            : null;
        _workEmailController.text = userProfile.email;
        // Use phoneNumber from onboarding first, fallback to userProfile
        _phoneNumberController.text =
            onboardingData['phoneNumber'] ?? userProfile.phoneNumber;
        _skills
          ..clear()
          ..addAll(userProfile.skills);
        _developmentAreas
          ..clear()
          ..addAll(userProfile.developmentAreas);
        _careerAspirationsController.text = userProfile.careerAspirations;
        _currentProjectsController.text = userProfile.currentProjects;
        _learningStyle = userProfile.learningStyle.isNotEmpty
            ? userProfile.learningStyle
            : null;
        _preferredDevActivities
          ..clear()
          ..addAll(userProfile.preferredDevActivities);
        _shortGoalsController.text = userProfile.shortGoals;
        _longGoalsController.text = userProfile.longGoals;
        _notificationFrequency = userProfile.notificationFrequency;
        _goalVisibility = userProfile.goalVisibility;
        _leaderboardOptin = userProfile.leaderboardOptin ? 'yes' : 'no';
        _badgeNameController.text = userProfile.badgeName;
        _celebrationConsent = userProfile.celebrationConsent;
        _profilePhotoUrl =
            (userProfile.profilePhotoUrl != null &&
                userProfile.profilePhotoUrl!.isNotEmpty)
            ? userProfile.profilePhotoUrl
            : null; // Normalize empty to null
      });
    } catch (e) {
      if (!mounted) return;

      // Retry up to 2 times for Firestore internal errors
      final errorString = e.toString();
      if (errorString.contains('INTERNAL ASSERTION FAILED') && retryCount < 2) {
        // Retry with exponential backoff
        await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
        if (mounted) {
          return _loadUserProfile(retryCount: retryCount + 1);
        }
      }

      await _showCenterNotice(
        'Failed to load profile: ${e.toString()}',
        title: 'Error',
      );
      // Show retry option in a separate dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0E1A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              content: const Text(
                'Would you like to retry loading your profile?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                ),
              ),
              actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (mounted) {
                      _loadUserProfile(retryCount: 0);
                    }
                  },
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Color(0xFFC10D00)),
                  ),
                ),
              ],
            );
          },
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _workEmailController.dispose();
    _phoneNumberController.dispose();
    _skillsInputController.dispose();
    _developmentInputController.dispose();
    _careerAspirationsController.dispose();
    _currentProjectsController.dispose();
    _shortGoalsController.dispose();
    _longGoalsController.dispose();
    _badgeNameController.dispose();
    _aiSkillsController.dispose();
    _aiDevelopmentAreasController.dispose();
    super.dispose();
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

  List<_ProfileAssistQuestion> _buildProfileAssistQuestions() {
    // Pre-fill the AI sheet controllers from existing tags
    _aiSkillsController.text = _skills.join(', ');
    _aiDevelopmentAreasController.text = _developmentAreas.join(', ');

    return [
      _ProfileAssistQuestion(
        id: 'shortGoals',
        prompt: 'What do you want to achieve in the next 3–6 months?',
        helper:
            'Share outcomes you can measure (delivery, quality, impact, collaboration).',
        placeholder: 'e.g., "Ship feature X and reduce bugs by 30%."',
        controller: _shortGoalsController,
        maxLines: 3,
      ),
      _ProfileAssistQuestion(
        id: 'longGoals',
        prompt: 'What longer-term goal are you working toward (12–24 months)?',
        helper:
            'Describe the role, capability, or impact you’re building toward.',
        placeholder:
            'e.g., "Grow into a senior engineer who can lead end-to-end delivery."',
        controller: _longGoalsController,
        maxLines: 3,
      ),
      _ProfileAssistQuestion(
        id: 'currentProjects',
        prompt: 'What are your current projects or focus areas (optional)?',
        helper:
            'List key initiatives, responsibilities, or priorities you’re currently working on.',
        placeholder:
            'e.g., "API migration, onboarding improvements, support queue."',
        controller: _currentProjectsController,
        maxLines: 4,
      ),
      _ProfileAssistQuestion(
        id: 'careerAspirations',
        prompt: 'What motivates your next career step?',
        helper:
            'Share what kind of work you want more of and what success looks like for you.',
        placeholder:
            'e.g., "Build products that help customers and mentor newer teammates."',
        controller: _careerAspirationsController,
        maxLines: 4,
      ),
      _ProfileAssistQuestion(
        id: 'skills',
        prompt: 'What are your current skills / strengths?',
        helper:
            'List 5–10 items separated by commas. Keep them specific (tools, domains, strengths).',
        placeholder: 'e.g., "Flutter, Firebase, SQL, Stakeholder management"',
        controller: _aiSkillsController,
        maxLines: 3,
      ),
      _ProfileAssistQuestion(
        id: 'developmentAreas',
        prompt: 'Which areas do you want to develop next?',
        helper:
            'List 3–8 items separated by commas. Prefer skills you can practice.',
        placeholder: 'e.g., "Testing, System design, Public speaking"',
        controller: _aiDevelopmentAreasController,
        maxLines: 3,
      ),
    ];
  }

  Future<bool> _showProfileAssistSheet(
    List<_ProfileAssistQuestion> questions,
  ) async {
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
                  // Use the sheet's context to avoid ancestor lookups on a
                  // deactivated builder context during route dismissal.
                  FocusScope.of(sheetContext).unfocus();
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
                                        'AI profile helper',
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
                                    isLast ? 'Apply refinements' : 'Next',
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

  List<String> _coerceStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      final raw = value.trim();
      final split = raw
          .split(RegExp(r'[,;\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
      return split.isNotEmpty ? split : [raw];
    }
    return [];
  }

  Future<void> _refineAndApplyProfileAssist(
    List<_ProfileAssistQuestion> questions,
  ) async {
    final Map<String, dynamic> payload = {};
    for (final question in questions) {
      final value = question.controller.text.trim();
      if (value.isNotEmpty) {
        payload[question.id] = value;
      }
    }

    if (payload.isEmpty) return;

    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.text(
        'You are a writing coach helping a user complete a professional profile. '
        'Refine each entry for clarity and a confident tone without changing meaning. '
        'Respond with JSON only. Keep answers concise (1–2 sentences each). '
        'For "skills" and "developmentAreas", return arrays of short items (no duplicates). '
        'Return keys exactly as provided.',
      ),
    );

    final response = await model.generateContent([
      Content.text('Refine and normalize this JSON:\n${jsonEncode(payload)}'),
    ]);

    final rawText = response.text ?? '';
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(rawText);
    if (jsonMatch == null) return;
    final decoded = jsonDecode(jsonMatch.group(0)!);
    if (decoded is! Map) return;

    if (!mounted) return;
    setState(() {
      _aiHelpError = null;

      final shortGoals = decoded['shortGoals'];
      if (shortGoals is String && shortGoals.trim().isNotEmpty) {
        _shortGoalsController.text = shortGoals.trim();
      }

      final longGoals = decoded['longGoals'];
      if (longGoals is String && longGoals.trim().isNotEmpty) {
        _longGoalsController.text = longGoals.trim();
      }

      final currentProjects = decoded['currentProjects'];
      if (currentProjects is String && currentProjects.trim().isNotEmpty) {
        _currentProjectsController.text = currentProjects.trim();
      }

      final aspirations = decoded['careerAspirations'];
      if (aspirations is String && aspirations.trim().isNotEmpty) {
        _careerAspirationsController.text = aspirations.trim();
      }

      final skills = _coerceStringList(decoded['skills']);
      final developmentAreas = _coerceStringList(decoded['developmentAreas']);
      _mergeTagValues(_skills, skills);
      _mergeTagValues(_developmentAreas, developmentAreas);

      // Keep the AI sheet fields in sync with the tags after applying.
      _aiSkillsController.text = _skills.join(', ');
      _aiDevelopmentAreasController.text = _developmentAreas.join(', ');
    });
  }

  Future<void> _runAiProfileHelper() async {
    if (_isAiHelpingProfile) return;

    final questions = _buildProfileAssistQuestions();
    final confirmed = await _showProfileAssistSheet(questions);
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _isAiHelpingProfile = true;
      _aiHelpError = null;
      _aiHelpPhase = 'Polishing your answers...';
    });

    try {
      await _refineAndApplyProfileAssist(questions);

      if (!mounted) return;
      setState(() {
        _aiHelpPhase = '';
      });

      // Avoid "Looking up a deactivated widget's ancestor" when the screen is
      // transitioning or was removed while the AI request was in-flight.
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'AI refinements added to your profile. Review & press Save when ready.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiHelpError = e.toString();
        _aiHelpPhase = '';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAiHelpingProfile = false;
        });
      }
    }
  }

  Widget _buildAiProfileHelperSummaryCard() {
    final bool shouldShowCard = _isAiHelpingProfile || _aiHelpError != null;
    if (!shouldShowCard) return const SizedBox.shrink();

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
                'AI Profile Helper',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isAiHelpingProfile) ...[
            LinearProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFC10D00),
              ),
              backgroundColor: Colors.white12,
            ),
            const SizedBox(height: 12),
            Text(
              _aiHelpPhase.isEmpty ? 'Refining your profile...' : _aiHelpPhase,
              style: const TextStyle(color: Colors.white70),
            ),
          ] else if (_aiHelpError != null) ...[
            Text(
              'Could not refine your profile right now.',
              style: TextStyle(
                color: Colors.red.shade300,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _aiHelpError!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isAiHelpingProfile ? null : _runAiProfileHelper,
                child: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return; // User cancelled picking

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      await _showCenterNotice('You must be logged in to upload a photo.');
      return;
    }

    try {
      // Upload to Cloudinary instead of Firebase Storage
      final fileBytes = await image.readAsBytes();
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

      // Try to save profile, only show success if save succeeded
      final saveSuccess = await _saveProfile(showDialog: false);
      if (saveSuccess && mounted) {
        _showProfileSavedDialog(
          title: 'Photo Uploaded',
          message: 'Your profile photo has been uploaded successfully!',
        );
      }
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(
        'Failed to upload photo: ${e.toString()}',
        title: 'Error',
      );
    }
  }

  Future<void> _showCenterNotice(String message, {String? title}) async {
    if (!mounted) return;
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          title: title != null
              ? Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Poppins',
                  ),
                )
              : null,
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                title?.toLowerCase().contains('error') == true ||
                        message.toLowerCase().contains('failed')
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                color:
                    title?.toLowerCase().contains('error') == true ||
                        message.toLowerCase().contains('failed')
                    ? const Color(0xFFC10D00)
                    : Colors.green,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFC10D00)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showProfileSavedDialog({
    String title = 'Profile Saved',
    String message = 'Your profile has been saved successfully!',
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0E1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'OK',
                style: TextStyle(color: Color(0xFFC10D00)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _saveProfile({
    bool showDialog = true,
    String? successTitle,
    String? successMessage,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return false;
      await _showCenterNotice('You must be logged in to save your profile.');
      return false;
    }

    // Flush any pending tag text so the latest entry gets saved even if the user didn't press enter
    final pendingSkill = _skillsInputController.text.trim();
    if (pendingSkill.isNotEmpty && !_skills.contains(pendingSkill)) {
      _skills.add(pendingSkill);
      _skillsInputController.clear();
    }

    final pendingDevelopment = _developmentInputController.text.trim();
    if (pendingDevelopment.isNotEmpty &&
        !_developmentAreas.contains(pendingDevelopment)) {
      _developmentAreas.add(pendingDevelopment);
      _developmentInputController.clear();
    }

    // Fetch the existing user profile to get non-editable fields like totalPoints, level, and badges
    final existingUserProfile = await DatabaseService.getUserProfile(user.uid);

    try {
      // Convert empty string to null for profilePhotoUrl
      final profilePhotoUrlValue = (_profilePhotoUrl?.isEmpty ?? true)
          ? null
          : _profilePhotoUrl;

      // ignore: avoid_print
      print('Saving profile...');
      final updatedProfile = existingUserProfile.copyWith(
        displayName: _fullNameController.text.trim(),
        email: _workEmailController.text.trim(),
        jobTitle: _selectedJobTitle ?? '',
        department: _selectedDepartment ?? '',
        profilePhotoUrl: profilePhotoUrlValue,
        skills: _skills.toList(),
        developmentAreas: _developmentAreas.toList(),
        careerAspirations: _careerAspirationsController.text.trim(),
        currentProjects: _currentProjectsController.text.trim(),
        learningStyle: _learningStyle ?? '',
        preferredDevActivities: _preferredDevActivities.toList(),
        shortGoals: _shortGoalsController.text.trim(),
        longGoals: _longGoalsController.text.trim(),
        notificationFrequency: _notificationFrequency ?? 'daily',
        goalVisibility: _goalVisibility ?? 'private',
        leaderboardOptin: _leaderboardOptin == 'yes',
        badgeName: _badgeNameController.text.trim(),
        celebrationConsent: _celebrationConsent ?? 'private',
      );

      await DatabaseService.updateUserProfile(updatedProfile);

      // Clear the profile cache to ensure fresh data on next fetch
      final cache = PerformanceCacheService();
      cache.clearAll();

      await _loadUserProfile();
      if (showDialog) {
        _showProfileSavedDialog(
          title: successTitle ?? 'Profile Saved',
          message:
              successMessage ?? 'Your profile has been saved successfully!',
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      await _showCenterNotice(
        'Failed to save profile: ${e.toString()}',
        title: 'Error',
      );
      return false;
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(color: Colors.white70, fontSize: 14),
    ); // Equivalent to label class
  }

  Widget _buildInputField({
    required TextEditingController controller,
    String? hintText,
    TextInputType? keyboardType,
    bool readOnly = false,
    int maxLines = 1,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        style: TextStyle(
          color: readOnly ? Colors.white54 : Colors.white,
        ), // text-white / text-white/50
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: const Color.fromARGB(13, 255, 255, 255),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 12.0,
          ), // px-4 py-2
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Color(0xFFC10D00), width: 1.0),
            borderRadius: BorderRadius.circular(8.0),
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildJobTitleDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(13, 255, 255, 255),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.transparent),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedJobTitle,
          hint: const Text(
            'Select job title',
            style: TextStyle(color: Colors.white30),
          ),
          dropdownColor: const Color(0xFF1F2840),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          items: _jobTitleOptions.map((String title) {
            return DropdownMenuItem<String>(value: title, child: Text(title));
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedJobTitle = newValue;
            });
          },
        ),
      ),
    );
  }

  Widget _buildDepartmentDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(13, 255, 255, 255),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.transparent),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedDepartment,
          hint: const Text(
            'Select department',
            style: TextStyle(color: Colors.white30),
          ),
          dropdownColor: const Color(0xFF1F2840),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
          items: _departmentOptions.map((String department) {
            return DropdownMenuItem<String>(
              value: department,
              child: Text(department),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedDepartment = newValue;
            });
          },
        ),
      ),
    );
  }

  // Custom widget for tags input
  Widget _buildTagInput({
    required TextEditingController controller,
    required List<String> tagsList,
    required String hintText,
    required Function(String) onTagAdded,
    required Function(String) onTagRemoved,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display existing tags as chips
        if (tagsList.isNotEmpty) ...[
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: tagsList.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: const TextStyle(color: Color(0xFFC10D00)),
                ),
                backgroundColor: const Color(0xFF1F2840),
                deleteIconColor: Colors.white70,
                onDeleted: () => onTagRemoved(tag),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        // Input field for adding new tags
        _buildInputField(
          controller: controller,
          hintText: hintText,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            final tag = value.trim();
            if (tag.isEmpty) return;
            if (!tagsList.contains(tag)) {
              onTagAdded(tag);
            }
          },
        ),
      ],
    );
  }

  Widget _buildProfileContent() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 32.0), // 2rem auto
        constraints: const BoxConstraints(
          maxWidth: 1000,
        ), // match manager profile width
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                                  const Icon(
                                    Icons.person,
                                    color: Colors.white70,
                                    size: 80,
                                  ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 80,
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
                          side: const BorderSide(
                            color: Color.fromARGB(51, 255, 255, 255),
                          ),
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
            const SizedBox(height: 40),
            // Basic Information Section
            _buildSectionCard(
              children: [
                _buildSectionTitle('Basic Information'),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('Full Name'),
                    _buildInputField(
                      controller: _fullNameController,
                      hintText: 'Enter your full name',
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('Job Title / Role'),
                    _buildJobTitleDropdown(),
                    const SizedBox(height: 24),
                    _buildInputLabel('Department / Team'),
                    _buildDepartmentDropdown(),
                    const SizedBox(height: 24),
                    _buildInputLabel('Work Email'),
                    _buildInputField(
                      controller: _workEmailController,
                      hintText: 'you@company.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('Phone Number (optional)'),
                    _buildInputField(
                      controller: _phoneNumberController,
                      hintText: 'e.g., +27 12 345 6789 or 012 345 6789',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Development & Skills Context Section
            _buildSectionCard(
              children: [
                _buildSectionTitle('Development & Skills Context'),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('Current Skills / Strengths'),
                    const SizedBox(height: 8),
                    _buildTagInput(
                      controller: _skillsInputController,
                      tagsList: _skills,
                      hintText: 'e.g., Python, Project Management',
                      onTagAdded: (tag) {
                        setState(() {
                          _skills.add(tag);
                          _skillsInputController.clear();
                        });
                      },
                      onTagRemoved: (tag) {
                        setState(() {
                          _skills.remove(tag);
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('Areas for Development'),
                    const SizedBox(height: 8),
                    _buildTagInput(
                      controller: _developmentInputController,
                      tagsList: _developmentAreas,
                      hintText: 'e.g., Machine Learning, Leadership',
                      onTagAdded: (tag) {
                        setState(() {
                          _developmentAreas.add(tag);
                          _developmentInputController.clear();
                        });
                      },
                      onTagRemoved: (tag) {
                        setState(() {
                          _developmentAreas.remove(tag);
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isAiHelpingProfile
                          ? null
                          : _runAiProfileHelper,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC10D00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        '✨ AI help me fill my profile ✨',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAiProfileHelperSummaryCard(),
                    const SizedBox(height: 16),
                    _buildInputLabel('Career Aspirations / Future Role'),
                    _buildInputField(
                      controller: _careerAspirationsController,
                      hintText: 'Describe where you see yourself...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel(
                      'Current Projects / Focus Areas (optional)',
                    ),
                    _buildInputField(
                      controller: _currentProjectsController,
                      hintText: 'Share your current projects...',
                      maxLines: 3,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Goal & Learning Preferences Section
            _buildSectionCard(
              children: [
                _buildSectionTitle('Goal & Learning Preferences'),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('Learning Style'),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(13, 255, 255, 255),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.transparent),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _learningStyle,
                          hint: const Text(
                            'Select a style',
                            style: TextStyle(color: Colors.white30),
                          ),
                          dropdownColor: const Color(0xFF1F2840),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              _learningStyle = newValue;
                            });
                          },
                          items:
                              <String>[
                                'Visual',
                                'Hands-on',
                                'Reading',
                                'Collaborative',
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value.toLowerCase(),
                                  child: Text(value),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('Preferred Development Activities'),
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
                    const SizedBox(height: 24),
                    _buildInputLabel('Short-Term Goals (next 3–6 months)'),
                    _buildInputField(
                      controller: _shortGoalsController,
                      hintText: 'Describe your short-term goals...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('Long-Term Goals (1–3 years)'),
                    _buildInputField(
                      controller: _longGoalsController,
                      hintText: 'Describe your long-term goals...',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('Notification Preferences'),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(13, 255, 255, 255),
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.transparent),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _notificationFrequency,
                          hint: const Text(
                            'Select frequency',
                            style: TextStyle(color: Colors.white30),
                          ),
                          dropdownColor: const Color(0xFF1F2840),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white70,
                          ),
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
                    const SizedBox(height: 24),
                    _buildInputLabel('Goal Visibility'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildRadio(
                          'Private',
                          'private',
                          _goalVisibility,
                          (value) => setState(() => _goalVisibility = value),
                        ),
                        _buildRadio(
                          'Manager Only',
                          'manager',
                          _goalVisibility,
                          (value) => setState(() => _goalVisibility = value),
                        ),
                        _buildRadio(
                          'Team Share',
                          'team',
                          _goalVisibility,
                          (value) => setState(() => _goalVisibility = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Gamification & Motivation Section
            _buildSectionCard(
              children: [
                _buildSectionTitle('Gamification & Motivation'),
                const SizedBox(height: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInputLabel('Opt-in to Leaderboards'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildRadio(
                          'Yes',
                          'yes',
                          _leaderboardOptin,
                          (value) => setState(() => _leaderboardOptin = value),
                        ),
                        _buildRadio(
                          'No',
                          'no',
                          _leaderboardOptin,
                          (value) => setState(() => _leaderboardOptin = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('Preferred Badge Display Name'),
                    _buildInputField(
                      controller: _badgeNameController,
                      hintText: 'e.g., Super Coder',
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('Celebration Feed Consent'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildRadio(
                          'Share wins publicly',
                          'public',
                          _celebrationConsent,
                          (value) =>
                              setState(() => _celebrationConsent = value),
                        ),
                        _buildRadio(
                          'Private only',
                          'private',
                          _celebrationConsent,
                          (value) =>
                              setState(() => _celebrationConsent = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Action Buttons
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: AnimatedScale(
                  scale: _saveButtonScale,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: const Color(0xFFC10D00),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFC10D00).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextButton(
                      onPressed: () async {
                        // Pop-out animation
                        setState(() {
                          _saveButtonScale = 1.1;
                        });
                        await Future.delayed(const Duration(milliseconds: 150));
                        setState(() {
                          _saveButtonScale = 1.0;
                        });
                        // Save profile after animation
                        _saveProfile();
                      },
                      child: const Text(
                        'Save Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      // When embedded in MainLayout, return just the content without Scaffold/AppBar/background
      return PopScope(
        canPop: _isBasicInfoComplete(),
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (!didPop && !_isBasicInfoComplete()) {
            await _onWillPop();
          }
        },
        child: _buildProfileContent(),
      );
    }

    // Standalone mode with full Scaffold
    return PopScope(
      canPop: _isBasicInfoComplete(),
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop && !_isBasicInfoComplete()) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: AppComponents.backgroundWithImage(
          imagePath: 'assets/khono_bg.png',
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 64.0,
            ),
            child: _buildProfileContent(),
          ),
        ),
      ),
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
          activeColor: const Color(0xFFC10D00), // text-red-600
          checkColor: Colors.white,
        ),
        Text(title, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildRadio(
    String title,
    String value,
    String? groupValue,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Radio<String>(
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
          activeColor: const Color(0xFFC10D00), // text-red-600
        ),
        Text(title, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  bool _isBasicInfoComplete() {
    return _fullNameController.text.trim().isNotEmpty &&
        _selectedJobTitle != null &&
        _selectedJobTitle!.isNotEmpty &&
        _selectedDepartment != null &&
        _selectedDepartment!.isNotEmpty &&
        _workEmailController.text.trim().isNotEmpty;
  }

  Future<bool> _onWillPop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2840),
          title: const Text(
            'Incomplete Profile',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Your profile is incomplete. Are you sure you want to leave without saving?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Stay',
                style: TextStyle(color: Color(0xFFC10D00)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Leave',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      },
    );
    return shouldLeave ?? false;
  }
}

class _ProfileAssistQuestion {
  final String id;
  final String prompt;
  final String helper;
  final String placeholder;
  final TextEditingController controller;
  final int maxLines;

  const _ProfileAssistQuestion({
    required this.id,
    required this.prompt,
    required this.helper,
    required this.placeholder,
    required this.controller,
    this.maxLines = 3,
  });
}
