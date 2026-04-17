// ignore_for_file: unnecessary_string_interpolations

import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/sidebar_config.dart';
// import 'package:pdh/design_system/app_components.dart'; // unused after redesign
import 'package:pdh/widgets/app_scaffold.dart';
// (removed unused Firestore/user_profile imports after redesign)
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
import 'package:showcaseview/showcaseview.dart';
import 'dart:developer' as developer;
import 'package:pdh/widgets/employee_dashboard_theme.dart';

const Color _kQuickActionHoverRed = Color(0xFFC10D00);

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
  String _managerName = 'Manager';
  late Stream<List<EmployeeData>> _employeesStream;
  // legacy: profile photo url (unused in redesigned dashboard)
  // String? _currentProfilePhotoUrl;
  final Stopwatch _employeesLoadWatch = Stopwatch()..start();

  // Tutorial state
  bool _shouldShowTutorial = false;
  int _currentTutorialStep = 0;
  final List<GlobalKey> _sidebarTutorialKeys = List.generate(
    12,
    (index) => GlobalKey(),
  );

  final GlobalKey _middleLeftKey = GlobalKey();
  double? _middleLeftHeight;

  void _maybeSyncMiddleHeights() {
    final ctx = _middleLeftKey.currentContext;
    if (ctx == null) return;
    final rb = ctx.findRenderObject();
    if (rb is! RenderBox || !rb.hasSize) return;
    final h = rb.size.height;
    if (_middleLeftHeight == null || (h - _middleLeftHeight!).abs() > 1.0) {
      setState(() => _middleLeftHeight = h);
    }
  }

  String _fullNameFromEmail(String email) {
    final local = email.split('@').first.trim();
    if (local.isEmpty) return '';

    final normalized = local.replaceAll(RegExp(r'[_\\.-]+'), ' ');
    final parts = normalized.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';

    return parts
        .map((p) {
          if (p.length == 1) return p.toUpperCase();
          return '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  String _pickBlurb(String key, List<String> lines) {
    if (lines.isEmpty) return '';
    final daySeed = DateTime.now().day;
    final keySeed = key.codeUnits.fold<int>(0, (a, b) => a + b);
    return lines[(daySeed + keySeed) % lines.length];
  }

  @override
  void initState() {
    super.initState();
    if (!widget.forAdminOversight) {
      _redirectIfManagerStandalone();
    }
    _loadManagerName();
    if (widget.forAdminOversight) {
      _employeesStream = ManagerRealtimeService.getManagersDataStream();
    } else {
      _employeesStream = _realtime.employeesStream();
    }
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
        // Prefer onboarding name so assigned-employees query matches employee docs' manager field
        final onboardingName = await DatabaseService.getUserNameFromOnboarding(
          userId: user.uid,
          email: user.email,
        );
        if (onboardingName != null && onboardingName.trim().isNotEmpty) {
          name = onboardingName.trim();
        } else {
          final profile = await DatabaseService.getUserProfile(user.uid);
          final display = profile.displayName.trim();
          if (display.isNotEmpty) {
            name = display;
          } else if ((user.displayName ?? '').isNotEmpty) {
            name = user.displayName!.trim();
          } else if ((user.email ?? '').isNotEmpty) {
            // Derive full name from email so onboarding manager field matches (e.g. Gladness Mulaudzi)
            final fromEmail = _fullNameFromEmail(user.email!);
            name = fromEmail.isNotEmpty ? fromEmail : user.email!.split('@').first;
          }
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
        ShowcaseView.get().startShowCase([_sidebarTutorialKeys[0]]);
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
              ShowcaseView.get().startShowCase([_sidebarTutorialKeys[_currentTutorialStep]]);
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
                    ShowcaseView.get().startShowCase([
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
      ShowcaseView.get().dismiss();
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
            final timedOut =
                _employeesLoadWatch.elapsed > const Duration(seconds: 12);
            if (timedOut) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _card(
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
                              color: DashboardChrome.fg,
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
                                      '/landing',
                                      (route) => false,
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: DashboardChrome.fg,
                                  side: BorderSide(
                                    color: _dashboardCardBorder(),
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

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final topGridColumns = width >= 920
                  ? 3
                  : width >= 640
                      ? 2
                      : 1;
              final middleTwoColumns = width >= 920;

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
              final onTrack = employees
                  .where((e) => e.status == EmployeeStatus.onTrack)
                  .length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDashboardHeader(),
                  const SizedBox(height: AppSpacing.lg),

                  _buildTopStatsGrid(
                    columns: topGridColumns,
                    activeToday: activeToday,
                    activeThisWeek: activeThisWeek,
                    inactive: inactive,
                    overdue: overdue,
                    atRisk: atRisk,
                    onTrack: onTrack,
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  if (middleTwoColumns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            key: _middleLeftKey,
                            children: [
                              _buildDailyMotivationCard(),
                              const SizedBox(height: AppSpacing.md),
                              _buildRecentActivitiesCard(employees),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _buildQuickActions(
                            expand: false,
                            minHeight: _middleLeftHeight,
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildDailyMotivationCard(),
                        const SizedBox(height: AppSpacing.md),
                        _buildRecentActivitiesCard(employees),
                        const SizedBox(height: AppSpacing.md),
                        _buildQuickActions(expand: false),
                      ],
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  _buildBottomKpisAndHealth(metrics, employees, maxWidth: width),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              );
            },
          );
        },
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeSyncMiddleHeights();
    });

    if (widget.embedded) {
      // ManagerPortal provides background + theme scope
      return content;
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
        // Keep manager navigation inside the portal so moved sidebar items
        // always load the correct content (e.g. Review Team).
        Navigator.pushReplacementNamed(
          context,
          '/manager_portal',
          arguments: {'initialRoute': route},
        );
      },
      onLogout: () async {
        final navigator = Navigator.of(context);
        await AuthService().signOut();
        if (mounted) {
          navigator.pushNamedAndRemoveUntil('/landing', (route) => false);
        }
      },
      content: DashboardThemedBackground(child: content),
    );
  }

  // Dark mode: reduce alpha so the background image remains visible.
  // "Drop opacity by 40%" => keep ~60% opacity (alpha 0x99).
  Color _dashboardCardFill() {
    return DashboardChrome.light ? const Color(0x99FFFFFF) : const Color(0x993D3F40);
  }

  Color _dashboardCardBorder() {
    return DashboardChrome.light
        ? const Color(0x1E000000)
        : Colors.white.withValues(alpha: 0.12);
  }

  Widget _card({required Widget child, double? minHeight}) {
    return Container(
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _dashboardCardFill(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dashboardCardBorder()),
      ),
      child: child,
    );
  }

  Widget _assetIcon(String assetPath, {required double size}) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // If an asset is missing, avoid crashing the dashboard.
        return SizedBox(width: size, height: size);
      },
    );
  }

  Widget _buildDashboardHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'Manager Dashboard',
            style: AppTypography.heading2.copyWith(color: DashboardChrome.fg),
          ),
        ),
        Text(
          'Hello, ${_resolveManagerName()}',
          style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
        ),
      ],
    );
  }

  Widget _buildTopStatsGrid({
    required int columns,
    required int activeToday,
    required int activeThisWeek,
    required int inactive,
    required int overdue,
    required int atRisk,
    required int onTrack,
  }) {
    final tiles = <Widget>[
      _topStatTile(
        title: 'Active Daily',
        subtitle: _pickBlurb('activeDaily', const [
          'Active team members today.',
          'Daily engagement count (today).',
          'Team activity recorded since midnight.',
        ]),
        value: '$activeToday',
        icon: Icons.calendar_today,
        assetPath:
            'assets/Goal_Target/Goal_Target_White_Badge_Red.png',
        accent: AppColors.activeColor,
      ),
      _topStatTile(
        title: 'Active Weekly',
        subtitle: _pickBlurb('activeWeekly', const [
          'Active in the last 7 days.',
          'Weekly engagement snapshot.',
          'Team members active this week.',
        ]),
        value: '$activeThisWeek',
        icon: Icons.check,
        assetPath: 'assets/Approved_Tick/Approved_White_Badge_Red.png',
        accent: AppColors.successColor,
      ),
      _topStatTile(
        title: 'Inactive',
        subtitle: _pickBlurb('inactive', const [
          'No recent activity detected.',
          'Needs a quick check‑in.',
          'Inactive status (last 7 days).',
        ]),
        value: '$inactive',
        icon: Icons.priority_high,
        assetPath: 'assets/Team_Meeting/Team.png',
        accent: AppColors.warningColor,
      ),
      _topStatTile(
        title: 'Overdue',
        subtitle: _pickBlurb('overdue', const [
          'Goals past their target date.',
          'Items requiring urgent attention.',
          'Overdue goals across the team.',
        ]),
        value: '$overdue',
        icon: Icons.remove_red_eye,
        assetPath:
            'assets/Goal_Target/Goal_Target_White_Badge_Red.png',
        accent: AppColors.dangerColor,
      ),
      _topStatTile(
        title: 'At Risk',
        subtitle: _pickBlurb('atRisk', const [
          'Goals trending behind plan.',
          'Potential blockers detected.',
          'At‑risk goals across the team.',
        ]),
        value: '$atRisk',
        icon: Icons.error_outline,
        assetPath:
            'assets/Task_Management/Task_Management_White_Badge_Red.png',
        accent: AppColors.dangerColor,
      ),
      _topStatTile(
        title: 'On Track',
        subtitle: _pickBlurb('onTrack', const [
          'Goals progressing as planned.',
          'On‑track goals across the team.',
          'Healthy momentum this period.',
        ]),
        value: '$onTrack',
        icon: Icons.rocket_launch,
        assetPath: 'assets/Badge.png',
        accent: AppColors.successColor,
      ),
    ];

    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: columns == 1 ? 3.4 : 2.9,
      children: tiles,
    );
  }

  Widget _topStatTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    String? assetPath,
    required Color accent,
  }) {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: DashboardChrome.fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: DashboardChrome.fg,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: AppTypography.heading2.copyWith(
                    color: DashboardChrome.fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (assetPath != null)
            // Always use dashboard asset icons so light/dark mode stays consistent.
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: _assetIcon(assetPath, size: 64),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DashboardChrome.light
                    ? const Color(0x0F000000)
                    : Colors.white.withValues(alpha: 0.072),
                border: Border.all(color: _dashboardCardBorder()),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitiesCard(List<EmployeeData> employees) {
    final items = <({String name, String description})>[];
    for (final e in employees) {
      for (final a in e.recentActivities) {
        if (a.description.trim().isEmpty) continue;
        items.add((name: e.profile.displayName, description: a.description));
      }
    }

    final top = items.take(3).toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              widget.forAdminOversight
                  ? _assetIcon('assets/bell_icon.png', size: 26)
                  : const Icon(Icons.notifications_none,
                      color: AppColors.dangerColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recent Activities',
                  style: AppTypography.heading4.copyWith(
                    color: DashboardChrome.fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _pickBlurb('recentActivities', const [
              'Latest updates from your team.',
              'Most recent goal activity.',
              'Recent progress and check‑ins.',
            ]),
            style: AppTypography.bodySmall.copyWith(color: DashboardChrome.fg),
          ),
          const SizedBox(height: 12),
          if (top.isEmpty)
            Text(
              'No recent activities yet.',
              style: AppTypography.bodyMedium.copyWith(color: DashboardChrome.fg),
            )
          else
            ...top.map(
              (x) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    widget.forAdminOversight
                        ? _assetIcon('assets/bell_icon.png', size: 22)
                        : Icon(
                            Icons.check_box,
                            size: 18,
                            color: DashboardChrome.light
                                ? AppColors.dangerColor
                                : AppColors.activeColor,
                          ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTypography.bodySmall.copyWith(
                            color: DashboardChrome.fg,
                          ),
                          children: [
                            TextSpan(
                              text: '${x.name}: ',
                              style: AppTypography.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                                color: DashboardChrome.fg,
                              ),
                            ),
                            TextSpan(text: x.description),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomKpisAndHealth(
    TeamMetrics? m,
    List<EmployeeData> employees, {
    required double maxWidth,
  }) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final totalEmployees = m?.totalEmployees ?? employees.length;
    final activeEmployees =
        m?.activeEmployees ??
        employees.where((e) => e.lastActivity.isAfter(sevenDaysAgo)).length;
    final avgProgress = m?.avgTeamProgress ?? 0.0;

    final onTrack = m?.onTrackGoals ?? 0;
    final atRisk = m?.atRiskGoals ?? 0;
    final overdue = m?.overdueGoals ?? 0;

    Widget section({
      required String title,
      required int cols,
      required List<Widget> tiles,
    }) {
      // Use fixed tile heights instead of width-derived aspect ratios.
      // This prevents bottom RenderFlex overflows when browser zoom/viewport
      // makes width-based tiles too short for 3 lines of KPI content.
      final double tileHeight = cols == 1 ? 96.0 : 118.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.heading2.copyWith(color: DashboardChrome.fg),
          ),
          const SizedBox(height: AppSpacing.md),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tiles.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              mainAxisExtent: tileHeight,
            ),
            itemBuilder: (context, index) => tiles[index],
          ),
        ],
      );
    }

    if (maxWidth >= 920) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: section(
              title: 'Team KPI’s',
              cols: 3,
              tiles: [
                _smallKpiTile('Total', '$totalEmployees'),
                _smallKpiTile('Active', '$activeEmployees'),
                _smallKpiTile(
                  'Average Progress',
                  '${avgProgress.toStringAsFixed(0)}',
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: section(
              title: 'Team Health',
              cols: 3,
              tiles: [
                _smallKpiTile('On Track', '$onTrack'),
                _smallKpiTile('At Risk', '$atRisk'),
                _smallKpiTile('Overdue', '$overdue'),
              ],
            ),
          ),
        ],
      );
    }

    final cols = maxWidth >= 640 ? 2 : 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        section(
          title: 'Team KPI’s',
          cols: cols,
          tiles: [
            _smallKpiTile('Total', '$totalEmployees'),
            _smallKpiTile('Active', '$activeEmployees'),
            _smallKpiTile('Average Progress', '${avgProgress.toStringAsFixed(0)}'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        section(
          title: 'Team Health',
          cols: cols,
          tiles: [
            _smallKpiTile('On Track', '$onTrack'),
            _smallKpiTile('At Risk', '$atRisk'),
            _smallKpiTile('Overdue', '$overdue'),
          ],
        ),
      ],
    );
  }

  Widget _smallKpiTile(String title, String value) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: DashboardChrome.fg,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _pickBlurb('kpi:$title', const [
              'This period.',
              'Current snapshot.',
              'Updated recently.',
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              color: DashboardChrome.fg,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: DashboardChrome.fg,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // _buildWelcomeCard removed (dashboard now uses _buildDashboardHeader).


  Widget _buildDailyMotivationCard() {
    return _card(
      child: Row(
        children: [
          _assetIcon('assets/Sprints.png', size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Motivation',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DashboardChrome.fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lead by example, and let your team grow today!',
                  style:
                      AppTypography.bodySmall.copyWith(color: DashboardChrome.fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // legacy: daily motivation picker removed (dashboard now matches screenshot copy)

  // legacy: _getManagerProfileStream removed (unused in redesigned dashboard)

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

  // legacy: _buildKpis/_buildTeamHealth removed (replaced by _buildBottomKpisAndHealth)

  // legacy KPI helpers removed (dashboard uses _smallKpiTile + _buildBottomKpisAndHealth)

  // legacy: _buildActivitySummary removed (replaced by top stat grid)

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

  // ignore: unused_element
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
  // ignore: unused_element
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
                  color: DashboardChrome.fg,
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
                    color: DashboardChrome.fg,
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
                    color: DashboardChrome.fg,
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
            ? AppColors.successColor.withValues(
                alpha: DashboardChrome.light ? 0.1 : 0.06,
              )
            : AppColors.warningColor.withValues(
                alpha: DashboardChrome.light ? 0.1 : 0.06,
              ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allCompleted
              ? AppColors.successColor.withValues(
                  alpha: DashboardChrome.light ? 0.3 : 0.18,
                )
              : AppColors.warningColor.withValues(
                  alpha: DashboardChrome.light ? 0.3 : 0.18,
                ),
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
                    color: DashboardChrome.fg,
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
                  color: DashboardChrome.fg,
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

  Widget _buildQuickActions({required bool expand, double? minHeight}) {
    const double employeeQuickActionIconSize = 40;

    Widget actionTile({
      required String label,
      required VoidCallback onTap,
      required IconData icon,
      String? assetPath,
      bool filled = false,
    }) {
      final fill =
          filled ? AppColors.dangerColor : _dashboardCardFill();
      final fg = filled ? Colors.white : DashboardChrome.fg;
      return _ManagerQuickActionTile(
        label: label,
        onTap: onTap,
        icon: icon,
        assetPath: assetPath,
        baseFill: fill,
        baseFg: fg,
        filled: filled,
        light: DashboardChrome.light,
        iconSize: employeeQuickActionIconSize,
      );
    }

    final actions = <Widget>[
      actionTile(
        label: 'Goal Workspace',
        icon: Icons.flag_outlined,
        assetPath: 'assets/Project_Management/Management_White_Badge_Red.png',
        onTap: () => Navigator.pushNamed(
          context,
          '/my_goal_workspace',
        ),
      ),
      actionTile(
        label: 'Progress Visuals',
        icon: Icons.insights_outlined,
        assetPath:
            'assets/Process_Flows_Automation/Process_Flows_Automation_White_Badge_Red.png',
        onTap: () => Navigator.pushNamed(context, '/progress_visuals'),
      ),
      actionTile(
        label: 'Leaderboard',
        icon: Icons.attribution_outlined,
        assetPath:
            'assets/Project_Direction_Acceleration/Project_Direction_Acceleration_White_Badge_Red.png',
        onTap: () => Navigator.pushNamed(context, '/manager_leaderboard'),
      ),
      actionTile(
        label: 'Badges & Points',
        icon: Icons.emoji_events_outlined,
        assetPath:
            'assets/Business_Growth_Development/Business_Growth_Development_White_Badge_Red.png',
        onTap: () => Navigator.pushNamed(context, '/manager_badges_points'),
      ),
    ];

    Widget grid({required bool shrinkWrap}) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // Match screenshot: buttons are taller than our previous ratio-based tiles.
          final tileHeight = constraints.maxWidth >= 520 ? 64.0 : 60.0;
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              mainAxisExtent: tileHeight,
            ),
            itemCount: actions.length,
            itemBuilder: (context, i) => actions[i],
            shrinkWrap: shrinkWrap,
            physics: const NeverScrollableScrollPhysics(),
          );
        },
      );
    }

    return _card(
      minHeight: minHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              widget.forAdminOversight
                  ? _assetIcon('assets/Innovation_Brainstorm.png', size: 26)
                  : const Icon(Icons.emoji_objects_outlined,
                      color: AppColors.dangerColor),
              const SizedBox(width: 8),
              Text(
                'Quick Action',
                style: AppTypography.heading4.copyWith(color: DashboardChrome.fg),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _pickBlurb('quickAction', const [
              'Jump to a tool to take action.',
              'Shortcuts to common manager tasks.',
              'Quick links for today’s focus.',
            ]),
            style: AppTypography.bodySmall.copyWith(color: DashboardChrome.fg),
          ),
          const SizedBox(height: AppSpacing.md),
          if (expand)
            Expanded(child: grid(shrinkWrap: false))
          else
            grid(shrinkWrap: true),
        ],
      ),
    );
  }
}

class _ManagerQuickActionTile extends StatefulWidget {
  const _ManagerQuickActionTile({
    required this.label,
    required this.onTap,
    required this.icon,
    required this.baseFill,
    required this.baseFg,
    required this.filled,
    required this.light,
    required this.iconSize,
    this.assetPath,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final String? assetPath;
  final Color baseFill;
  final Color baseFg;
  final bool filled;
  final bool light;
  final double iconSize;

  @override
  State<_ManagerQuickActionTile> createState() => _ManagerQuickActionTileState();
}

class _ManagerQuickActionTileState extends State<_ManagerQuickActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = _hover ? _kQuickActionHoverRed : widget.baseFill;
    final borderColor = _hover
        ? _kQuickActionHoverRed
        : (widget.filled
              ? AppColors.dangerColor
              : (widget.light
                    ? const Color(0x33000000)
                    : Colors.white.withValues(alpha: 0.25)));
    final fg = _hover ? Colors.white : widget.baseFg;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.assetPath != null)
                  Image.asset(
                    widget.assetPath!,
                    width: widget.iconSize,
                    height: widget.iconSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, _) =>
                        Icon(Icons.touch_app_outlined, color: fg, size: 18),
                  )
                else
                  Icon(widget.icon, color: fg, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}