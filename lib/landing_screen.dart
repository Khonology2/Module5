// ignore_for_file: deprecated_member_use

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

    // Precache hero images after first frame to avoid jank on first paint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = this.context;
      if (!mounted) return;
      // Background image sized to screen width to reduce decode cost
      final int bgWidth = (MediaQuery.of(context).size.width * 1.5).toInt();
      precacheImage(
        const AssetImage('assets/khono_bg.png'),
        context,
        size: Size(bgWidth.toDouble(), MediaQuery.of(context).size.height),
      );
      // Logo at a fixed reasonable size
      precacheImage(
        const AssetImage('assets/khono.png'),
        context,
        size: const Size(320, 160),
      );
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
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
              child: Image.asset(
                'assets/khono_bg.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
                cacheWidth: (MediaQuery.of(context).size.width * 1.5).toInt(),
              ),
            ),
          ),
          // Content overlay
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo - Centered
                  Center(
                    child: Image.asset(
                      'assets/khono.png',
                      height: 160,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.low,
                      cacheWidth: 320,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Tagline - Centered
                  const Center(
                    child: Text(
                      'Your Growth Journey, Simplified',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC10D00),
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Inspirational message - Centered
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        inspirationalLines[_currentLineIndex],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white.withAlpha(204),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Button - Centered
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/sign_in');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFC10D00), // Use the new red color
                        padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        shape: const StadiumBorder(), // Changed to StadiumBorder
                      ),
                      child: const Text(
                        'GET STARTED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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