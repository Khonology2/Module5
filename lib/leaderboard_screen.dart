import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/onboarding_service.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/utils/firestore_safe.dart';
import 'package:pdh/utils/firestore_web_circuit_breaker.dart';

enum LeaderboardFilter {
  thisMonth,
  allTime,
  points,
  streaks,
  myTeam,
  organization,
}

enum LeaderboardMetric { points, badges, streaks }

/// Helper class to represent onboarding users as document-like objects
class _OnboardingUserDoc {
  final Map<String, dynamic> data;
  _OnboardingUserDoc(this.data);
}

class LeaderboardScreen extends StatefulWidget {
  /// When true, admin is viewing; show managers only (no employees).
  final bool forAdminOversight;

  const LeaderboardScreen({super.key, this.forAdminOversight = false});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  // Initialize with concrete values to prevent initialization errors
  final Set<LeaderboardFilter> _selectedFilters = <LeaderboardFilter>{
    // Default to all-time because totalPoints is authoritative across the app.
    // Monthly points rely on `metrics.points.daily`, which may not be updated by all point-awarding flows.
    LeaderboardFilter.allTime,
    LeaderboardFilter.points,
  };
  LeaderboardMetric _currentMetric = LeaderboardMetric.points;
  UserProfile? _currentUser;
  late final AnimationController _topHoverController;
  bool _isTopHovered = false;
  List<Map<String, dynamic>> _lastLeaderboardData = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedUserDocs = const [];
  bool _hasFetchedUsers = false;
  Future<void>? _fetchUsersFuture;
  List<Map<String, dynamic>> _cachedOnboardingUsers = const [];
  bool _hasFetchedOnboarding = false;
  Future<void>? _fetchOnboardingFuture;

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
  void didUpdateWidget(covariant LeaderboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forAdminOversight != widget.forAdminOversight) {
      _hasFetchedUsers = false;
      _fetchUsersFuture = null;
    }
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
            // Department-based queries depend on current user; refetch when profile arrives.
            _hasFetchedUsers = false;
            _fetchUsersFuture = null;
          });
        }
      } catch (e) {
        developer.log('Error loading current user: $e');
      }
    } else {
      // No authenticated user; nothing to load for currentUser
    }
  }

  void _onFilterToggle(LeaderboardFilter filter) {
    setState(() {
      if (_selectedFilters.contains(filter)) {
        _selectedFilters.remove(filter);
      } else {
        // Handle mutually exclusive filters
        if (filter == LeaderboardFilter.thisMonth) {
          _selectedFilters.remove(LeaderboardFilter.allTime);
        } else if (filter == LeaderboardFilter.allTime) {
          _selectedFilters.remove(LeaderboardFilter.thisMonth);
        } else if (filter == LeaderboardFilter.points) {
          _selectedFilters.remove(LeaderboardFilter.streaks);
        } else if (filter == LeaderboardFilter.streaks) {
          _selectedFilters.remove(LeaderboardFilter.points);
        }
        _selectedFilters.add(filter);
      }

      // Only the team filter affects the Firestore query; refetch docs when toggled.
      if (filter == LeaderboardFilter.myTeam) {
        _hasFetchedUsers = false;
        _fetchUsersFuture = null;
      }
    });
  }

  void _onMetricChange(LeaderboardMetric metric) {
    setState(() {
      _currentMetric = metric;
    });
  }

  // Removed unused _getOrderByField to satisfy linter

  Query<Map<String, dynamic>> _buildQuery() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'users',
    );

    if (widget.forAdminOversight) {
      query = query.where('role', isEqualTo: 'manager').limit(500);
      return query;
    }

    // NOTE: We intentionally do NOT filter by `role` at the query level.
    // Some user docs may be missing the `role` field; we treat missing role as "employee"
    // and filter to employees in-memory during processing.

    // Apply team filter if selected
    if (_selectedFilters.contains(LeaderboardFilter.myTeam) &&
        _currentUser != null &&
        _currentUser!.department.isNotEmpty) {
      query = query.where('department', isEqualTo: _currentUser!.department);
    }

    // Use a simple query without ordering to avoid field existence issues
    // We'll handle sorting in the processing step
    // Increased limit to 10000 to show all employees in Full Leaderboard
    return query.limit(10000);
  }

  Future<void> _ensureUsersFetched({bool force = false}) {
    // Avoid repeated network reads on rebuild/animation.
    if (!force && _hasFetchedUsers) {
      return Future.value();
    }
    final existing = _fetchUsersFuture;
    if (!force && existing != null) return existing;

    final fut = () async {
      try {
        final snap = await FirestoreSafe.getQuery(_buildQuery());
        _cachedUserDocs = snap.docs;
        _hasFetchedUsers = true;
      } catch (e) {
        developer.log('Leaderboard fetch users failed: $e');
        // Keep previous cached docs if any
      }
    }();

    _fetchUsersFuture = fut;
    return fut;
  }

  Future<void> _ensureOnboardingFetched({bool force = false}) {
    if (!force && _hasFetchedOnboarding) {
      return Future.value();
    }
    final existing = _fetchOnboardingFuture;
    if (!force && existing != null) return existing;

    final fut = () async {
      try {
        _cachedOnboardingUsers = await _fetchOnboardingUsers();
        _hasFetchedOnboarding = true;
      } catch (e) {
        developer.log('Leaderboard fetch onboarding failed: $e');
      }
    }();

    _fetchOnboardingFuture = fut;
    return fut;
  }

  Future<List<Map<String, dynamic>>> _computeLeaderboardFromCache() async {
    if (widget.forAdminOversight) {
      return _processLeaderboardData(
        _cachedUserDocs,
        forAdminOversight: true,
      );
    }
    await _ensureOnboardingFetched();
    final onboardingDocs = _cachedOnboardingUsers.map((userData) {
      return _OnboardingUserDoc(userData);
    }).toList();
    final allDocs = <dynamic>[..._cachedUserDocs, ...onboardingDocs];
    return _processLeaderboardData(allDocs);
  }

  /// Fetch onboarding users and convert them to a list of maps compatible with user format
  Future<List<Map<String, dynamic>>> _fetchOnboardingUsers() async {
    try {
      final onboardingSnapshot = await FirestoreSafe.getQuery(
        FirebaseFirestore.instance.collection('onboarding'),
      );

      // Filter onboarding users to only include those with 'employee' persona for PDH
      final employeeOnboardingUsers = onboardingSnapshot.docs.where((doc) {
        final data = doc.data();
        final moduleAccessRole = data['moduleAccessRole'] as String?;
        return OnboardingService.shouldIncludeUser(
          moduleAccessRole,
          'employee',
        );
      }).toList();

      // Convert onboarding users to user format
      return employeeOnboardingUsers.map((doc) {
        final data = doc.data();
        final convertedData =
            OnboardingService.convertOnboardingUserToUserFormat(data, doc.id);
        // Add the document ID for reference
        convertedData['_id'] = doc.id;
        return convertedData;
      }).toList();
    } catch (e) {
      developer.log('Error fetching onboarding users: $e');
      return [];
    }
  }

  // Calculate monthly points from daily points data
  int _calculateMonthlyPoints(Map<String, dynamic> data) {
    try {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      // Get daily points from metrics.points.daily
      final metrics = data['metrics'] as Map<String, dynamic>?;
      if (metrics == null) return 0;

      final points = metrics['points'] as Map<String, dynamic>?;
      if (points == null) return 0;

      final daily = points['daily'] as Map<String, dynamic>?;
      if (daily == null) return 0;

      int monthlyTotal = 0;

      // Iterate through daily points and sum up current month's points
      daily.forEach((dateKey, value) {
        try {
          // Date key format: YYYYMMDD (e.g., "20240115")
          if (dateKey.length == 8) {
            final year = int.tryParse(dateKey.substring(0, 4));
            final month = int.tryParse(dateKey.substring(4, 6));

            if (year == currentYear && month == currentMonth) {
              final pointsValue = value is num
                  ? value.toInt()
                  : (value is int
                        ? value
                        : (int.tryParse(value.toString()) ?? 0));
              monthlyTotal += pointsValue;
            }
          }
        } catch (e) {
          // Skip invalid date keys
        }
      });

      return monthlyTotal;
    } catch (e) {
      developer.log('Error calculating monthly points: $e');
      return 0;
    }
  }

  int _coerceInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  num _coerceNum(dynamic value, [num fallback = 0]) {
    if (value is num) return value;
    if (value == null) return fallback;
    return num.tryParse(value.toString()) ?? fallback;
  }

  List<Map<String, dynamic>> _processLeaderboardData(
    List<dynamic> docs, {
    String? userRole,
    bool forAdminOversight = false,
  }) {
    try {
      developer.log('Processing ${docs.length} documents for leaderboard');

      // If no docs, return empty list but don't treat as error
      if (docs.isEmpty) {
        developer.log('No documents to process');
        return [];
      }

      // Determine filter states
      final isThisMonth = _selectedFilters.contains(
        LeaderboardFilter.thisMonth,
      );
      final isAllTime = _selectedFilters.contains(LeaderboardFilter.allTime);
      final isPoints = _selectedFilters.contains(LeaderboardFilter.points);
      final isStreaks = _selectedFilters.contains(LeaderboardFilter.streaks);

      // Determine time period: if thisMonth is selected (and allTime is not), use monthly; otherwise use all-time
      final useThisMonth = isThisMonth && !isAllTime;

      // Determine metric: if streaks is selected (and points is not), use streaks; otherwise use points
      final useStreaks = isStreaks && !isPoints;
      final usePoints =
          !useStreaks; // Default to points if streaks not selected

      // Use the role parameter instead of checking filters
      final isManager = userRole == 'manager';
      List<dynamic> filteredDocs;

      // For admin: show only managers. For others: show only employees (exclude managers).
      filteredDocs = docs.where((doc) {
        try {
          Map<String, dynamic>? data;

          // Handle both QueryDocumentSnapshot and _OnboardingUserDoc
          if (doc is QueryDocumentSnapshot) {
            data = doc.data() as Map<String, dynamic>?;
          } else if (doc is _OnboardingUserDoc) {
            data = doc.data;
          }

          if (data != null) {
            var role = (data['role'] ?? 'employee').toString().trim();
            role = role.isEmpty ? 'employee' : role.toLowerCase();
            if (forAdminOversight) {
              return role == 'manager';
            }
            if (role != 'employee') {
              return false; // Exclude managers and any other non-employee roles
            }
            final optIn = data['leaderboardOptin'];
            final legacyOptIn = data['leaderboardParticipation'];
            return optIn == true || legacyOptIn == true;
          }
          return false;
        } catch (e) {
          final docId = doc is QueryDocumentSnapshot ? doc.id : 'unknown';
          developer.log('Error processing doc $docId: $e');
          return false;
        }
      }).toList();

      developer.log('${filteredDocs.length} users to display on leaderboard');

      // If no users to display, return empty list
      if (filteredDocs.isEmpty) {
        if (!isManager) {
          developer.log('No employees have enabled leaderboard participation');
        }
        return [];
      }

      // Process and sort data with better error handling
      List<Map<String, dynamic>> processedData = filteredDocs.map((doc) {
        Map<String, dynamic> data;
        String docId;

        // Handle both QueryDocumentSnapshot and _OnboardingUserDoc
        if (doc is QueryDocumentSnapshot) {
          data = doc.data() as Map<String, dynamic>;
          docId = doc.id;
        } else if (doc is _OnboardingUserDoc) {
          data = doc.data;
          docId = data['_id'] as String? ?? 'unknown';
        } else {
          data = {};
          docId = 'unknown';
        }

        // Safely extract values with defaults
        int badgeCount = 0;
        try {
          // Prefer v2 badge summary/counts (category-based badge system)
          final badgeV2Summary = data['badgeV2Summary'];
          if (badgeV2Summary is Map<String, dynamic>) {
            final earned = badgeV2Summary['earned'];
            if (earned is num) {
              badgeCount = earned.toInt();
            } else if (earned is String) {
              badgeCount = int.tryParse(earned) ?? 0;
            }
          }
          if (badgeCount == 0) {
            final badgesV2Field = data['badgesV2'];
            if (badgesV2Field is List) {
              badgeCount = badgesV2Field.length;
            } else if (badgesV2Field is num) {
              badgeCount = badgesV2Field.toInt();
            } else if (badgesV2Field is String) {
              badgeCount = int.tryParse(badgesV2Field) ?? 0;
            }
          }

          // Legacy fallback (kept for managers/older data)
          final badgesField = data['badges'];
          if (badgeCount == 0) {
            if (badgesField is List) {
              badgeCount = badgesField.length;
            } else if (badgesField is num) {
              badgeCount = badgesField.toInt();
            } else if (badgesField is String) {
              badgeCount = int.tryParse(badgesField) ?? 0;
            }
          }

          if (badgeCount == 0) {
            final earnedBadgesCount = data['earnedBadgesCount'];
            if (earnedBadgesCount is num) {
              badgeCount = earnedBadgesCount.toInt();
            } else if (earnedBadgesCount is String) {
              badgeCount = int.tryParse(earnedBadgesCount) ?? 0;
            } else {
              final badgeSummary = data['badgeSummary'];
              if (badgeSummary is Map<String, dynamic>) {
                final earned = badgeSummary['earned'];
                if (earned is num) {
                  badgeCount = earned.toInt();
                } else if (earned is String) {
                  badgeCount = int.tryParse(earned) ?? 0;
                }
              }
            }
          }

          if (_currentUser != null && docId == _currentUser!.uid) {
            badgeCount = max(badgeCount, _currentUser!.badgesV2.length);
          }
        } catch (e) {
          developer.log('Error processing badges for user $docId: $e');
        }

        // Calculate points based on time filter
        num points = 0;
        if (useThisMonth) {
          // Monthly points require metrics.points.daily to be present.
          // If not present (or not used by some point-award flows), fall back to 0 for month view.
          points = _calculateMonthlyPoints(data);
        } else {
          // All time - use totalPoints
          try {
            points = _coerceNum(data['totalPoints'], 0);
          } catch (e) {
            developer.log('Error processing points for user $docId: $e');
          }
        }

        // Extract streak data
        int currentStreak = 0;
        int longestStreak = 0;
        try {
          currentStreak = _coerceInt(data['currentStreak'], 0);
          longestStreak = _coerceInt(data['longestStreak'], 0);
        } catch (e) {
          developer.log('Error processing streaks for user $docId: $e');
        }

        return {
          'userId': docId,
          'name': data['displayName']?.toString() ?? 'Anonymous',
          // Use ints for display consistency.
          'points': _coerceInt(points, 0),
          'badges': badgeCount,
          'currentStreak': currentStreak,
          'longestStreak': longestStreak,
          'department': data['department']?.toString() ?? 'Unknown',
          'jobTitle': data['jobTitle']?.toString() ?? 'Unknown',
        };
      }).toList();

      // Sort by the selected metric based on filters
      // Priority: Filter selections > Dropdown menu selection
      if (useStreaks) {
        // Sort by streaks (use currentStreak, fallback to longestStreak)
        processedData.sort((a, b) {
          final aStreak =
              (a['currentStreak'] as int?) ?? (a['longestStreak'] as int?) ?? 0;
          final bStreak =
              (b['currentStreak'] as int?) ?? (b['longestStreak'] as int?) ?? 0;
          return bStreak.compareTo(aStreak);
        });
      } else if (usePoints) {
        // Sort by points (already calculated based on time filter - monthly or all-time)
        processedData.sort((a, b) {
          final aPoints = (a['points'] as num?) ?? 0;
          final bPoints = (b['points'] as num?) ?? 0;
          return bPoints.compareTo(aPoints);
        });
      } else {
        // Fallback to current metric (from dropdown menu)
        switch (_currentMetric) {
          case LeaderboardMetric.points:
            processedData.sort((a, b) {
              final aPoints = (a['points'] as num?) ?? 0;
              final bPoints = (b['points'] as num?) ?? 0;
              return bPoints.compareTo(aPoints);
            });
            break;
          case LeaderboardMetric.badges:
            processedData.sort((a, b) {
              final aBadges = (a['badges'] as int?) ?? 0;
              final bBadges = (b['badges'] as int?) ?? 0;
              return bBadges.compareTo(aBadges);
            });
            break;
          case LeaderboardMetric.streaks:
            processedData.sort((a, b) {
              final aStreak =
                  (a['currentStreak'] as int?) ??
                  (a['longestStreak'] as int?) ??
                  0;
              final bStreak =
                  (b['currentStreak'] as int?) ??
                  (b['longestStreak'] as int?) ??
                  0;
              return bStreak.compareTo(aStreak);
            });
            break;
        }
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
    // If Firestore Web entered an unrecoverable internal state, don't keep subscribing.
    if (kIsWeb && FirestoreWebCircuitBreaker.isBroken) {
      return _buildFirestoreBrokenState();
    }

    final isManager = _currentUser?.role == 'manager';

    // Render as a plain widget so it works inside MainLayout
    return Container(
      color: Colors.transparent,
      child: FutureBuilder<void>(
        future: _ensureUsersFetched(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState();
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: () async {
              try {
                if (_cachedUserDocs.isNotEmpty) {
                  return await _computeLeaderboardFromCache();
                }
                return _lastLeaderboardData;
              } catch (e) {
                developer.log('Error processing leaderboard data: $e');
                return _lastLeaderboardData;
              }
            }(),
            builder: (context, dataSnapshot) {
              List<Map<String, dynamic>> leaderboardData;
              if (dataSnapshot.hasData) {
                leaderboardData = dataSnapshot.data!;
                _lastLeaderboardData = leaderboardData;
              } else if (dataSnapshot.hasError) {
                return _buildErrorState();
              } else {
                leaderboardData = _lastLeaderboardData;
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await _ensureUsersFetched(force: true);
                  await _ensureOnboardingFetched(force: true);
                  if (mounted) setState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: _buildHeader()),
                          const SizedBox(width: 12),
                          IconButton(
                            tooltip: 'Refresh',
                            onPressed: () async {
                              await _ensureUsersFetched(force: true);
                              await _ensureOnboardingFetched(force: true);
                              if (mounted) setState(() {});
                            },
                            icon: const Icon(
                              Icons.refresh,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFiltersBar(isManager: isManager),
                      const SizedBox(height: 16),
                      leaderboardData.isEmpty
                          ? _buildEmptyState()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildPodium(leaderboardData),
                                const SizedBox(height: 20),
                                _buildLeaderList(
                                  leaderboardData,
                                  isManager: isManager,
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFirestoreBrokenState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh, color: AppColors.warningColor, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Live data temporarily unavailable',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'A Firestore web issue was detected. Please reload the page to recover.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: FirestoreWebCircuitBreaker.forceReload,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Leaderboard',
            style: AppTypography.heading2.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 35,
                height: 35,
                child: Image.asset(
                  'assets/Internet_Web_Browser/Live.png', // Corrected asset path
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ), // Replaced Icon with Image.asset
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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                  PopupMenuItem(
                    value: LeaderboardMetric.streaks,
                    child: Text(
                      'Sort by Streaks',
                      style: TextStyle(
                        color: _currentMetric == LeaderboardMetric.streaks
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
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
    final bool showTopPerformersSection = !isManager;

    // Podium already shows top 3; avoid duplicating them in lists below.
    final List<Map<String, dynamic>> topPerformers = showTopPerformersSection
        ? leaderboardData.skip(3).take(5).toList()
        : const [];

    final int alreadyShownCount = showTopPerformersSection
        ? (3 + topPerformers.length)
        : 3;

    final remainingUsers = leaderboardData.skip(alreadyShownCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current user's position (hidden for managers)
        if (!isManager && currentUserId != null && _currentUser != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Position',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _showCompetitorAnalysis(context, leaderboardData),
                icon: const Icon(Icons.insights, size: 16),
                label: const Text('AI Competitor Analysis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.activeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildLeaderboardItem(
            _getCurrentUserRank(leaderboardData),
            isCurrentUser: true,
          ),
          const SizedBox(height: 20),
        ],

        if (showTopPerformersSection && topPerformers.isNotEmpty) ...[
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
        ],
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

    final bool isManager = _currentUser!.role.trim().toLowerCase() == 'manager';
    final bool optedIn = _currentUser!.leaderboardOptin;
    if (!isManager && !optedIn) {
      // Employees who opted out shouldn't be surfaced anywhere on the leaderboard
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
          'badges': _currentUser!.badgesV2.length,
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
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                    _buildStatChip(
                      null, // Set icon to null as we are using iconWidget
                      '$points pts',
                      Colors.amber,
                      iconWidget: SizedBox(
                        width: 12,
                        height: 12,
                        child: Image.asset(
                          'assets/Process_Flows_Automation/Points.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    _buildStatChip(
                      null, // Set icon to null as we are using iconWidget
                      '$badges',
                      Colors.orange,
                      iconWidget: SizedBox(
                        width: 12,
                        height: 12,
                        child: Image.asset(
                          'assets/Goal_Target/Goal_Target_White_Badge_Red_Badge_White.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    if (user['department'] != null &&
                        user['department'] != 'Unknown')
                      _buildStatChip(
                        null, // Set icon to null as we are using iconWidget
                        user['department'],
                        AppColors.successColor,
                        iconWidget: SizedBox(
                          width: 12,
                          height: 12,
                          child: Image.asset(
                          'assets/Office_Workplace/Offices.png',
                            fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                          ),
                        ),
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

  Widget _buildStatChip(
    IconData? icon,
    String text,
    Color color, {
    Widget? iconWidget,
  }) {
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
          if (iconWidget != null) ...[
            SizedBox(width: 19, height: 19, child: iconWidget),
          ] else if (icon != null) ...[
            Icon(icon, color: color, size: 19),
          ],
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
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
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

  Future<void> _showCompetitorAnalysis(
    BuildContext context,
    List<Map<String, dynamic>> leaderboardData,
  ) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || _currentUser == null) return;

    final currentUserRank = _getCurrentUserRank(leaderboardData);
    final currentRank = currentUserRank['rank'] ?? leaderboardData.length + 1;

    // Get users ranked just above and below
    final usersAbove = leaderboardData
        .where((user) => (user['rank'] ?? 0) < currentRank)
        .take(3)
        .toList();
    final usersBelow = leaderboardData
        .where((user) => (user['rank'] ?? 0) > currentRank)
        .take(2)
        .toList();

    if (usersAbove.isEmpty && usersBelow.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough data for competitor analysis'),
            backgroundColor: AppColors.warningColor,
          ),
        );
      }
      return;
    }

    // Show loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
          ),
        ),
      );
    }

    try {
      // Get goals for current user and competitors
      final currentUserGoals = await DatabaseService.getUserGoals(
        currentUserId,
      );

      // Build comparison data
      final comparisonData = StringBuffer();
      comparisonData.writeln('Current User (Rank $currentRank):');
      comparisonData.writeln('Points: ${currentUserRank['points'] ?? 0}');
      comparisonData.writeln('Badges: ${currentUserRank['badges'] ?? 0}');
      comparisonData.writeln('Goals: ${currentUserGoals.length}');
      comparisonData.writeln('');

      for (var competitor in usersAbove) {
        final competitorId = competitor['userId'];
        final competitorGoals = await DatabaseService.getUserGoals(
          competitorId,
        );
        comparisonData.writeln(
          'Competitor Above (Rank ${competitor['rank']}):',
        );
        comparisonData.writeln('Name: ${competitor['name']}');
        comparisonData.writeln('Points: ${competitor['points'] ?? 0}');
        comparisonData.writeln('Badges: ${competitor['badges'] ?? 0}');
        comparisonData.writeln('Goals: ${competitorGoals.length}');
        comparisonData.writeln('');
      }

      for (var competitor in usersBelow) {
        final competitorId = competitor['userId'];
        final competitorGoals = await DatabaseService.getUserGoals(
          competitorId,
        );
        comparisonData.writeln(
          'Competitor Below (Rank ${competitor['rank']}):',
        );
        comparisonData.writeln('Name: ${competitor['name']}');
        comparisonData.writeln('Points: ${competitor['points'] ?? 0}');
        comparisonData.writeln('Badges: ${competitor['badges'] ?? 0}');
        comparisonData.writeln('Goals: ${competitorGoals.length}');
        comparisonData.writeln('');
      }

      // Generate AI analysis
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: Content.text(
          'You are an AI assistant specialized in analyzing leaderboard performance and providing actionable insights. '
          'Compare the current user\'s performance with competitors ranked above and below them. '
          'Identify specific differences in:\n'
          '1. Points earned and how they\'re distributed\n'
          '2. Goal completion rates and types\n'
          '3. Badge achievements and types\n'
          '4. Activity patterns and consistency\n'
          '\n'
          'Provide specific, actionable recommendations on what the user should focus on to improve their ranking. '
          'Be encouraging but direct. Format your response in clear sections with bullet points.',
        ),
      );

      final prompt = [
        Content.text(
          'Analyze this leaderboard comparison data and provide insights:\n\n'
          '$comparisonData\n\n'
          'What specific actions or achievements do the competitors have that the current user doesn\'t? '
          'What should the current user focus on to move up in the rankings?',
        ),
      ];

      final response = await model.generateContent(prompt);
      final analysis =
          response.text?.replaceAll('*', '').trim() ??
          'Unable to generate analysis. Please try again.';

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show analysis dialog
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black.withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            title: Row(
              children: [
                Icon(Icons.insights, color: AppColors.activeColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  'AI Competitor Analysis',
                  style: AppTypography.heading4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Text(
                  analysis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Close',
                  style: TextStyle(color: AppColors.activeColor),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating analysis: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }
}
