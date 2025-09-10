import 'package:flutter/material.dart';

class SeasonChallengeScreen extends StatelessWidget {
  const SeasonChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Season Challenge'),
      ),
      body: const Center(
        child: Text(
          'Season Challenge Screen Content',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
