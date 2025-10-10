import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/design_system/app_colors.dart';

enum LeaderboardFilter {
  thisMonth,
  allTime,
  points,
  streaks,
  myTeam,
  organization,
}

enum LeaderboardMetric { points, level, badges }

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  // Initialize with concrete values to prevent initialization errors
  final Set<LeaderboardFilter> _selectedFilters = <LeaderboardFilter>{
    LeaderboardFilter.thisMonth,
    LeaderboardFilter.points,
  };
  LeaderboardMetric _currentMetric = LeaderboardMetric.points;
  UserProfile? _currentUser;
  bool _isLoading = true;
  late final AnimationController _topHoverController;
  bool _isTopHovered = false;

  @override
  void initState() {
    super.initState();
    _topHoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Always float; we'll only boost amplitude on hover
    _topHoverController.repeat(reverse: true);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _topHoverController.dispose();
    super.dispose();
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

  // Removed unused _getOrderByField to satisfy linter

  Query<Map<String, dynamic>> _buildQuery({String? userRole}) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'users',
    );

    // For non-managers, we'll filter in the processing step instead of in the query
    // This avoids issues with missing fields in the database
    // Note: role-specific filtering is handled later; no need to store here

    // Apply team filter if selected
    if (_selectedFilters.contains(LeaderboardFilter.myTeam) &&
        _currentUser != null &&
        _currentUser!.department.isNotEmpty) {
      query = query.where('department', isEqualTo: _currentUser!.department);
    }

    // Use a simple query without ordering to avoid field existence issues
    // We'll handle sorting in the processing step
    return query.limit(100);
  }

  List<Map<String, dynamic>> _processLeaderboardData(
    List<QueryDocumentSnapshot> docs, {
    String? userRole,
  }) {
    try {
      developer.log('Processing ${docs.length} documents for leaderboard');

      // If no docs, return empty list but don't treat as error
      if (docs.isEmpty) {
        developer.log('No documents to process');
        return [];
      }

      // Use the role parameter instead of checking filters
      final isManager = userRole == 'manager';
      List<QueryDocumentSnapshot> filteredDocs;

      // For managers, show all users regardless of opt-in status
      if (isManager) {
        filteredDocs = docs;
      } else {
        // For regular users, filter for users who have opted into the leaderboard
        filteredDocs = docs.where((doc) {
          try {
            final data = doc.data() as Map<String, dynamic>?;
            if (data != null) {
              // Check both field names for compatibility and default to false if field doesn't exist
              final opted =
                  (data['leaderboardParticipation'] == true) ||
                  (data['leaderboardOptin'] == true);
              return opted;
            }
            return false;
          } catch (e) {
            developer.log('Error processing doc ${doc.id}: $e');
            return false;
          }
        }).toList();
      }

      developer.log('${filteredDocs.length} users to display on leaderboard');

      // If no users to display, return empty list
      if (filteredDocs.isEmpty) {
        if (!isManager) {
          developer.log('No users have opted into leaderboard');
        }
        return [];
      }

      // Process and sort data with better error handling
      List<Map<String, dynamic>> processedData = filteredDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        // Safely extract values with defaults
        int badgeCount = 0;
        try {
          final badges = data['badges'];
          if (badges is List) {
            badgeCount = badges.length;
          }
        } catch (e) {
          developer.log('Error processing badges for user ${doc.id}: $e');
        }

        // Ensure numeric fields have valid defaults
        num points = 0;
        num level = 1;

        try {
          if (data['totalPoints'] is num) {
            points = data['totalPoints'] as num;
          }
        } catch (e) {
          developer.log('Error processing points for user ${doc.id}: $e');
        }

        try {
          if (data['level'] is num) {
            level = data['level'] as num;
          }
        } catch (e) {
          developer.log('Error processing level for user ${doc.id}: $e');
        }

        return {
          'userId': doc.id,
          'name': data['displayName']?.toString() ?? 'Anonymous',
          'points': points,
          'level': level,
          'badges': badgeCount,
          'department': data['department']?.toString() ?? 'Unknown',
          'jobTitle': data['jobTitle']?.toString() ?? 'Unknown',
        };
      }).toList();

      // Sort by the selected metric with safe comparisons
      switch (_currentMetric) {
        case LeaderboardMetric.points:
          processedData.sort((a, b) {
            final aPoints = (a['points'] as num?) ?? 0;
            final bPoints = (b['points'] as num?) ?? 0;
            return bPoints.compareTo(aPoints);
          });
          break;
        case LeaderboardMetric.level:
          processedData.sort((a, b) {
            final aLevel = (a['level'] as num?) ?? 1;
            final bLevel = (b['level'] as num?) ?? 1;
            return bLevel.compareTo(aLevel);
          });
          break;
        case LeaderboardMetric.badges:
          processedData.sort((a, b) {
            final aBadges = (a['badges'] as int?) ?? 0;
            final bBadges = (b['badges'] as int?) ?? 0;
            return bBadges.compareTo(aBadges);
          });
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
              stream: _buildQuery(userRole: role).snapshots(),
              builder: (context, leaderboardSnapshot) {
                if (leaderboardSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.activeColor,
                    ),
                  );
                }

                if (leaderboardSnapshot.hasError) {
                  developer.log(
                    'Leaderboard error: ${leaderboardSnapshot.error}',
                  );
                  developer.log(
                    'Error details: ${leaderboardSnapshot.error.toString()}',
                  );
                  return _buildErrorState();
                }

                // Add debugging info
                if (leaderboardSnapshot.hasData) {
                  developer.log(
                    'Received ${leaderboardSnapshot.data!.docs.length} documents from Firestore',
                  );
                }

                List<Map<String, dynamic>> leaderboardData;
                try {
                  leaderboardData = leaderboardSnapshot.hasData
                      ? _processLeaderboardData(
                          leaderboardSnapshot.data!.docs,
                          userRole: role,
                        )
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
                        _buildLeaderList(leaderboardData, isManager: isManager),
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
              Icon(Icons.live_tv, color: AppColors.successColor, size: 16),
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
            color: isSelected
                ? AppColors.activeColor
                : AppColors.elevatedBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.activeColor : AppColors.borderColor,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
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
                    if (isManager)
                      chip('Organization', LeaderboardFilter.organization),
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

    // Colors for the podium positions
    final colors = [
      const Color(0xFFFFD700), // Gold
      const Color(0xFFC0C0C0), // Silver
      const Color(0xFFCD7F32), // Bronze
    ];

    // Create the floating animation for the top employee
    return SizedBox(
      height: 300, // Increased height for the rectangular podium
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rectangular podium background
          Positioned(
            bottom: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: (0.1 * 255).toDouble(),
                    ),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

          // 2nd place (left)
          if (topThree.length > 1)
            Positioned(
              bottom: 20,
              left: MediaQuery.of(context).size.width * 0.2,
              child: _buildPodiumCardWithNumber(
                user: topThree[1],
                position: 1,
                color: colors[1],
                width: 120,
                numberText: '2',
              ),
            ),

          // 3rd place (right)
          if (topThree.length > 2)
            Positioned(
              bottom: 20,
              right: MediaQuery.of(context).size.width * 0.2,
              child: _buildPodiumCardWithNumber(
                user: topThree[2],
                position: 2,
                color: colors[2],
                width: 120,
                numberText: '3',
              ),
            ),

          // 1st place (top center) with hover-activated continuous floating animation
          if (topThree.isNotEmpty)
            Positioned(
              top: 0,
              child: MouseRegion(
                onEnter: (_) => setState(() => _isTopHovered = true),
                onExit: (_) => setState(() => _isTopHovered = false),
                child: AnimatedBuilder(
                  animation: _topHoverController,
                  builder: (context, child) {
                    // Always float; boost amplitude when hovered
                    final double amplitude = _isTopHovered ? 10.0 : 4.0;
                    final double dy =
                        sin(_topHoverController.value * pi) * amplitude;
                    return Transform.translate(
                      offset: Offset(0, dy),
                      child: child,
                    );
                  },
                  child: _buildPodiumCardWithNumber(
                    user: topThree[0],
                    position: 0,
                    color: colors[0],
                    width: 120,
                    numberText: '1',
                  ),
                ),
              ),
            ),
          // Numbers are now rendered under each card, so explicit Positioned badges are removed
        ],
      ),
    );
  }

  Widget _buildPodiumCard(
    Map<String, dynamic> user,
    int position,
    Color color,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: (0.3 * 255).toDouble()),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color,
            child: Text(
              (user['name']?.toString().isNotEmpty == true)
                  ? user['name'][0].toString().toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user['name'],
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${user['points']} pts',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Lvl ${user['level']}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumCardWithNumber({
    required Map<String, dynamic> user,
    required int position,
    required Color color,
    required double width,
    required String numberText,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPodiumCard(user, position, color, width),
        const SizedBox(height: 8),
        _buildPositionBadge(color: color, text: numberText),
      ],
    );
  }

  Widget _buildPositionBadge({required Color color, required String text}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: (0.4 * 255).toDouble()),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderList(
    List<Map<String, dynamic>> leaderboardData, {
    bool isManager = false,
  }) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final topPerformers = leaderboardData.take(5).toList();
    final remainingUsers = leaderboardData.skip(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current user's position (hidden for managers)
        if (!isManager && currentUserId != null && _currentUser != null) ...[
          const Text(
            'Your Position',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          _buildLeaderboardItem(
            _getCurrentUserRank(leaderboardData),
            isCurrentUser: true,
          ),
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
    );
  }

  Map<String, dynamic> _getCurrentUserRank(
    List<Map<String, dynamic>> leaderboardData,
  ) {
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

  Widget _buildLeaderboardItem(
    Map<String, dynamic> user, {
    bool isCurrentUser = false,
  }) {
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
                          color: isCurrentUser
                              ? AppColors.activeColor
                              : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
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
                    _buildStatChip(
                      Icons.military_tech,
                      'Lvl $level',
                      Colors.blue,
                    ),
                    _buildStatChip(
                      Icons.emoji_events,
                      '$badges',
                      Colors.orange,
                    ),
                    if (user['department'] != null &&
                        user['department'] != 'Unknown')
                      _buildStatChip(
                        Icons.business,
                        user['department'],
                        AppColors.successColor,
                      ),
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
            Icon(
              Icons.trending_up_outlined,
              color: AppColors.textMuted,
              size: 48,
            ),
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
                border: Border.all(
                  color: AppColors.activeColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.settings,
                        color: AppColors.activeColor,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'To Enable:',
                        style: TextStyle(
                          color: AppColors.activeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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
