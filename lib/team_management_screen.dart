import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/widgets/app_scaffold.dart';

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

    if (teamGoalDoc.exists) {
      final data = teamGoalDoc.data();
      final List<dynamic> participants = data?['participants'] ?? [];
      setState(() {
        _selectedEmployeeIds.addAll(participants.map((e) => e.toString()));
      });
    }

    // Set up stream for participants (for real-time updates if needed)
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team participants updated successfully!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating team participants: $e')),
      );
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

                final employees = snapshot.data?.docs ?? [];

                if (employees.isEmpty) {
                  return const Center(child: Text('No employees found.'));
                }

                return ListView.builder(
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index].data() as Map<String, dynamic>;
                    final employeeId = employees[index].id;
                    final employeeName = employee['displayName'] ?? 'Unknown Employee';

                    return CheckboxListTile(
                      title: Text(employeeName, style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary)),
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
                      checkColor: AppColors.textPrimary, // Color of the tick
                      activeColor: AppColors.activeColor, // Color when checked
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
