import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/utils/firestore_safe.dart';

class TeamDetailsScreen extends StatefulWidget {
  final String teamGoalId;

  const TeamDetailsScreen({super.key, required this.teamGoalId});

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Team Goal Details',
      embedded: false,
      items: const [],
      currentRouteName: '/team_details',
      onNavigate: (route) {
        Navigator.pushNamed(context, route);
      },
      onLogout: () {
        Navigator.pushReplacementNamed(context, '/sign_in');
      },
      content: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirestoreSafe.stream<DocumentSnapshot<Map<String, dynamic>>>(
          FirebaseFirestore.instance
              .collection('team_goals')
              .doc(widget.teamGoalId)
              .snapshots(),
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load team goal. Please try again.'),
            );
          }

          if (!snapshot.hasData || !(snapshot.data?.exists ?? false)) {
            return const Center(child: Text('Team goal not found.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final teamGoal = snapshot.data!.data() ?? const <String, dynamic>{};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamGoal['title'] ?? 'Untitled Goal',
                  style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  teamGoal['description'] ?? 'No description provided.',
                  style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildDetailRow(
                  icon: Icons.calendar_today,
                  label: 'Deadline',
                  value: _formatDate((teamGoal['targetDate'] as Timestamp).toDate()),
                ),
                _buildDetailRow(
                  icon: Icons.star,
                  label: 'Points Reward',
                  value: '${teamGoal['points'] ?? 0} points',
                ),
                _buildDetailRow(
                  icon: Icons.people,
                  label: 'Participants',
                  value: '${teamGoal['participantCount'] ?? 0} members',
                ),
                _buildDetailRow(
                  icon: Icons.category,
                  label: 'Status',
                  value: (teamGoal['status'] as String? ?? 'N/A').toUpperCase(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Manager: ${teamGoal['managerName'] ?? 'N/A'}',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, color: AppColors.activeColor, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}
