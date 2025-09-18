import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleService {
  RoleService._internal();
  static final RoleService instance = RoleService._internal();

  String? _cachedRole; // 'manager' | 'employee'

  Future<String?> getRole({bool refresh = false}) async {
    if (!refresh && _cachedRole != null) return _cachedRole;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    _cachedRole = snap.data()?['role'] as String?;
    return _cachedRole;
  }

  Stream<String?> roleStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.data()?['role'] as String?);
  }
}

enum RequiredRole { manager, employee, any }

class RoleGate extends StatelessWidget {
  final RequiredRole requiredRole;
  final Widget child;
  final Widget? unauthorized;

  const RoleGate({super.key, required this.requiredRole, required this.child, this.unauthorized});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: RoleService.instance.roleStream(),
      builder: (context, snapshot) {
        final role = snapshot.data;
        if (requiredRole == RequiredRole.any) return child;
        if (role == null) {
          return Center(
            child: CircularProgressIndicator(color: Colors.blueAccent.shade100),
          );
        }
        final ok = (requiredRole == RequiredRole.manager && role == 'manager') ||
            (requiredRole == RequiredRole.employee && role == 'employee');
        if (ok) return child;
        return unauthorized ?? _Unauthorized(role: role);
      },
    );
  }
}

class _Unauthorized extends StatelessWidget {
  final String? role;
  const _Unauthorized({this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1931),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1F2840), borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.orangeAccent),
              const SizedBox(height: 12),
              const Text('Access restricted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Your role (${role ?? "unknown"}) does not have access to this page.', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  if (role == 'manager') {
                    Navigator.pushReplacementNamed(context, '/manager_portal');
                  } else {
                    Navigator.pushReplacementNamed(context, '/employee_portal');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
                child: const Text('Go to my portal'),
              )
            ],
          ),
        ),
      ),
    );
  }
}


