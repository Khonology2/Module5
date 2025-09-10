import 'package:flutter/material.dart';

class MyGoalWorkspaceScreen extends StatelessWidget {
  const MyGoalWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Goal Workspace'),
      ),
      body: const Center(
        child: Text(
          'My Goal Workspace Screen Content',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
