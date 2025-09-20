import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:pdh/employee_drawer.dart'; // Import the EmployeeDrawer
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Cloud Firestore

class MyPdpScreen extends StatefulWidget {
  const MyPdpScreen({super.key});

  @override
  State<MyPdpScreen> createState() => _MyPdpScreenState();
}

class _MyPdpScreenState extends State<MyPdpScreen> {
  // State for toggling expansion of sections
  bool _isOperationalExpanded = true;
  bool _isCustomerExpanded = true;
  bool _isFinancialExpanded = true;

  String _userName = 'User';
  String _userRole = 'Role not set';
  final TextEditingController _roleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? 'User';
      });

      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        setState(() {
          _userRole = data?['role_position'] ?? 'Role not set';
          _roleController.text = _userRole;
        });
      } else {
        _roleController.text = _userRole;
      }
    }
  }

  Future<void> _saveRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _roleController.text.trim().isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'role_position': _roleController.text.trim()},
          SetOptions(merge: true),
        );
        setState(() {
          _userRole = _roleController.text.trim();
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role saved successfully!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save role: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        title: const Text(
          'My Personal Development Plan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove AppBar shadow
      ),
      drawer: const EmployeeDrawer(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/20250919_1033_Futuristic Red Patterns_remix_01k5ghm3a8e39bxbzcpw8sgg6v.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // Apply stronger blur effect
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.2,
                    colors: [
                      Color(0x880A0F1F), // More opaque semi-transparent overlay (alpha 0x88)
                      Color(0x88040610), // More opaque semi-transparent overlay (alpha 0x88)
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 100, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserProfileCard(),
                      const SizedBox(height: 20),
                      _buildKeyPerformanceArea(
                        title: 'Operational Excellence',
                        isExpanded: _isOperationalExpanded,
                        onToggle: (bool expanded) {
                          setState(() {
                            _isOperationalExpanded = expanded;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildKeyPerformanceArea(
                        title: 'Customer Excellence',
                        isExpanded: _isCustomerExpanded,
                        onToggle: (bool expanded) {
                          setState(() {
                            _isCustomerExpanded = expanded;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      _buildKeyPerformanceArea(
                        title: 'Financial Excellence',
                        isExpanded: _isFinancialExpanded,
                        onToggle: (bool expanded) {
                          setState(() {
                            _isFinancialExpanded = expanded;
                          });
                        },
                      ),
                      const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840), // App's card background color
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey,
            child: Icon(
              Icons.person,
              size: 30,
              color: Colors.white70,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName, // Dynamic user name
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextField(
                  controller: _roleController,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your role position',
                    hintStyle: TextStyle(color: Colors.white70.withValues(alpha: 0.5)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save, color: Color(0xFFC10D00)),
                      onPressed: _saveRole,
                    ),
                  ),
                  onSubmitted: (_) => _saveRole(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyPerformanceArea({
    required String title,
    required bool isExpanded,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2840), // App's card background color
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Key Performance Area/Key Performance Indicator',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white,
            ),
            onTap: () => onToggle(!isExpanded),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubSection('Goals (3)'),
                  const SizedBox(height: 10),
                  _buildSubSection('Milestones (3)'),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Adding Goal to $title')),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add Goal', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC10D00), // App's red color
                      minimumSize: const Size.fromHeight(40), // Make button full width
                      shape: const StadiumBorder(), // Changed to StadiumBorder
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Adding Milestone to $title')),
                      );
                    },
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Add Milestone', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC10D00), // App's red color
                      minimumSize: const Size.fromHeight(40), // Make button full width
                      shape: const StadiumBorder(), // Changed to StadiumBorder
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubSection(String text) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        Icon(Icons.keyboard_arrow_down, color: Colors.white70), // Placeholder for actual items
      ],
    );
  }
}