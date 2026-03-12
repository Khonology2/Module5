import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/utils/firestore_safe.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/models/goal.dart';

class AdminDashboardScreen extends StatefulWidget {
  final bool embedded;

  /// When set, quick actions call this to switch admin portal route instead of pushing.
  final void Function(String route)? onNavigate;

  const AdminDashboardScreen({
    super.key,
    this.embedded = false,
    this.onNavigate,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _adminName = 'Admin';
  late Stream<List<EmployeeData>> _managersStream;
  String? _currentProfilePhotoUrl;
  final Stopwatch _loadWatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _loadAdminName();
    _managersStream = ManagerRealtimeService.getManagersDataStream();
    _loadWatch
      ..reset()
      ..start();
  }

  Future<void> _loadAdminName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String name = 'Admin';
      if (user != null) {
        final profile = await DatabaseService.getUserProfile(user.uid);
        final display = profile.displayName.trim();
        if (display.isNotEmpty) {
          name = display.split(' ').first;
        } else if ((user.displayName ?? '').isNotEmpty) {
          name = user.displayName!.split(' ').first;
        } else if ((user.email ?? '').isNotEmpty) {
          name = user.email!.split('@').first;
        }
      }
      if (!mounted) return;
      setState(() {
        _adminName = name;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: StreamBuilder<List<EmployeeData>>(
        stream: _managersStream,
        builder: (context, managersSnap) {
          if (managersSnap.hasError) {
            return Center(
              child: Text('Error loading managers: ${managersSnap.error}'),
            );
          }
          if (!managersSnap.hasData) {
            final timedOut = _loadWatch.elapsed > const Duration(seconds: 12);
            if (timedOut) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppComponents.card(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Still loading…',
                            style: AppTypography.heading4,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We couldn’t load your team data. This is usually caused by a connection issue or missing Firestore permissions.',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _managersStream =
                                        ManagerRealtimeService.getManagersDataStream();
                                    _loadWatch
                                      ..reset()
                                      ..start();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.activeColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Retry'),
                              ),
                              OutlinedButton(
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  await AuthService().signOut();
                                  if (mounted) {
                                    navigator.pushNamedAndRemoveUntil(
                                      '/sign_in',
                                      (route) => false,
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Text('Sign out'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }
            return SizedBox(
              height: 360,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.activeColor,
                  ),
                ),
              ),
            );
          }
          final managers = managersSnap.data!;
          if (_loadWatch.isRunning) {
            _loadWatch.stop();
          }

          final metrics = _computeTeamMetrics(managers);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<UserProfile?>(
                stream: _getAdminProfileStream(),
                builder: (context, profileSnap) {
                  return _buildWelcomeCard();
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildDailyMotivationCard(),
              const SizedBox(height: AppSpacing.xl),
              _buildQuickActions(),
              const SizedBox(height: AppSpacing.xl),
              _buildTeamAtAGlance(metrics, managers),
              const SizedBox(height: AppSpacing.xl),
              _buildProgressTrends(managers),
              const SizedBox(height: AppSpacing.xl),
              _buildTeamProgressComparison(managers),
              const SizedBox(height: AppSpacing.xl),
              _buildRisksCard(managers),
              const SizedBox(height: AppSpacing.xl),
              _buildTopTwoPerformers(managers),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );

    // Admin dashboard is always used embedded in admin portal.
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/khono_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: content,
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Transparent black background to show background image
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  Widget _buildWelcomeCard() {
    final greeting = _getTimeBasedGreeting();
    return _card(
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
              color: Colors.black.withValues(alpha: 0.15),
            ),
            child: ClipOval(
              child: ((_currentProfilePhotoUrl ?? '').isNotEmpty)
                  ? Image.network(
                      _currentProfilePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 36,
                      ),
                    )
                  : const Icon(Icons.person, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${_resolveAdminName()}!',
                  style: AppTypography.heading4,
                ),
                const SizedBox(height: 5),
                Text(
                  'Overview of all managers across the organization.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMotivationCard() {
    return AppComponents.card(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppColors.activeColor.withValues(alpha: 0.1),
              AppColors.warningColor.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Image.asset(
                'Innovation_Brainstorm/innovation_brainstorm_red_badge_white.png',
                width: 78,
                height: 78,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Motivation',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.activeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDailyMotivation(),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _getDailyMotivation() {
    final motivations = [
      "Great leaders inspire others to dream more, learn more, do more.",
      "Your guidance today shapes your team's success tomorrow.",
      "Consistency beats intensity—coach your team daily.",
      "Empower your team; results will follow.",
      "Small nudges create big momentum.",
      "Celebrate progress, not just outcomes.",
      "Lead with clarity, empathy, and action.",
      "The best leaders are those who develop other leaders.",
      "Your team's growth reflects your leadership excellence.",
      "Listen to understand, not just to respond.",
      "Delegate with trust, support with guidance.",
      "A great leader takes people where they don't necessarily want to go, but ought to be.",
      "Build bridges, not walls, within your team.",
      "Your vision becomes reality when your team believes in it.",
      "Leadership is about making others better as a result of your presence.",
      "Invest in your team's development; it's your greatest asset.",
      "Clear communication is the foundation of effective leadership.",
      "Recognize effort, reward achievement, inspire excellence.",
      "The best leaders create more leaders, not more followers.",
      "Your team's success is a reflection of your leadership.",
      "Lead by example, not by command.",
      "Empathy and strength together create unstoppable leadership.",
      "Your decisions today shape your team's tomorrow.",
      "Great leaders don't create followers; they create more leaders.",
      "Trust your team, and they will trust you.",
      "The mark of a great leader is the ability to bring out the best in others.",
      "Your leadership legacy is built one interaction at a time.",
      "Challenge your team to grow, support them to succeed.",
      "Effective leadership is about influence, not authority.",
      "Your team's potential is unlimited when you unlock it.",
    ];
    // Use day of month to get consistent daily motivation (1-30)
    final dayOfMonth = DateTime.now().day;
    return motivations[(dayOfMonth - 1) % motivations.length];
  }

  Stream<UserProfile?> _getAdminProfileStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);
    return FirestoreSafe.stream(
      FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
    ).map((doc) {
      if (!doc.exists) return null;
      final profile = UserProfile.fromFirestore(doc);
      _currentProfilePhotoUrl =
          (profile.profilePhotoUrl != null &&
              profile.profilePhotoUrl!.isNotEmpty)
          ? profile.profilePhotoUrl
          : null;
      return profile;
    });
  }

  String _resolveAdminName() {
    if (_adminName.isNotEmpty && _adminName != 'Admin') {
      return _adminName.split(' ').first;
    }
    final authUser = FirebaseAuth.instance.currentUser;
    final display = (authUser?.displayName ?? '').trim();
    if (display.isNotEmpty) return display.split(' ').first;
    final email = (authUser?.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Admin';
  }

  TeamMetrics _computeTeamMetrics(List<EmployeeData> employees) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final totalEmployees = employees.length;
    final activeEmployees = employees
        .where((e) => e.lastActivity.isAfter(sevenDaysAgo))
        .length;
    final avgProgress = totalEmployees > 0
        ? employees.map((e) => e.avgProgress).fold(0.0, (a, b) => a + b) /
              totalEmployees
        : 0.0;
    final engagement = totalEmployees > 0
        ? (activeEmployees / totalEmployees) * 100.0
        : 0.0;

    int onTrack = 0;
    int atRisk = 0;
    int overdue = employees.fold<int>(0, (acc, e) => acc + e.overdueGoalsCount);
    for (final e in employees) {
      for (final g in e.goals) {
        if (g.status != GoalStatus.completed && g.targetDate.isAfter(now)) {
          if (g.progress >= 30) {
            onTrack++;
          } else {
            atRisk++;
          }
        }
      }
    }

    return TeamMetrics(
      totalEmployees: totalEmployees,
      activeEmployees: activeEmployees,
      onTrackGoals: onTrack,
      atRiskGoals: atRisk,
      overdueGoals: overdue,
      avgTeamProgress: avgProgress,
      teamEngagement: engagement,
      totalPointsEarned: employees.fold<int>(
        0,
        (acc, e) => acc + e.totalPoints,
      ),
      goalsCompleted: employees.fold<int>(
        0,
        (acc, e) => acc + e.completedGoalsCount,
      ),
      lastUpdated: DateTime.now(),
    );
  }

  /// Single consolidated card: no duplication of dashboard metrics.
  Widget _buildTeamAtAGlance(TeamMetrics? m, List<EmployeeData> employees) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final total = m?.totalEmployees ?? employees.length;
    final active =
        m?.activeEmployees ??
        employees.where((e) => e.lastActivity.isAfter(sevenDaysAgo)).length;
    final avgProgress = m?.avgTeamProgress ?? 0.0;
    final engagement =
        m?.teamEngagement ?? (total > 0 ? (active / total) * 100.0 : 0.0);
    final overdue = m?.overdueGoals ?? 0;
    final lowEngagement = total - active; // Inactive in last 7 days

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Managers at a glance', style: AppTypography.heading2),
          const SizedBox(height: 4),
          Text(
            'Key metrics for all managers. See trends and risks below.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _kpi('Managers', total.toString()),
              const SizedBox(width: 8),
              _kpi('Avg progress', '${avgProgress.toStringAsFixed(0)}%'),
              const SizedBox(width: 8),
              _kpi('Engagement (7d)', '${engagement.toStringAsFixed(0)}%'),
            ],
          ),
          if (overdue > 0 || lowEngagement > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (overdue > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppColors.warningColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$overdue overdue goal(s)',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.warningColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                if (lowEngagement > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_off_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$lowEngagement low engagement',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Progress trends over time: activity in the last 7 days (from recentActivities).
  Widget _buildProgressTrends(List<EmployeeData> employees) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayCounts = List<int>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final dayStart = today.subtract(Duration(days: 6 - i));
      final dayEnd = dayStart.add(const Duration(days: 1));
      for (final e in employees) {
        for (final a in e.recentActivities) {
          if (!a.timestamp.isBefore(dayStart) && a.timestamp.isBefore(dayEnd)) {
            dayCounts[i]++;
          }
        }
      }
    }
    final maxCount = dayCounts.isEmpty
        ? 1
        : dayCounts.reduce((a, b) => a > b ? a : b);
    final maxVal = maxCount == 0 ? 1 : maxCount;

    String dayLabel(int i) {
      final d = today.subtract(Duration(days: 6 - i));
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[d.weekday - 1];
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: AppColors.activeColor, size: 22),
              const SizedBox(width: 8),
              Text('Progress trends', style: AppTypography.heading2),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Manager activity over the last 7 days.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (i) {
              final h = maxVal > 0
                  ? (dayCounts[i] / maxVal).clamp(0.1, 1.0)
                  : 0.1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 80,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 80 * h,
                          decoration: BoxDecoration(
                            color: AppColors.activeColor.withValues(alpha: 0.8),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dayLabel(i),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${dayCounts[i]}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Visual comparison of team members by progress (and points).
  Widget _buildTeamProgressComparison(List<EmployeeData> employees) {
    final sorted = [...employees]
      ..sort((a, b) => b.avgProgress.compareTo(a.avgProgress));
    if (sorted.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manager progress comparison', style: AppTypography.heading2),
            const SizedBox(height: 12),
            Text('No managers yet.', style: AppTypography.muted),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: AppColors.activeColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text('Team progress comparison', style: AppTypography.heading2),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Compare progress across team members. Top to low performers.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...sorted.map((e) {
            final isTop = sorted.indexOf(e) < 3;
            final isLow =
                sorted.indexOf(e) >= sorted.length - 2 && sorted.length >= 3;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircleAvatar(
                      backgroundColor: isTop
                          ? AppColors.successColor.withValues(alpha: 0.3)
                          : isLow
                          ? AppColors.warningColor.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.15),
                      child: Text(
                        e.profile.displayName.isNotEmpty
                            ? e.profile.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(
                      e.profile.displayName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: isTop ? FontWeight.w600 : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: LinearProgressIndicator(
                      value: (e.avgProgress / 100).clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isTop
                            ? AppColors.successColor
                            : isLow
                            ? AppColors.warningColor
                            : AppColors.activeColor,
                      ),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${e.avgProgress.toStringAsFixed(0)}%',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Risks: overdue goals and low engagement with actionable list of who.
  Widget _buildRisksCard(List<EmployeeData> employees) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final overdue = employees.where((e) => e.overdueGoalsCount > 0).toList();
    final lowEngagement = employees
        .where((e) => !e.lastActivity.isAfter(sevenDaysAgo))
        .toList();

    if (overdue.isEmpty && lowEngagement.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: AppColors.successColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text('Risks & attention', style: AppTypography.heading2),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'No overdue goals or low-engagement managers right now.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warningColor,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text('Risks & attention', style: AppTypography.heading2),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Overdue goals and low engagement. Review and nudge where needed.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (overdue.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.assignment_late,
                  size: 18,
                  color: AppColors.warningColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Overdue goals (${overdue.length} manager(s))',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...overdue
                .take(5)
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 26, bottom: 4),
                    child: Text(
                      '${e.profile.displayName} · ${e.overdueGoalsCount} overdue',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            if (overdue.length > 5)
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 4),
                child: Text(
                  '+ ${overdue.length - 5} more',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
          if (lowEngagement.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Low engagement — no activity in 7 days (${lowEngagement.length})',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...lowEngagement
                .take(5)
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(left: 26, bottom: 4),
                    child: Text(
                      e.profile.displayName,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            if (lowEngagement.length > 5)
              Padding(
                padding: const EdgeInsets.only(left: 26, top: 4),
                child: Text(
                  '+ ${lowEngagement.length - 5} more',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                if (widget.onNavigate != null) {
                  widget.onNavigate!('/manager_oversight');
                } else {
                  Navigator.pushNamed(context, '/manager_oversight');
                }
              },
              icon: const Icon(Icons.people, size: 18),
              label: const Text('Open Manager Oversight'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.activeColor,
                side: BorderSide(
                  color: AppColors.activeColor.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Transparent black for KPI tiles to match card styling
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.heading4.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.muted),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildGreetingCard(List<EmployeeData> employees) {
    final greeting = _timeGreeting();
    final teamSize = employees.length;
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: AppTypography.heading1),
                const SizedBox(height: 4),
                Text('Team size: $teamSize', style: AppTypography.muted),
              ],
            ),
          ),
          // simple avatar or placeholder
          const CircleAvatar(child: Icon(Icons.person)),
        ],
      ),
    );
  }

  String _timeGreeting() {
    final hour = DateTime.now().hour;
    final name = _adminName;
    if (hour < 12) return 'Good morning, $name';
    if (hour < 17) return 'Good afternoon, $name';
    return 'Good evening, $name';
  }

  Widget _buildTopTwoPerformers(List<EmployeeData> employees) {
    final top = [...employees]
      ..sort((a, b) => b.totalPoints.compareTo(a.totalPoints));
    final top2 = top.take(2).toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top managers', style: AppTypography.heading2),
          const SizedBox(height: 12),
          if (top2.isEmpty)
            Text('No performers yet', style: AppTypography.muted)
          else
            ...top2.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.profile.displayName,
                        style: AppTypography.bodyText,
                      ),
                    ),
                    // Active status indicator
                    _buildActiveStatusIndicator(e),
                    const SizedBox(width: 8),
                    Text('${e.totalPoints}', style: AppTypography.heading4),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveStatusIndicator(EmployeeData employee) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    bool isActiveToday = employee.lastActivity.isAfter(today);
    bool isActiveThisWeek = employee.lastActivity.isAfter(sevenDaysAgo);

    Color statusColor;
    IconData statusIcon;
    String tooltip;

    if (isActiveToday) {
      statusColor = Colors.green;
      statusIcon = Icons.circle;
      tooltip = 'Active today';
    } else if (isActiveThisWeek) {
      statusColor = Colors.orange;
      statusIcon = Icons.circle;
      tooltip = 'Active this week';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.circle_outlined;
      tooltip = 'Inactive';
    }

    return Tooltip(
      message: tooltip,
      child: Icon(statusIcon, color: statusColor, size: 12),
    );
  }

  Widget _buildQuickActions() {
    final items = [
      ('Progress', '/manager_oversight'),
      ('Leaderboard', '/org_leaderboard'),
      ('Settings & Privacy', '/admin_settings'),
      ('Repository Audit', '/admin_repository_audit'),
    ];
    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTypography.heading4),
          const SizedBox(height: AppSpacing.md),
          ...List.generate((items.length / 4).ceil(), (row) {
            final start = row * 4;
            final rowItems = items.skip(start).take(4).toList();
            return Padding(
              padding: EdgeInsets.only(
                bottom: row < (items.length / 4).ceil() - 1 ? AppSpacing.md : 0,
              ),
              child: Row(
                children: [
                  for (int i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: i < rowItems.length
                          ? AppComponents.primaryButton(
                              label: rowItems[i].$1,
                              onPressed: () {
                                if (widget.onNavigate != null) {
                                  widget.onNavigate!(rowItems[i].$2);
                                } else {
                                  Navigator.pushNamed(context, rowItems[i].$2);
                                }
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
