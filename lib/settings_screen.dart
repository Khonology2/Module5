// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdh/utils/pdf_saver.dart' show savePdfBytes;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/settings_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/services/sound_service.dart';
import 'package:pdh/services/notification_service.dart' as notif;
import 'package:pdh/services/employee_tutorial_service.dart';
import 'package:pdh/main.dart' show appLocaleNotifier;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdh/l10n/generated/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserSettings? _currentSettings;
  bool _hasInitialLoadAttempted = false;
  DateTime? _loadStartTime;
  static const String _localSettingsKey = 'cached_user_settings_v1';
  final Set<String> _pendingKeys = <String>{};

  @override
  void initState() {
    super.initState();
    // Hydrate from local cache first so UI has data even if Firestore is slow
    _hydrateLocalSettings();
    // Ensure role is loaded
    RoleService.instance.ensureRoleLoaded();
    // Try to load settings immediately as fallback
    _loadSettingsFallback();
    _loadStartTime = DateTime.now();
  }

  Future<void> _loadSettingsFallback() async {
    if (!_hasInitialLoadAttempted) {
      _hasInitialLoadAttempted = true;
      try {
        final settings = await SettingsService.getUserSettings();
        if (mounted && settings != null) {
          setState(() {
            _currentSettings = settings;
          });
          _persistLocalSettings(settings);
        }
      } catch (e) {
        developer.log('Error loading settings fallback: $e');
      }
    }
  }

  Future<void> _hydrateLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_localSettingsKey);
      if (json == null) return;
      final map = jsonDecode(json) as Map<String, dynamic>;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final settings = _userSettingsFromLocal(map, user.uid);
      setState(() {
        _currentSettings = settings;
      });
    } catch (e) {
      developer.log('Error hydrating local settings: $e');
    }
  }

  Future<void> _persistLocalSettings(UserSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localSettingsKey,
        jsonEncode(_userSettingsToLocal(settings)),
      );
    } catch (e) {
      developer.log('Error persisting local settings: $e');
    }
  }

  Map<String, dynamic> _userSettingsToLocal(UserSettings s) {
    return {
      'displayName': s.displayName,
      'email': s.email,
      'photoURL': s.photoURL,
      'department': s.department,
      'jobTitle': s.jobTitle,
      'privateGoals': s.privateGoals,
      'managerOnly': s.managerOnly,
      'teamShare': s.teamShare,
      'leaderboardParticipation': s.leaderboardParticipation,
      'profileVisible': s.profileVisible,
      'pushNotifications': s.pushNotifications,
      'emailNotifications': s.emailNotifications,
      'soundAlerts': s.soundAlerts,
      'goalReminders': s.goalReminders,
      'weeklyReports': s.weeklyReports,
      'darkMode': s.darkMode,
      'speechRecognitionEnabled': s.speechRecognitionEnabled,
      'celebrationFeed': s.celebrationFeed,
      'autoSync': s.autoSync,
      'language': s.language,
      'timeZone': s.timeZone,
      'tutorialEnabled': s.tutorialEnabled,
      'twoFactorAuth': s.twoFactorAuth,
      'sessionTimeout': s.sessionTimeout,
      'sessionTimeoutMinutes': s.sessionTimeoutMinutes,
      'biometricAuth': s.biometricAuth,
    };
  }

  UserSettings _userSettingsFromLocal(Map<String, dynamic> m, String userId) {
    return UserSettings(
      userId: userId,
      displayName: (m['displayName'] ?? '') as String,
      email: (m['email'] ?? '') as String,
      photoURL: m['photoURL'] as String?,
      department: m['department'] as String?,
      jobTitle: m['jobTitle'] as String?,
      privateGoals: m['privateGoals'] as bool? ?? false,
      managerOnly: m['managerOnly'] as bool? ?? false,
      teamShare: m['teamShare'] as bool? ?? true,
      leaderboardParticipation: m['leaderboardParticipation'] as bool? ?? false,
      profileVisible: m['profileVisible'] as bool? ?? true,
      pushNotifications: m['pushNotifications'] as bool? ?? true,
      emailNotifications: m['emailNotifications'] as bool? ?? true,
      soundAlerts: m['soundAlerts'] as bool? ?? true,
      goalReminders: m['goalReminders'] as bool? ?? true,
      weeklyReports: m['weeklyReports'] as bool? ?? false,
      darkMode: m['darkMode'] as bool? ?? true,
      speechRecognitionEnabled: m['speechRecognitionEnabled'] as bool? ?? false,
      celebrationFeed: m['celebrationFeed'] as bool? ?? true,
      autoSync: m['autoSync'] as bool? ?? true,
      language: m['language'] as String? ?? 'en',
      timeZone: m['timeZone'] as String? ?? 'UTC',
      tutorialEnabled: m['tutorialEnabled'] as bool? ?? false,
      twoFactorAuth: m['twoFactorAuth'] as bool? ?? false,
      sessionTimeout: m['sessionTimeout'] as bool? ?? false,
      sessionTimeoutMinutes: m['sessionTimeoutMinutes'] as int? ?? 30,
      biometricAuth: m['biometricAuth'] as bool? ?? false,
    );
  }

  bool get _isLoadingTooLong {
    if (_loadStartTime == null) return false;
    return DateTime.now().difference(_loadStartTime!).inSeconds > 10;
  }

  @override
  void dispose() {
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
            key: const ValueKey('settings_stream'),
            stream: SettingsService.getUserSettingsStream(),
            initialData:
                _currentSettings, // use cached settings to avoid spinner
            builder: (context, settingsSnapshot) {
              // Prefer last known settings to avoid full-screen flicker while waiting
              if (settingsSnapshot.hasError && _currentSettings == null) {
                return _buildErrorState(settingsSnapshot.error.toString());
              }

              final streamed = settingsSnapshot.data;
              // Prefer local state so switches can update optimistically without
              // being immediately overwritten by the last streamed snapshot.
              final settings = _currentSettings ?? streamed;
              if (streamed != null && mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;

                  // If we have optimistic pending keys, keep them pending until
                  // the stream catches up to the same values.
                  if (_pendingKeys.isNotEmpty && _currentSettings != null) {
                    final stillPending = <String>{};
                    for (final k in _pendingKeys) {
                      final localVal = _getSettingValue(_currentSettings!, k);
                      final streamVal = _getSettingValue(streamed, k);
                      if (localVal != streamVal) {
                        stillPending.add(k);
                      }
                    }
                    if (stillPending.length != _pendingKeys.length) {
                      setState(() {
                        _pendingKeys
                          ..clear()
                          ..addAll(stillPending);
                      });
                    }
                  }

                  // Only adopt streamed snapshots when they won't overwrite
                  // optimistic local changes that haven't been observed yet.
                  if (_pendingKeys.isEmpty && _currentSettings != streamed) {
                    setState(() {
                      _currentSettings = streamed;
                    });
                    _persistLocalSettings(streamed);
                  }
                });
              }

              // Show loading only if we truly don't have any data yet
              if (settings == null &&
                  settingsSnapshot.connectionState == ConnectionState.waiting) {
                // If loading too long, show error instead of infinite spinner
                if (_isLoadingTooLong) {
                  return _buildErrorState(
                    'Settings are taking too long to load. Please check your connection and try again.',
                  );
                }
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.activeColor,
                  ),
                );
              }

              // If still null after waiting, try to load default settings or show error
              final effectiveSettings = settings ?? _currentSettings;
              if (effectiveSettings == null) {
                // If connection is done but still null, show error
                if (settingsSnapshot.connectionState == ConnectionState.done) {
                  // Try one more time to load settings
                  if (!_hasInitialLoadAttempted) {
                    _loadSettingsFallback();
                  }
                  return _buildErrorState(
                    'Unable to load settings. Please try again.',
                  );
                }
                // Still waiting, show spinner (but with timeout check)
                if (_isLoadingTooLong) {
                  return _buildErrorState(
                    'Settings are taking too long to load. Please check your connection and try again.',
                  );
                }
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.activeColor,
                  ),
                );
              }

              // Use StreamBuilder for role, but with initial data to avoid waiting
              return StreamBuilder<String?>(
                key: const ValueKey('role_stream'),
                stream: RoleService.instance.roleStream(),
                initialData: RoleService.instance.cachedRole,
                builder: (context, roleSnapshot) {
                  final role =
                      roleSnapshot.data ?? RoleService.instance.cachedRole;
                  final isManager = role == 'manager';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isManager) ...[
                        _buildPrivacySection(effectiveSettings),
                        const SizedBox(height: 24),
                      ],
                      _buildNotificationSection(effectiveSettings),
                      const SizedBox(height: 24),
                      _buildAppSection(effectiveSettings),
                      if (isManager) ...[
                        const SizedBox(height: 24),
                        _buildManagerSection(effectiveSettings),
                      ],
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
          Center(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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

            return _buildSwitchTile(
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
          value: _normalizeLanguage(settings.language),
          items: const [
            DropdownMenuItem<String>(
              value: 'en_ZA',
              child: Text('English (South Africa)'),
            ),
            DropdownMenuItem<String>(value: 'af', child: Text('Afrikaans')),
            DropdownMenuItem<String>(value: 'zu', child: Text('isiZulu')),
            DropdownMenuItem<String>(value: 'st', child: Text('Sotho')),
          ],
          onChanged: (value) {
            if (value != null) {
              _updateSetting('language', value);
              _onLanguageChanged(value);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Language updated')));
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
            label: Text(AppLocalizations.of(context).export_my_data),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC10D00),
              side: const BorderSide(color: Color(0xFFC10D00)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resetPassword,
            icon: const Icon(Icons.lock_reset),
            label: Text(AppLocalizations.of(context).send_password_reset_email),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.activeColor,
              side: BorderSide(color: AppColors.activeColor),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    bool enabled = true,
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
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: enabled
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
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
                key: ValueKey('language_dropdown_$safeValue'),
                initialValue: safeValue,
                items: items,
                onChanged: (newValue) {
                  // Unfocus before changing to prevent focus errors
                  FocusScope.of(context).unfocus();
                  Future.microtask(() => onChanged(newValue));
                },
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

  String _normalizeLanguage(String code) {
    // Map legacy 'en' to 'en_ZA' for display
    if (code == 'en') return 'en_ZA';
    return code;
  }

  Future<void> _onLanguageChanged(String selectedCode) async {
    final parts = selectedCode.split('_');
    final locale = parts.length == 2
        ? Locale(parts[0], parts[1])
        : Locale(parts[0]);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appLocale', selectedCode);
    appLocaleNotifier.value = locale;
  }

  // Action methods

  Future<void> _updateSetting(String key, dynamic value) async {
    // Optimistic UI update: immediately update local state so switches feel responsive
    final previous = _currentSettings;
    _pendingKeys.add(key);
    if (previous != null && mounted) {
      final next = _applySettingToUserSettings(previous, key, value);
      if (next != null) {
        setState(() {
          _currentSettings = next;
        });
        _persistLocalSettings(next);
      }
    }
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
                  // Also revert optimistic local state
                  if (mounted) {
                    setState(() {
                      _currentSettings = _currentSettings?.copyWith(
                        pushNotifications: false,
                      );
                      _pendingKeys.remove('pushNotifications');
                    });
                    if (_currentSettings != null) {
                      _persistLocalSettings(_currentSettings!);
                    }
                  }
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
      // Revert optimistic local state on failure
      _pendingKeys.remove(key);
      if (mounted && previous != null) {
        setState(() {
          _currentSettings = previous;
        });
        _persistLocalSettings(previous);
      }
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Hide low-signal internal Firestore errors from the UI; show a friendly message instead.
            final msg = e.toString();
            final isTransient =
                msg.toLowerCase().contains('unavailable') ||
                msg.toLowerCase().contains('offline') ||
                msg.toLowerCase().contains('network') ||
                msg.toLowerCase().contains('failed-precondition') ||
                msg.toLowerCase().contains('permission-denied') ||
                msg.toLowerCase().contains('internal assertion failed') ||
                msg.toLowerCase().contains('unexpected state');
            _showCenterOverlay(
              isTransient
                  ? 'Could not save ${_getSettingName(key)}. Please check your connection and try again.'
                  : 'Error updating ${_getSettingName(key)}: $e',
            );
          }
        });
      }
    } finally {
      // no-op, already handled above to prevent double setState around dialogs
    }
  }

  UserSettings? _applySettingToUserSettings(
    UserSettings current,
    String key,
    dynamic value,
  ) {
    // Only support the keys we use in this screen. Returning null means "don't change local state".
    if (value is! bool && value is! String && value is! int) return null;
    switch (key) {
      case 'privateGoals':
        return current.copyWith(privateGoals: value as bool);
      case 'managerOnly':
        return current.copyWith(managerOnly: value as bool);
      case 'teamShare':
        return current.copyWith(teamShare: value as bool);
      case 'leaderboardParticipation':
        return current.copyWith(leaderboardParticipation: value as bool);
      case 'profileVisible':
        return current.copyWith(profileVisible: value as bool);
      case 'pushNotifications':
        return current.copyWith(pushNotifications: value as bool);
      case 'emailNotifications':
        return current.copyWith(emailNotifications: value as bool);
      case 'soundAlerts':
        return current.copyWith(soundAlerts: value as bool);
      case 'goalReminders':
        return current.copyWith(goalReminders: value as bool);
      case 'weeklyReports':
        return current.copyWith(weeklyReports: value as bool);
      case 'speechRecognitionEnabled':
        return current.copyWith(speechRecognitionEnabled: value as bool);
      case 'celebrationFeed':
        return current.copyWith(celebrationFeed: value as bool);
      case 'autoSync':
        return current.copyWith(autoSync: value as bool);
      case 'tutorialEnabled':
        return current.copyWith(tutorialEnabled: value as bool);
      case 'twoFactorAuth':
        return current.copyWith(twoFactorAuth: value as bool);
      case 'sessionTimeout':
        return current.copyWith(sessionTimeout: value as bool);
      case 'sessionTimeoutMinutes':
        return current.copyWith(sessionTimeoutMinutes: value as int);
      case 'biometricAuth':
        return current.copyWith(biometricAuth: value as bool);
      default:
        return null;
    }
  }

  Object? _getSettingValue(UserSettings s, String key) {
    switch (key) {
      case 'privateGoals':
        return s.privateGoals;
      case 'managerOnly':
        return s.managerOnly;
      case 'teamShare':
        return s.teamShare;
      case 'leaderboardParticipation':
        return s.leaderboardParticipation;
      case 'profileVisible':
        return s.profileVisible;
      case 'pushNotifications':
        return s.pushNotifications;
      case 'emailNotifications':
        return s.emailNotifications;
      case 'soundAlerts':
        return s.soundAlerts;
      case 'goalReminders':
        return s.goalReminders;
      case 'weeklyReports':
        return s.weeklyReports;
      case 'darkMode':
        return s.darkMode;
      case 'speechRecognitionEnabled':
        return s.speechRecognitionEnabled;
      case 'celebrationFeed':
        return s.celebrationFeed;
      case 'autoSync':
        return s.autoSync;
      case 'language':
        return s.language;
      case 'timeZone':
        return s.timeZone;
      case 'tutorialEnabled':
        return s.tutorialEnabled;
      case 'twoFactorAuth':
        return s.twoFactorAuth;
      case 'sessionTimeout':
        return s.sessionTimeout;
      case 'sessionTimeoutMinutes':
        return s.sessionTimeoutMinutes;
      case 'biometricAuth':
        return s.biometricAuth;
      default:
        return null;
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

    String? emailText = FirebaseAuth.instance.currentUser?.email;
    emailText = emailText?.trim();

    if (emailText == null || emailText.isEmpty) {
      await _showCenterNotice(
        context,
        'We could not determine your account email. Please sign in again and try resetting your password from the sign-in screen.',
      );
      return;
    }

    _showLoadingDialog(context, message: 'Sending password reset email...');

    try {
      await SettingsService.resetPassword(emailText);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await _showCenterNotice(
        context,
        'If an account exists for $emailText, a password reset email has been sent.',
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await _showCenterNotice(
        context,
        'Error sending password reset email: $e',
      );
    }
  }

  Future<void> _exportUserData() async {
    if (!mounted) return;

    try {
      // Show loading dialog
      _showLoadingDialog(context, message: 'Preparing your data export...');

      final data = await SettingsService.exportUserData();
      if (!mounted) return;

      // Update loading message
      Navigator.of(context, rootNavigator: true).pop(); // Close current dialog
      _showLoadingDialog(context, message: 'Generating PDF...');

      final pdf = await _generatePdf(data);
      if (!mounted) return;

      // Update loading message
      Navigator.of(context, rootNavigator: true).pop(); // Close current dialog
      _showLoadingDialog(context, message: 'Saving PDF...');

      final fileName = 'pdh-export-${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfBytes = await pdf.save();

      // Save or download depending on platform
      final savedPath = await savePdfBytes(fileName, pdfBytes);
      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();

      try {
        if (kIsWeb) {
          await _showCenterNotice(context, 'PDF download started.');
        } else if (savedPath != null) {
          // Try to open the saved file on non-web platforms
          final result = await OpenFile.open(savedPath);
          if (result.type != ResultType.done) {
            await _showCenterNotice(context, 'PDF saved to: $savedPath');
          } else {
            await _showCenterNotice(
              context,
              'Data exported successfully as PDF! ${data.keys.length} sections included.',
            );
          }
        } else {
          await _showCenterNotice(context, 'PDF saved.');
        }
      } catch (e) {
        // If there's an error opening the file, just show the success message
        final msgPath = savedPath ?? 'your device';
        await _showCenterNotice(
          context,
          'PDF saved to: $msgPath\n\nYou can find your exported data here.',
        );
      }
    } catch (e, stackTrace) {
      developer.log('Error exporting data', error: e, stackTrace: stackTrace);
      if (!mounted) return;

      // Close any open loading dialog
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      String errorMessage = 'An error occurred while exporting your data.';
      if (e is FileSystemException) {
        errorMessage =
            'Could not save the PDF file. Please check storage permissions.';
      } else if (e is MissingPluginException) {
        errorMessage = 'A required feature is not available on this device.';
      } else if (e.toString().contains('TooManyPagesException')) {
        errorMessage =
            'Your data is too large to export in a single PDF. Consider reducing the amount of data or contact support.';
      } else if (e.toString().contains('INTERNAL ASSERTION FAILED')) {
        errorMessage =
            'A temporary database error occurred. Please refresh the page and try again.';
      } else if (e.toString().contains('_Namespace')) {
        errorMessage =
            'A system error occurred during export. Please try again with a smaller data set.';
      }

      await _showCenterNotice(context, '$errorMessage\n\nError details: $e');
    }
  }

  Future<pw.Document> _generatePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    // Load a Unicode-capable font from assets (Poppins is bundled in pubspec.yaml)
    final fontData = await rootBundle.load('assets/fonts/poppins/Poppins-Regular.ttf');
    final ttfFont = pw.Font.ttf(fontData);

    // Try to load a header and footer logo asset (optional)
    pw.MemoryImage? logoImage;
    pw.MemoryImage? bottomLogoImage;
    try {
      final logoData = await rootBundle.load('assets/khono.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {
      logoImage = null;
    }
    try {
      final bottomData = await rootBundle.load('assets/discs.png');
      bottomLogoImage = pw.MemoryImage(bottomData.buffer.asUint8List());
    } catch (_) {
      bottomLogoImage = null;
    }

    // Helper to render profile photo (try network then skip)
    Future<pw.MemoryImage?> _loadProfilePhoto(String? url) async {
      if (url == null) return null;
      try {
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          return pw.MemoryImage(resp.bodyBytes);
        }
      } catch (_) {}
      return null;
    }

    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final goals = (data['goals'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    final activities = (data['activities'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
    final badges = (data['badges'] as List<dynamic>?) ?? <dynamic>[];

    final profilePhoto = await _loadProfilePhoto(profile['photoURL']?.toString());

    // Compute goals overview stats
    int totalGoals = goals.length;
    int completedGoals = 0;
    final Map<String, int> byCategory = {};
    final Map<String, int> byPriority = {};
    final Map<String, int> byStatus = {};

    for (final g in goals) {
      final status = (g['status'] ?? 'unknown').toString();
      byStatus[status] = (byStatus[status] ?? 0) + 1;
      if (status.toLowerCase() == 'completed' || status.toLowerCase() == 'done') completedGoals++;
      final cat = (g['category'] ?? 'Uncategorized').toString();
      byCategory[cat] = (byCategory[cat] ?? 0) + 1;
      final pri = (g['priority'] ?? 'Medium').toString();
      byPriority[pri] = (byPriority[pri] ?? 0) + 1;
    }

    // Footer builder
    pw.Widget _buildFooter(pw.Context ctx) {
      return pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount} • Generated ${DateTime.now().toIso8601String()}', style: pw.TextStyle(font: ttfFont, fontSize: 8)),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        footer: (ctx) => _buildFooter(ctx),
        build: (pw.Context ctx) {
          final widgets = <pw.Widget>[];

          // Header & Branding
          widgets.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 80, height: 40),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Employee Development Data Export', style: pw.TextStyle(font: ttfFont, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Generated: ${data['exportDate'] ?? DateTime.now().toIso8601String()}', style: pw.TextStyle(font: ttfFont, fontSize: 9)),
                    pw.Text(profile['displayName'] ?? '', style: pw.TextStyle(font: ttfFont, fontSize: 9)),
                  ],
                ),
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 8));
          widgets.add(pw.Text('Confidential — For internal use only', style: pw.TextStyle(font: ttfFont, fontSize: 9, color: PdfColors.grey)));
          widgets.add(pw.Divider());

          // Profile Section
          widgets.add(pw.Header(level: 1, child: pw.Text('Employee Profile', style: pw.TextStyle(font: ttfFont, fontSize: 14, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Full name: ${profile['displayName'] ?? 'N/A'}', style: pw.TextStyle(font: ttfFont, fontSize: 10)),
                      pw.Text('Email: ${profile['email'] ?? 'N/A'}', style: pw.TextStyle(font: ttfFont, fontSize: 10)),
                      pw.Text('Department: ${profile['department'] ?? 'N/A'}', style: pw.TextStyle(font: ttfFont, fontSize: 10)),
                      pw.Text('Job title: ${profile['jobTitle'] ?? 'N/A'}', style: pw.TextStyle(font: ttfFont, fontSize: 10)),
                      pw.Text('Employee ID: ${profile['userId'] ?? 'N/A'}', style: pw.TextStyle(font: ttfFont, fontSize: 10)),
                      pw.Text('Account created: ${profile['createdAt'] ?? 'N/A'}', style: pw.TextStyle(font: ttfFont, fontSize: 10)),
                      pw.Text('Last updated: ${profile['lastUpdated'] ?? 'N/A'}', style: pw.TextStyle(font: ttfFont, fontSize: 10)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Container(
                  width: 80,
                  height: 80,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                  child: profilePhoto != null ? pw.Image(profilePhoto, fit: pw.BoxFit.cover) : pw.Center(child: pw.Text('No photo', style: pw.TextStyle(font: ttfFont, fontSize: 9))),
                ),
              ],
            ),
          );

          widgets.add(pw.SizedBox(height: 12));

          // Goals Overview
          widgets.add(pw.Header(level: 1, child: pw.Text('Goals Overview', style: pw.TextStyle(font: ttfFont, fontSize: 14, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Text('Total goals: $totalGoals', style: pw.TextStyle(font: ttfFont, fontSize: 10)));
          widgets.add(pw.Text('Completed: $completedGoals • Active: ${totalGoals - completedGoals}', style: pw.TextStyle(font: ttfFont, fontSize: 10)));
          widgets.add(pw.SizedBox(height: 6));

          // Goals by category
          if (byCategory.isNotEmpty) {
            widgets.add(pw.Text('Goals by category:', style: pw.TextStyle(font: ttfFont, fontSize: 10, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.Column(children: byCategory.entries.map((e) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(e.key, style: pw.TextStyle(font: ttfFont, fontSize: 10)), pw.Text(e.value.toString(), style: pw.TextStyle(font: ttfFont, fontSize: 10))])).toList()));
            widgets.add(pw.SizedBox(height: 6));
          }

          // Goals by priority
          if (byPriority.isNotEmpty) {
            widgets.add(pw.Text('Goals by priority:', style: pw.TextStyle(font: ttfFont, fontSize: 10, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.Column(children: byPriority.entries.map((e) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(e.key, style: pw.TextStyle(font: ttfFont, fontSize: 10)), pw.Text(e.value.toString(), style: pw.TextStyle(font: ttfFont, fontSize: 10))])).toList()));
            widgets.add(pw.SizedBox(height: 6));
          }

          // Status breakdown
          if (byStatus.isNotEmpty) {
            widgets.add(pw.Text('Status breakdown:', style: pw.TextStyle(font: ttfFont, fontSize: 10, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.Column(children: byStatus.entries.map((e) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(e.key, style: pw.TextStyle(font: ttfFont, fontSize: 10)), pw.Text(e.value.toString(), style: pw.TextStyle(font: ttfFont, fontSize: 10))])).toList()));
            widgets.add(pw.SizedBox(height: 6));
          }

          widgets.add(pw.SizedBox(height: 8));

          // Detailed Goals Section
          widgets.add(pw.Header(level: 1, child: pw.Text('Detailed Goals', style: pw.TextStyle(font: ttfFont, fontSize: 14, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 6));

          if (goals.isEmpty) {
            widgets.add(pw.Text('No goals found', style: pw.TextStyle(font: ttfFont, fontSize: 10)));
          } else {
            for (final g in goals) {
              final title = g['title'] ?? g['name'] ?? 'Untitled Goal';
              final desc = (g['description'] ?? '').toString();
              final category = g['category'] ?? 'Uncategorized';
              final priority = g['priority'] ?? 'Medium';
              final status = g['status'] ?? 'Unknown';
              final progress = (g['progress'] is num) ? (g['progress'] as num).toDouble() : double.tryParse((g['progress'] ?? '0').toString()) ?? 0.0;
              final target = g['targetDate']?.toString() ?? g['dueDate']?.toString() ?? 'N/A';
              final points = g['points']?.toString() ?? '0';
              final approval = g['approvalStatus'] ?? g['approved'] ?? 'N/A';
              final approver = g['approver'] ?? g['approvedBy'] ?? 'N/A';
              final evidence = (g['evidence'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
              final kpa = g['kpa'] ?? 'N/A';
              final created = g['createdAt']?.toString() ?? 'N/A';
              final approvedAt = g['approvedAt']?.toString() ?? 'N/A';

              widgets.add(pw.Container(padding: const pw.EdgeInsets.symmetric(vertical: 6), decoration: pw.BoxDecoration(border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(title.toString(), style: pw.TextStyle(font: ttfFont, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(desc.toString(), style: pw.TextStyle(font: ttfFont, fontSize: 10)),
                pw.SizedBox(height: 6),
                pw.Row(children: [
                  pw.Expanded(child: pw.Text('Category: $category', style: pw.TextStyle(font: ttfFont, fontSize: 9))),
                  pw.Expanded(child: pw.Text('Priority: $priority', style: pw.TextStyle(font: ttfFont, fontSize: 9))),
                  pw.Expanded(child: pw.Text('Status: $status', style: pw.TextStyle(font: ttfFont, fontSize: 9))),
                ]),
                pw.SizedBox(height: 4),
                pw.Row(children: [
                  pw.Expanded(child: pw.Text('Progress: ${progress.toStringAsFixed(0)}%', style: pw.TextStyle(font: ttfFont, fontSize: 9))),
                  pw.Expanded(child: pw.Text('Target: $target', style: pw.TextStyle(font: ttfFont, fontSize: 9))),
                  pw.Expanded(child: pw.Text('Points: $points', style: pw.TextStyle(font: ttfFont, fontSize: 9))),
                ]),
                pw.SizedBox(height: 4),
                pw.Row(children: [pw.Text('Approval: $approval', style: pw.TextStyle(font: ttfFont, fontSize: 9)), pw.Spacer(), pw.Text('Approver: $approver', style: pw.TextStyle(font: ttfFont, fontSize: 9))]),
                if (evidence.isNotEmpty) pw.SizedBox(height: 6),
                if (evidence.isNotEmpty) pw.Text('Evidence:', style: pw.TextStyle(font: ttfFont, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                if (evidence.isNotEmpty) pw.Column(children: evidence.map((e) => pw.Text('- $e', style: pw.TextStyle(font: ttfFont, fontSize: 9))).toList()),
                pw.SizedBox(height: 6),
                pw.Text('KPA: $kpa • Created: $created • Approved: $approvedAt', style: pw.TextStyle(font: ttfFont, fontSize: 8, color: PdfColors.grey700)),
              ])));
            }
          }

          widgets.add(pw.SizedBox(height: 12));

          // Activities & Performance
          widgets.add(pw.Header(level: 1, child: pw.Text('Activities & Performance', style: pw.TextStyle(font: ttfFont, fontSize: 14, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 6));

          widgets.add(pw.Text('Total activities: ${activities.length}', style: pw.TextStyle(font: ttfFont, fontSize: 10)));
          if (activities.isNotEmpty) {
            final recent = activities.take(10).toList();
            widgets.add(pw.SizedBox(height: 6));
            widgets.add(pw.Text('Recent activity timeline (latest first):', style: pw.TextStyle(font: ttfFont, fontSize: 10, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.Column(children: recent.map((a) => pw.Row(children: [pw.Expanded(child: pw.Text(a['description']?.toString() ?? 'No description', style: pw.TextStyle(font: ttfFont, fontSize: 9))), pw.Text(a['createdAt']?.toString() ?? '', style: pw.TextStyle(font: ttfFont, fontSize: 8, color: PdfColors.grey))])).toList()));
          }

          widgets.add(pw.SizedBox(height: 12));

          // Performance Metrics
          widgets.add(pw.Header(level: 1, child: pw.Text('Performance Metrics', style: pw.TextStyle(font: ttfFont, fontSize: 14, fontWeight: pw.FontWeight.bold))));
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Text('Points: ${profile['points'] ?? 0}', style: pw.TextStyle(font: ttfFont, fontSize: 10)));
          widgets.add(pw.Text('Current streak: ${profile['currentStreak'] ?? 0}', style: pw.TextStyle(font: ttfFont, fontSize: 10)));
          widgets.add(pw.SizedBox(height: 8));
          if (badges.isNotEmpty) {
            widgets.add(pw.Text('Badges earned:', style: pw.TextStyle(font: ttfFont, fontSize: 10, fontWeight: pw.FontWeight.bold)));
            widgets.add(pw.Column(children: badges.map((b) => pw.Text('- ${b['name'] ?? b.toString()}', style: pw.TextStyle(font: ttfFont, fontSize: 9))).toList()));
          }

          widgets.add(pw.SizedBox(height: 20));

          // Footer metadata and bottom logo
          widgets.add(pw.Divider());
          if (bottomLogoImage != null) {
            widgets.add(
              pw.Center(
                child: pw.Image(bottomLogoImage, width: 160, height: 36, fit: pw.BoxFit.contain),
              ),
            );
          }
          widgets.add(pw.SizedBox(height: 6));
          widgets.add(pw.Text('Export generated: ${data['exportDate'] ?? DateTime.now().toIso8601String()}', style: pw.TextStyle(font: ttfFont, fontSize: 8)));
          widgets.add(pw.Text('Data retention: This export contains personal data. Handle securely.', style: pw.TextStyle(font: ttfFont, fontSize: 8)));
          widgets.add(pw.Text('Support: support@example.com', style: pw.TextStyle(font: ttfFont, fontSize: 8)));

          return widgets;
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfSection(String section, dynamic data, {required pw.Font font}) {
    if (data == null) {
      return pw.Text('No data available for this section.', style: pw.TextStyle(font: font, fontSize: 10));
    }

    if (data is Map) {
      final items = <pw.Widget>[];
      data.forEach((key, value) {
        // Sanitize the value to remove non-serializable objects
        final sanitizedValue = _sanitizeValue(value);
        String displayValue = sanitizedValue.toString();
        if (displayValue.length > 100) {
          displayValue = '${displayValue.substring(0, 100)}...';
        }
        items.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  key.toString().replaceAll('_', ' ').toUpperCase(),
                  style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Text(displayValue, style: pw.TextStyle(font: font, fontSize: 10)),
                pw.Divider(),
              ],
            ),
          ),
        );
      });
      return pw.Column(children: items);
    } else if (data is List) {
      final items = <pw.Widget>[];
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        if (item is Map) {
          items.add(
            pw.Text(
              'Item ${i + 1}:',
              style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
          );
          item.forEach((k, v) {
            final sanitizedValue = _sanitizeValue(v);
            String displayValue = sanitizedValue.toString();
            if (k == 'evidence' && sanitizedValue is List) {
              displayValue = sanitizedValue.take(3).join(', ');
              if (sanitizedValue.length > 3) displayValue += '...';
            } else if (displayValue.length > 50) {
              displayValue = '${displayValue.substring(0, 50)}...';
            }
            items.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 16, bottom: 4),
                child: pw.Text(
                  '$k: $displayValue',
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ),
            );
          });
          items.add(pw.SizedBox(height: 10));
        } else {
          final sanitizedValue = _sanitizeValue(item);
          items.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                '${i + 1}. ${sanitizedValue.toString()}',
                style: pw.TextStyle(font: font, fontSize: 10),
              ),
            ),
          );
        }
      }
      return pw.Column(children: items);
    } else {
      final sanitizedValue = _sanitizeValue(data);
      return pw.Text(sanitizedValue.toString(), style: pw.TextStyle(font: font, fontSize: 10));
    }
  }

  /// Sanitizes values to remove non-serializable Firestore objects
  dynamic _sanitizeValue(dynamic value) {
    try {
      if (value == null) {
        return 'N/A';
      }

      // Handle basic types
      if (value is String || value is int || value is double || value is bool) {
        return value;
      }

      // Handle DateTime
      if (value is DateTime) {
        return value.toIso8601String();
      }

      // Handle Lists
      if (value is List) {
        return value
            .map((item) => _sanitizeValue(item))
            .toList();
      }

      // Handle Maps
      if (value is Map) {
        final sanitized = <String, dynamic>{};
        value.forEach((k, v) {
          sanitized[k.toString()] = _sanitizeValue(v);
        });
        return sanitized;
      }

      // For any other type (including Firestore internal types),
      // convert to string and filter out problematic characters
      final stringValue = value.toString();

      // Skip if it looks like an internal Firestore object
      if (stringValue.contains('_Namespace') ||
          stringValue.contains('Instance of') ||
          stringValue.startsWith('_')) {
        return '[Complex Object - Not Serializable]';
      }

      return stringValue;
    } catch (_) {
      return '[Unable to Serialize]';
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

  // ignore: unused_element
  String _prettyJson(Map<String, dynamic> data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  Future<File> _savePdfFile(String fileName, pw.Document pdf) async {
    final safeFileName = fileName.replaceAll(RegExp(r'[<>:\"|?*]'), '_');

    try {
      final directory = await getApplicationDocumentsDirectory();
      final safePath = '${directory.path}/$safeFileName'.replaceAll('\\', '/');
      final file = File(safePath);
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      developer.log('Error saving PDF file: $e');
      rethrow;
    }
  }
}
