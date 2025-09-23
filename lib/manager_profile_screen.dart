// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/database_service.dart';
// import 'package:pdh/models/user_profile.dart'; // Removed as it is not directly used in this file's UI logic.
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io'; // Import for File

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
        fontFamily: 'Inter',
        scaffoldBackgroundColor: const Color(0xFF040610), // Set scaffold background color here
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
  const ManagerProfileScreen({super.key});

  @override
  State<ManagerProfileScreen> createState() => _ManagerProfileScreenState();
}

class _ManagerProfileScreenState extends State<ManagerProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _workEmailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _skillsInputController = TextEditingController();
  final TextEditingController _developmentInputController = TextEditingController();
  final TextEditingController _careerAspirationsController = TextEditingController();
  final TextEditingController _currentProjectsController = TextEditingController();
  final TextEditingController _devActivitiesController = TextEditingController();
  final TextEditingController _shortGoalsController = TextEditingController();
  final TextEditingController _longGoalsController = TextEditingController();
  final TextEditingController _notificationPrefsController = TextEditingController();
  final TextEditingController _goalVisibilityController = TextEditingController();
  final TextEditingController _leaderboardOptinController = TextEditingController();
  final TextEditingController _badgeNameController = TextEditingController();
  final TextEditingController _celebrationConsentController = TextEditingController();

  final List<String> _skills = [];
  final List<String> _developmentAreas = [];
  final List<String> _preferredDevActivities = []; // For preferred development activities
  String? _selectedLearningStyle;
  String? _profilePhotoUrl;
  String? _leaderboardOptin = 'no';
  String? _celebrationConsent = 'private';
  String? _notificationFrequency = 'daily';
  String? _goalVisibility = 'private';

  @override
  void initState() {
    super.initState();
    _loadManagerProfile();
  }

  Future<void> _loadManagerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userProfile = await DatabaseService.getUserProfile(user.uid);
      setState(() {
        _fullNameController.text = userProfile.displayName;
        _jobTitleController.text = userProfile.jobTitle;
        _departmentController.text = userProfile.department;
        _workEmailController.text = userProfile.email;
        _phoneNumberController.text = userProfile.phoneNumber;
        _skills.addAll(userProfile.skills);
        _developmentAreas.addAll(userProfile.developmentAreas);
        _careerAspirationsController.text = userProfile.careerAspirations;
        _currentProjectsController.text = userProfile.currentProjects;
        _selectedLearningStyle = userProfile.learningStyle.isNotEmpty ? userProfile.learningStyle : null;
        _preferredDevActivities.addAll(userProfile.preferredDevActivities);
        _shortGoalsController.text = userProfile.shortGoals;
        _longGoalsController.text = userProfile.longGoals;
        _notificationFrequency = userProfile.notificationFrequency;
        _goalVisibility = userProfile.goalVisibility;
        _leaderboardOptin = userProfile.leaderboardOptin ? 'yes' : 'no';
        _badgeNameController.text = userProfile.badgeName;
        _celebrationConsent = userProfile.celebrationConsent;
        _profilePhotoUrl = userProfile.profilePhotoUrl;
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
    _jobTitleController.dispose();
    _departmentController.dispose();
    _workEmailController.dispose();
    _phoneNumberController.dispose();
    _skillsInputController.dispose();
    _developmentInputController.dispose();
    _careerAspirationsController.dispose();
    _currentProjectsController.dispose();
    _devActivitiesController.dispose();
    _shortGoalsController.dispose();
    _longGoalsController.dispose();
    _notificationPrefsController.dispose();
    _goalVisibilityController.dispose();
    _leaderboardOptinController.dispose();
    _badgeNameController.dispose();
    _celebrationConsentController.dispose();
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
              child: const Text('OK', style: TextStyle(color: Color(0xFFC10D00))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _generateDevelopmentPlan() {
    _showAlertDialog('Feature Unavailable', 'The development plan generation feature is not currently active. You can integrate your own API to enable this functionality.');
  }

  void _draftMotivationalMessage() {
    _showAlertDialog('Feature Unavailable', 'The motivational message drafting feature is not currently active. You can integrate your own API to enable this functionality.');
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showAlertDialog('Error', 'You must be logged in to save your profile.');
      return;
    }

    try {
      // Fetch the existing user profile to preserve immutable fields
      final existingUserProfile = await DatabaseService.getUserProfile(user.uid);

      final updatedProfile = existingUserProfile.copyWith(
        displayName: _fullNameController.text.trim(),
        jobTitle: _jobTitleController.text.trim(),
        department: _departmentController.text.trim(),
        email: _workEmailController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        skills: _skills.toList(),
        developmentAreas: _developmentAreas.toList(),
        careerAspirations: _careerAspirationsController.text.trim(),
        currentProjects: _currentProjectsController.text.trim(),
        learningStyle: _selectedLearningStyle ?? '',
        preferredDevActivities: _preferredDevActivities.toList(),
        shortGoals: _shortGoalsController.text.trim(),
        longGoals: _longGoalsController.text.trim(),
        notificationFrequency: _notificationFrequency ?? 'daily',
        goalVisibility: _goalVisibility ?? 'private',
        leaderboardOptin: _leaderboardOptin == 'yes',
        badgeName: _badgeNameController.text.trim(),
        celebrationConsent: _celebrationConsent ?? 'private',
        profilePhotoUrl: _profilePhotoUrl,
      );

      await DatabaseService.updateUserProfile(updatedProfile);
      _showAlertDialog('Profile Saved', 'Your manager profile has been saved successfully!');
    } catch (e) {
      _showAlertDialog('Error', 'Failed to save profile: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Background container with blur effect
          Positioned.fill(
            child: Image.network(
              'https://i.imgur.com/e2N2gJ8.png',
              fit: BoxFit.cover,
              color: Color.fromARGB(128, 0, 0, 0),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    Color.fromARGB(204, 10, 15, 31),
                    Color.fromARGB(204, 4, 6, 16),
                  ],
                ),
              ),
            ),
          ),
          // Main content container
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 64.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50),
                  borderRadius: BorderRadius.circular(24.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'My Profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    const Text(
                      'These fields allow you to set up your identity, preferences, and development context.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14.0, color: Colors.white70),
                    ),
                    const SizedBox(height: 40.0),

                    // Basic Information Section
                    _buildCardSection(
                      title: 'Basic Information',
                      children: [
                        _buildTextField(controller: _fullNameController, hintText: 'Enter your full name'),
                        _buildTextField(controller: _jobTitleController, hintText: 'Job Title / Role'),
                        _buildTextField(controller: _departmentController, hintText: 'Department / Team'),
                        _buildTextField(controller: TextEditingController(text: 'M-123456'), hintText: 'Employee ID', readOnly: true, color: Colors.white10),
                        _buildTextField(controller: _workEmailController, hintText: 'Work Email', keyboardType: TextInputType.emailAddress),
                        _buildTextField(controller: _phoneNumberController, hintText: 'Phone Number (optional)', keyboardType: TextInputType.phone),
                        const SizedBox(height: 16.0),
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: ClipOval(
                                child: _profilePhotoUrl != null
                                    ? Image.network(
                                        _profilePhotoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 40, color: Colors.white54),
                                      )
                                    : const Icon(Icons.person, size: 40, color: Colors.white54),
                              ),
                            ),
                            const SizedBox(width: 16.0),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Profile Photo', style: TextStyle(fontSize: 14, color: Colors.white70)),
                                const SizedBox(height: 4.0),
                                ElevatedButton(
                                  onPressed: _pickAndUploadImage,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white10,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Upload Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ],
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
                          label: 'Areas for Development (self-identified growth areas)',
                          controller: _developmentInputController,
                          list: _developmentAreas,
                          onAdd: () => _addTag(_developmentInputController, _developmentAreas),
                        ),
                        const SizedBox(height: 16),
                        _buildActionButton(
                          text: '✨ Generate Personalized Development Plan ✨',
                          onPressed: _generateDevelopmentPlan,
                        ),
                        const SizedBox(height: 16),
                        _buildTextArea(controller: _careerAspirationsController, hintText: 'Career Aspirations / Future Role'),
                        _buildTextArea(controller: _currentProjectsController, hintText: 'Current Projects / Focus Areas (optional)'),
                      ],
                    ),

                    // Goal & Learning Preferences Section
                    _buildCardSection(
                      title: 'Goal & Learning Preferences',
                      children: [
                        _buildLearningStyleDropdown(),
                        _buildPreferredDevActivitiesCheckboxes(), // Use a new widget for checkboxes
                        const SizedBox(height: 16),
                        _buildTextArea(controller: _shortGoalsController, hintText: 'Short-Term Goals (next 3–6 months)'),
                        _buildTextArea(controller: _longGoalsController, hintText: 'Long-Term Goals (1–3 years)'),
                        _buildActionButton(
                          text: '✨ Draft Motivational Message ✨',
                          onPressed: _draftMotivationalMessage,
                        ),
                        const SizedBox(height: 16),
                        _buildNotificationPreferencesDropdown(), // Use a new widget for dropdown
                        _buildGoalVisibilityRadios(), // Use a new widget for radio buttons
                      ],
                    ),

                    // Gamification & Motivation Section
                    _buildCardSection(
                      title: 'Gamification & Motivation',
                      children: [
                        _buildLeaderboardOptInRadios(), // Use a new widget for radio buttons
                        _buildTextField(controller: _badgeNameController, hintText: 'Preferred Badge Display Name'),
                        _buildCelebrationConsentRadios(), // Use a new widget for radio buttons
                      ],
                    ),

                    // Action Buttons
                    const SizedBox(height: 32.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Color.fromARGB(51, 255, 255, 255)),
                            ),
                          ),
                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _saveProfile, // Call the _saveProfile method
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC10D00),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 32.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  Widget _buildTextField({required TextEditingController controller, required String hintText, TextInputType keyboardType = TextInputType.text, bool readOnly = false, Color? color}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFC10D00)),
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

  Widget _buildTextArea({required TextEditingController controller, required String hintText}) {
    return TextFormField(
      controller: controller,
      maxLines: 3,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFC10D00)),
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

  Widget _buildActionButton({required String text, required VoidCallback onPressed}) {
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
                  label: Text(tag, style: const TextStyle(color: Color(0xFFC10D00))),
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
            backgroundColor: WidgetStateProperty.all(const Color(0xFF1F2840)), // Changed to WidgetStateProperty
          ),
        ),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedLearningStyle, // Changed from value to initialValue
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Select Learning Style',
          hintStyle: TextStyle(color: Color(0xFFC10D00)),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide.none,
          ),
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('Select Learning Style', style: TextStyle(color: Colors.white70))),
          DropdownMenuItem(value: 'visual', child: Text('Visual')),
          DropdownMenuItem(value: 'hands-on', child: Text('Hands-on')),
          DropdownMenuItem(value: 'reading', child: Text('Reading')),
          DropdownMenuItem(value: 'collaborative', child: Text('Collaborative')),
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
        const Text('Preferred Development Activities', style: TextStyle(fontSize: 14, color: Colors.white70)),
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
          fillColor: WidgetStateProperty.all(const Color(0xFFC10D00)), // Changed to WidgetStateProperty
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
        const Text('Notification Preferences', style: TextStyle(fontSize: 14, color: Colors.white70)),
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
                  backgroundColor: WidgetStateProperty.all(const Color(0xFF1F2840)),
                ),
              ),
            ),
            child: DropdownButton<String>(
              isExpanded: true,
              value: _notificationFrequency,
              hint: const Text('Select frequency', style: TextStyle(color: Colors.white30)),
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
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalVisibilityRadios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Goal Visibility', style: TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildRadio('Private', 'private', _goalVisibility, (value) => setState(() => _goalVisibility = value)),
            _buildRadio('Manager Only', 'manager', _goalVisibility, (value) => setState(() => _goalVisibility = value)),
            _buildRadio('Team Share', 'team', _goalVisibility, (value) => setState(() => _goalVisibility = value)),
          ],
        ),
      ],
    );
  }

  Widget _buildRadio(String title, String value, String? groupValue, ValueChanged<String?> onChanged) {
    return RadioListTile<String>(
      title: Text(title, style: const TextStyle(color: Colors.white70)),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: const Color(0xFFC10D00), // This is still needed for the active color of the radio button itself
      fillColor: WidgetStateProperty.all(const Color(0xFFC10D00)), // Changed to WidgetStateProperty
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildLeaderboardOptInRadios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Opt-in to Leaderboards', style: TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildRadio('Yes', 'yes', _leaderboardOptin, (value) => setState(() => _leaderboardOptin = value)),
            _buildRadio('No', 'no', _leaderboardOptin, (value) => setState(() => _leaderboardOptin = value)),
          ],
        ),
      ],
    );
  }

  Widget _buildCelebrationConsentRadios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Celebration Feed Consent', style: TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            _buildRadio('Share wins publicly', 'public', _celebrationConsent, (value) => setState(() => _celebrationConsent = value)),
            _buildRadio('Private only', 'private', _celebrationConsent, (value) => setState(() => _celebrationConsent = value)),
          ],
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
      final storageRef = FirebaseStorage.instance.ref().child('profile_photos/${user.uid}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(File(pickedFile.path)); // Use File from dart:io
      final downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _profilePhotoUrl = downloadUrl;
      });

      if (!mounted) return;
      _showAlertDialog('Success', 'Profile photo uploaded successfully!');
    } catch (e) {
      if (!mounted) return;
      _showAlertDialog('Error', 'Failed to upload photo: ${e.toString()}');
    }
  }
}
