import 'package:flutter/material.dart';
import 'package:pdh/landing_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Development Hub',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      home: const PersonalDevelopmentHubScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
