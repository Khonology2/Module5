import 'package:flutter/material.dart';

class ManagerReviewTeamDashboardScreen extends StatelessWidget {
  const ManagerReviewTeamDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Review / Team Dashboard'),
      ),
      body: const Center(
        child: Text(
          'Manager Review / Team Dashboard Screen Content',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
