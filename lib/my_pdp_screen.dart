import 'package:flutter/material.dart';

class MyPdpScreen extends StatelessWidget {
  const MyPdpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My PDP'),
      ),
      body: const Center(
        child: Text(
          'My PDP Screen Content',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
