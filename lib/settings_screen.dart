// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:pdh/employee_drawer.dart';
import 'package:pdh/manager_nav_drawer.dart';
// import 'package:pdh/bottom_nav_bar.dart'; // Bottom nav removed on settings
import 'package:pdh/auth_service.dart'; // Import AuthService
import 'package:pdh/services/role_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:pdh/employee_profile_screen.dart'; // Import EmployeeProfileScreen
import 'package:pdh/manager_profile_screen.dart'; // Import ManagerProfileScreen

class SettingsScreen extends StatefulWidget { // Changed to StatefulWidget
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

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      _displayNameController.text = user.displayName ?? '';
      _photoUrlController.text = user.photoURL ?? '';
    }
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
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)), // Ensure title is visible
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
        actions: [
          StreamBuilder<String?>(
            stream: RoleService.instance.roleStream(),
            builder: (context, snapshot) {
              final role = snapshot.data;
              final isManager = role == 'manager';
              return _buildProfileButton(context, isManager: isManager);
            },
          ),
        ],
      ),
      drawer: const _RoleAwareDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Apply stronger blur effect
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F), // More opaque semi-transparent overlay (alpha 0x88)
                      Color(0x88040610), // More opaque semi-transparent overlay (alpha 0x88)
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: StreamBuilder<String?>(
                  stream: RoleService.instance.roleStream(),
                  builder: (context, snapshot) {
                    final role = snapshot.data;
                    if (role == null) {
                      return const Center(child: CircularProgressIndicator(color: Colors.white70));
                    }
                    final isManager = role == 'manager';
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withAlpha(26), borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isManager ? Icons.manage_accounts : Icons.person, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(isManager ? 'Manager settings' : 'Employee settings', style: const TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Settings',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 30),
                      // Update Profile Section
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
                            const SnackBar(content: Text('Profile updated successfully!')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00), // Red background
                          foregroundColor: Colors.white, // White text
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: const StadiumBorder(), // Changed to StadiumBorder
                        ),
                        child: const Text('Update Profile'),
                      ),
                      const SizedBox(height: 30),
                      // Reset Password Section
                      _buildBlurredTextField(
                        controller: _resetEmailController,
                        hintText: 'Email for Password Reset',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await _authService.resetPassword(_resetEmailController.text);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Password reset email sent to ${_resetEmailController.text}')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00), // Red background
                          foregroundColor: Colors.white, // White text
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: const StadiumBorder(), // Changed to StadiumBorder
                        ),
                        child: const Text('Send Password Reset Email'),
                      ),
                      const SizedBox(height: 30),
                      if (isManager) ...[
                        const Text('Manager Controls', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.policy, size: 16),
                              label: const Text('Team policy'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white30)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.notifications_active, size: 16),
                              label: const Text('Nudge defaults'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white30)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ] else ...[
                        const Text('Privacy Controls', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.emoji_events_outlined, size: 16),
                              label: const Text('Leaderboard participation'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white30)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      // Shared Settings & Privacy (simplified)
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Goal Visibility'),
                            const SizedBox(height: 10),
                            _buildSettingsCard(children: [
                              _buildToggleRow(
                                title: 'Private Goals',
                                subtitle: 'Only you can see your goals',
                                value: _privateGoals,
                                onChanged: (v) => setState(() => _privateGoals = v),
                              ),
                              _buildDivider(),
                              _buildToggleRow(
                                title: 'Manager Only',
                                subtitle: 'Share with your manager',
                                value: _managerOnly,
                                onChanged: (v) => setState(() => _managerOnly = v),
                              ),
                              _buildDivider(),
                              _buildToggleRow(
                                title: isManager ? 'Team Share (org-wide)' : 'Team Share',
                                subtitle: isManager ? 'Visible to teams you manage' : 'Visible to your entire team',
                                value: _teamShare,
                                onChanged: (v) => setState(() => _teamShare = v),
                              ),
                            ]),
                            const SizedBox(height: 24),
                            _buildSectionTitle('Notification Preferences'),
                            const SizedBox(height: 10),
                            _buildSettingsCard(children: [
                              _buildToggleRow(
                                title: 'Push Notifications',
                                subtitle: 'Goal reminders and updates',
                                value: _pushNotifications,
                                onChanged: (v) => setState(() => _pushNotifications = v),
                              ),
                              _buildDivider(),
                              _buildDropdownRow(
                                title: 'Email Frequency',
                                subtitle: 'How often to receive emails',
                                value: _emailFrequency,
                                items: const ['Daily', 'Weekly', 'Monthly', 'Never'],
                                onChanged: (val) => setState(() => _emailFrequency = val ?? _emailFrequency),
                              ),
                              _buildDivider(),
                              _buildToggleRow(
                                title: 'Sound Alerts',
                                subtitle: 'Play sounds for notifications',
                                value: _soundAlerts,
                                onChanged: (v) => setState(() => _soundAlerts = v),
                              ),
                            ]),
                            const SizedBox(height: 24),
                            _buildSectionTitle('Privacy Controls'),
                            const SizedBox(height: 10),
                            _buildSettingsCard(children: [
                              _buildToggleRow(
                                title: 'Leaderboard Participation',
                                subtitle: 'Show my progress on leaderboards',
                                value: _leaderboardParticipation,
                                onChanged: (v) => setState(() => _leaderboardParticipation = v),
                              ),
                              _buildDivider(),
                              _buildToggleRow(
                                title: 'Celebration Feed',
                                subtitle: 'Share achievements publicly',
                                value: _celebrationFeed,
                                onChanged: (v) => setState(() => _celebrationFeed = v),
                              ),
                            ]),
                          ],
                        ),
                      ),

                      // Delete Account Button
                      ElevatedButton(
                        onPressed: () async {
                          await _authService.deleteAccount();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account deleted successfully!')),
                          );
                          if (!mounted) return;
                          Navigator.pushReplacementNamed(context, '/sign_in');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00), // Red background
                          foregroundColor: Colors.white, // White text
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: const StadiumBorder(), // Changed to StadiumBorder
                        ),
                        child: const Text('Delete Account'),
                      ),
                      const SizedBox(height: 30),
                      // Sign Out Button
                      ElevatedButton(
                        onPressed: () async {
                          await _authService.signOut();
                          if (!mounted) return;
                          Navigator.pushReplacementNamed(context, '/sign_in');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC10D00), // Red background
                          foregroundColor: Colors.white, // White text
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: const StadiumBorder(), // Changed to StadiumBorder
                        ),
                        child: const Text('Sign Out'),
                      ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      // bottomNavigationBar removed per request
    );
  }

  Widget _buildProfileButton(BuildContext context, {required bool isManager}) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? 'Profile';
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: InkWell(
        onTap: () {
          if (isManager) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerProfileScreen()));
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeProfileScreen()));
          }
        },
        child: Row(
          children: [
            const Icon(Icons.person, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              userName,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withAlpha(25), // Semi-transparent white for blurred effect
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
          decoration: _inputDecoration(hintText: hintText), // Pass hintText to decoration
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
    required bool value,
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
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white70.withAlpha(178), fontSize: 13)), // Using withAlpha for consistency
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFFC10D00),
            activeThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.withAlpha(127),
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
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white70.withAlpha(178), fontSize: 13)), // Using withAlpha for consistency
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2840),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.white70.withAlpha(76)), // Using withAlpha for consistency
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                dropdownColor: const Color(0xFF1F2840),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onChanged: onChanged,
                items: items.map<DropdownMenuItem<String>>((String itemValue) {
                  return DropdownMenuItem<String>(value: itemValue, child: Text(itemValue));
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(color: Colors.white.withAlpha(26), height: 1, thickness: 0.5); // Using withAlpha for consistency
  }
}

class _RoleAwareDrawer extends StatelessWidget {
  const _RoleAwareDrawer();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, snapshot) {
        final isManager = snapshot.data == 'manager';
        return isManager ? const ManagerNavDrawer() : const EmployeeDrawer();
      },
    );
  }
}
