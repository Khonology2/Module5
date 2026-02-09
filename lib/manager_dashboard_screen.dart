import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/utils/firestore_safe.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/services/season_service.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/role_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/manager_tutorial_service.dart';
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:pdh/widgets/version_badge.dart';
import 'package:showcaseview/showcaseview.dart';
import 'dart:developer' as developer;

class ManagerDashboardScreen extends StatefulWidget {
  final bool embedded;

  const ManagerDashboardScreen({super.key, this.embedded = false});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ManagerRealtimeService _realtime = ManagerRealtimeService();
  String _managerName = 'Manager';
  late Stream<List<EmployeeData>> _employeesStream;
  String? _currentProfilePhotoUrl;
  final Stopwatch _employeesLoadWatch = Stopwatch()..start();

  // Tutorial state
  bool _shouldShowTutorial = false;
  int _currentTutorialStep = 0;
  final List<GlobalKey> _sidebarTutorialKeys = List.generate(
    12,
    (index) => GlobalKey(),
  );

  @override
  void initState() {
    super.initState();
    _redirectIfManagerStandalone();
    _loadManagerName();
    _employeesStream = _realtime.employeesStream();
    _employeesLoadWatch
      ..reset()
      ..start();

    // Sync manager season points from season metrics into the manager's user doc.
    // This is required because employee milestone updates cannot write to the manager's user doc.
    Future.microtask(() => SeasonService.syncCurrentManagerSeasonPoints());
    // Sync manager season badges earned (tracked on seasons) into the manager's badges collection.
    Future.microtask(() => SeasonService.syncCurrentManagerSeasonBadges());

    // Check if tutorial should be shown
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _checkTutorial();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-check tutorial when screen becomes visible again
    if (!_shouldShowTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkTutorial();
        }
      });
    }
  }

  Future<void> _loadManagerName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      String name = 'Manager';
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
        _managerName = name;
      });
    } catch (_) {}
  }

  Future<void> _redirectIfManagerStandalone() async {
    try {
      final role = await RoleService.instance.getRole();
      if (!mounted) return;
      if (role == 'manager') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final current = ModalRoute.of(context)?.settings.name;
          if (current != '/manager_portal') {
            Navigator.pushReplacementNamed(
              context,
              '/manager_portal',
              arguments: {'initialRoute': '/dashboard'},
            );
          }
        });
      }
    } catch (_) {
      // ignore
    }
  }

  // Simplified immediate start
  void _startTutorialImmediate() {
    if (!mounted || !_shouldShowTutorial) return;

    developer.log(
      'Starting manager tutorial immediately - step: $_currentTutorialStep',
      name: 'ManagerDashboardScreen',
    );

    try {
      // Check if key is attached
      final keyContext = _sidebarTutorialKeys[0].currentContext;
      developer.log(
        'Key context check: ${keyContext != null ? "ATTACHED" : "NOT ATTACHED"}',
        name: 'ManagerDashboardScreen',
      );

      if (keyContext != null) {
        // Key is attached, start showcase
        ShowCaseWidget.of(context).startShowCase([_sidebarTutorialKeys[0]]);
        developer.log(
          'Started manager showcase for step 0',
          name: 'ManagerDashboardScreen',
        );
      } else {
        // Key not attached yet, retry
        developer.log(
          'Key not attached, retrying in 500ms...',
          name: 'ManagerDashboardScreen',
        );
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _shouldShowTutorial) {
            _startTutorialImmediate();
          }
        });
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error starting showcase: $e',
        name: 'ManagerDashboardScreen',
        error: e,
      );
      developer.log('Stack: $stackTrace', name: 'ManagerDashboardScreen');

      // Retry after error
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _shouldShowTutorial) {
          _startTutorialImmediate();
        }
      });
    }
  }

  Future<void> _checkTutorial({int retryCount = 0}) async {
    if (!mounted) return;

    try {
      developer.log(
        'Checking if manager sidebar tutorial should start...',
        name: 'ManagerDashboardScreen',
      );

      // Add delay for first attempt to ensure Firestore writes are complete
      if (retryCount == 0) {
        await Future.delayed(const Duration(milliseconds: 800));
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final shouldShow = await ManagerTutorialService.instance
          .shouldShowTutorial();
      developer.log(
        'Manager sidebar tutorial check result: shouldShow=$shouldShow',
        name: 'ManagerDashboardScreen',
      );

      if (shouldShow && mounted) {
        developer.log(
          'Tutorial should start - initializing...',
          name: 'ManagerDashboardScreen',
        );

        // Set tutorial state first
        setState(() {
          _shouldShowTutorial = true;
          _currentTutorialStep = 0;
        });

        // Ensure sidebar is expanded
        SidebarState.instance.isCollapsed.value = false;

        // Wait for widgets to rebuild with tutorial state
        await Future.delayed(const Duration(milliseconds: 200));

        // Start tutorial after widgets rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted && _shouldShowTutorial) {
                developer.log(
                  'Starting tutorial from check...',
                  name: 'ManagerDashboardScreen',
                );
                _startTutorialImmediate();
              }
            });
          });
        });
      } else if (retryCount < 2 && mounted) {
        // Retry up to 2 times if tutorial should show but didn't
        developer.log(
          'Tutorial check returned false, retrying (attempt ${retryCount + 1}/2)...',
          name: 'ManagerDashboardScreen',
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _checkTutorial(retryCount: retryCount + 1);
          }
        });
      } else {
        developer.log(
          'Tutorial will NOT start - shouldShow=$shouldShow',
          name: 'ManagerDashboardScreen',
        );
      }
    } catch (e) {
      developer.log(
        'Error checking manager sidebar tutorial: $e',
        name: 'ManagerDashboardScreen',
        error: e,
      );
    }
  }

  void _moveToNextTutorialStep() {
    if (!mounted || !_shouldShowTutorial) return;

    if (_currentTutorialStep < SidebarConfig.managerItems.length - 1) {
      setState(() {
        _currentTutorialStep++;
      });

      // Trigger showcase for next step
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _shouldShowTutorial) {
          try {
            final keyContext =
                _sidebarTutorialKeys[_currentTutorialStep].currentContext;
            if (keyContext != null) {
              ShowCaseWidget.of(
                context,
              ).startShowCase([_sidebarTutorialKeys[_currentTutorialStep]]);
              developer.log(
                'Started showcase for step $_currentTutorialStep',
                name: 'ManagerDashboardScreen',
              );
            } else {
              developer.log(
                'Key not attached for step $_currentTutorialStep, retrying...',
                name: 'ManagerDashboardScreen',
              );
              // Retry
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && _shouldShowTutorial) {
                  try {
                    ShowCaseWidget.of(context).startShowCase([
                      _sidebarTutorialKeys[_currentTutorialStep],
                    ]);
                  } catch (e) {
                    developer.log(
                      'Retry failed: $e',
                      name: 'ManagerDashboardScreen',
                    );
                  }
                }
              });
            }
          } catch (e) {
            developer.log(
              'Could not start showcase for step $_currentTutorialStep: $e',
              name: 'ManagerDashboardScreen',
              error: e,
            );
          }
        }
      });
    } else {
      // Tutorial complete
      _completeTutorial();
    }
  }

  Future<void> _completeTutorial() async {
    developer.log(
      'Completing manager sidebar tutorial',
      name: 'ManagerDashboardScreen',
    );
    await ManagerTutorialService.instance.markTutorialCompleted();

    if (mounted) {
      setState(() {
        _shouldShowTutorial = false;
        _currentTutorialStep = 0;
      });
    }
  }

  Future<void> _skipTutorial() async {
    developer.log(
      'Skipping manager sidebar tutorial',
      name: 'ManagerDashboardScreen',
    );

    // Dismiss the current showcase overlay
    try {
      ShowCaseWidget.of(context).dismiss();
    } catch (e) {
      developer.log(
        'Error dismissing showcase: $e',
        name: 'ManagerDashboardScreen',
      );
    }

    // Mark tutorial as completed
    await ManagerTutorialService.instance.markTutorialCompleted();

    if (mounted) {
      setState(() {
        _shouldShowTutorial = false;
        _currentTutorialStep = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: StreamBuilder<List<EmployeeData>>(
        stream: _employeesStream,
        builder: (context, employeesSnap) {
          if (employeesSnap.hasError) {
            return Center(
              child: Text('Error loading employees: ${employeesSnap.error}'),
            );
          }
          if (!employeesSnap.hasData) {
            final timedOut = _employeesLoadWatch.elapsed >
                const Duration(seconds: 12);
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
                                    _employeesStream = _realtime.employeesStream();
                                    _employeesLoadWatch
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
          final employees = employeesSnap.data!;
          if (_employeesLoadWatch.isRunning) {
            _employeesLoadWatch.stop();
          }

          // Compute metrics locally to avoid adding another Firestore listener
          final metrics = _computeTeamMetrics(employees);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<UserProfile?>(
                stream: _getManagerProfileStream(),
                builder: (context, profileSnap) {
                  return _buildWelcomeCard();
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildDailyMotivationCard(),
              const SizedBox(height: AppSpacing.xl),
              _buildQuickActions(),
              const SizedBox(height: AppSpacing.xl),
              _buildKpis(metrics, employees),
              const SizedBox(height: AppSpacing.xl),
              _buildTeamHealth(metrics, employees),
              const SizedBox(height: AppSpacing.xl),
              _buildActivitySummary(employees),
              const SizedBox(height: AppSpacing.xl),
              _buildSeasonProgressAlerts(),
              const SizedBox(height: AppSpacing.xl),
              _buildTopTwoPerformers(employees),
              const SizedBox(height: AppSpacing.lg),
              const Align(alignment: Alignment.center, child: VersionBadge()),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );

    if (widget.embedded) {
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

    return AppScaffold(
      title: '',
      showAppBar: false,
      items: SidebarConfig.managerItems,
      currentRouteName: '/dashboard',
      tutorialStepIndex: _shouldShowTutorial ? _currentTutorialStep : null,
      sidebarTutorialKeys:
          _shouldShowTutorial && _sidebarTutorialKeys.isNotEmpty
          ? _sidebarTutorialKeys
          : null,
      onTutorialNext: _shouldShowTutorial ? _moveToNextTutorialStep : null,
      onTutorialSkip: _shouldShowTutorial ? _skipTutorial : null,
      onNavigate: (route) {
        final current = ModalRoute.of(context)?.settings.name;
        if (current != route) {
          Navigator.pushNamed(context, route);
        }
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        if (mounted) {
          navigator.pushNamedAndRemoveUntil('/sign_in', (route) => false);
        }
      },
      content: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/khono_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: content,
          ),
          const Positioned(
            left: 0,
            bottom: 0,
            child: SafeArea(left: true, bottom: true, child: VersionBadge()),
          ),
        ],
      ),
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
                  '$greeting, ${_resolveManagerName()}!',
                  style: AppTypography.heading4,
                ),
                const SizedBox(height: 5),
                Text(
                  'Lead by example and help your team grow today.',
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

  Stream<UserProfile?> _getManagerProfileStream() {
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

  String _resolveManagerName() {
    // Prefer the loaded manager name if available
    if (_managerName.isNotEmpty && _managerName != 'Manager') {
      return _managerName.split(' ').first;
    }
    final authUser = FirebaseAuth.instance.currentUser;
    final display = (authUser?.displayName ?? '').trim();
    if (display.isNotEmpty) return display.split(' ').first;
    final email = (authUser?.email ?? '').trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Manager';
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

  Widget _buildKpis(TeamMetrics? m, List<EmployeeData> employees) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final totalEmployees = m?.totalEmployees ?? employees.length;
    final activeEmployees =
        m?.activeEmployees ??
        employees.where((e) => e.lastActivity.isAfter(sevenDaysAgo)).length;
    final avgProgress = m?.avgTeamProgress ?? 0.0;
    final engagement =
        m?.teamEngagement ??
        (totalEmployees > 0 ? (activeEmployees / totalEmployees) * 100 : 0.0);

    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team KPIs', style: AppTypography.heading2),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('Total', totalEmployees.toString()),
              const SizedBox(width: 8),
              _kpi('Active (7d)', activeEmployees.toString()),
              const SizedBox(width: 8),
              _kpi('Avg Progress', '${avgProgress.toStringAsFixed(0)}%'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Engagement: ${engagement.toStringAsFixed(0)}%',
            style: AppTypography.muted,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamHealth(TeamMetrics? m, List<EmployeeData> employees) {
    final onTrack = m?.onTrackGoals ?? 0;
    final atRisk = m?.atRiskGoals ?? 0;
    final overdue = m?.overdueGoals ?? 0;

    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Team Health', style: AppTypography.heading2),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('On Track', onTrack.toString()),
              const SizedBox(width: 8),
              _kpi('At Risk', atRisk.toString()),
              const SizedBox(width: 8),
              _kpi('Overdue', overdue.toString()),
            ],
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

  Widget _buildActivitySummary(List<EmployeeData> employees) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final activeToday = employees
        .where((e) => e.lastActivity.isAfter(today))
        .length;
    final activeThisWeek = employees
        .where((e) => e.lastActivity.isAfter(sevenDaysAgo))
        .length;
    final inactive = employees
        .where((e) => e.status == EmployeeStatus.inactive)
        .length;
    final overdue = employees
        .where((e) => e.status == EmployeeStatus.overdue)
        .length;
    final atRisk = employees
        .where((e) => e.status == EmployeeStatus.atRisk)
        .length;

    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity Summary', style: AppTypography.heading2),
          const SizedBox(height: 12),
          Row(
            children: [
              _kpi('Active Today', activeToday.toString()),
              const SizedBox(width: 8),
              _kpi('Active (7d)', activeThisWeek.toString()),
              const SizedBox(width: 8),
              _kpi('Inactive', inactive.toString()),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _kpi('Overdue', overdue.toString()),
              const SizedBox(width: 8),
              _kpi('At Risk', atRisk.toString()),
              const SizedBox(width: 8),
              _kpi(
                'On Track',
                employees
                    .where((e) => e.status == EmployeeStatus.onTrack)
                    .length
                    .toString(),
              ),
            ],
          ),
        ],
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
    final name = _managerName;
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
          Text('Top Performers', style: AppTypography.heading2),
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

  // Check-in functionality removed
  Widget _buildSeasonProgressAlerts() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: AppColors.activeColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Season Progress Alerts',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Season>>(
            stream: SeasonService.getManagerSeasonsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Text(
                  'No season data available',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              }

              final seasons = snapshot.data!;
              final activeSeasons = seasons
                  .where((s) => s.status == SeasonStatus.active)
                  .toList();

              if (activeSeasons.isEmpty) {
                return Text(
                  'No active seasons',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                );
              }

              return Column(
                children: activeSeasons.map((season) {
                  return _buildSeasonProgressCard(season);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonProgressCard(Season season) {
    final completedParticipants = season.participantIds.where((participantId) {
      final participation = season.participations[participantId];
      if (participation == null) return false;

      // Check if all milestones are completed
      int totalMilestones = 0;
      int completedMilestones = 0;

      for (final challenge in season.challenges) {
        totalMilestones += challenge.milestones.length;
        for (final milestone in challenge.milestones) {
          final milestoneStatus = participation
              .milestoneProgress['${challenge.id}.${milestone.id}'];
          if (milestoneStatus == MilestoneStatus.completed) {
            completedMilestones++;
          }
        }
      }

      return totalMilestones > 0 && completedMilestones == totalMilestones;
    }).length;

    final totalParticipants = season.participantIds.length;
    final allCompleted =
        completedParticipants == totalParticipants && totalParticipants > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: allCompleted
            ? AppColors.successColor.withValues(alpha: 0.1)
            : AppColors.warningColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allCompleted
              ? AppColors.successColor.withValues(alpha: 0.3)
              : AppColors.warningColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allCompleted ? Icons.check_circle : Icons.schedule,
                color: allCompleted
                    ? AppColors.successColor
                    : AppColors.warningColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  season.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (allCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'READY',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Progress: ',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '$completedParticipants/$totalParticipants employees completed',
                style: AppTypography.bodySmall.copyWith(
                  color: allCompleted
                      ? AppColors.successColor
                      : AppColors.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: totalParticipants > 0
                ? completedParticipants / totalParticipants
                : 0.0,
            backgroundColor: AppColors.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(
              allCompleted ? AppColors.successColor : AppColors.warningColor,
            ),
            minHeight: 4,
          ),
          if (allCompleted) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _completeSeason(season),
                icon: const Icon(Icons.flag, size: 16),
                label: const Text('Complete Season'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _completeSeason(Season season) {
    Navigator.pushNamed(
      context,
      '/season_management',
      arguments: {'seasonId': season.id},
    );
  }

  Widget _buildQuickActions() {
    return AppComponents.card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTypography.heading4),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Manager Review',
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/manager_review_team_dashboard',
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Progress Visuals',
                  onPressed: () {
                    Navigator.pushNamed(context, '/progress_visuals');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Leaderboard',
                  onPressed: () {
                    Navigator.pushNamed(context, '/manager_leaderboard');
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppComponents.primaryButton(
                  label: 'Badges & Points',
                  onPressed: () {
                    Navigator.pushNamed(context, '/manager_badges_points');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
