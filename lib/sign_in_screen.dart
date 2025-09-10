import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter

// The main entry point for the Flutter application.
void main() {
  runApp(const MyApp());
}

// A StatelessWidget that sets up the MaterialApp.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Development Hub',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// The main screen widget for the Personal Development Hub login.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/hillyxyz_Generate_a_background_image_for_a_personal_development_app._Theme_1b482d56-7423-46ca-8b2d-ea094e0e91f6.png',
              fit: BoxFit.cover,
            ),
          ),
          // Overlay for gradient effect and content (optional, can be removed if not desired)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Color(0x330A0F1F), // Semi-transparent for overlay
                  Color(0x33040610), // Semi-transparent for overlay
                ],
                stops: [0.0, 1.0],
              ),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC7E3FF),
                      ),
                    ),
                    const SizedBox(height: 50),
                    const Text(
                      'Username',
                      style: TextStyle(
                        color: Color(0xFFC7E3FF),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                        child: TextField(
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withAlpha(25), // Semi-transparent white for blurred effect
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFC7E3FF), width: 1.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Password',
                      style: TextStyle(
                        color: Color(0xFFC7E3FF),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                        child: TextField(
                          obscureText: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withAlpha(25), // Semi-transparent white for blurred effect
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFC7E3FF), width: 1.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6B4EE8), Color(0xFF48A6ED)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have your account yet?",
                          style: TextStyle(
                            color: Color(0xFF8B9FB7),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 5),
                        TextButton(
                          onPressed: () {},
                          child: const Text(
                            'Register Now?',
                            style: TextStyle(
                              color: Color(0xFF48A6ED),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
