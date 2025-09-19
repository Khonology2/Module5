import 'package:flutter/material.dart';
import 'dart:async'; // For Timer

// The main entry point for the Flutter application.
// void main() {
//   runApp(const MyApp());
// }

// A StatelessWidget that sets up the MaterialApp.
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Personal Development Hub',
//       theme: ThemeData(
//         brightness: Brightness.dark,
//         primarySwatch: Colors.blue,
//         fontFamily: 'Inter',
//       ),
//       home: const PersonalDevelopmentHubScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

// The main screen widget for the Personal Development Hub.
class PersonalDevelopmentHubScreen extends StatefulWidget {
  const PersonalDevelopmentHubScreen({super.key});

  @override
  State<PersonalDevelopmentHubScreen> createState() => _PersonalDevelopmentHubScreenState();
}

class _PersonalDevelopmentHubScreenState extends State<PersonalDevelopmentHubScreen> {
  late List<String> inspirationalLines;
  int _currentLineIndex = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    inspirationalLines = [
      "Cultivate your mind, blossom your potential.",
      "Every step forward is a victory.",
      "Organize your life, clarify your purpose.",
      "Knowledge is the compass of growth.",
      "Build strong habits, build a strong future.",
      "Financial wisdom empowers freedom.",
      "Unlock your inner creativity.",
      "Mindfulness lights the path to peace.",
      "Fitness fuels your ambition.",
      "Learn relentlessly, live boundlessly.",
      "Your journey, your rules, your growth.",
      "Small changes, significant impact.",
      "Embrace the challenge, find your strength.",
      "Beyond limits, lies growth.",
      "Master your days, master your destiny.",
      "Innovate, iterate, inspire.",
      "The best investment is in yourself.",
      "Find your balance, elevate your being.",
      "Progress, not perfection.",
      "Dream big, start small, act now.",
    ];
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      setState(() {
        _currentLineIndex = (_currentLineIndex + 1) % inspirationalLines.length;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_background.png',
              fit: BoxFit.cover,
            ),
          ),
          // Content overlay
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome to Personal Development Hub',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      inspirationalLines[_currentLineIndex],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white.withAlpha(204), // Replaced withOpacity(0.8) with .withAlpha(204) (0.8 * 255 = 204)
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/sign_in');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF6B4EE8), // Use a color from your gradient
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}