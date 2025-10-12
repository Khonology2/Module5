// ignore_for_file: use_build_context_synchronously

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/settings_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  late final TextEditingController _displayNameController;
  late final TextEditingController _photoUrlController;
  late final TextEditingController _resetEmailController;
  late final TextEditingController _departmentController;
  late final TextEditingController _jobTitleController;
  
  bool _isLoading = false;
  UserSettings? _currentSettings;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadCurrentUser();
  }

  void _initializeControllers() {
    // Initialize controllers with empty values to prevent null errors
    _displayNameController = TextEditingController(text: '');
    _photoUrlController = TextEditingController(text: '');
    _departmentController = TextEditingController(text: '');
    _jobTitleController = TextEditingController(text: '');
    _resetEmailController = TextEditingController(text: '');
  }

  void _loadCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _resetEmailController.text = user.email ?? '';
      _displayNameController.text = user.displayName ?? '';
      _photoUrlController.text = user.photoURL ?? '';
          } catch (e) {
            developer.log('Error loading current user: $e');
          }
        }
      });
    }
  }

  @override
  void dispose() {
    try {
      _displayNameController.dispose();
      _photoUrlController.dispose();
      _resetEmailController.dispose();
      _departmentController.dispose();
      _jobTitleController.dispose();
    } catch (e) {
      developer.log('Error disposing controllers: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundColor,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: StreamBuilder<UserSettings?>(
            stream: SettingsService.getUserSettingsStream(),
            builder: (context, settingsSnapshot) {
              if (settingsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.activeColor),
                );
              }

              if (settingsSnapshot.hasError) {
                return _buildErrorState(settingsSnapshot.error.toString());
              }

              final settings = settingsSnapshot.data;
              if (settings != null && _currentSettings != settings && mounted) {
                _currentSettings = settings;
                _updateControllers(settings);
              }

              return StreamBuilder<String?>(
        stream: RoleService.instance.roleStream(),
                builder: (context, roleSnapshot) {
                  final role = roleSnapshot.data;
                  final isManager = role == 'manager';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(isManager),
                      const SizedBox(height: 24),
                      _buildProfileSection(),
                      const SizedBox(height: 24),
                      _buildPrivacySection(settings),
                      const SizedBox(height: 24),
                      _buildNotificationSection(settings),
                      const SizedBox(height: 24),
                      _buildAppSection(settings),
                      if (isManager) ...[
                        const SizedBox(height: 24),
                        _buildManagerSection(settings),
                      ],
                      const SizedBox(height: 24),
                      _buildSecuritySection(settings),
                      const SizedBox(height: 24),
                      _buildAccountSection(),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _updateControllers(UserSettings settings) {
    // Only update controllers if they're mounted and not disposed
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _displayNameController.text = settings.displayName;
            _photoUrlController.text = settings.photoURL ?? '';
            _departmentController.text = settings.department ?? '';
            _jobTitleController.text = settings.jobTitle ?? '';
          } catch (e) {
            developer.log('Error updating controllers: $e');
            // Reinitialize controllers if they became null
            _initializeControllers();
          }
        }
      });
    }
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: AppColors.dangerColor,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Settings',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unable to load your settings. Please check your connection and try again.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  // Force rebuild to retry
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Error: $error',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isManager) {
          return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        Text(
          'Settings & Privacy',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
              Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
            color: AppColors.elevatedBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isManager ? Icons.manage_accounts : Icons.person,
                color: AppColors.activeColor,
                size: 20,
                    ),
              const SizedBox(width: 8),
                    Text(
                isManager ? 'Manager Settings' : 'Employee Settings',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                    ),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.activeColor, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return _buildSectionCard(
      title: 'Profile Information',
      icon: Icons.person_outline,
      children: [
        _buildTextField(
          controller: _displayNameController,
          label: 'Display Name',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 16),
        _buildTextField(
                controller: _photoUrlController,
          label: 'Photo URL',
          icon: Icons.image_outlined,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _departmentController,
          label: 'Department',
          icon: Icons.business_outlined,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _jobTitleController,
          label: 'Job Title',
          icon: Icons.work_outline,
              ),
              const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _updateProfile,
            icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_isLoading ? 'Updating...' : 'Update Profile'),
                style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
                  foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacySection(UserSettings? settings) {
    if (settings == null) return const SizedBox.shrink();

    return _buildSectionCard(
      title: 'Privacy Controls',
      icon: Icons.privacy_tip_outlined,
      children: [
        _buildSwitchTile(
          title: 'Private Goals',
          subtitle: 'Hide your goals from other team members',
          value: settings.privateGoals,
          onChanged: (value) => _updateSetting('privateGoals', value),
        ),
        _buildSwitchTile(
          title: 'Manager Only Visibility',
          subtitle: 'Only managers can see your goals and progress',
          value: settings.managerOnly,
          onChanged: (value) => _updateSetting('managerOnly', value),
        ),
        _buildSwitchTile(
          title: 'Team Sharing',
          subtitle: 'Allow team members to see your completed goals',
          value: settings.teamShare,
          onChanged: (value) => _updateSetting('teamShare', value),
        ),
        _buildSwitchTile(
          title: 'Leaderboard Participation',
          subtitle: 'Show your progress on the leaderboard',
          value: settings.leaderboardParticipation,
          onChanged: (value) => _updateSetting('leaderboardParticipation', value),
        ),
        _buildSwitchTile(
          title: 'Profile Visibility',
          subtitle: 'Make your profile visible to other users',
          value: settings.profileVisible,
          onChanged: (value) => _updateSetting('profileVisible', value),
        ),
      ],
    );
  }

  Widget _buildNotificationSection(UserSettings? settings) {
    if (settings == null) return const SizedBox.shrink();

    return _buildSectionCard(
      title: 'Notifications',
      icon: Icons.notifications_outlined,
      children: [
        _buildSwitchTile(
          title: 'Push Notifications',
          subtitle: 'Receive push notifications on your device',
          value: settings.pushNotifications,
          onChanged: (value) => _updateSetting('pushNotifications', value),
        ),
        _buildSwitchTile(
          title: 'Email Notifications',
          subtitle: 'Receive notifications via email',
          value: settings.emailNotifications,
          onChanged: (value) => _updateSetting('emailNotifications', value),
        ),
        _buildSwitchTile(
          title: 'Sound Alerts',
          subtitle: 'Play sounds for notifications',
          value: settings.soundAlerts,
          onChanged: (value) => _updateSetting('soundAlerts', value),
        ),
        _buildSwitchTile(
          title: 'Goal Reminders',
          subtitle: 'Get reminded about upcoming goal deadlines',
          value: settings.goalReminders,
          onChanged: (value) => _updateSetting('goalReminders', value),
        ),
        _buildSwitchTile(
          title: 'Weekly Reports',
          subtitle: 'Receive weekly progress reports',
          value: settings.weeklyReports,
          onChanged: (value) => _updateSetting('weeklyReports', value),
        ),
      ],
    );
  }

  Widget _buildAppSection(UserSettings? settings) {
    if (settings == null) return const SizedBox.shrink();

    return _buildSectionCard(
      title: 'App Settings',
      icon: Icons.settings_outlined,
      children: [
        _buildSwitchTile(
          title: 'Speech Recognition',
          subtitle: 'Enable voice input for goal creation',
          value: settings.speechRecognitionEnabled,
          onChanged: (value) => _updateSetting('speechRecognitionEnabled', value),
        ),
        _buildSwitchTile(
          title: 'Celebration Feed',
          subtitle: 'Show celebrations when goals are completed',
          value: settings.celebrationFeed,
          onChanged: (value) => _updateSetting('celebrationFeed', value),
        ),
        _buildSwitchTile(
          title: 'Auto Sync',
          subtitle: 'Automatically sync data when online',
          value: settings.autoSync,
          onChanged: (value) => _updateSetting('autoSync', value),
        ),
        const SizedBox(height: 16),
        _buildDropdownTile(
          title: 'Language',
          value: settings.language,
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'es', child: Text('Spanish')),
            DropdownMenuItem(value: 'fr', child: Text('French')),
            DropdownMenuItem(value: 'de', child: Text('German')),
          ],
          onChanged: (value) => _updateSetting('language', value),
        ),
      ],
    );
  }

  Widget _buildManagerSection(UserSettings? settings) {
    if (settings == null) return const SizedBox.shrink();

    return _buildSectionCard(
      title: 'Manager Tools',
      icon: Icons.admin_panel_settings_outlined,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.download, color: AppColors.activeColor),
          title: Text(
            'Export Team Data',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Download team performance data',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          trailing: Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 16),
          onTap: _exportTeamData,
        ),
        const Divider(color: AppColors.borderColor),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.analytics, color: AppColors.activeColor),
          title: Text(
            'Team Analytics',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'View detailed team performance metrics',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          trailing: Icon(Icons.arrow_forward_ios, color: AppColors.textMuted, size: 16),
          onTap: _viewTeamAnalytics,
        ),
      ],
    );
  }

  Widget _buildSecuritySection(UserSettings? settings) {
    if (settings == null) return const SizedBox.shrink();

    return _buildSectionCard(
      title: 'Security & Privacy',
      icon: Icons.security_outlined,
      children: [
        _buildTextField(
                controller: _resetEmailController,
          label: 'Email for Password Reset',
          icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
          readOnly: true,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resetPassword,
            icon: const Icon(Icons.lock_reset),
            label: const Text('Send Password Reset Email'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.activeColor,
              side: BorderSide(color: AppColors.activeColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          title: 'Two-Factor Authentication',
          subtitle: 'Add an extra layer of security to your account',
          value: settings.twoFactorAuth,
          onChanged: (value) => _updateSetting('twoFactorAuth', value),
        ),
        _buildSwitchTile(
          title: 'Session Timeout',
          subtitle: 'Automatically sign out after inactivity',
          value: settings.sessionTimeout,
          onChanged: (value) => _updateSetting('sessionTimeout', value),
        ),
        if (settings.sessionTimeout) ...[
          const SizedBox(height: 8),
          _buildDropdownTile(
            title: 'Timeout Duration',
            value: settings.sessionTimeoutMinutes.toString(),
            items: const [
              DropdownMenuItem(value: '15', child: Text('15 minutes')),
              DropdownMenuItem(value: '30', child: Text('30 minutes')),
              DropdownMenuItem(value: '60', child: Text('1 hour')),
              DropdownMenuItem(value: '120', child: Text('2 hours')),
            ],
            onChanged: (value) => _updateSetting('sessionTimeoutMinutes', int.parse(value!)),
          ),
        ],
      ],
    );
  }

  Widget _buildAccountSection() {
    return _buildSectionCard(
      title: 'Account Actions',
      icon: Icons.account_circle_outlined,
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _exportUserData,
            icon: const Icon(Icons.download),
            label: const Text('Export My Data'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.borderColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.warningColor,
              side: BorderSide(color: AppColors.warningColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _deleteAccount,
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete Account'),
                style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerColor,
                  foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMuted),
        prefixIcon: Icon(icon, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.elevatedBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.activeColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      style: TextStyle(color: AppColors.textPrimary),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              Switch(
                value: value,
                onChanged: _isLoading ? null : onChanged,
                activeThumbColor: AppColors.activeColor,
                activeTrackColor: AppColors.activeColor.withValues(alpha: 0.3),
                inactiveThumbColor: AppColors.textMuted,
                inactiveTrackColor: AppColors.textMuted.withValues(alpha: 0.3),
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.activeColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            decoration: InputDecoration(
      filled: true,
              fillColor: AppColors.elevatedBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            dropdownColor: AppColors.elevatedBackground,
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  // Action methods
  Future<void> _updateProfile() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    try {
      // Safely get text from controllers
      final displayName = _displayNameController.text;
      final photoURL = _photoUrlController.text.isEmpty ? null : _photoUrlController.text;
      final department = _departmentController.text.isEmpty ? null : _departmentController.text;
      final jobTitle = _jobTitleController.text.isEmpty ? null : _jobTitleController.text;
      
      await SettingsService.updateProfile(
        displayName: displayName,
        photoURL: photoURL,
        department: department,
        jobTitle: jobTitle,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() => _isLoading = true);
    try {
      await SettingsService.updateSetting(key, value);
      
      // Show success messages for important settings changes
      if (mounted) {
        String message = _getSuccessMessage(key, value);
        if (message.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ${_getSettingName(key)}: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getSuccessMessage(String key, dynamic value) {
    switch (key) {
      case 'leaderboardParticipation':
        return value == true 
          ? 'Leaderboard participation enabled! Your progress will now appear on the leaderboard.'
          : 'Leaderboard participation disabled.';
      case 'privateGoals':
        return value == true 
          ? 'Goals are now private and hidden from team members.'
          : 'Goals are now visible to team members.';
      case 'managerOnly':
        return value == true 
          ? 'Goals are now only visible to managers.'
          : 'Goal visibility restored to normal.';
      case 'pushNotifications':
        return value == true 
          ? 'Push notifications enabled.'
          : 'Push notifications disabled.';
      case 'emailNotifications':
        return value == true 
          ? 'Email notifications enabled.'
          : 'Email notifications disabled.';
      case 'soundAlerts':
        return value == true 
          ? 'Sound alerts enabled.'
          : 'Sound alerts disabled.';
      case 'twoFactorAuth':
        return value == true 
          ? 'Two-factor authentication enabled for enhanced security.'
          : 'Two-factor authentication disabled.';
      case 'sessionTimeout':
        return value == true 
          ? 'Session timeout enabled.'
          : 'Session timeout disabled.';
      default:
        return 'Setting updated successfully.';
    }
  }

  String _getSettingName(String key) {
    switch (key) {
      case 'leaderboardParticipation': return 'Leaderboard Participation';
      case 'privateGoals': return 'Private Goals';
      case 'managerOnly': return 'Manager Only Visibility';
      case 'teamShare': return 'Team Sharing';
      case 'profileVisible': return 'Profile Visibility';
      case 'pushNotifications': return 'Push Notifications';
      case 'emailNotifications': return 'Email Notifications';
      case 'soundAlerts': return 'Sound Alerts';
      case 'goalReminders': return 'Goal Reminders';
      case 'weeklyReports': return 'Weekly Reports';
      case 'speechRecognitionEnabled': return 'Speech Recognition';
      case 'celebrationFeed': return 'Celebration Feed';
      case 'autoSync': return 'Auto Sync';
      case 'language': return 'Language';
      case 'twoFactorAuth': return 'Two-Factor Authentication';
      case 'sessionTimeout': return 'Session Timeout';
      case 'sessionTimeoutMinutes': return 'Session Timeout Duration';
      default: return key;
    }
  }

  Future<void> _resetPassword() async {
    if (!mounted) return;
    
    final emailText = _resetEmailController.text;
    if (emailText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    try {
      await SettingsService.resetPassword(emailText);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $emailText'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending password reset: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _exportUserData() async {
    try {
      final data = await SettingsService.exportUserData();
      // In a real app, you'd save this to a file or share it
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data exported successfully! ${data.keys.length} sections included.'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting data: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  Future<void> _exportTeamData() async {
    // Placeholder for team data export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Team data export feature coming soon!')),
    );
  }

  Future<void> _viewTeamAnalytics() async {
    // Placeholder for team analytics
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Team analytics feature coming soon!')),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Sign Out', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warningColor),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/sign_in');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: $e'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Delete Account',
          style: TextStyle(color: AppColors.dangerColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action cannot be undone. This will permanently delete your account and all associated data.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Text(
              'Are you absolutely sure?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerColor),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SettingsService.deleteAccount();
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/sign_in');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting account: $e'),
              backgroundColor: AppColors.dangerColor,
            ),
          );
        }
      }
    }
  }

}
