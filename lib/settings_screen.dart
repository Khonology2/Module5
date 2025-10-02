// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
// Drawers removed in favor of persistent sidebar
import 'package:pdh/auth_service.dart'; // Import AuthService
import 'package:pdh/services/role_service.dart';
// Firebase import not needed here after MainLayout
// Profile handled by MainLayout
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
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
  final bool _privateGoals = true;
  final bool _managerOnly = false;
  final bool _teamShare = false;
  final bool _pushNotifications = true;
  final bool _soundAlerts = true;
  final bool _leaderboardParticipation = true;
  final bool _celebrationFeed = false;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0), // Adjusted padding
      child: StreamBuilder<String?>(
        stream: RoleService.instance.roleStream(),
        builder: (context, snapshot) {
          final role = snapshot.data;
          if (role == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          }
          final isManager = role == 'manager';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align content to the start
            children: [
              Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
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
          );
        },
      ),
    );
  }

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
}
