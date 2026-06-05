import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdh/services/learning_assignment_service.dart';

/// Prefetches My Learning tutorials after the employee shell loads so the
/// dedicated screen can render from cache instead of waiting on a cold API call.
class LearningFeedWarmup extends StatefulWidget {
  const LearningFeedWarmup({super.key, required this.child});

  final Widget child;

  @override
  State<LearningFeedWarmup> createState() => _LearningFeedWarmupState();
}

class _LearningFeedWarmupState extends State<LearningFeedWarmup> {
  static String? _warmedEmployeeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleWarmup());
  }

  void _scheduleWarmup() {
    final employeeId = FirebaseAuth.instance.currentUser?.uid;
    if (employeeId == null || employeeId.isEmpty) return;
    if (_warmedEmployeeId == employeeId) return;
    _warmedEmployeeId = employeeId;

    // Delay so login/dashboard badge storms finish before this lighter request.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      LearningAssignmentService.instance.warmupEmployeeFeed(employeeId);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
