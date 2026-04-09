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
import 'package:pdh/services/season_service.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/role_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/workspace_context_service.dart';
import 'package:pdh/models/goal.dart';
import 'package:intl/intl.dart';
import 'package:pdh/services/manager_tutorial_service.dart';
import 'package:pdh/services/streak_service.dart';
import 'package:pdh/widgets/sidebar_state.dart';
import 'package:showcaseview/showcaseview.dart';
import 'dart:developer' as developer;

class ManagerDashboardScreen extends StatefulWidget {
  final bool embedded;

  /// When true, admin is viewing this screen; data shows managers (not employees).
  final bool forAdminOversight;

  /// When set with [forAdminOversight], show data for this manager only (future use).
  final String? selectedManagerId;

  const ManagerDashboardScreen({
    super.key,
    this.embedded = false,
    this.forAdminOversight = false,
    this.selectedManagerId,
  });

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  final ManagerRealtimeService _realtime = ManagerRealtimeService();
  final WorkspaceContextService _workspaceService = WorkspaceContextService();
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
    if (!widget.forAdminOversight) {
      _redirectIfManagerStandalone();
    }
    _loadManagerName();

    // Initialize workspace context if not already set
    _workspaceService.initializeFromRole();

    _workspaceService.addListener(_onWorkspaceChanged);
    _updateDataStream();
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

  @override
  void dispose() {
    _workspaceService.removeListener(_onWorkspaceChanged);
    super.dispose();
  }

  void _onWorkspaceChanged() {
    if (mounted) {
      setState(() {
        _updateDataStream();
        _employeesLoadWatch
          ..reset()
          ..start();
      });

      // Force immediate refresh of all workspace-dependent widgets
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _updateDataStream() {
    if (widget.forAdminOversight) {
      _employeesStream = ManagerRealtimeService.getManagersDataStream();
    } else if (_workspaceService.isMyWorkspace) {
      // Personal workspace - show personal data
      _employeesStream = _getPersonalDataStream();
    } else {
      // Manager workspace - show team data
      _employeesStream = _realtime.employeesStream();
    }
  }

  Stream<List<EmployeeData>> _getPersonalDataStream() async* {
    // For personal workspace, return stream with only the manager's data
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get actual user profile data
      final profile = await DatabaseService.getUserProfile(user.uid);

      // Get actual goals for this user
      final goals = await DatabaseService.getUserGoals(user.uid);

      yield [
        EmployeeData(
          profile: profile,
          goals: goals,
          recentActivities: [],
          recentAlerts: [],
          completedGoalsCount: goals
              .where((g) => g.status == GoalStatus.completed)
              .length,
          overdueGoalsCount: goals
              .where(
                (g) =>
                    g.status == GoalStatus.inProgress &&
                    g.targetDate.isBefore(DateTime.now()),
              )
              .length,
          totalPoints: profile.totalPoints,
          lastActivity: DateTime.now(),
          avgProgress: goals.isNotEmpty
              ? goals.map((g) => g.progress).reduce((a, b) => a + b) /
                    goals.length
              : 0.0,
          streakDays: await StreakService.getCurrentStreak(user.uid),
          status: EmployeeStatus.onTrack,
          weeklyActivityCount: 0,
          engagementScore: goals.isNotEmpty
              ? (goals.where((g) => g.status == GoalStatus.completed).length /
                        goals.length) *
                    100.0
              : 0.0,
          motivationLevel: 'medium',
        ),
      ];
    } catch (e) {
      // Fallback to basic data if there's an error
      yield [
        EmployeeData(
          profile: UserProfile(
            uid: user.uid,
            displayName: _managerName,
            email: user.email ?? '',
            totalPoints: 0,
            level: 1,
            badges: [],
            role: 'manager',
            profilePhotoUrl: _currentProfilePhotoUrl,
          ),
          goals: [],
          recentActivities: [],
          recentAlerts: [],
          completedGoalsCount: 0,
          overdueGoalsCount: 0,
          totalPoints: 0,
          lastActivity: DateTime.now(),
          avgProgress: 0.0,
          streakDays: 0, // Will be calculated when user has streak data
          status: EmployeeStatus.onTrack,
          weeklyActivityCount: 0,
          engagementScore: 0.0, // No goals = no engagement
          motivationLevel: 'medium',
        ),
      ];
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
            final timedOut =
                _employeesLoadWatch.elapsed > const Duration(seconds: 12);
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
                                    _employeesStream = _realtime
                                        .employeesStream();
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
              // Show context-specific widgets
              if (_workspaceService.isMyWorkspace) ...[
                _buildPersonalKpis(metrics, employees),
                const SizedBox(height: AppSpacing.xl),
                _buildPersonalGoals(),
                const SizedBox(height: AppSpacing.xl),
                _buildPersonalMilestones(),
                const SizedBox(height: AppSpacing.xl),
                _buildPersonalActivitySummary(employees),
              ] else ...[
                _buildTeamKpis(metrics, employees),
                const SizedBox(height: AppSpacing.xl),
                _buildTeamHealth(metrics, employees),
                const SizedBox(height: AppSpacing.xl),
                _buildPendingApprovals(),
                const SizedBox(height: AppSpacing.xl),
                _buildTeamActivitySummary(employees),
                const SizedBox(height: AppSpacing.xl),
                _buildSeasonProgressAlerts(),
                const SizedBox(height: AppSpacing.xl),
                _buildTopTwoPerformers(employees),
              ],
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

  // Personal workspace widgets
  Widget _buildPersonalKpis(TeamMetrics metrics, List<EmployeeData> employees) {
    return _buildKpis(metrics, employees);
  }

  Widget _buildPersonalGoals() {
    return StreamBuilder<List<Goal>>(
      stream: DatabaseService.getUserGoalsStream(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      ),
      builder: (context, goalsSnap) {
        final goals = goalsSnap.data ?? [];
        final activeGoals = goals
            .where((g) => g.status != GoalStatus.completed)
            .length;
        final completedGoals = goals
            .where((g) => g.status == GoalStatus.completed)
            .length;

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Goals',
                style: AppTypography.heading4.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildGoalStat(
                      'Active Goals',
                      activeGoals.toString(),
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildGoalStat(
                      'Completed',
                      completedGoals.toString(),
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/my_pdp');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.activeColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Personal Goals'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalMilestones() {
    return StreamBuilder<List<Goal>>(
      stream: DatabaseService.getUserGoalsStream(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      ),
      builder: (context, goalsSnap) {
        final goals = goalsSnap.data ?? [];
        final completedGoals = goals.where(
          (g) => g.status == GoalStatus.completed,
        );
        final recentMilestones = completedGoals.take(3).toList();

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Milestones',
                style: AppTypography.heading4.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              if (recentMilestones.isEmpty) ...[
                Text(
                  'No milestones yet. Complete your goals to see achievements here!',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/my_pdp');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create Your First Goal'),
                ),
              ] else ...[
                ...recentMilestones.map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  goal.title,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Completed on ${DateFormat('MMM dd, yyyy').format(goal.approvedAt ?? DateTime.now())}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPersonalActivitySummary(List<EmployeeData> employees) {
    return _buildActivitySummary(employees);
  }

  // Manager workspace widgets
  Widget _buildTeamKpis(TeamMetrics metrics, List<EmployeeData> employees) {
    return _buildKpis(metrics, employees);
  }

  Widget _buildPendingApprovals() {
    return StreamBuilder<List<EmployeeData>>(
      stream: _realtime.employeesStream(),
      builder: (context, employeesSnap) {
        final employees = employeesSnap.data ?? [];
        final pendingApprovals = employees.where((emp) {
          return emp.goals.any(
            (goal) => goal.approvalStatus == GoalApprovalStatus.pending,
          );
        }).length;

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pending Approvals',
                style: AppTypography.heading4.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildApprovalStat(
                      'Goals Pending',
                      pendingApprovals.toString(),
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildApprovalStat(
                      'Team Members',
                      employees.length.toString(),
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (pendingApprovals > 0) ...[
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/pending_approvals');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Review Pending Approvals'),
                ),
              ] else ...[
                Text(
                  'No pending approvals at this time',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildApprovalStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamActivitySummary(List<EmployeeData> employees) {
    return _buildActivitySummary(employees);
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
              _kpiTap('Total', totalEmployees.toString(), null),
              const SizedBox(width: 8),
              _kpiTap('Active (7d)', activeEmployees.toString(), 'active7d'),
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
              _kpiTap('On Track', onTrack.toString(), 'onTrack'),
              const SizedBox(width: 8),
              _kpiTap('At Risk', atRisk.toString(), 'atRisk'),
              const SizedBox(width: 8),
              _kpiTap('Overdue', overdue.toString(), 'overdue'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Expanded(child: _kpiInner(label, value));
  }

  /// Tappable KPI that navigates to the team list with an optional status filter.
  /// [filterKey] null = no drill-down; non-null = navigate to Review Team with that filter.
  Widget _kpiTap(String label, String value, String? filterKey) {
    final inner = _kpiInner(label, value);
    if (filterKey == null) return Expanded(child: inner);
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/manager_review_team_dashboard',
            arguments: <String, String>{'statusFilter': filterKey},
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: inner,
      ),
    );
  }

  Widget _kpiInner(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
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
              _kpiTap('Active Today', activeToday.toString(), 'activeToday'),
              const SizedBox(width: 8),
              _kpiTap('Active (7d)', activeThisWeek.toString(), 'active7d'),
              const SizedBox(width: 8),
              _kpiTap('Inactive', inactive.toString(), 'inactive'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _kpiTap('Overdue', overdue.toString(), 'overdue'),
              const SizedBox(width: 8),
              _kpiTap('At Risk', atRisk.toString(), 'atRisk'),
              const SizedBox(width: 8),
              _kpiTap(
                'On Track',
                employees
                    .where((e) => e.status == EmployeeStatus.onTrack)
                    .length
                    .toString(),
                'onTrack',
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
