// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:ui'; // Import for ImageFilter
import 'package:pdh/employee_drawer.dart';
import 'package:pdh/bottom_nav_bar.dart'; // Import the new AppBottomNavBar
import 'package:pdh/auth_service.dart'; // Import AuthService

class SettingsScreen extends StatefulWidget { // Changed to StatefulWidget
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService(); // Instantiate AuthService
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _photoUrlController = TextEditingController();
  final TextEditingController _resetEmailController = TextEditingController();
  int _selectedIndex = 0; // Add state variable for selected index

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      _displayNameController.text = user.displayName ?? '';
      _photoUrlController.text = user.photoURL ?? '';
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _photoUrlController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setInitialIndex();
  }

  void _setInitialIndex() {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == '/my_pdp') {
      setState(() {
        _selectedIndex = 0; // Corresponds to My PDP
      });
    } else if (currentRoute == '/leaderboard') {
      setState(() {
        _selectedIndex = 1; // Corresponds to Leaderboard
      });
    } else if (currentRoute == '/progress_visuals') {
      setState(() {
        _selectedIndex = 2; // Corresponds to Progress Visuals
      });
    } else if (currentRoute == '/settings') {
      setState(() {
        _selectedIndex = 3; // Corresponds to Setting
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Handle navigation based on the selected index
    String targetRoute;
    switch (index) {
      case 0: // My PDP
        targetRoute = '/my_pdp';
        break;
      case 1: // Leaderboard
        targetRoute = '/leaderboard';
        break;
      case 2: // Progress Visuals
        targetRoute = '/progress_visuals';
        break;
      case 3: // Setting
        targetRoute = '/settings';
        break;
      default:
        targetRoute = '/my_pdp'; // Default to my_pdp (or appropriate fallback)
    }
    if (ModalRoute.of(context)?.settings.name != targetRoute) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        targetRoute,
        (Route<dynamic> route) => route.settings.name == '/my_pdp' || route.isFirst, // Keep my_pdp or first route
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Set Scaffold background to transparent
      extendBodyBehindAppBar: true, // Extend the body behind the AppBar
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)), // Ensure title is visible
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
                  image: AssetImage('assets/hillyxyz_Generate_a_background_image_for_a_personal_development_app._Theme_7058e6a9-bc4e-49a4-836d-7344ed124d1f.png'),
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
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Settings',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 30),
                      // Update Profile Section
                      _buildBlurredTextField(
                        controller: _displayNameController,
                        hintText: 'Display Name',
                      ),
                      const SizedBox(height: 10),
                      _buildBlurredTextField(
                        controller: _photoUrlController,
                        hintText: 'Photo URL',
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await _authService.updateProfile(
                            _displayNameController.text,
                            _photoUrlController.text,
                          );
                          if (!mounted) return; 
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated successfully!')),
                          );
                        },
                        child: const Text('Update Profile'),
                      ),
                      const SizedBox(height: 30),
                      // Reset Password Section
                      _buildBlurredTextField(
                        controller: _resetEmailController,
                        hintText: 'Email for Password Reset',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await _authService.resetPassword(_resetEmailController.text);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Password reset email sent to ${_resetEmailController.text}')),
                          );
                        },
                        child: const Text('Send Password Reset Email'),
                      ),
                      const SizedBox(height: 30),
                      // Delete Account Button
                      ElevatedButton(
                        onPressed: () async {
                          await _authService.deleteAccount();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account deleted successfully!')),
                          );
                          if (!mounted) return;
                          Navigator.pushReplacementNamed(context, '/sign_in');
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Delete Account'),
                      ),
                      const SizedBox(height: 30),
                      // Sign Out Button
                      ElevatedButton(
                        onPressed: () async {
                          await _authService.signOut();
                          if (!mounted) return;
                          Navigator.pushReplacementNamed(context, '/sign_in');
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedIndex,
        onTabTapped: _onItemTapped,
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
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
      hintText: hintText, // Add hintText
      hintStyle: const TextStyle(color: Color(0xB2C7E3FF)), // Remove const
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

// Helper widget to build a blurred text field.
  Widget _buildBlurredTextField({
    TextEditingController? controller,
    bool obscureText = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? hintText,
    TextInputType? keyboardType,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: _inputDecoration(hintText: hintText), // Pass hintText to decoration
          style: const TextStyle(color: Colors.white),
          validator: validator,
          onChanged: onChanged,
          keyboardType: keyboardType,
        ),
      ),
    );
  }
}
