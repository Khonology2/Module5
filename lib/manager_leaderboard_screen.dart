import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/models/user_profile.dart';

class ManagerLeaderboardScreen extends StatefulWidget {
  const ManagerLeaderboardScreen({super.key});

  @override
  State<ManagerLeaderboardScreen> createState() => _ManagerLeaderboardScreenState();
}

class _ManagerLeaderboardScreenState extends State<ManagerLeaderboardScreen> {
  UserProfile? _manager;

  @override
  void initState() {
    super.initState();
    _loadManagerProfile();
  }

  Future<void> _loadManagerProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      setState(() {
        _manager = UserProfile.fromFirestore(doc);
      });
    } catch (e) {
      developer.log('Error loading manager profile: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    if (_manager == null || _manager!.department.isEmpty) {
      // Fallback to opted-in users if manager data not ready; UI shows loading until ready
      return FirebaseFirestore.instance
          .collection('users')
          .where('leaderboardOptin', isEqualTo: true)
          .orderBy('totalPoints', descending: true)
          .limit(100)
          .snapshots();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .where('leaderboardOptin', isEqualTo: true)
        .where('department', isEqualTo: _manager!.department)
        .orderBy('totalPoints', descending: true)
        .limit(100)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: const Text('Manager Leaderboard'),
      ),
      body: _manager == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.activeColor))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.activeColor));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.textSecondary)),
                  );
                }
                final docs = snapshot.data?.docs ?? const [];
                final items = docs.map((d) {
                  final data = d.data();
                  return {
                    'userId': d.id,
                    'name': data['displayName']?.toString() ?? 'Anonymous',
                    'points': (data['totalPoints'] is num) ? data['totalPoints'] : 0,
                    'level': (data['level'] is num) ? data['level'] : 1,
                    'department': data['department']?.toString() ?? 'Unknown',
                  };
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final user = items[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.activeColor,
                            child: Text(
                              (user['name'] as String).isNotEmpty ? (user['name'] as String)[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user['name'] as String, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('Dept: ${user['department']}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text('${user['points']} pts', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemCount: items.length,
                );
              },
            ),
    );
  }
}


