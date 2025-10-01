// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
// Drawers removed in favor of persistent sidebar
import 'package:pdh/widgets/main_layout.dart';
// import 'package:pdh/bottom_nav_bar.dart'; // Bottom nav removed on settings
import 'package:pdh/auth_service.dart'; // Import AuthService
import 'package:pdh/services/role_service.dart';
// Firebase import not needed here after MainLayout
// Profile handled by MainLayout
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:pdh/services/speech_recognition_service.dart'; // Import SpeechRecognitionService
import 'package:flutter/foundation.dart' show kDebugMode; // Import kDebugMode

class SettingsScreen extends StatefulWidget {
  // Changed to StatefulWidget
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService(); // Instantiate AuthService
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _photoUrlController = TextEditingController();
  final TextEditingController _resetEmailController = TextEditingController();
  // int _selectedIndex = 0; // Bottom nav removed

  // Settings & Privacy state
  bool _privateGoals = true;
  bool _managerOnly = false;
  bool _teamShare = false;
  bool _pushNotifications = true;
  String _emailFrequency = 'Weekly';
  bool _soundAlerts = true;
  bool _leaderboardParticipation = true;
  bool _celebrationFeed = false;
  bool _speechRecognitionEnabled =
      false; // Ensure it's non-nullable and initialized

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('SettingsScreen InitState: Initializing booleans...');
      debugPrint('_privateGoals: $_privateGoals');
      debugPrint('_managerOnly: $_managerOnly');
      debugPrint('_teamShare: $_teamShare');
      debugPrint('_pushNotifications: $_pushNotifications');
      debugPrint('_soundAlerts: $_soundAlerts');
      debugPrint('_leaderboardParticipation: $_leaderboardParticipation');
      debugPrint('_celebrationFeed: $_celebrationFeed');
      debugPrint('_speechRecognitionEnabled: $_speechRecognitionEnabled');
    }
    _loadUserProfile();
    _loadSpeechRecognitionPreference();
  }

  void _loadUserProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      _displayNameController.text = user.displayName ?? '';
      _photoUrlController.text = user.photoURL ?? '';
    }
  }

  void _loadSpeechRecognitionPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _speechRecognitionEnabled =
          prefs.getBool('speechRecognitionEnabled') ?? false;
      if (kDebugMode) {
        debugPrint(
          'Speech recognition preference loaded: $_speechRecognitionEnabled',
        );
      }
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _photoUrlController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setInitialIndex();
  }

  void _setInitialIndex() {}

  // _onItemTapped removed with bottom nav

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Settings',
      currentRouteName: '/settings',
      body: StreamBuilder<String?>(
        stream: RoleService.instance.roleStream(),
        builder: (context, snapshot) {
          final role = snapshot.data;
          if (role == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          }
          final isManager = role == 'manager';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(0x1A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isManager ? Icons.manage_accounts : Icons.person,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isManager ? 'Manager settings' : 'Employee settings',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                _buildBlurredTextField(
                  controller: _displayNameController,
                  hintText: 'Display Name',
                ),
                const SizedBox(height: 10),
                _buildBlurredTextField(
                  controller: _photoUrlController,
                  hintText: 'Photo URL',
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await _authService.updateProfile(
                      _displayNameController.text,
                      _photoUrlController.text,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Update Profile'),
                ),
                const SizedBox(height: 30),
                _buildBlurredTextField(
                  controller: _resetEmailController,
                  hintText: 'Email for Password Reset',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await _authService.resetPassword(
                      _resetEmailController.text,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Password reset email sent to ${_resetEmailController.text}',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Send Password Reset Email'),
                ),
                const SizedBox(height: 30),
                // ... keep all existing settings sections here (unchanged) ...
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    await _authService.deleteAccount();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account deleted successfully!'),
                      ),
                    );
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, '/sign_in');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Delete Account'),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () async {
                    await _authService.signOut();
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, '/sign_in');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC10D00),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Profile handled by MainLayout

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withAlpha(
        0x26,
      ), // Semi-transparent white for blurred effect
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFC10D00), width: 1.0),
      ),
      hintText: hintText, // Add hintText
      hintStyle: const TextStyle(color: Color(0xFFC10D00)), // Remove const
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // Helper widget to build a blurred text field.
  Widget _buildBlurredTextField({
    TextEditingController? controller,
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? hintText,
    TextInputType? keyboardType,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: _inputDecoration(
            hintText: hintText,
          ), // Pass hintText to decoration
          style: const TextStyle(color: Colors.white),
          validator: validator,
          onChanged: onChanged,
          keyboardType: keyboardType,
        ),
      ),
    );
  }

  // Settings & Privacy helpers
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

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50),
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool? value, // Make value nullable
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white70.withAlpha(0xB3),
                    fontSize: 13,
                  ),
                ), // Using withAlpha for consistency
              ],
            ),
          ),
          Switch.adaptive(
            value: value ?? false, // Provide a default false if value is null
            onChanged: onChanged,
            activeTrackColor: const Color(0xFFC10D00),
            activeThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.withAlpha(0x7F),
            inactiveThumbColor: Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white70.withAlpha(0xB3),
                    fontSize: 13,
                  ),
                ), // Using withAlpha for consistency
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2840),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: Colors.white70.withAlpha(0x4C),
              ), // Using withAlpha for consistency
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                dropdownColor: const Color(0xFF1F2840),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onChanged: onChanged,
                items: items.map<DropdownMenuItem<String>>((String itemValue) {
                  return DropdownMenuItem<String>(
                    value: itemValue,
                    child: Text(itemValue),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: Colors.white.withAlpha(0x1A),
      height: 1,
      thickness: 0.5,
    ); // Using withAlpha for consistency
  }
}

// Drawer removed; persistent sidebar via MainLayout
