// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
// For ImageFilter
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/database_service.dart'; // Import DatabaseService
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
  // Text editing controllers for input fields
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController(
    text: 'P-123456',
  ); // Read-only
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

  String? _learningStyle;
  String? _notificationFrequency = 'daily';
  String? _goalVisibility = 'private';
  String? _leaderboardOptin = 'no';
  String? _celebrationConsent = 'private';
  String? _profilePhotoUrl; // State variable for profile photo URL

  final List<String> _skills = [];
  final List<String> _developmentAreas = [];
  final List<String> _preferredDevActivities = []; // State for checkboxes

  @override
  void initState() {
    super.initState();
    _employeeIdController.text = 'P-123456'; // Set initial read-only value
    _loadUserProfile();
  }

  Future<void> _removeProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to remove your photo.'),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove photo: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // User not logged in

    try {
      // First, try to get data from onboarding collection
      final onboardingData = await DatabaseService.getOnboardingData(
        userId: user.uid,
        email: user.email,
      );
      
      // Then get user profile for other fields
      final userProfile = await DatabaseService.getUserProfile(user.uid);
      
      setState(() {
        // Use onboarding data if available, otherwise fallback to userProfile
        _fullNameController.text = onboardingData['fullName']?.trim() ?? 
            userProfile.displayName;
        _jobTitleController.text = onboardingData['designation']?.trim() ?? 
            userProfile.jobTitle;
        _departmentController.text = onboardingData['department']?.trim() ?? 
            userProfile.department;
        _workEmailController.text = userProfile.email;
        _phoneNumberController.text = userProfile.phoneNumber;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _jobTitleController.dispose();
    _departmentController.dispose();
    _employeeIdController.dispose();
    _workEmailController.dispose();
    _phoneNumberController.dispose();
    _skillsInputController.dispose();
    _developmentInputController.dispose();
    _careerAspirationsController.dispose();
    _currentProjectsController.dispose();
    _shortGoalsController.dispose();
    _longGoalsController.dispose();
    _badgeNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return; // User cancelled picking

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to upload a photo.'),
        ),
      );
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
      await _saveProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload photo: ${e.toString()}')),
      );
    }
  }

  void _showProfileSavedDialog({
    String title = 'Profile Saved',
    String message = 'Your profile has been saved successfully!',
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3E50), // Matches dark-card-2
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFC10D00),
              ), // Matches primary-red
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfile({
    bool showDialog = true,
    String? successTitle,
    String? successMessage,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to save your profile.'),
        ),
      );
      return;
    }

    // Fetch the existing user profile to get non-editable fields like totalPoints, level, and badges
    final existingUserProfile = await DatabaseService.getUserProfile(user.uid);

    try {
      // ignore: avoid_print
      print('Saving profile...');
      await DatabaseService.updateUserProfile(
        existingUserProfile.copyWith(
          displayName: _fullNameController.text.trim(),
          email: _workEmailController.text.trim(),
          jobTitle: _jobTitleController.text.trim(),
          department: _departmentController.text.trim(),
          phoneNumber: _phoneNumberController.text.trim(),
          profilePhotoUrl: _profilePhotoUrl, // Pass the profile photo URL
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
        ),
      );
      await _loadUserProfile();
      if (showDialog) {
        _showProfileSavedDialog(
          title: successTitle ?? 'Profile Saved',
          message:
              successMessage ?? 'Your profile has been saved successfully!',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
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
          hintStyle: const TextStyle(
            color: Color(0xFFC10D00),
          ), // match manager red hint
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
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ), // py-2 px-3
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
            color: Colors.black.withOpacity(0.4),
          ),
          constraints: const BoxConstraints(minHeight: 44), // min-h-[44px]
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: tagsList.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ), // px-2 py-1
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(9999), // rounded-full
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(
                        color: Color(0xFFC10D00),
                        fontSize: 12,
                      ), // text-red-600 text-xs
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => onTagRemoved(tag),
                      child: const Icon(
                        Icons.close,
                        color: Color(0xFFC10D00), // text-red-400
                        size: 16,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
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
            Text(
              'Profile',
              style: AppTypography.heading2.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'These fields allow you to set up your identity, preferences, and development context.',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
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
                    _buildInputField(
                      controller: _jobTitleController,
                      hintText: 'e.g., Software Engineer',
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('Department / Team'),
                    _buildInputField(
                      controller: _departmentController,
                      hintText: 'e.g., Engineering - Platform Team',
                    ),
                    const SizedBox(height: 24),
                    _buildInputLabel('Employee ID'),
                    _buildInputField(
                      controller: _employeeIdController,
                      readOnly: true,
                    ),
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
                      hintText: 'e.g., +1 (555) 123-4567',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(25, 255, 255, 255),
                            shape: BoxShape.circle,
                          ),
                          child: ClipOval(
                            child:
                                (_profilePhotoUrl != null &&
                                    _profilePhotoUrl!.isNotEmpty)
                                ? Image.network(
                                    _profilePhotoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.person,
                                              color: Colors.white70,
                                              size: 40,
                                            ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: Colors.white70,
                                    size: 40,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputLabel('Profile Photo'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: _pickAndUploadImage,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color.fromARGB(
                                      25,
                                      255,
                                      255,
                                      255,
                                    ),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    side: const BorderSide(
                                      color: Color.fromARGB(51, 255, 255, 255),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: const Text(
                                    'Upload Photo',
                                    style: TextStyle(fontSize: 14),
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
                      ],
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
                      hintText: 'List your current projects...',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!widget.embedded) ...[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(
                          color: Color.fromARGB(51, 255, 255, 255),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                ElevatedButton(
                  onPressed: () {
                    _saveProfile();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Save Profile',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
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
      return _buildProfileContent();
    }

    // Standalone mode with full Scaffold
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
}
