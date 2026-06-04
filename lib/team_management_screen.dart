import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/onboarding_service.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';
import 'package:pdh/widgets/custom_logo_loader.dart';

class TeamManagementScreen extends StatefulWidget {
  final String teamGoalId;

  const TeamManagementScreen({super.key, required this.teamGoalId});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  // State for selected employees
  final List<String> _selectedEmployeeIds = [];
  // Stream for current team goal participants
  Future<void> _showCenterNotice(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'OK',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.activeColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchCurrentParticipants();
  }

  void _fetchCurrentParticipants() async {
    try {
      final data = await BackendAuthService.instance.getCollectionItem(
        'team_goals',
        widget.teamGoalId,
      );
      if (!mounted) return;
      final List<dynamic> participants = data['participants'] ?? [];
      setState(() {
        _selectedEmployeeIds.addAll(participants.map((e) => e.toString()));
      });
    } catch (_) {}

    // Set up stream for participants (for real-time updates if needed)
  }

  /// Fetch all employees including onboarding users (excludes deleted accounts)
  Future<List<Map<String, dynamic>>> _fetchAllEmployees(
    List<Map<String, dynamic>> regularEmployees,
  ) async {
    final deletedUids = await ManagerRealtimeService.getDeletedAccountUids();

    final employees = regularEmployees
        .where((data) {
          final id = (data['id'] ?? data['userId'] ?? '').toString();
          return id.isNotEmpty && !deletedUids.contains(id);
        })
        .map((data) {
          final id = (data['id'] ?? data['userId'] ?? '').toString();
          return {
            'id': id,
            'displayName': data['displayName'] ?? 'Unknown Employee',
            ...data,
          };
        })
        .toList();

    try {
      final onboardingItems =
          await OnboardingService.listOnboardingRecords(limit: 500);

      final onboardingEmployees = onboardingItems
          .where((data) {
            final id = (data['id'] ?? '').toString();
            if (id.isEmpty || deletedUids.contains(id)) return false;
            final moduleAccessRole = data['moduleAccessRole'] as String?;
            return OnboardingService.shouldIncludeUser(
              moduleAccessRole,
              'employee',
            );
          })
          .map((data) {
            final id = (data['userId'] ?? data['id'] ?? '').toString();
            final convertedData =
                OnboardingService.convertOnboardingUserToUserFormat(data, id);
            return {
              'id': id,
              'displayName': convertedData['displayName'] ?? 'Unknown Employee',
              ...convertedData,
            };
          })
          .toList();

      // Combine and remove duplicates (in case a user exists in both collections)
      final allEmployees = <String, Map<String, dynamic>>{};
      for (final emp in employees) {
        allEmployees[emp['id'] as String] = emp;
      }
      for (final emp in onboardingEmployees) {
        allEmployees[emp['id'] as String] = emp;
      }

      return allEmployees.values.toList();
    } catch (e) {
      // If onboarding fetch fails, return regular employees
      return employees;
    }
  }

  Future<void> _updateTeamParticipants() async {
    try {
      await BackendAuthService.instance.patchCollectionItem(
        'team_goals',
        widget.teamGoalId,
        {
          'participants': _selectedEmployeeIds,
          'participantCount': _selectedEmployeeIds.length,
        },
      );
      if (!mounted) return;
      if (!mounted) return;
      await _showCenterNotice(
        context,
        'Team participants updated successfully!',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(context, 'Error updating team participants: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Manage Team Members',
      embedded: false,
      items: const [],
      currentRouteName: '/team_management',
      onNavigate: (route) {
        Navigator.pushNamed(context, route);
      },
      onLogout: () {
        Navigator.pushReplacementNamed(context, '/sign_in');
      },
      content: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: backendPollingStream<List<Map<String, dynamic>>>(
                initialValue: const [],
                fetch: () => BackendAuthService.instance.listUsers(
                  role: 'employee',
                  limit: 500,
                ),
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load employees. Please try again.'),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CustomLogoLoader(centerInViewport: true);
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchAllEmployees(snapshot.data ?? const []),
                  builder: (context, employeesSnapshot) {
                    if (employeesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const CustomLogoLoader(centerInViewport: true);
                    }

                    final allEmployees = employeesSnapshot.data ?? [];

                    if (allEmployees.isEmpty) {
                      return const Center(child: Text('No employees found.'));
                    }

                    return ListView.builder(
                      itemCount: allEmployees.length,
                      itemBuilder: (context, index) {
                        final employee = allEmployees[index];
                        final employeeId = employee['id'] as String;
                        final employeeName =
                            employee['displayName'] as String? ??
                            'Unknown Employee';

                        return CheckboxListTile(
                          title: Text(
                            employeeName,
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          value: _selectedEmployeeIds.contains(employeeId),
                          onChanged: (bool? selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedEmployeeIds.add(employeeId);
                              } else {
                                _selectedEmployeeIds.remove(employeeId);
                              }
                            });
                          },
                          checkColor:
                              AppColors.textPrimary, // Color of the tick
                          activeColor:
                              AppColors.activeColor, // Color when checked
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ElevatedButton(
              onPressed: _updateTeamParticipants,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: AppColors.textPrimary,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Update Team'),
            ),
          ),
        ],
      ),
    );
  }
}
