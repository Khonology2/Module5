// ignore_for_file: use_build_context_synchronously

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/settings_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/utils/download_helper.dart';
import 'package:pdh/services/sound_service.dart';
import 'package:pdh/services/notification_service.dart' as notif;
import 'package:pdh/services/employee_tutorial_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  late final TextEditingController _resetEmailController;
  bool _allowResetEmailEdit = false;
  UserSettings? _currentSettings;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadCurrentUser();
    // Ensure role is loaded
    RoleService.instance.ensureRoleLoaded();
  }

  void _initializeControllers() {
    _resetEmailController = TextEditingController(text: '');
  }

  void _loadCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          // Prefer auth email first
          String email = user.email ?? '';

          // If auth provider didn't expose an email, fall back to Firestore user doc
          if (email.isEmpty) {
            try {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();
              final data = doc.data();
              email = (data?['email'] as String?) ?? '';
            } catch (e) {
              developer.log('Error loading email from Firestore: $e');
            }
          }

          if (!mounted) return;
          setState(() {
            _resetEmailController.text = email;
            // If we still don't know the email, allow the user to type it manually
            _allowResetEmailEdit = email.isEmpty;
          });
        } catch (e) {
          developer.log('Error loading current user: $e');
        }
      });
    }
  }

  @override
  void dispose() {
    try {
      _resetEmailController.dispose();
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
          image: DecorationImage(
            image: AssetImage('assets/khono_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
          child: StreamBuilder<UserSettings?>(
            stream: SettingsService.getUserSettingsStream(),
            builder: (context, settingsSnapshot) {
              // Prefer last known settings to avoid full-screen flicker while waiting
              if (settingsSnapshot.hasError) {
                return _buildErrorState(settingsSnapshot.error.toString());
              }

              final streamed = settingsSnapshot.data;
              final settings = streamed ?? _currentSettings;
              if (streamed != null && _currentSettings != streamed && mounted) {
                _currentSettings = streamed;
              }

              if (settings == null) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.activeColor,
                  ),
                );
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

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.dangerColor, size: 48),
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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
              style: TextStyle(color: AppColors.textMuted, fontSize: 10),
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
          style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/Account_User_Profile/Profile.png',
                width: 20,
                height: 20,
                fit: BoxFit.contain,
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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
          onChanged: (value) =>
              _updateSetting('leaderboardParticipation', value),
        ),
        _buildSwitchTile(
          title: 'Profile Visibility',
          subtitle: 'Make your profile visible to other users',
          value: settings.profileVisible,
          onChanged: (value) => _updateSetting('profileVisible', value),
        ),
        const SizedBox(height: 16),
        StreamBuilder<String?>(
          stream: RoleService.instance.roleStream(),
          builder: (context, roleSnapshot) {
            // Use stream data, fallback to cached role
            final role = roleSnapshot.data ?? RoleService.instance.cachedRole;

            // Only hide tutorial controls if we're certain user is NOT an employee
            // If role is null or unknown, show controls (default to employee)
            if (role != null && role != 'employee') {
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                _buildSwitchTile(
                  title: 'Enable Tutorial',
                  subtitle: 'Show sidebar navigation tutorial when enabled',
                  value: settings.tutorialEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Show confirmation dialog when enabling
                      final confirmed = await _showTutorialConfirmationDialog(
                        context,
                      );
                      if (!confirmed) {
                        // User cancelled - don't update the setting
                        // The switch will revert to false automatically
                        return;
                      }
                      // If confirmed, dialog already handled enabling and navigation
                    } else {
                      // Disable tutorial - mark as completed so it won't show on next login
                      await _toggleTutorial(false);
                    }
                  },
                ),
              ],
            );
          },
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
          onChanged: (value) =>
              _updateSetting('speechRecognitionEnabled', value),
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
            DropdownMenuItem<String>(value: 'en', child: Text('English')),
            DropdownMenuItem<String>(value: 'es', child: Text('Spanish')),
            DropdownMenuItem<String>(value: 'fr', child: Text('French')),
            DropdownMenuItem<String>(value: 'de', child: Text('German')),
          ],
          onChanged: (value) {
            if (value != null) {
              _updateSetting('language', value);
            }
          },
        ),
      ],
    );
  }

  Future<bool> _showTutorialConfirmationDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280, maxHeight: 320),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.activeColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/chat_bot.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                Text(
                  'Start Sidebar Tutorial?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This tutorial will guide you through all the sidebar navigation options. You can skip it at any time.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.activeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Start Tutorial',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      // Enable tutorial and reset completion status so it will start immediately
      await SettingsService.updateSetting('tutorialEnabled', true);
      await EmployeeTutorialService.instance.resetTutorialCompletion();

      if (context.mounted) {
        // Navigate to dashboard where tutorial will start immediately
        Navigator.pushReplacementNamed(context, '/employee_dashboard');
      }
      return true;
    }
    return false;
  }

  Future<void> _toggleTutorial(bool enabled) async {
    // Update the setting
    await _updateSetting('tutorialEnabled', enabled);

    // Handle tutorial completion status
    if (enabled) {
      // When enabling, reset completion status so tutorial will show
      // But don't navigate here - let the confirmation dialog handle navigation
      await EmployeeTutorialService.instance.resetTutorialCompletion();
    } else {
      // When disabling, mark as completed so it won't show even on next login
      await EmployeeTutorialService.instance.markTutorialCompleted();
    }
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
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Download team performance data',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: AppColors.textMuted,
            size: 16,
          ),
          onTap: _exportTeamData,
        ),
        const Divider(color: AppColors.borderColor),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.analytics, color: AppColors.activeColor),
          title: Text(
            'Team Analytics',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'View detailed team performance metrics',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: AppColors.textMuted,
            size: 16,
          ),
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
          // If we couldn't determine an email, allow user to type it
          readOnly: !_allowResetEmailEdit ? true : false,
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
              DropdownMenuItem<String>(value: '15', child: Text('15 minutes')),
              DropdownMenuItem<String>(value: '30', child: Text('30 minutes')),
              DropdownMenuItem<String>(value: '60', child: Text('1 hour')),
              DropdownMenuItem<String>(value: '120', child: Text('2 hours')),
            ],
            onChanged: (value) {
              if (value != null) {
                _updateSetting('sessionTimeoutMinutes', int.parse(value));
              }
            },
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
    String? assetIconPath,
    Widget? suffix,
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
        prefixIcon: assetIconPath != null
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.asset(
                  assetIconPath,
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
              )
            : Icon(icon, color: AppColors.textMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.activeColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.activeColor,
            activeTrackColor: AppColors.activeColor.withValues(alpha: 0.3),
            inactiveThumbColor: AppColors.textMuted,
            inactiveTrackColor: AppColors.textMuted.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
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
          Builder(
            builder: (context) {
              final values = items
                  .map((e) => e.value)
                  .whereType<String>()
                  .toList();
              final safeValue = values.contains(value)
                  ? value
                  : (values.isNotEmpty ? values.first : null);
              return DropdownButtonFormField<String>(
                initialValue: safeValue,
                items: items,
                onChanged: onChanged,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.activeColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                dropdownColor: Colors.black.withValues(alpha: 0.9),
                style: TextStyle(color: AppColors.textPrimary),
              );
            },
          ),
        ],
      ),
    );
  }

  // Action methods

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await SettingsService.updateSetting(key, value);
      // Immediate side-effects for specific toggles
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          try {
            if (key == 'soundAlerts' && value == true) {
              await SoundService.playChime();
            }

            if (key == 'pushNotifications') {
              if (value == true) {
                bool granted = true;
                if (kIsWeb) {
                  granted = await notif.requestPushPermission();
                }
                if (granted) {
                  if (kIsWeb) {
                    await notif.showTestNotification(
                      'Notifications enabled',
                      'You will receive alerts here.',
                    );
                  }
                } else {
                  // Revert the setting if permission denied
                  await SettingsService.updateSetting(
                    'pushNotifications',
                    false,
                  );
                  _showCenterOverlay(
                    'Notification permission was denied. Push notifications remain off.',
                  );
                  return;
                }
              }
            }
          } catch (_) {}

          final message = _getSuccessMessage(key, value);
          if (message.isNotEmpty) {
            _showCenterOverlay(message);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showCenterOverlay('Error updating ${_getSettingName(key)}: $e');
          }
        });
      }
    } finally {
      // no-op, already handled above to prevent double setState around dialogs
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
      case 'leaderboardParticipation':
        return 'Leaderboard Participation';
      case 'privateGoals':
        return 'Private Goals';
      case 'managerOnly':
        return 'Manager Only Visibility';
      case 'teamShare':
        return 'Team Sharing';
      case 'profileVisible':
        return 'Profile Visibility';
      case 'pushNotifications':
        return 'Push Notifications';
      case 'emailNotifications':
        return 'Email Notifications';
      case 'soundAlerts':
        return 'Sound Alerts';
      case 'goalReminders':
        return 'Goal Reminders';
      case 'weeklyReports':
        return 'Weekly Reports';
      case 'speechRecognitionEnabled':
        return 'Speech Recognition';
      case 'celebrationFeed':
        return 'Celebration Feed';
      case 'autoSync':
        return 'Auto Sync';
      case 'language':
        return 'Language';
      case 'twoFactorAuth':
        return 'Two-Factor Authentication';
      case 'sessionTimeout':
        return 'Session Timeout';
      case 'sessionTimeoutMinutes':
        return 'Session Timeout Duration';
      default:
        return key;
    }
  }

  Future<void> _resetPassword() async {
    if (!mounted) return;

    final emailText = _resetEmailController.text;
    if (emailText.isEmpty) {
      await _showCenterNotice(context, 'Please enter your email address');
      return;
    }

    try {
      await SettingsService.resetPassword(emailText);
      if (mounted) {
        await _showCenterNotice(
          context,
          'Password reset email sent to $emailText',
        );
      }
    } catch (e) {
      if (mounted) {
        await _showCenterNotice(context, 'Error sending password reset: $e');
      }
    }
  }

  Future<void> _exportUserData() async {
    try {
      // Show blocking loading dialog centred on screen
      _showLoadingDialog(context, message: 'Exporting your data...');
      final data = await SettingsService.exportUserData();
      if (!mounted) return;
      // Close loading
      Navigator.of(context, rootNavigator: true).pop();
      // Trigger JSON file download on web
      if (kIsWeb) {
        final filename =
            'pdh-export-${DateTime.now().millisecondsSinceEpoch}.json';
        downloadJsonFile(filename, _prettyJson(data));
      }
      // Show success dialog centred
      await _showCenterNotice(
        context,
        'Data exported successfully! ${data.keys.length} sections included.',
      );
    } catch (e) {
      if (!mounted) return;
      // Close loading if still open
      Navigator.of(context, rootNavigator: true).pop();
      await _showCenterNotice(context, 'Error exporting data: $e');
    }
  }

  Future<void> _exportTeamData() async {
    // Placeholder for team data export
    await _showCenterNotice(context, 'Team data export feature coming soon!');
  }

  Future<void> _viewTeamAnalytics() async {
    // Placeholder for team analytics
    await _showCenterNotice(context, 'Team analytics feature coming soon!');
  }

  // Dialog helpers
  Future<void> _showCenterOverlay(
    String message, {
    Duration autoClose = const Duration(milliseconds: 1600),
  }) async {
    if (!mounted) return;
    final overlayState = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (ctx) {
        return IgnorePointer(
          ignoring: true,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(minWidth: 260, maxWidth: 420),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ),
            ),
          ),
        );
      },
    );
    overlayState.insert(entry);
    await Future.delayed(autoClose);
    if (mounted) {
      entry.remove();
    }
  }

  Future<void> _showCenterNotice(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          content: Text(
            message,
            style: TextStyle(color: AppColors.textPrimary),
          ),
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

  void _showLoadingDialog(
    BuildContext context, {
    String message = 'Loading...',
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        content: Row(
          children: [
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.activeColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _prettyJson(Map<String, dynamic> data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warningColor,
            ),
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
          await _showCenterNotice(context, 'Error signing out: $e');
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
          style: TextStyle(
            color: AppColors.dangerColor,
            fontWeight: FontWeight.bold,
          ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerColor,
            ),
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
          String message = 'Error deleting account: $e';
          if (e is FirebaseAuthException && e.code == 'requires-recent-login') {
            message =
                'For your security, please sign in again and then delete your account.';
          }
          await _showCenterNotice(context, message);
        }
      }
    }
  }
}
