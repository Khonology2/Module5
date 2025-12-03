import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/services/onboarding_service.dart';

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
    final teamGoalDoc = await FirebaseFirestore.instance
        .collection('team_goals')
        .doc(widget.teamGoalId)
        .get();

    if (!mounted) return;

    if (teamGoalDoc.exists) {
      final data = teamGoalDoc.data();
      final List<dynamic> participants = data?['participants'] ?? [];
      setState(() {
        _selectedEmployeeIds.addAll(participants.map((e) => e.toString()));
      });
    }

    // Set up stream for participants (for real-time updates if needed)
  }

  /// Fetch all employees including onboarding users
  Future<List<Map<String, dynamic>>> _fetchAllEmployees(
    List<QueryDocumentSnapshot> regularEmployees,
  ) async {
    // Convert regular employees to map format
    final employees = regularEmployees.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'displayName': data['displayName'] ?? 'Unknown Employee',
        ...data,
      };
    }).toList();

    // Fetch onboarding users with employee persona
    try {
      final onboardingSnapshot = await FirebaseFirestore.instance
          .collection('onboarding')
          .get();

      final onboardingEmployees = onboardingSnapshot.docs
          .where((doc) {
            final data = doc.data();
            final moduleAccessRole = data['moduleAccessRole'] as String?;
            return OnboardingService.shouldIncludeUser(
              moduleAccessRole,
              'employee',
            );
          })
          .map((doc) {
            final data = doc.data();
            final convertedData =
                OnboardingService.convertOnboardingUserToUserFormat(
                  data,
                  doc.id,
                );
            return {
              'id': doc.id,
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
      await FirebaseFirestore.instance
          .collection('team_goals')
          .doc(widget.teamGoalId)
          .update({
            'participants': _selectedEmployeeIds,
            'participantCount': _selectedEmployeeIds.length,
          });
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
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'employee')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchAllEmployees(snapshot.data?.docs ?? []),
                  builder: (context, employeesSnapshot) {
                    if (employeesSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
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
