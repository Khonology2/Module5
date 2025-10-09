import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/manager_realtime_service.dart';

class ManagerEmployeeDetailScreen extends StatelessWidget {
  final EmployeeData employee;
  const ManagerEmployeeDetailScreen({super.key, required this.employee});

  Stream<List<Goal>> _goalsStream() {
    // Merge top-level and nested user goals
    final topLevel = FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: employee.profile.uid)
        .snapshots()
        .map((s) => s.docs.map((d) => Goal.fromFirestore(d)).toList());

    final nested = FirebaseFirestore.instance
        .collection('users')
        .doc(employee.profile.uid)
        .collection('goals')
        .snapshots()
        .map((s) => s.docs.map((d) => Goal.fromFirestore(d)).toList());

    return topLevel.combineLatest<List<Goal>, List<Goal>>(nested, (a, b) {
      final seen = <String>{};
      final merged = <Goal>[];
      for (final g in [...a, ...b]) {
        if (!seen.contains(g.id)) {
          seen.add(g.id);
          merged.add(g);
        }
      }
      merged.sort((x, y) => y.createdAt.compareTo(x.createdAt));
      return merged;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text(employee.profile.displayName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Goal>>(
                stream: _goalsStream(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.activeColor,
                      ),
                    );
                  }
                  final goals = snapshot.data!;
                  if (goals.isEmpty) {
                    return Center(
                      child: Text('No goals yet', style: AppTypography.muted),
                    );
                  }
                  return ListView.builder(
                    itemCount: goals.length,
                    itemBuilder: (context, i) => _goalTile(goals[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.activeColor,
            child: Text(
              employee.profile.displayName.isNotEmpty
                  ? employee.profile.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.profile.displayName,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(employee.profile.jobTitle, style: AppTypography.muted),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${employee.totalPoints} pts',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Level ${employee.profile.level}',
                style: AppTypography.muted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _goalTile(Goal g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  g.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _statusChip(g.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(g.description, style: AppTypography.muted),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (g.progress.clamp(0, 100)) / 100.0,
            backgroundColor: AppColors.borderColor,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.activeColor,
            ),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _statusChip(GoalStatus status) {
    Color c;
    String t;
    switch (status) {
      case GoalStatus.completed:
        c = AppColors.successColor;
        t = 'Completed';
        break;
      case GoalStatus.inProgress:
        c = AppColors.activeColor;
        t = 'In Progress';
        break;
      case GoalStatus.notStarted:
        c = AppColors.textSecondary;
        t = 'Not Started';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        border: Border.all(color: c.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        t,
        style: AppTypography.bodySmall.copyWith(
          color: c,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

extension _Rx on Stream<List<Goal>> {
  Stream<R> combineLatest<T, R>(
    Stream<T> other,
    R Function(List<Goal>, T) combiner,
  ) {
    late List<Goal> aCache;
    late T bCache;
    bool hasA = false, hasB = false;
    final controller = StreamController<R>();
    final subA = listen((a) {
      hasA = true;
      aCache = a;
      if (hasB) controller.add(combiner(aCache, bCache));
    });
    final subB = other.listen((b) {
      hasB = true;
      bCache = b;
      if (hasA) controller.add(combiner(aCache, bCache));
    });
    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
    };
    return controller.stream;
  }
}
