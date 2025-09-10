import 'package:flutter/material.dart';

class BadgesPointsScreen extends StatelessWidget {
  const BadgesPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Badges & Points'),
      ),
      body: const Center(
        child: Text(
          'Badges & Points Screen Content',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
