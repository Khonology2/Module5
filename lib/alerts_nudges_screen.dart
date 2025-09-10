import 'package:flutter/material.dart';

class AlertsNudgesScreen extends StatelessWidget {
  const AlertsNudgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Nudges'),
      ),
      body: const Center(
        child: Text(
          'Alerts & Nudges Screen Content',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
