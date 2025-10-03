import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/design_system/app_colors.dart';

enum LeaderboardFilter { thisMonth, allTime, points, streaks, myTeam, organization }
enum LeaderboardMetric { points, level, badges }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // Initialize with concrete values to prevent initialization errors
  final Set<LeaderboardFilter> _selectedFilters = <LeaderboardFilter>{LeaderboardFilter.thisMonth, LeaderboardFilter.points};
  LeaderboardMetric _currentMetric = LeaderboardMetric.points;
  UserProfile? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userProfile = await DatabaseService.getUserProfile(user.uid);
        if (mounted) {
          setState(() {
            _currentUser = userProfile;
            _isLoading = false;
          });
        }
      } catch (e) {
        developer.log('Error loading current user: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onFilterToggle(LeaderboardFilter filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        _selectedFilters.add(filter);
      }
    });
  }

  void _onMetricChange(LeaderboardMetric metric) {
    setState(() {
      _currentMetric = metric;
    });
  }

  String _getOrderByField() {
    switch (_currentMetric) {
      case LeaderboardMetric.points:
        return 'totalPoints';
      case LeaderboardMetric.level:
        return 'level';
      case LeaderboardMetric.badges:
        return 'badges';
    }
  }

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('users')
        // Only users who opted in should be included in leaderboard
        .where('leaderboardOptin', isEqualTo: true);

    // Apply team filter if selected
    if (_selectedFilters.contains(LeaderboardFilter.myTeam) && _currentUser != null && _currentUser!.department.isNotEmpty) {
      query = query.where('department', isEqualTo: _currentUser!.department);
    }

    // Default to ordering by totalPoints and add safety for missing fields
    String orderField = 'totalPoints';
    try {
      orderField = _getOrderByField();
    } catch (e) {
      developer.log('Error getting order field, defaulting to totalPoints: $e');
    }

    // Only order by fields that are guaranteed to exist
    if (orderField == 'badges') {
      // For badges, we'll handle this in processing instead of ordering
      orderField = 'totalPoints';
    }

    return query.orderBy(orderField, descending: true).limit(100);
  }

  List<Map<String, dynamic>> _processLeaderboardData(List<QueryDocumentSnapshot> docs) {
    try {
      developer.log('Processing ${docs.length} documents for leaderboard');
      
      // If no docs, return empty list but don't treat as error
      if (docs.isEmpty) {
        developer.log('No documents to process');
        return [];
      }

      // First filter for users who have opted into the leaderboard
      final filteredDocs = docs.where((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            // Check both field names for compatibility
            final opted = data['leaderboardParticipation'] == true || data['leaderboardOptin'] == true;
            developer.log('User ${doc.id}: leaderboardParticipation = ${data['leaderboardParticipation']}, leaderboardOptin = ${data['leaderboardOptin']}, opted = $opted');
            return opted;
          }
          return false;
        } catch (e) {
          developer.log('Error processing doc ${doc.id}: $e');
          return false;
        }
      }).toList();
      
      developer.log('${filteredDocs.length} users opted into leaderboard');

      // If no users opted in, return empty list but show a helpful message
      if (filteredDocs.isEmpty) {
        developer.log('No users have opted into leaderboard');
        // For testing purposes, if no users have opted in, we can show all users with low priority
        // In production, this would require user consent
        developer.log('No opted-in users found. Users need to enable leaderboard participation in their settings.');
        return [];
      }

      // Process and sort data
      List<Map<String, dynamic>> processedData = filteredDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Safely extract badge count
        int badgeCount = 0;
        try {
          final badges = data['badges'];
          if (badges is List) {
            badgeCount = badges.length;
          }
        } catch (e) {
          developer.log('Error processing badges for user ${doc.id}: $e');
        }
        
        return {
          'userId': doc.id,
          'name': data['displayName']?.toString() ?? 'Anonymous',
          'points': (data['totalPoints'] is num) ? data['totalPoints'] : 0,
          'level': (data['level'] is num) ? data['level'] : 1,
          'badges': badgeCount,
          'department': data['department']?.toString() ?? 'Unknown',
          'jobTitle': data['jobTitle']?.toString() ?? 'Unknown',
        };
      }).toList();

      // Sort by the selected metric
      switch (_currentMetric) {
        case LeaderboardMetric.points:
          processedData.sort((a, b) => (b['points'] as num).compareTo(a['points'] as num));
          break;
        case LeaderboardMetric.level:
          processedData.sort((a, b) => (b['level'] as num).compareTo(a['level'] as num));
          break;
        case LeaderboardMetric.badges:
          processedData.sort((a, b) => (b['badges'] as int).compareTo(a['badges'] as int));
          break;
      }

      // Add rankings
      return processedData.asMap().entries.map((entry) {
        final index = entry.key;
        final user = entry.value;
        user['rank'] = index + 1;
        return user;
      }).toList();

    } catch (e) {
      developer.log('Error processing leaderboard data: $e');
      return <Map<String, dynamic>>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: StreamBuilder<String?>(
          stream: RoleService.instance.roleStream(),
          builder: (context, roleSnapshot) {
            final role = roleSnapshot.data;
            if (role == null || _isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.activeColor),
              );
            }
            
            final isManager = role == 'manager';
          
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _buildQuery().snapshots(),
              builder: (context, leaderboardSnapshot) {
                if (leaderboardSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.activeColor),
                  );
                }

                if (leaderboardSnapshot.hasError) {
                  developer.log('Leaderboard error: ${leaderboardSnapshot.error}');
                  developer.log('Error details: ${leaderboardSnapshot.error.toString()}');
                  return _buildErrorState();
                }

                // Add debugging info
                if (leaderboardSnapshot.hasData) {
                  developer.log('Received ${leaderboardSnapshot.data!.docs.length} documents from Firestore');
                }

                List<Map<String, dynamic>> leaderboardData;
                try {
                  leaderboardData = leaderboardSnapshot.hasData 
                      ? _processLeaderboardData(leaderboardSnapshot.data!.docs)
                      : <Map<String, dynamic>>[];
                } catch (e) {
                  developer.log('Error processing leaderboard data: $e');
                  return _buildErrorState();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildFiltersBar(isManager: isManager),
                      const SizedBox(height: 16),
                      if (leaderboardData.isEmpty)
                        _buildEmptyState()
                      else ...[
                        _buildPodium(leaderboardData),
                        const SizedBox(height: 20),
                        _buildLeaderList(leaderboardData),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Leaderboard',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.live_tv,
                color: AppColors.successColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Live',
                style: TextStyle(
                  color: AppColors.successColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBar({required bool isManager}) {
    Widget chip(String label, LeaderboardFilter filter) {
      final isSelected = _selectedFilters.contains(filter);
      return GestureDetector(
        onTap: () => _onFilterToggle(filter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.activeColor : AppColors.elevatedBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.activeColor : AppColors.borderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    chip('This month', LeaderboardFilter.thisMonth),
                    chip('All time', LeaderboardFilter.allTime),
                    chip('Points', LeaderboardFilter.points),
                    chip('Streaks', LeaderboardFilter.streaks),
                    if (isManager) chip('My team', LeaderboardFilter.myTeam),
                    if (isManager) chip('Organization', LeaderboardFilter.organization),
                  ],
                ),
              ),
              PopupMenuButton<LeaderboardMetric>(
                icon: const Icon(Icons.sort, color: AppColors.textSecondary),
                color: AppColors.elevatedBackground,
                onSelected: _onMetricChange,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: LeaderboardMetric.points,
                    child: Text(
                      'Sort by Points',
                      style: TextStyle(
                        color: _currentMetric == LeaderboardMetric.points 
                            ? AppColors.activeColor 
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: LeaderboardMetric.level,
                    child: Text(
                      'Sort by Level',
                      style: TextStyle(
                        color: _currentMetric == LeaderboardMetric.level 
                            ? AppColors.activeColor 
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: LeaderboardMetric.badges,
                    child: Text(
                      'Sort by Badges',
                      style: TextStyle(
                        color: _currentMetric == LeaderboardMetric.badges 
                            ? AppColors.activeColor 
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_selectedFilters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Active filters: ${_selectedFilters.map((f) => f.name).join(', ')}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> leaderboardData) {
    final topThree = leaderboardData.take(3).toList();
    
    if (topThree.isEmpty) {
      return const SizedBox.shrink();
    }
    
    Widget podiumPlace(Map<String, dynamic> user, int position, double height) {
      final colors = [
        const Color(0xFFFFD700), // Gold
        const Color(0xFFC0C0C0), // Silver  
        const Color(0xFFCD7F32), // Bronze
      ];
      
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 90),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors[position], width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors[position],
                  child: Text(
                    (user['name']?.toString().isNotEmpty == true) 
                        ? user['name'][0].toString().toUpperCase() 
                        : '?',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user['name'],
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 10),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${user['points']} pts',
                  style: TextStyle(color: colors[position], fontSize: 9, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Lvl ${user['level']}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 8),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 50,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors[position].withValues(alpha: 0.8),
                  colors[position].withValues(alpha: 0.4),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Center(
              child: Text(
                '${position + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      height: 240, // Increased height to prevent overflow
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (topThree.length > 1)
            Flexible(child: podiumPlace(topThree[1], 1, 60)),
          // 1st place
          if (topThree.isNotEmpty)
            Flexible(child: podiumPlace(topThree[0], 0, 80)),
          // 3rd place
          if (topThree.length > 2)
            Flexible(child: podiumPlace(topThree[2], 2, 40)),
        ],
      ),
    );
  }

  Widget _buildLeaderList(List<Map<String, dynamic>> leaderboardData) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final topPerformers = leaderboardData.take(5).toList();
    final remainingUsers = leaderboardData.skip(3).toList();

    return IntrinsicHeight(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
        // Current user's position (if not in top 3)
        if (currentUserId != null && _currentUser != null) ...[
          const Text(
            'Your Position',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          _buildLeaderboardItem(_getCurrentUserRank(leaderboardData), isCurrentUser: true),
          const SizedBox(height: 20),
        ],

        const Text(
          'Top Performers',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 10),
        ...topPerformers.map((user) => _buildLeaderboardItem(user)),
        
        if (remainingUsers.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Full Leaderboard',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          ...remainingUsers.map((user) => _buildLeaderboardItem(user)),
        ],
        ],
      ),
    );
  }

  Map<String, dynamic> _getCurrentUserRank(List<Map<String, dynamic>> leaderboardData) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || _currentUser == null) {
      return {};
    }

    // Find user in leaderboard or create entry
    final userInLeaderboard = leaderboardData.firstWhere(
      (user) => user['userId'] == currentUserId,
      orElse: () => {
        'rank': leaderboardData.length + 1,
        'userId': currentUserId,
        'name': _currentUser!.displayName,
        'points': _currentUser!.totalPoints,
        'level': _currentUser!.level,
        'badges': _currentUser!.badges.length,
        'department': _currentUser!.department,
      },
    );

    return userInLeaderboard;
  }

  Widget _buildLeaderboardItem(Map<String, dynamic> user, {bool isCurrentUser = false}) {
    if (user.isEmpty) return const SizedBox.shrink();

    final rank = user['rank'] ?? 0;
    final name = user['name'] ?? 'Unknown';
    final points = user['points'] ?? 0;
    final level = user['level'] ?? 1;
    final badges = user['badges'] ?? 0;

    Color rankColor = AppColors.textSecondary;
    if (rank <= 3) {
      switch (rank) {
        case 1:
          rankColor = const Color(0xFFFFD700); // Gold
          break;
        case 2:
          rankColor = const Color(0xFFC0C0C0); // Silver
          break;
        case 3:
          rankColor = const Color(0xFFCD7F32); // Bronze
          break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentUser 
            ? AppColors.activeColor.withValues(alpha: 0.2)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: isCurrentUser 
            ? Border.all(color: AppColors.activeColor, width: 2)
            : Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: rankColor, width: 1),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.activeColor,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isCurrentUser ? AppColors.activeColor : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.activeColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'YOU',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    _buildStatChip(Icons.stars, '$points pts', Colors.amber),
                    _buildStatChip(Icons.military_tech, 'Lvl $level', Colors.blue),
                    _buildStatChip(Icons.emoji_events, '$badges', Colors.orange),
                    if (user['department'] != null && user['department'] != 'Unknown')
                      _buildStatChip(Icons.business, user['department'], AppColors.successColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.trending_up_outlined, color: AppColors.textMuted, size: 48),
            SizedBox(height: 12),
            Text(
              'Leaderboard Coming Soon',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Users need to enable leaderboard participation in their profile settings.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.activeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.activeColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings, color: AppColors.activeColor, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'To Enable:',
                        style: TextStyle(color: AppColors.activeColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    '1. Go to Profile Settings\n2. Enable "Leaderboard Participation"',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, color: AppColors.dangerColor, size: 48),
            SizedBox(height: 12),
            Text(
              'Error loading leaderboard',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            Text(
              'Please try again later',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}