import 'package:flutter/material.dart';
import 'package:pdh/landing_screen.dart';
import 'package:flutter/services.dart'; // Import for SystemChrome

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding is initialized
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const MyApp());
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
