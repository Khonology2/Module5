import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:pdh/employee_drawer.dart';

class EmployeePortalScreen extends StatelessWidget {
  const EmployeePortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const EmployeeDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Employee Portal.',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6B4EE8), Color(0xFF48A6ED)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/hillyxyz_Generate_a_background_image_for_a_personal_development_app._Theme_7058e6a9-bc4e-49a4-836d-7344ed124d1f.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: Container(
        decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F),
                      Color(0x88040610),
                    ],
                    stops: [0.0, 1.0],
          ),
        ),
        child: const Center(
          child: Text(
            'Open menu to navigate',
            style: TextStyle(
              fontSize: 16.0,
              color: Color(0xFFC7E3FF),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // No main content actions; navigation happens via drawer
}
