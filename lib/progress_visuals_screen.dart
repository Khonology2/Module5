// ignore_for_file: unused_element

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/alert_service.dart';
import 'package:pdh/services/manager_realtime_service.dart';
import 'package:pdh/models/user_profile.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/goal_milestone.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/streak_service.dart';
import 'package:pdh/widgets/ai_generation_indicator.dart';
import 'dart:developer' as developer;
import 'package:pdh/models/alert.dart';
import 'package:pdh/services/badge_service.dart';
import 'package:pdh/models/badge.dart' as badge_model;
import 'package:pdh/services/manager_badge_evaluator.dart';
import 'package:pdh/utils/firestore_safe.dart';

class ProgressVisualsScreen extends StatefulWidget {
  final bool embedded;
  /// When true, render employee-style progress visuals even for manager users.
  /// Used by Manager Workspace routes.
  final bool forManagerGwMenu;
  /// When true, admin is viewing; show managers only (no employees).
  final bool forAdminOversight;
  /// When set with [forAdminOversight], show data for this manager only.
  final String? selectedManagerId;

  const ProgressVisualsScreen({
    super.key,
    this.embedded = false,
    this.forManagerGwMenu = false,
    this.forAdminOversight = false,
    this.selectedManagerId,
  });

  @override
  State<ProgressVisualsScreen> createState() => _ProgressVisualsScreenState();
}

class _ProgressVisualsScreenState extends State<ProgressVisualsScreen> {
  UserProfile? userProfile;
  bool isLoading = true;
  String? error;
  UserProfile? _cachedProfile;
  static UserProfile? _globalCachedProfile;
  bool get _isAdminManagerView => widget.forAdminOversight;
  String get _populationSingular => _isAdminManagerView ? 'Manager' : 'Employee';
  String get _populationPlural => _isAdminManagerView ? 'Managers' : 'Employees';

  @override
  void initState() {
    super.initState();
    // Ensure role is loaded before building
    RoleService.instance.ensureRoleLoaded();
    // Populate daily progress snapshots used by "View Trend" charts.
    // This was previously only triggered on Alerts & Nudges screen load.
    AlertService.checkAndCreateGoalAlerts();
    _redirectIfManagerStandalone();
    _seedFastProfile();
    _loadUserData();
  }

  void _seedFastProfile() {
    // Render instantly using an in-memory or auth-based profile placeholder.
    // The Firestore stream + DatabaseService load will replace this shortly.
    if (_cachedProfile != null || userProfile != null) return;
    if (_globalCachedProfile != null) {
      _cachedProfile = _globalCachedProfile;
      userProfile = _globalCachedProfile;
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final role = RoleService.instance.cachedRole ?? 'employee';
    final email = (user.email ?? '').trim();
    final displayName =
        (user.displayName ?? '').trim().isNotEmpty
            ? user.displayName!.trim()
            : (email.isNotEmpty ? email.split('@').first : 'User');

    final placeholder = UserProfile(
      uid: user.uid,
      email: email,
      displayName: displayName,
      totalPoints: 0,
      level: 1,
      badges: const [],
      role: role,
    );
    _cachedProfile = placeholder;
    userProfile = placeholder;
  }

  Future<void> _redirectIfManagerStandalone() async {
    try {
      if (widget.forAdminOversight) return; // Admin context: no redirect.
      final role = await RoleService.instance.getRole();
      if (!mounted) return;
      if (role == 'manager') {
        if (widget.embedded) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final current = ModalRoute.of(context)?.settings.name;
          if (current != '/manager_portal') {
            Navigator.pushReplacementNamed(
              context,
              '/manager_portal',
              arguments: {'initialRoute': '/progress_visuals'},
            );
          }
        });
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadUserData() async {
    try {
      // Only trigger the full-screen "loading" state if we truly have nothing to render yet.
      if (mounted && _cachedProfile == null && userProfile == null) {
        setState(() {
          isLoading = true;
          error = null;
        });
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await DatabaseService.getUserProfile(user.uid);

        setState(() {
          userProfile = profile;
          _cachedProfile = profile;
          _globalCachedProfile = profile;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  bool get isManager => userProfile?.role == 'manager';

  Stream<UserProfile?> _getUserProfileStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);

    return FirestoreSafe.stream(
      FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
    ).map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _getUserProfileStream(),
      initialData:
          _cachedProfile ?? userProfile, // Use cached profile to avoid spinner
      builder: (context, profileSnapshot) {
        final streamedProfile = profileSnapshot.data;
        if (streamedProfile != null && streamedProfile != _cachedProfile) {
          _cachedProfile = streamedProfile;
          userProfile = streamedProfile;
        }

        // Prefer cached profile to avoid spinner on transient errors
        if (profileSnapshot.hasError && _cachedProfile == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.dangerColor,
                ),
                const SizedBox(height: 16),
                Text('Error loading user data', style: AppTypography.heading4),
                const SizedBox(height: 8),
                Text(
                  profileSnapshot.error.toString(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final effectiveProfile =
            streamedProfile ?? _cachedProfile ?? userProfile;

        // Only show loading if we truly don't have any data
        if (profileSnapshot.connectionState == ConnectionState.waiting &&
            effectiveProfile == null) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }

        if (effectiveProfile == null) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }

        userProfile = effectiveProfile;

        return Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/khono_bg.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: (widget.forAdminOversight || isManager)
                ? (widget.forManagerGwMenu
                      ? EmployeeProgressVisualsContent(userProfile: userProfile!)
                      : ManagerProgressVisualsContent(
                          userProfile: userProfile!,
                          forAdminOversight: widget.forAdminOversight,
                          selectedManagerId: widget.selectedManagerId,
                        ))
                : EmployeeProgressVisualsContent(userProfile: userProfile!),
          ),
        );
      },
    );
  }
}

class ManagerProgressVisualsContent extends StatefulWidget {
  final UserProfile userProfile;
  final bool forAdminOversight;
  final String? selectedManagerId;

  const ManagerProgressVisualsContent({
    super.key,
    required this.userProfile,
    this.forAdminOversight = false,
    this.selectedManagerId,
  });

  @override
  State<ManagerProgressVisualsContent> createState() =>
      _ManagerProgressVisualsContentState();
}

enum ProgressViewType { team, myProgress }

enum ManagerActivityType { nudge, approval, replan, meeting, checkIn }

class ManagerActivity {
  final String id;
  final ManagerActivityType type;
  final String title;
  final String description;
  final String? employeeId;
  final String? employeeName;
  final DateTime createdAt;
  final DateTime? scheduledFor;
  final bool isCompleted;
  final Map<String, dynamic>? metadata;

  const ManagerActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.employeeId,
    this.employeeName,
    required this.createdAt,
    this.scheduledFor,
    this.isCompleted = true,
    this.metadata,
  });
}

class _ManagerActivitySummary {
  final int total;
  final int nudges;
  final int approvals;
  final int replans;
  final int meetings;

  const _ManagerActivitySummary({
    required this.total,
    required this.nudges,
    required this.approvals,
    required this.replans,
    required this.meetings,
  });
}

enum _NeedsAttentionAction { view, nudge, review }

class _NeedsAttentionItem {
  final String employeeName;
  final String reason;
  final _NeedsAttentionAction actionType;
  final EmployeeData employee;

  const _NeedsAttentionItem({
    required this.employeeName,
    required this.reason,
    required this.actionType,
    required this.employee,
  });
}

class _CategoryProgressItem {
  final String label;
  final double progress;

  const _CategoryProgressItem({required this.label, required this.progress});
}

class _TrendSeries {
  final List<double> points;
  final List<String> labels;

  const _TrendSeries({required this.points, required this.labels});
}

class _DateRange {
  final DateTime start;
  final DateTime endExclusive;

  const _DateRange({required this.start, required this.endExclusive});
}

class _DonutSegment {
  final String label;
  final double fraction;
  final Color color;

  const _DonutSegment(this.label, this.fraction, this.color);
}

class _DonutChartPainter extends CustomPainter {
  final List<_DonutSegment> segments;

  const _DonutChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    double start = -0.25; // start from top
    for (final s in segments) {
      if (s.fraction <= 0) continue;
      final sweep = s.fraction * 2 * 3.141592;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.4
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start * 2 * 3.141592, sweep, false, paint);
      start += s.fraction;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TeamProgressLineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> xLabels;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final int? hoveredIndex;

  const _TeamProgressLineChartPainter({
    required this.data,
    required this.xLabels,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const leftPad = 42.0;
    const rightPad = 16.0;
    const topPad = 14.0;
    const bottomPad = 30.0;
    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;
    final maxY = 100.0;
    final minY = 0.0;

    // Grid + Y-axis labels (0, 25, 50, 75, 100)
    final gridPaint = Paint()..color = gridColor..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = topPad + h - (h * (i / 4));
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );

      final label = '${(i * 25)}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: textColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 8, y - tp.height / 2));
    }

    // Line
    final pts = <Offset>[];
    for (var i = 0; i < data.length; i++) {
      final x = leftPad + (w * (i / (data.length - 1).clamp(1, data.length)));
      final y = topPad + h - (h * ((data[i].clamp(minY, maxY) - minY) / (maxY - minY)));
      pts.add(Offset(x, y));
    }
    if (pts.length >= 2) {
      final linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, linePaint);
    }

    // Point markers
    final pointPaint = Paint()..color = lineColor..style = PaintingStyle.fill;
    for (int i = 0; i < pts.length; i++) {
      final p = pts[i];
      canvas.drawCircle(p, 3.2, pointPaint);
      if (hoveredIndex == i) {
        canvas.drawCircle(
          p,
          6.0,
          Paint()
            ..color = lineColor.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill,
        );
      }
    }

    // X-axis labels (dynamic)
    for (var i = 0; i < pts.length; i++) {
      final label = i < xLabels.length ? xLabels[i] : 'P${i + 1}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: textColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pts[i].dx - tp.width / 2, size.height - bottomPad + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _TeamProgressLineChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.xLabels != xLabels ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

class _InteractiveTeamTrendChart extends StatefulWidget {
  final List<double> points;
  final List<String> labels;

  const _InteractiveTeamTrendChart({
    required this.points,
    required this.labels,
  });

  @override
  State<_InteractiveTeamTrendChart> createState() =>
      _InteractiveTeamTrendChartState();
}

class _InteractiveTeamTrendChartState extends State<_InteractiveTeamTrendChart> {
  int? _hoveredIndex;
  Offset? _hoveredPoint;

  static const double _leftPad = 42.0;
  static const double _rightPad = 16.0;
  static const double _topPad = 14.0;
  static const double _bottomPad = 30.0;

  List<Offset> _pointsForSize(Size size) {
    final data = widget.points;
    if (data.isEmpty) return const <Offset>[];
    final w = size.width - _leftPad - _rightPad;
    final h = size.height - _topPad - _bottomPad;
    final maxY = 100.0;
    final minY = 0.0;
    return List<Offset>.generate(data.length, (i) {
      final x = _leftPad + (w * (i / (data.length - 1).clamp(1, data.length)));
      final y =
          _topPad + h - (h * ((data[i].clamp(minY, maxY) - minY) / (maxY - minY)));
      return Offset(x, y);
    }, growable: false);
  }

  void _updateHover(Offset localPosition, Size size) {
    final pts = _pointsForSize(size);
    if (pts.isEmpty) return;
    int nearest = 0;
    double nearestDist = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final dx = localPosition.dx - pts[i].dx;
      final dy = localPosition.dy - pts[i].dy;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = i;
      }
    }
    if (nearestDist <= 20) {
      setState(() {
        _hoveredIndex = nearest;
        _hoveredPoint = pts[nearest];
      });
    } else if (_hoveredIndex != null) {
      setState(() {
        _hoveredIndex = null;
        _hoveredPoint = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return MouseRegion(
          onHover: (event) => _updateHover(event.localPosition, size),
          onExit: (_) => setState(() {
            _hoveredIndex = null;
            _hoveredPoint = null;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => _updateHover(details.localPosition, size),
            onPanUpdate: (details) => _updateHover(details.localPosition, size),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _TeamProgressLineChartPainter(
                      data: widget.points,
                      xLabels: widget.labels,
                      lineColor: AppColors.activeColor,
                      gridColor: Colors.white.withValues(alpha: 0.15),
                      textColor: AppColors.textSecondary,
                      hoveredIndex: _hoveredIndex,
                    ),
                  ),
                ),
                if (_hoveredIndex != null && _hoveredPoint != null)
                  Positioned(
                    left: (_hoveredPoint!.dx - 34).clamp(0.0, size.width - 68),
                    top: (_hoveredPoint!.dy - 36).clamp(0.0, size.height - 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        '${widget.points[_hoveredIndex!].toStringAsFixed(1)}%',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ManagerProgressVisualsContentState
    extends State<ManagerProgressVisualsContent> {
  TimeFilter currentTimeFilter = TimeFilter.month;
  ProgressViewType currentViewType = ProgressViewType.myProgress;
  String _rankingDisplayMode = 'top3';
  bool _hasAppliedDefaultView = false;
  // Keep a stable focus anchor so we don't leave focus on a disposed widget
  // when swapping between "Team" and "My Progress" subtrees (web can crash on this).
  final FocusNode _stableFocusNode = FocusNode(debugLabel: 'ManagerProgressVisuals');
  DateTime? _lastBadgeEval;
  static const Duration _badgeEvalCooldown = Duration(minutes: 5);
  late final Stream<List<ManagerActivity>> _managerActivitiesStream;
  late Stream<List<EmployeeData>> _teamStream;
  String _teamStreamKey = '';
  String _teamTrendKey = '';
  Future<_TrendSeries>? _teamTrendFuture;
  List<EmployeeData> _lastEnrichedTeamEmployees = const [];

  // In-memory caches to avoid an entry-time "blank loading" state.
  static List<ManagerActivity> _cachedManagerActivities = const [];
  static String _cachedTeamKey = '';
  static List<EmployeeData> _cachedTeamEmployees = const [];
  bool get _isAdminManagerView => widget.forAdminOversight;
  String get _populationPlural => _isAdminManagerView ? 'Managers' : 'Employees';

  @override
  void initState() {
    super.initState();
    _ensureDefaultManagerView();
    // Cache the stream so expanding/collapsing UI doesn't recreate it (which causes a reload spinner).
    _managerActivitiesStream = _getManagerActivitiesStream();
    _rebuildTeamStream();
  }

  @override
  void dispose() {
    _stableFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureDefaultManagerView();
  }

  @override
  void reassemble() {
    super.reassemble();
    // Make sure hot reload also reapplies the default view
    _hasAppliedDefaultView = false;
    _ensureDefaultManagerView();
  }

  void _ensureDefaultManagerView() {
    if (_hasAppliedDefaultView) return;
    currentViewType = ProgressViewType.myProgress;
    _hasAppliedDefaultView = true;
  }

  String _makeTeamStreamKey({TimeFilter? timeFilter}) {
    final tf = (timeFilter ?? currentTimeFilter).name;
    return '${widget.forAdminOversight}_${widget.selectedManagerId ?? ""}_$tf';
  }

  void _rebuildTeamStream() {
    _teamStreamKey = _makeTeamStreamKey(timeFilter: currentTimeFilter);
    if (widget.forAdminOversight) {
      _teamStream = ManagerRealtimeService.getManagersDataStreamForAdmin(
        timeFilter: currentTimeFilter,
        selectedManagerId: widget.selectedManagerId,
      );
    } else {
      _teamStream = ManagerRealtimeService.getTeamDataStream(
        timeFilter: currentTimeFilter,
      );
    }
  }

  void _switchViewType(ProgressViewType next) {
    // Clear any focus that might belong to a widget that's about to be removed.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      currentViewType = next;
    });
    // After rebuild, re-anchor focus on a stable node to avoid web focus traversal crashes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _stableFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _stableFocusNode,
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    currentViewType == ProgressViewType.team
                        ? (_isAdminManagerView
                              ? 'Manager Progress Analytics'
                              : 'Team Progress Analytics')
                        : (_isAdminManagerView ? 'My Progress (Admin)' : 'My Progress Overview'),
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _buildViewTypeFilter(),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            if (currentViewType == ProgressViewType.team)
              _buildTeamProgressView()
            else
              _buildMyProgressView(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamProgressView() {
    return StreamBuilder<List<EmployeeData>>(
      stream: _teamStream,
      initialData:
          (_cachedTeamKey == _teamStreamKey) ? _cachedTeamEmployees : null,
      builder: (context, teamSnapshot) {
        final incoming = teamSnapshot.data;
        final hasPlaceholderBatch =
            incoming != null &&
            incoming.isNotEmpty &&
            incoming.every((e) => e.isPlaceholder);

        // Only treat non-placeholder emissions as "real" (placeholders have no goals/metrics).
        if (incoming != null && incoming.isNotEmpty && !hasPlaceholderBatch) {
          _lastEnrichedTeamEmployees = incoming;
          _cachedTeamKey = _teamStreamKey;
          _cachedTeamEmployees = incoming;
        }

        if (teamSnapshot.hasError) {
          return _buildErrorState(teamSnapshot.error.toString());
        }

        final employees =
            (!hasPlaceholderBatch && incoming != null)
                ? incoming
                : (_lastEnrichedTeamEmployees.isNotEmpty
                      ? _lastEnrichedTeamEmployees
                      : (_cachedTeamKey == _teamStreamKey
                            ? _cachedTeamEmployees
                            : (incoming ?? const [])));

        // If we're still warming up (or only have placeholders), show a lightweight skeleton
        // instead of a full-screen spinner.
        final noEnrichedCache =
            _lastEnrichedTeamEmployees.isEmpty &&
            (_cachedTeamKey != _teamStreamKey || _cachedTeamEmployees.isEmpty);
        if (employees.isEmpty || (hasPlaceholderBatch && noEnrichedCache)) {
          return _buildTeamProgressSkeleton();
        }

        final metrics = _calculateTeamMetrics(employees);
        final goalStatusCounts = _calculateGoalStatusDistribution(employees);
        final engagementByDay = _calculateEngagementByWeekday(employees);
        final categoryProgress = _calculateGoalCategoryProgress(employees);

        final trendFuture = _getTeamTrendFuture(employees);
        return FutureBuilder<_TrendSeries>(
          future: trendFuture,
          builder: (context, trendSnapshot) {
            final effectiveSeries = trendSnapshot.hasError
                ? _buildFallbackTrendFromGoals(employees)
                : (trendSnapshot.data ?? _buildFallbackTrendFromGoals(employees));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTeamAnalyticsFilters(),
                const SizedBox(height: AppSpacing.xl),
                _buildTeamProgressTrendSection(effectiveSeries),
                const SizedBox(height: AppSpacing.xl),
                _buildGoalStatusAndEngagementRow(
                  goalStatusCounts,
                  engagementByDay,
                  metrics,
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildTeamPerformanceRankingSection(employees),
                const SizedBox(height: AppSpacing.xl),
                _buildAiInsightPanel(
                  metrics: metrics,
                  goalStatusCounts: goalStatusCounts,
                  engagementByDay: engagementByDay,
                  categoryProgress: categoryProgress,
                  trendPoints: effectiveSeries.points,
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildGoalCategoryProgressSection(categoryProgress),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMyProgressView() {
    if (_isAdminManagerView) {
      return _buildAdminPersonalMyProgressView();
    }
    return StreamBuilder<List<ManagerActivity>>(
      stream: _managerActivitiesStream,
      initialData: _cachedManagerActivities.isNotEmpty
          ? _cachedManagerActivities
          : null,
      builder: (context, activitySnapshot) {
        if (activitySnapshot.hasError) {
          return _buildErrorState(activitySnapshot.error.toString());
        }

        final activities = activitySnapshot.data ?? [];
        if (activities.isNotEmpty) {
          _cachedManagerActivities = activities;
        }

        // If we don't have any cached activities yet, show skeleton cards rather than
        // blocking the entire screen with a spinner.
        final isStillLoading =
            (activitySnapshot.connectionState == ConnectionState.waiting ||
                activitySnapshot.connectionState == ConnectionState.none) &&
            _cachedManagerActivities.isEmpty &&
            activities.isEmpty;
        if (isStillLoading) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManagerProgressMetricsLoading(),
              const SizedBox(height: AppSpacing.xl),
              _buildManagerBadgesSummary(),
            ],
          );
        }

        if (activities.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNoManagerActivitiesState(),
              const SizedBox(height: AppSpacing.lg),
              _buildManagerBadgesSummary(),
            ],
          );
        }

        final summary = _summarizeManagerActivities(activities);
        _maybeEvaluateManagerBadges();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildManagerProgressMetrics(
              summary.total,
              summary.nudges,
              summary.approvals,
              summary.replans,
              summary.meetings,
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildManagerBadgesSummary(),
            const SizedBox(height: AppSpacing.xl),
            _buildRecentManagerActionsCollapsible(activities),
          ],
        );
      },
    );
  }

  Widget _buildAdminPersonalMyProgressView() {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) {
      return _buildErrorState('Not signed in');
    }

    return StreamBuilder<List<Goal>>(
      stream: _getGoalsStreamForUser(admin.uid),
      builder: (context, goalsSnapshot) {
        if (goalsSnapshot.hasError) {
          return _buildErrorState(goalsSnapshot.error.toString());
        }

        final goals = goalsSnapshot.data ?? const <Goal>[];
        final approvedGoals = goals
            .where((g) => g.approvalStatus == GoalApprovalStatus.approved)
            .toList(growable: false);

        final statusCounts = _calculateGoalStatusForGoals(approvedGoals);
        final categoryProgress =
            _calculateCategoryProgressForGoals(approvedGoals);

        final trendFuture = _getUserTrendFuture(admin.uid);
        return FutureBuilder<_TrendSeries>(
          future: trendFuture,
          builder: (context, trendSnapshot) {
            final series = trendSnapshot.data ??
                _buildFallbackUserTrendFromGoals(approvedGoals);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAdminSeparator(),
                _buildAdminPersonalTimeFilter(),
                const SizedBox(height: AppSpacing.lg),
                _buildAdminSectionTitle('My Progress Trend'),
                _buildTeamProgressTrendSection(
                  series,
                  showHeader: false,
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildAdminSectionTitle('My Goal Status'),
                _buildGoalStatusDonut(
                  statusCounts,
                  showHeader: false,
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildAdminSectionTitle('Goal Category Progress'),
                _buildGoalCategoryProgressSection(categoryProgress),
                const SizedBox(height: AppSpacing.xl),
                _buildAdminSectionTitle('My Activity Summary'),
                _buildAdminActivitySummaryCard(approvedGoals),
                const SizedBox(height: AppSpacing.xl),
                _buildAdminSectionTitle(
                  'Personal Insights',
                  withTrailingLine: false,
                ),
                _buildAdminPersonalInsights(
                  goals: approvedGoals,
                  statusCounts: statusCounts,
                  categoryProgress: categoryProgress,
                  trendPoints: series.points,
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildAdminSectionTitle(
                  'Recent Progress / Updates',
                  withTrailingLine: false,
                ),
                _buildRecentGoalsUpdates(approvedGoals),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdminPersonalTimeFilter() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TimeFilter>(
              value: currentTimeFilter,
              dropdownColor: AppColors.backgroundColor,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
              items: TimeFilter.values
                  .where((t) => t != TimeFilter.today && t != TimeFilter.year)
                  .map(
                    (t) => DropdownMenuItem<TimeFilter>(
                      value: t,
                      child: Text(
                        t.name[0].toUpperCase() + t.name.substring(1),
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  currentTimeFilter = v;
                  // Keep team stream in sync so switching back to "Team"
                  // uses the same selected time filter.
                  _rebuildTeamStream();
                });
              },
            ),
          ),
        ),
        Text(
          'Period: ${currentTimeFilter.name[0].toUpperCase()}${currentTimeFilter.name.substring(1)}',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Stream<List<Goal>> _getGoalsStreamForUser(String uid) {
    return FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final goals = snapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
          goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return goals;
        });
  }

  Map<String, int> _calculateGoalStatusForGoals(List<Goal> goals) {
    final now = DateTime.now();
    int completed = 0;
    int onTrack = 0;
    int atRisk = 0;
    int overdue = 0;

    for (final g in goals) {
      final isCompleted = g.status == GoalStatus.completed || g.status == GoalStatus.acknowledged;
      if (isCompleted) {
        completed++;
        continue;
      }
      if (g.targetDate.isBefore(now)) {
        overdue++;
        continue;
      }
      if (g.progress >= 70) {
        onTrack++;
      } else if (g.progress >= 40) {
        atRisk++;
      } else {
        atRisk++;
      }
    }

    return <String, int>{
      'completed': completed,
      'onTrack': onTrack,
      'atRisk': atRisk,
      'overdue': overdue,
    };
  }

  List<_CategoryProgressItem> _calculateCategoryProgressForGoals(List<Goal> goals) {
    final sums = <GoalCategory, List<double>>{};
    for (final c in GoalCategory.values) {
      sums[c] = <double>[];
    }
    for (final g in goals) {
      sums[g.category]!.add(g.progress.toDouble());
    }
    final labels = <GoalCategory, String>{
      GoalCategory.personal: 'Personal',
      GoalCategory.work: 'Work',
      GoalCategory.health: 'Health',
      GoalCategory.learning: 'Learning',
    };
    return GoalCategory.values.map((c) {
      final values = sums[c]!;
      final avg = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
      return _CategoryProgressItem(label: labels[c] ?? c.name, progress: avg.clamp(0.0, 100.0));
    }).toList(growable: false);
  }

  Future<_TrendSeries> _getUserTrendFuture(String uid) async {
    final range = _historicalFilterRange(currentTimeFilter);
    final sinceKey =
        '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
    final untilKey =
        '${range.endExclusive.year}-${range.endExclusive.month.toString().padLeft(2, '0')}-${range.endExclusive.day.toString().padLeft(2, '0')}';

    final query = FirebaseFirestore.instance
        .collection('goal_daily_progress')
        .where('userId', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: sinceKey)
        .where('date', isLessThan: untilKey)
        .limit(2000);

    final snapshot = await query.get();
    final Map<String, List<double>> byDate = <String, List<double>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final dateKey = (data['date'] ?? '').toString();
      if (dateKey.isEmpty) continue;
      final progress = (data['progress'] as num?)?.toDouble();
      if (progress == null) continue;
      byDate.putIfAbsent(dateKey, () => <double>[]).add(progress.clamp(0.0, 100.0));
    }

    if (byDate.isEmpty) {
      return const _TrendSeries(points: <double>[], labels: <String>[]);
    }

    final dates = byDate.keys.toList()..sort();
    final dailySeries = dates.map((d) {
      final values = byDate[d]!;
      final sum = values.fold<double>(0, (a, b) => a + b);
      return MapEntry(d, (sum / values.length).clamp(0.0, 100.0));
    }).toList(growable: false);

    switch (currentTimeFilter) {
      case TimeFilter.week:
        return _buildWeeklySeries(dailySeries);
      case TimeFilter.month:
        return _buildMonthlySeries(dailySeries);
      case TimeFilter.quarter:
        return _buildQuarterlySeries(dailySeries);
      case TimeFilter.year:
        return _buildYearlySeries(dailySeries);
      case TimeFilter.today:
        return _TrendSeries(
          points: dailySeries.map((e) => e.value).toList(growable: false),
          labels: dailySeries.map((e) => e.key.substring(5)).toList(growable: false),
        );
    }
  }

  _TrendSeries _buildFallbackUserTrendFromGoals(List<Goal> goals) {
    final avg = goals.isEmpty
        ? 0.0
        : goals.map((g) => g.progress).fold<double>(0, (a, b) => a + b) / goals.length;
    final points = currentTimeFilter == TimeFilter.week
        ? <double>[
            (avg * 0.88).clamp(0.0, 100.0),
            (avg * 0.92).clamp(0.0, 100.0),
            (avg * 0.96).clamp(0.0, 100.0),
            (avg * 0.98).clamp(0.0, 100.0),
            avg.clamp(0.0, 100.0),
          ]
        : <double>[
            (avg * 0.72).clamp(0.0, 100.0),
            (avg * 0.81).clamp(0.0, 100.0),
            (avg * 0.88).clamp(0.0, 100.0),
            avg.clamp(0.0, 100.0),
          ];
    final labels = _fallbackLabelsForFilter(points.length);
    return _TrendSeries(points: points, labels: labels);
  }

  Widget _buildAdminActivitySummaryCard(List<Goal> goals) {
    final now = DateTime.now();
    final overdue = goals.where((g) => g.status != GoalStatus.completed && g.targetDate.isBefore(now)).length;
    final completed = goals.where((g) => g.status == GoalStatus.completed || g.status == GoalStatus.acknowledged).length;
    final active = goals.where((g) => g.status != GoalStatus.completed && g.status != GoalStatus.acknowledged).length;
    final avg = goals.isEmpty ? 0.0 : goals.map((g) => g.progress).fold<double>(0, (a, b) => a + b) / goals.length;

    return _buildSectionCard(
      title: 'My Activity Summary',
      showHeader: false,
      child: goals.isEmpty
          ? Text(
              'No personal goals found. Admins typically monitor manager goals using the Team view.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            )
          : Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Active Goals',
                    value: active.toString(),
                    icon: Icons.track_changes,
                    color: AppColors.activeColor,
                    subtitle: 'In progress',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Completed',
                    value: completed.toString(),
                    icon: Icons.check_circle_outline,
                    color: AppColors.successColor,
                    subtitle: 'Achieved',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Overdue',
                    value: overdue.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.dangerColor,
                    subtitle: 'Needs attention',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Average',
                    value: '${avg.toStringAsFixed(0)}%',
                    icon: Icons.trending_up,
                    color: avg >= 70
                        ? AppColors.successColor
                        : avg >= 40
                            ? AppColors.warningColor
                            : AppColors.dangerColor,
                    subtitle: 'Progress',
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAdminPersonalInsights({
    required List<Goal> goals,
    required Map<String, int> statusCounts,
    required List<_CategoryProgressItem> categoryProgress,
    required List<double> trendPoints,
  }) {
    if (goals.isEmpty) {
      return _buildSectionCard(
        title: 'Personal Insights',
        showHeader: false,
        child: Text(
          'No personal goal data to generate insights. Use Team view to monitor managers.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final overdue = statusCounts['overdue'] ?? 0;
    final trendDelta = _calculateTrendDeltaPercent(trendPoints);
    _CategoryProgressItem? lowestCategory;
    if (categoryProgress.isNotEmpty) {
      lowestCategory = categoryProgress.reduce((a, b) => a.progress <= b.progress ? a : b);
    }

    final trendMsg = trendDelta > 0
        ? 'Your progress is improving compared to the previous step (+${trendDelta.abs()}%).'
        : trendDelta < 0
            ? 'Your progress is declining compared to the previous step (-${trendDelta.abs()}%).'
            : 'Your progress is steady compared to the previous step.';

    return _buildSectionCard(
      title: 'Personal Insights',
      showHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trendMsg,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '- $overdue overdue goal${overdue == 1 ? '' : 's'} need attention',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
          Text(
            '- Lowest category progress: ${lowestCategory?.label ?? 'N/A'}'
            '${lowestCategory != null ? ' (${lowestCategory.progress.toStringAsFixed(0)}%)' : ''}',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
          Text(
            '- Focus on one small update today to maintain consistency.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentGoalsUpdates(List<Goal> goals) {
    if (goals.isEmpty) {
      return _buildSectionCard(
        title: 'Recent Progress / Updates',
        showHeader: false,
        child: Text(
          'No recent updates yet.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final visible = goals.take(6).toList(growable: false);
    return _buildSectionCard(
      title: 'Recent Progress / Updates',
      showHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...visible.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildGoalRow(g),
            ),
          ),
          if (goals.length > visible.length)
            Text(
              '+${goals.length - visible.length} more goals',
              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Divider(
        color: Colors.white.withValues(alpha: 0.25),
        thickness: 1,
        height: 1,
      ),
    );
  }

  Widget _buildAdminSectionTitle(
    String title, {
    bool withTrailingLine = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.heading4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (withTrailingLine) _buildAdminSeparator(),
      ],
    );
  }

  Widget _buildAdminGoalStatusAndEngagementSection({
    required Map<String, int> goalStatusCounts,
    required List<int> engagementByDay,
    required TeamMetrics metrics,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 600;

        final goalStatusBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manager Goal Status',
              style: AppTypography.heading4.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildGoalStatusDonut(
              goalStatusCounts,
              showHeader: false,
            ),
          ],
        );

        final engagementBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manager Engagement',
              style: AppTypography.heading4.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildTeamEngagementChart(
              engagementByDay,
              metrics.totalEmployees,
              showHeader: false,
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAdminSeparator(),
            if (isNarrow) ...[
              goalStatusBlock,
              const SizedBox(height: AppSpacing.xl),
              engagementBlock,
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: goalStatusBlock),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: engagementBlock),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            _buildAdminSeparator(),
          ],
        );
      },
    );
  }

  Widget _buildManagerGrowthIndicator(List<double> trendPoints) {
    final bool hasEnoughTrend = trendPoints.length >= 3;

    double? slope;
    if (hasEnoughTrend) {
      // Least squares slope over the whole series (x=0..n-1, y=progress).
      final n = trendPoints.length;
      double sumX = 0;
      double sumY = 0;
      double sumXY = 0;
      double sumXX = 0;
      for (int i = 0; i < n; i++) {
        final x = i.toDouble();
        final y = trendPoints[i];
        sumX += x;
        sumY += y;
        sumXY += x * y;
        sumXX += x * x;
      }
      final denom = (n * sumXX) - (sumX * sumX);
      if (denom.abs() > 0.00001) {
        slope = ((n * sumXY) - (sumX * sumY)) / denom;
      }
    }

    // Threshold is in "progress points per bucket" (bucket = chart step).
    const stagnantThreshold = 0.35;
    final status = !hasEnoughTrend || slope == null
        ? 'Not enough trend data'
        : (slope > stagnantThreshold
              ? 'Improving'
              : (slope < -stagnantThreshold ? 'Declining' : 'Stagnant'));

    final statusColor = !hasEnoughTrend || slope == null
        ? AppColors.textSecondary
        : (status == 'Improving'
              ? AppColors.successColor
              : (status == 'Declining' ? AppColors.dangerColor : AppColors.infoColor));

    final slopeText = !hasEnoughTrend || slope == null
        ? ''
        : '(${slope >= 0 ? '+' : ''}${slope.toStringAsFixed(2)} pts/step)';

    return _buildSectionCard(
      title: 'Manager Growth',
      showHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$status${slopeText.isNotEmpty ? ' $slopeText' : ''}',
            style: AppTypography.heading4.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Based on average goal completion across managers.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildManagerProgressMetricsLoading() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total Activities',
                value: '...',
                icon: Icons.work_outline,
                color: AppColors.activeColor,
                subtitle: 'Loading',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Nudges Sent',
                value: '...',
                icon: Icons.send,
                color: AppColors.infoColor,
                subtitle: 'Loading',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Approvals',
                value: '...',
                icon: Icons.check_circle_outline,
                color: AppColors.successColor,
                subtitle: 'Loading',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Replans',
                value: '...',
                icon: Icons.update,
                color: AppColors.warningColor,
                subtitle: 'Loading',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamProgressSkeleton() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Team Progress',
                value: '...',
                icon: Icons.trending_up,
                color: AppColors.activeColor,
                subtitle: 'Loading metrics',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Goals Completed',
                value: '...',
                icon: Icons.check_circle_outline,
                color: AppColors.successColor,
                subtitle: 'Loading',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _buildMetricCard(
          title: 'Active $_populationPlural',
          value: '...',
          icon: Icons.online_prediction,
          color: AppColors.infoColor,
          subtitle: 'Loading',
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildRecentManagerActionsCollapsible(
    List<ManagerActivity> activities,
  ) {
    final visible = activities.take(8).toList();
    final remaining = (activities.length - visible.length).clamp(0, 999999);

    final subtitleText = activities.isEmpty
        ? 'No actions yet'
        : 'Tap to view your most recent actions (${visible.length} of ${activities.length})';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: const PageStorageKey<String>('recent_manager_actions'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: AppColors.activeColor,
          collapsedIconColor: AppColors.activeColor,
          title: Text(
            'Recent manager actions',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            subtitleText,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            const SizedBox(height: AppSpacing.sm),
            ...visible.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildManagerActivityCard(activity),
              ),
            ),
            if (remaining > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '+$remaining more actions',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.activeColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/manager_review_team_dashboard',
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.activeColor,
                      ),
                      child: const Text('View all'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _maybeEvaluateManagerBadges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final now = DateTime.now();
    if (_lastBadgeEval != null &&
        now.difference(_lastBadgeEval!) < _badgeEvalCooldown) {
      return;
    }
    _lastBadgeEval = now;
    Future.microtask(() async {
      try {
        await ManagerBadgeEvaluator.evaluate(user.uid);
      } catch (e) {
        developer.log('Manager badge evaluate failed: $e');
      }
    });
  }

  _ManagerActivitySummary _summarizeManagerActivities(
    List<ManagerActivity> activities,
  ) {
    int nudges = 0;
    int approvals = 0;
    int replans = 0;
    int meetings = 0;

    for (final a in activities) {
      switch (a.type) {
        case ManagerActivityType.nudge:
          nudges++;
          break;
        case ManagerActivityType.approval:
          approvals++;
          break;
        case ManagerActivityType.replan:
          replans++;
          break;
        case ManagerActivityType.meeting:
          meetings++;
          break;
        case ManagerActivityType.checkIn:
          break;
      }
    }

    return _ManagerActivitySummary(
      total: activities.length,
      nudges: nudges,
      approvals: approvals,
      replans: replans,
      meetings: meetings,
    );
  }

  Widget _buildManagerBadgesSummary() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<List<badge_model.Badge>>(
      stream: BadgeService.getUserBadgesStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }

        final badges = snapshot.data ?? <badge_model.Badge>[];
        final managerBadges = badges.where(_isManagerBadge).toList();
        final earnedCount = managerBadges.where((b) => b.isEarned).length;
        final totalCount = managerBadges.length;
        final progress = totalCount == 0 ? 0.0 : earnedCount / totalCount;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manager badges',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Badge progress gives a quick view of how you are supporting your team (nudges, approvals, replans, seasons).',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LinearPercentIndicator(
                percent: progress.clamp(0.0, 1.0),
                backgroundColor: AppColors.borderColor,
                progressColor: AppColors.activeColor,
                lineHeight: 10,
                animation: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$earnedCount of $totalCount earned',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/manager_badges_points',
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.activeColor,
                    ),
                    child: const Text('View badges'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isManagerBadge(badge_model.Badge badge) {
    final criteria = badge.criteria;
    final source = criteria['source'];
    final hasManagerLevel = criteria.containsKey('managerLevel');
    return badge.id.startsWith('mgr_') || source == 'season' || hasManagerLevel;
  }

  Stream<List<Goal>> _getManagerGoalsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    // Merge top-level and nested user goals (same pattern as manager_employee_detail_screen)
    final topLevel = FirestoreSafe.stream(
      FirebaseFirestore.instance
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
    ).map((s) => s.docs.map((d) => Goal.fromFirestore(d)).toList());

    final nested = FirestoreSafe.stream(
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('goals')
          .snapshots(),
    ).map((s) => s.docs.map((d) => Goal.fromFirestore(d)).toList());

    return topLevel.combineLatest<List<Goal>, List<Goal>>(nested, (a, b) {
      final seen = <String>{};
      final merged = <Goal>[];
      for (final g in [...a, ...b]) {
        if (!seen.contains(g.id)) {
          seen.add(g.id);
          merged.add(g);
        }
      }
      merged.sort((x, y) => y.createdAt.compareTo(x.createdAt));
      return merged;
    });
  }

  Map<String, dynamic> _calculateManagerGoalMetrics(List<Goal> goals) {
    final totalGoals = goals.length;
    final completedGoals = goals
        .where((g) => g.status == GoalStatus.completed || g.progress >= 100)
        .length;
    final activeGoals = goals
        .where(
          (g) =>
              g.approvalStatus == GoalApprovalStatus.approved &&
              g.status != GoalStatus.completed &&
              g.progress < 100,
        )
        .length;
    final overdueGoals = goals.where((g) {
      final now = DateTime.now();
      return g.targetDate.isBefore(now) && g.status != GoalStatus.completed;
    }).length;

    final avgProgress = goals.isEmpty
        ? 0.0
        : goals.map((g) => g.progress).fold(0, (a, b) => a + b) / goals.length;

    final totalPoints = goals.fold<int>(0, (total, g) => total + g.points);

    return {
      'totalGoals': totalGoals,
      'completedGoals': completedGoals,
      'activeGoals': activeGoals,
      'overdueGoals': overdueGoals,
      'avgProgress': avgProgress,
      'totalPoints': totalPoints,
    };
  }

  Widget _buildManagerGoalMetricsCards(Map<String, dynamic> metrics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total Goals',
                value: metrics['totalGoals'].toString(),
                icon: Icons.flag_outlined,
                color: AppColors.activeColor,
                subtitle: 'All goals',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Completed',
                value: metrics['completedGoals'].toString(),
                icon: Icons.check_circle_outline,
                color: AppColors.successColor,
                subtitle: 'Finished',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Active Goals',
                value: metrics['activeGoals'].toString(),
                icon: Icons.trending_up,
                color: AppColors.infoColor,
                subtitle: 'In progress',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Average Progress',
                value: '${metrics['avgProgress'].toStringAsFixed(1)}%',
                icon: Icons.analytics_outlined,
                color: metrics['avgProgress'] >= 70
                    ? AppColors.successColor
                    : metrics['avgProgress'] >= 40
                    ? AppColors.warningColor
                    : AppColors.dangerColor,
                subtitle: 'Overall',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Overdue',
                value: metrics['overdueGoals'].toString(),
                icon: Icons.warning_outlined,
                color: AppColors.dangerColor,
                subtitle: 'Needs attention',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Total Points',
                value: metrics['totalPoints'].toString(),
                icon: Icons.stars_outlined,
                color: AppColors.warningColor,
                subtitle: 'Earned',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManagerMilestoneInsights(List<Goal> goals) {
    if (goals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Milestone Analytics',
          style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        ...goals
            .take(3)
            .map(
              (goal) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: GoalMilestoneAnalyticsCard(goal: goal),
              ),
            ),
      ],
    );
  }

  Widget _buildNoManagerGoalsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.flag_outlined, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No Goals Yet',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking your progress by creating your first goal.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Stream<List<ManagerActivity>> _getManagerActivitiesStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return Stream.periodic(const Duration(seconds: 5)).asyncMap((_) async {
      final activities = <ManagerActivity>[];
      final seenActivityIds = <String>{}; // Track to avoid duplicates

      try {
        // Fetch nudges from alerts - try with composite index first, fallback to simpler query
        List<QueryDocumentSnapshot> nudgeDocs = [];
        try {
          final nudgesSnapshot = await FirebaseFirestore.instance
              .collection('alerts')
              .where('type', isEqualTo: AlertType.managerNudge.name)
              .where('fromUserId', isEqualTo: user.uid)
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();
          nudgeDocs = nudgesSnapshot.docs;
        } catch (e) {
          // If composite index fails, try without orderBy and sort in memory
          developer.log(
            'Alerts composite index query failed, using fallback: $e',
          );
          try {
            final allNudges = await FirebaseFirestore.instance
                .collection('alerts')
                .where('type', isEqualTo: AlertType.managerNudge.name)
                .where('fromUserId', isEqualTo: user.uid)
                .limit(100)
                .get();

            // Sort in memory and take top 50
            nudgeDocs = allNudges.docs.toList()
              ..sort((a, b) {
                final aTime =
                    (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final bTime =
                    (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return bTime.compareTo(aTime);
              });
            nudgeDocs = nudgeDocs.take(50).toList();
          } catch (e2) {
            developer.log('Fallback alerts query also failed: $e2');
            // Continue - nudges will be picked up from manager_actions
          }
        }

        // Process nudges from alerts
        for (final doc in nudgeDocs) {
          final activityId = 'alert_${doc.id}';
          if (seenActivityIds.contains(activityId)) continue;
          seenActivityIds.add(activityId);

          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          final employeeId = data['userId'] as String?;
          String? employeeName;
          if (employeeId != null) {
            try {
              final empDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(employeeId)
                  .get();
              employeeName = empDoc.data()?['displayName'] as String?;
            } catch (_) {
              // Ignore errors fetching employee name
            }
          }

          // Format description from manager's perspective
          // Alert message format: "$managerName sent you a nudge about "$goalTitle": $nudgeMessage"
          // We need: "You sent a nudge to [employee name]"
          String description = 'Sent a nudge to employee';
          if (employeeName != null) {
            description = 'You sent a nudge to $employeeName';
          } else if (employeeId != null) {
            description = 'You sent a nudge to employee';
          }

          activities.add(
            ManagerActivity(
              id: activityId,
              type: ManagerActivityType.nudge,
              title: 'Sent Nudge',
              description: description,
              employeeId: employeeId,
              employeeName: employeeName,
              createdAt:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isCompleted: true,
              metadata: {'goalTitle': data['relatedGoalId']},
            ),
          );
        }

        // Fetch approvals from goals (ONLY goals approved by *this* manager).
        // Include both top-level goals and nested user goals, with index-safe fallbacks.
        List<QueryDocumentSnapshot<Map<String, dynamic>>> approvalDocs = [];
        Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
        fetchApprovalDocsFrom(Query<Map<String, dynamic>> q) async {
          try {
            final snap = await q
                .where('approvedByUserId', isEqualTo: user.uid)
                .where(
                  'approvalStatus',
                  isEqualTo: GoalApprovalStatus.approved.name,
                )
                .orderBy('approvedAt', descending: true)
                .limit(50)
                .get();
            return snap.docs;
          } catch (e) {
            // If composite index fails, try without orderBy and sort in memory
            developer.log('Approvals orderBy failed, using fallback: $e');
            try {
              final snap = await q
                  .where('approvedByUserId', isEqualTo: user.uid)
                  .where(
                    'approvalStatus',
                    isEqualTo: GoalApprovalStatus.approved.name,
                  )
                  .limit(100)
                  .get();
              final docs = snap.docs.toList()
                ..sort((a, b) {
                  final aTime =
                      (a.data()['approvedAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime =
                      (b.data()['approvedAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });
              return docs.take(50).toList();
            } catch (e2) {
              developer.log('Approvals fallback also failed: $e2');
              return const [];
            }
          }
        }

        // Top-level goals approvals
        approvalDocs.addAll(
          await fetchApprovalDocsFrom(
            FirebaseFirestore.instance.collection('goals'),
          ),
        );
        // Nested user goals approvals (in case approvals are stored under users/{uid}/goals)
        approvalDocs.addAll(
          await fetchApprovalDocsFrom(
            FirebaseFirestore.instance.collectionGroup('goals'),
          ),
        );

        // Process approvals (dedupe across sources)
        final seenApprovalKeys = <String>{};
        for (final doc in approvalDocs) {
          final data = doc.data();

          // Defensive: ensure it's really approved by this manager
          if ((data['approvedByUserId'] ?? '').toString() != user.uid) continue;
          if ((data['approvalStatus'] ?? '').toString() !=
              GoalApprovalStatus.approved.name) {
            continue;
          }

          final employeeId = (data['userId'] ?? data['ownerId'])?.toString();
          final approvedAt =
              (data['approvedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final goalTitle = (data['title'] ?? 'Approved a goal').toString();

          // Build a stable dedupe key across collections
          final approvalKey =
              '${employeeId ?? ''}|$goalTitle|${approvedAt.millisecondsSinceEpoch}';
          if (seenApprovalKeys.contains(approvalKey)) continue;
          seenApprovalKeys.add(approvalKey);

          String? employeeName;
          if (employeeId != null && employeeId.isNotEmpty) {
            try {
              final empDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(employeeId)
                  .get();
              employeeName = empDoc.data()?['displayName'] as String?;
            } catch (_) {
              // Ignore errors fetching employee name
            }
          }

          activities.add(
            ManagerActivity(
              id: 'approval_${doc.id}',
              type: ManagerActivityType.approval,
              title: 'Approved Goal',
              description: goalTitle,
              employeeId: employeeId,
              employeeName: employeeName,
              createdAt: approvedAt,
              isCompleted: true,
              metadata: {'goalTitle': goalTitle},
            ),
          );
        }

        // Fetch replans and other actions from manager_actions (primary source for nudges)
        try {
          List<QueryDocumentSnapshot> actionDocs = [];
          try {
            final actionsSnapshot = await FirebaseFirestore.instance
                .collection('manager_actions')
                .where('managerId', isEqualTo: user.uid)
                .orderBy('createdAt', descending: true)
                .limit(50)
                .get();
            actionDocs = actionsSnapshot.docs;
          } catch (e) {
            // If orderBy fails, try without it and sort in memory
            developer.log('Manager actions orderBy failed, using fallback: $e');
            try {
              final allActions = await FirebaseFirestore.instance
                  .collection('manager_actions')
                  .where('managerId', isEqualTo: user.uid)
                  .limit(100)
                  .get();

              actionDocs = allActions.docs.toList()
                ..sort((a, b) {
                  final aTime =
                      (a.data()['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bTime =
                      (b.data()['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bTime.compareTo(aTime);
                });
              actionDocs = actionDocs.take(50).toList();
            } catch (e2) {
              developer.log('Manager actions fallback also failed: $e2');
            }
          }

          // Process all manager actions (including nudges)
          developer.log('Processing ${actionDocs.length} manager actions');
          for (final doc in actionDocs) {
            final activityId = 'action_${doc.id}';
            if (seenActivityIds.contains(activityId)) continue;
            seenActivityIds.add(activityId);

            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) continue;

            final actionType = data['actionType'] as String? ?? '';
            final type = data['type'] as String? ?? '';

            developer.log(
              'Processing action: actionType=$actionType, type=$type, id=${doc.id}',
            );

            ManagerActivityType activityType;
            String title;
            String description;

            if (type == 'replan_helped' || actionType == 'replan_helped') {
              activityType = ManagerActivityType.replan;
              title = 'Helped Replan Goal';
              description =
                  data['note'] as String? ?? 'Helped employee replan a goal';
            } else if (actionType == 'scheduleMeeting' ||
                actionType == 'schedule_meeting') {
              activityType = ManagerActivityType.meeting;
              title = 'Scheduled Meeting';
              description =
                  data['description'] as String? ?? 'Scheduled a 1:1 meeting';
              final scheduledFor = data['scheduledFor'] as Timestamp?;
              if (scheduledFor != null) {
                activities.add(
                  ManagerActivity(
                    id: activityId,
                    type: activityType,
                    title: title,
                    description: description,
                    employeeId: data['employeeId'] as String?,
                    employeeName: data['employeeName'] as String?,
                    createdAt:
                        (data['createdAt'] as Timestamp?)?.toDate() ??
                        DateTime.now(),
                    scheduledFor: scheduledFor.toDate(),
                    isCompleted: scheduledFor.toDate().isBefore(DateTime.now()),
                    metadata: data['details'] as Map<String, dynamic>?,
                  ),
                );
                continue;
              }
            } else if (actionType == 'giveRecognition') {
              activityType = ManagerActivityType.checkIn;
              title = 'Gave Recognition';
              description =
                  data['description'] as String? ??
                  'Recognized employee achievement';
            } else if (actionType == 'sendNudge') {
              activityType = ManagerActivityType.nudge;
              title = 'Sent Nudge';
              // Format description from manager's perspective
              final employeeName = data['employeeName'] as String?;
              if (employeeName != null) {
                description = 'You sent a nudge to $employeeName';
              } else {
                description =
                    data['description'] as String? ??
                    'Sent a nudge to employee';
                // If description exists but doesn't have employee name, try to enhance it
                if (description != 'Sent a nudge to employee' &&
                    !description.toLowerCase().startsWith('you sent')) {
                  description = 'You sent a nudge to employee';
                }
              }
              developer.log(
                'Found nudge in manager_actions: ${doc.id}, actionType: $actionType, description: $description',
              );
            } else {
              activityType = ManagerActivityType.checkIn;
              title = 'Manager Action';
              description =
                  data['description'] as String? ?? 'Performed manager action';
            }

            final status = data['status'] as String? ?? 'completed';
            activities.add(
              ManagerActivity(
                id: activityId,
                type: activityType,
                title: title,
                description: description,
                employeeId: data['employeeId'] as String?,
                employeeName: data['employeeName'] as String?,
                createdAt:
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                scheduledFor: data['scheduledFor'] != null
                    ? (data['scheduledFor'] as Timestamp).toDate()
                    : null,
                isCompleted: status == 'completed',
                metadata: data['details'] as Map<String, dynamic>?,
              ),
            );
          }
        } catch (e) {
          developer.log('Error fetching manager_actions: $e');
        }

        // Sort by date (most recent first)
        activities.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (e) {
        developer.log('Error fetching manager activities: $e');
      }

      return activities;
    });
  }

  Widget _buildViewTypeFilter() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewTypeButton(
            label: 'Team',
            isSelected: currentViewType == ProgressViewType.team,
            onTap: () {
              _switchViewType(ProgressViewType.team);
            },
          ),
          _buildViewTypeButton(
            label: 'My Progress',
            isSelected: currentViewType == ProgressViewType.myProgress,
            onTap: () {
              _switchViewType(ProgressViewType.myProgress);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildViewTypeButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildManagerProgressMetrics(
    int totalActivities,
    int nudges,
    int approvals,
    int replans,
    int meetings,
  ) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total Activities',
                value: totalActivities.toString(),
                icon: Icons.work_outline,
                color: AppColors.activeColor,
                subtitle: 'Completed this period',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Nudges Sent',
                value: nudges.toString(),
                icon: Icons.send,
                color: AppColors.infoColor,
                subtitle: 'Employee nudges',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Approvals',
                value: approvals.toString(),
                icon: Icons.check_circle_outline,
                color: AppColors.successColor,
                subtitle: 'Goals approved',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Replans',
                value: replans.toString(),
                icon: Icons.update,
                color: AppColors.warningColor,
                subtitle: 'Goals replanned',
              ),
            ),
          ],
        ),
        if (meetings > 0) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Meetings',
                  value: meetings.toString(),
                  icon: Icons.calendar_today,
                  color: AppColors.activeColor,
                  subtitle: '1:1 meetings',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildManagerActivityCard(ManagerActivity activity) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    IconData typeIcon;

    // Determine color and icon based on activity type
    switch (activity.type) {
      case ManagerActivityType.nudge:
        statusColor = AppColors.infoColor;
        typeIcon = Icons.send;
        break;
      case ManagerActivityType.approval:
        statusColor = AppColors.successColor;
        typeIcon = Icons.check_circle;
        break;
      case ManagerActivityType.replan:
        statusColor = AppColors.warningColor;
        typeIcon = Icons.update;
        break;
      case ManagerActivityType.meeting:
        statusColor = AppColors.activeColor;
        typeIcon = Icons.calendar_today;
        break;
      case ManagerActivityType.checkIn:
        statusColor = AppColors.activeColor;
        typeIcon = Icons.person_search;
        break;
    }

    if (activity.isCompleted) {
      statusIcon = Icons.check_circle;
      statusText = 'Completed';
    } else if (activity.scheduledFor != null) {
      statusIcon = Icons.schedule;
      statusText = 'Scheduled';
    } else {
      statusIcon = Icons.pending;
      statusText = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (activity.employeeName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'With: ${activity.employeeName}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: AppTypography.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (activity.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              activity.description,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                activity.isCompleted
                    ? 'Completed: ${_formatDate(activity.createdAt)}'
                    : activity.scheduledFor != null
                    ? 'Scheduled: ${_formatDate(activity.scheduledFor!)}'
                    : 'Created: ${_formatDate(activity.createdAt)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoManagerActivitiesState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.work_outline, size: 64, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No activities yet',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start managing your team by sending nudges, approving goals, and helping with replans',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Map<String, dynamic> _calculateNudgeAnalytics(List<EmployeeData> employees) {
    final managerId = FirebaseAuth.instance.currentUser?.uid;
    if (managerId == null) {
      return {
        'responseRate': 0.0,
        'pendingNudges': 0,
        'openedNudges': 0,
        'totalNudges': 0,
      };
    }

    // Get all nudge alerts from employees
    final nudgeAlerts = employees.expand((e) => e.recentAlerts).where((alert) {
      if (alert.type != AlertType.managerNudge) return false;
      if (alert.fromUserId == null) return true;
      return alert.fromUserId == managerId;
    }).toList();

    final openedNudges = nudgeAlerts
        .where((alert) => alert.isRead && !alert.isDismissed)
        .length;
    final dismissedNudges = nudgeAlerts
        .where((alert) => alert.isDismissed)
        .length;
    final pendingNudges = nudgeAlerts.length - openedNudges - dismissedNudges;

    final responseRate = nudgeAlerts.isNotEmpty
        ? (openedNudges / nudgeAlerts.length) * 100
        : 0.0;

    return {
      'responseRate': responseRate,
      'pendingNudges': pendingNudges,
      'openedNudges': openedNudges,
      'totalNudges': nudgeAlerts.length,
    };
  }

  Widget _buildNudgeAnalyticsSummary(Map<String, dynamic> analytics) {
    final responseRate = analytics['responseRate'] as double;
    final pendingNudges = analytics['pendingNudges'] as int;
    final openedNudges = analytics['openedNudges'] as int;
    final totalNudges = analytics['totalNudges'] as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights_outlined,
                      size: 18,
                      color: AppColors.activeColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nudge Analytics',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsMetric(
                        label: 'Response Rate',
                        value: '${responseRate.toStringAsFixed(0)}%',
                        color: responseRate >= 70
                            ? AppColors.successColor
                            : responseRate >= 40
                            ? AppColors.warningColor
                            : AppColors.dangerColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAnalyticsMetric(
                        label: 'Pending Nudges',
                        value: pendingNudges.toString(),
                        color: pendingNudges == 0
                            ? AppColors.successColor
                            : AppColors.warningColor,
                      ),
                    ),
                  ],
                ),
                if (totalNudges > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$openedNudges of $totalNudges nudges opened',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTypography.heading4.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  TeamMetrics _calculateTeamMetrics(List<EmployeeData> employees) {
    final now = DateTime.now();
    final range = _historicalFilterRange(currentTimeFilter);

    int activeCount = 0;
    int onTrackCount = 0;
    int atRiskCount = 0;
    int overdueCount = 0;
    int totalPoints = 0;
    int totalGoalsCompleted = 0;
    double totalProgress = 0;

    for (final employee in employees) {
      if (!employee.lastActivity.isBefore(range.start) &&
          employee.lastActivity.isBefore(range.endExclusive)) {
        activeCount++;
      }

      final goals = _goalsForCurrentFilter(employee);
      for (final g in goals) {
        if (g.status == GoalStatus.completed || g.status == GoalStatus.acknowledged) {
          continue;
        }
        if (g.targetDate.isBefore(now)) {
          overdueCount++;
        } else if (g.progress < 30) {
          atRiskCount++;
        } else {
          onTrackCount++;
        }
      }

      totalPoints += employee.totalPoints;
      totalGoalsCompleted += goals
          .where((g) => g.status == GoalStatus.completed || g.status == GoalStatus.acknowledged)
          .length;
      totalProgress += _averageProgressForEmployee(employee);
    }

    final avgProgress = employees.isNotEmpty
        ? totalProgress / employees.length
        : 0.0;
    final engagement = employees.isNotEmpty
        ? (activeCount / employees.length) * 100
        : 0.0;

    return TeamMetrics(
      totalEmployees: employees.length,
      activeEmployees: activeCount,
      onTrackGoals: onTrackCount,
      atRiskGoals: atRiskCount,
      overdueGoals: overdueCount,
      avgTeamProgress: avgProgress,
      teamEngagement: engagement,
      totalPointsEarned: totalPoints,
      goalsCompleted: totalGoalsCompleted,
      lastUpdated: DateTime.now(),
    );
  }

  List<Goal> _goalsForCurrentFilter(EmployeeData employee) {
    final range = _historicalFilterRange(currentTimeFilter);
    return employee.goals
        .where((g) => !g.createdAt.isBefore(range.start))
        .where((g) => g.createdAt.isBefore(range.endExclusive))
        .toList(growable: false);
  }

  double _averageProgressForEmployee(EmployeeData employee) {
    final goals = _goalsForCurrentFilter(employee);
    if (goals.isEmpty) return 0.0;
    final sum = goals.fold<double>(0.0, (acc, g) => acc + g.progress.toDouble());
    return (sum / goals.length).clamp(0.0, 100.0);
  }

  /// Goal status distribution for donut chart (counts).
  Map<String, int> _calculateGoalStatusDistribution(List<EmployeeData> employees) {
    int completed = 0, onTrack = 0, atRisk = 0, overdue = 0;
    final now = DateTime.now();

    for (final emp in employees) {
      for (final g in _goalsForCurrentFilter(emp)) {
        if (g.status == GoalStatus.completed || g.status == GoalStatus.acknowledged) {
          completed++;
        } else if (g.targetDate.isBefore(now)) {
          overdue++;
        } else if (g.progress < 30) {
          atRisk++;
        } else {
          onTrack++;
        }
      }
    }

    return <String, int>{
      'completed': completed,
      'onTrack': onTrack,
      'atRisk': atRisk,
      'overdue': overdue,
    };
  }

  /// Unique active employees per weekday (Mon..Fri) within the selected filter window.
  List<int> _calculateEngagementByWeekday(List<EmployeeData> employees) {
    final activeByDay = List<Set<String>>.generate(5, (_) => <String>{});
    final range = _historicalFilterRange(currentTimeFilter);

    for (final emp in employees) {
      for (final act in emp.recentActivities) {
        if (act.timestamp.isBefore(range.start) ||
            !act.timestamp.isBefore(range.endExclusive)) {
          continue;
        }
        final weekday = act.timestamp.weekday;
        if (weekday >= 1 && weekday <= 5) {
          activeByDay[weekday - 1].add(emp.profile.uid);
        }
      }
    }

    return activeByDay.map((s) => s.length).toList(growable: false);
  }

  /// Needs attention: overdue goals, inactive days, missed milestone.
  List<_NeedsAttentionItem> _buildNeedsAttentionList(List<EmployeeData> employees) {
    final now = DateTime.now();
    final list = <_NeedsAttentionItem>[];

    for (final emp in employees) {
      if (emp.overdueGoalsCount > 0) {
        list.add(_NeedsAttentionItem(
          employeeName: emp.profile.displayName.isNotEmpty
              ? emp.profile.displayName
              : emp.profile.email.split('@').first,
          reason: '${emp.overdueGoalsCount} overdue goal${emp.overdueGoalsCount == 1 ? '' : 's'}',
          actionType: _NeedsAttentionAction.view,
          employee: emp,
        ));
      }
      final inactiveDays = now.difference(emp.lastActivity).inDays;
      if (inactiveDays >= 7 && emp.overdueGoalsCount == 0) {
        list.add(_NeedsAttentionItem(
          employeeName: emp.profile.displayName.isNotEmpty
              ? emp.profile.displayName
              : emp.profile.email.split('@').first,
          reason: 'inactive for $inactiveDays days',
          actionType: _NeedsAttentionAction.nudge,
          employee: emp,
        ));
      }
      if (emp.status == EmployeeStatus.atRisk && list.every((e) => e.employee != emp)) {
        list.add(_NeedsAttentionItem(
          employeeName: emp.profile.displayName.isNotEmpty
              ? emp.profile.displayName
              : emp.profile.email.split('@').first,
          reason: 'at risk — review goals',
          actionType: _NeedsAttentionAction.review,
          employee: emp,
        ));
      }
    }

    return list.take(8).toList();
  }

  /// Average progress per goal category (personal, work, health, learning).
  List<_CategoryProgressItem> _calculateGoalCategoryProgress(List<EmployeeData> employees) {
    final sums = <GoalCategory, List<double>>{};
    for (final c in GoalCategory.values) {
      sums[c] = [];
    }

    for (final emp in employees) {
      for (final g in _goalsForCurrentFilter(emp)) {
        if (g.approvalStatus != GoalApprovalStatus.approved) continue;
        sums[g.category]!.add(g.progress.toDouble());
      }
    }

    final labels = <GoalCategory, String>{
      GoalCategory.personal: 'Personal',
      GoalCategory.work: 'Work',
      GoalCategory.health: 'Health',
      GoalCategory.learning: 'Learning',
    };

    return GoalCategory.values.map((c) {
      final values = sums[c]!;
      final avg = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
      return _CategoryProgressItem(
        label: labels[c] ?? c.name,
        progress: avg.clamp(0.0, 100.0),
      );
    }).toList();
  }

  Widget _buildTeamAnalyticsFilters() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Time range
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TimeFilter>(
              value: currentTimeFilter,
              isExpanded: false,
              dropdownColor: AppColors.backgroundColor,
              icon: const Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
              items: TimeFilter.values
                  .where((t) => t != TimeFilter.today && t != TimeFilter.year)
                  .map((t) => DropdownMenuItem<TimeFilter>(
                        value: t,
                        child: Text(
                          t.name[0].toUpperCase() + t.name.substring(1),
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                        ),
                      ))
                  .toList(),
              onChanged: (TimeFilter? v) {
                if (v == null) return;
                setState(() {
                  currentTimeFilter = v;
                  _rebuildTeamStream();
                });
              },
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => _exportTeamReport(),
          icon: const Icon(Icons.download, size: 18, color: AppColors.textPrimary),
          label: Text(
            'Export Report',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
          style: TextButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.4),
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ),
        Text(
          'Trend: Previous ${currentTimeFilter.name[0].toUpperCase()}${currentTimeFilter.name.substring(1)} + Now',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Future<void> _exportTeamReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Export report — PDF generation can be wired here'),
        backgroundColor: AppColors.activeColor,
      ),
    );
  }

  Widget _buildTeamProgressTrendSection(
    _TrendSeries series, {
    bool showHeader = true,
  }) {
    if (series.points.isEmpty) {
      return _buildSectionCard(
        title: 'Team Progress Trend',
        showHeader: showHeader,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'No historical snapshot data found for this period.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    return _buildSectionCard(
      title: 'Team Progress Trend',
      showHeader: showHeader,
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: _InteractiveTeamTrendChart(
          points: series.points,
          labels: series.labels,
        ),
      ),
    );
  }

  Future<_TrendSeries> _getTeamTrendFuture(List<EmployeeData> employees) {
    final ids = employees.map((e) => e.profile.uid).toList()..sort();
    final key = '${currentTimeFilter.name}|${ids.join(',')}';
    if (_teamTrendFuture != null && _teamTrendKey == key) {
      return _teamTrendFuture!;
    }
    _teamTrendKey = key;
    _teamTrendFuture = _fetchTeamTrendPointsFromSnapshots(employees);
    return _teamTrendFuture!;
  }

  _DateRange _historicalFilterRange(TimeFilter filter) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case TimeFilter.today:
        return _DateRange(
          start: todayStart,
          endExclusive: todayStart.add(const Duration(days: 1)),
        );
      case TimeFilter.week:
        // Previous full business week window (Mon -> next Mon).
        final thisWeekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
        return _DateRange(start: lastWeekStart, endExclusive: thisWeekStart);
      case TimeFilter.month:
        // Previous full month.
        final thisMonthStart = DateTime(now.year, now.month, 1);
        final lastMonthStart = DateTime(thisMonthStart.year, thisMonthStart.month - 1, 1);
        return _DateRange(start: lastMonthStart, endExclusive: thisMonthStart);
      case TimeFilter.quarter:
        // Previous full quarter.
        final thisQuarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        final thisQuarterStart = DateTime(now.year, thisQuarterStartMonth, 1);
        final lastQuarterStart = DateTime(
          thisQuarterStart.year,
          thisQuarterStart.month - 3,
          1,
        );
        return _DateRange(start: lastQuarterStart, endExclusive: thisQuarterStart);
      case TimeFilter.year:
        final thisYearStart = DateTime(now.year, 1, 1);
        return _DateRange(
          start: DateTime(now.year - 1, 1, 1),
          endExclusive: thisYearStart,
        );
    }
  }

  _DateRange _currentPeriodRange(TimeFilter filter) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (filter) {
      case TimeFilter.today:
        return _DateRange(
          start: todayStart,
          endExclusive: now.add(const Duration(milliseconds: 1)),
        );
      case TimeFilter.week:
        final thisWeekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        return _DateRange(
          start: thisWeekStart,
          endExclusive: now.add(const Duration(milliseconds: 1)),
        );
      case TimeFilter.month:
        final thisMonthStart = DateTime(now.year, now.month, 1);
        return _DateRange(
          start: thisMonthStart,
          endExclusive: now.add(const Duration(milliseconds: 1)),
        );
      case TimeFilter.quarter:
        final thisQuarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        final thisQuarterStart = DateTime(now.year, thisQuarterStartMonth, 1);
        return _DateRange(
          start: thisQuarterStart,
          endExclusive: now.add(const Duration(milliseconds: 1)),
        );
      case TimeFilter.year:
        final thisYearStart = DateTime(now.year, 1, 1);
        return _DateRange(
          start: thisYearStart,
          endExclusive: now.add(const Duration(milliseconds: 1)),
        );
    }
  }

  Future<_TrendSeries> _fetchTeamTrendPointsFromSnapshots(
    List<EmployeeData> employees,
  ) async {
    if (employees.isEmpty) {
      return const _TrendSeries(points: <double>[], labels: <String>[]);
    }

    final userIds = employees.map((e) => e.profile.uid).where((id) => id.isNotEmpty).toList();
    if (userIds.isEmpty) {
      return const _TrendSeries(points: <double>[], labels: <String>[]);
    }

    final range = _historicalFilterRange(currentTimeFilter);
    final sinceKey =
        '${range.start.year}-${range.start.month.toString().padLeft(2, '0')}-${range.start.day.toString().padLeft(2, '0')}';
    final untilKey =
        '${range.endExclusive.year}-${range.endExclusive.month.toString().padLeft(2, '0')}-${range.endExclusive.day.toString().padLeft(2, '0')}';

    final Map<String, List<double>> byDate = <String, List<double>>{};

    for (int i = 0; i < userIds.length; i += 10) {
      final end = (i + 10 < userIds.length) ? i + 10 : userIds.length;
      final chunk = userIds.sublist(i, end);
      final query = FirebaseFirestore.instance
          .collection('goal_daily_progress')
          .where('userId', whereIn: chunk)
          .where('date', isGreaterThanOrEqualTo: sinceKey)
          .where('date', isLessThan: untilKey)
          .limit(2000);

      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final dateKey = (data['date'] ?? '').toString();
        if (dateKey.isEmpty) continue;
        final progress = (data['progress'] as num?)?.toDouble();
        if (progress == null) continue;
        byDate.putIfAbsent(dateKey, () => <double>[]).add(progress.clamp(0.0, 100.0));
      }
    }

    if (byDate.isEmpty) {
      return _buildFallbackTrendFromGoals(employees);
    }

    final dates = byDate.keys.toList()..sort();
    final dailySeries = dates.map((d) {
      final values = byDate[d]!;
      final sum = values.fold<double>(0, (a, b) => a + b);
      return MapEntry(d, (sum / values.length).clamp(0.0, 100.0));
    }).toList(growable: false);

    switch (currentTimeFilter) {
      case TimeFilter.week:
        return _appendNowPoint(_buildWeeklySeries(dailySeries), employees);
      case TimeFilter.month:
        return _appendNowPoint(_buildMonthlySeries(dailySeries), employees);
      case TimeFilter.quarter:
        return _appendNowPoint(_buildQuarterlySeries(dailySeries), employees);
      case TimeFilter.year:
        return _appendNowPoint(_buildYearlySeries(dailySeries), employees);
      case TimeFilter.today:
        return _appendNowPoint(_TrendSeries(
          points: dailySeries.map((e) => e.value).toList(growable: false),
          labels: dailySeries.map((e) => e.key.substring(5)).toList(growable: false),
        ), employees);
    }
  }

  _TrendSeries _appendNowPoint(_TrendSeries base, List<EmployeeData> employees) {
    final nowValue = _currentAverageProgress(employees);
    if (base.points.isEmpty) {
      return _TrendSeries(points: <double>[nowValue], labels: const <String>['Now']);
    }
    final points = List<double>.from(base.points)..add(nowValue);
    final labels = List<String>.from(base.labels)..add('Now');
    return _TrendSeries(points: points, labels: labels);
  }

  _TrendSeries _buildFallbackTrendFromGoals(List<EmployeeData> employees) {
    final labels = _fallbackLabelsForFilter(0);
    final baseAvg = _historicalAverageProgress(employees);
    if (labels.isEmpty) {
      return _TrendSeries(
        points: <double>[_currentAverageProgress(employees)],
        labels: const <String>['Now'],
      );
    }

    final points = <double>[];
    for (int i = 0; i < labels.length; i++) {
      final factor = 0.85 + ((i + 1) / labels.length) * 0.15;
      points.add((baseAvg * factor).clamp(0.0, 100.0));
    }
    return _appendNowPoint(
      _TrendSeries(points: points, labels: labels),
      employees,
    );
  }

  double _historicalAverageProgress(List<EmployeeData> employees) {
    if (employees.isEmpty) return 0.0;
    double total = 0.0;
    for (final e in employees) {
      final goals = _goalsForCurrentFilter(e);
      if (goals.isEmpty) continue;
      final sum = goals.fold<double>(0.0, (a, g) => a + g.progress.toDouble());
      total += (sum / goals.length);
    }
    return (total / employees.length).clamp(0.0, 100.0);
  }

  double _currentAverageProgress(List<EmployeeData> employees) {
    if (employees.isEmpty) return 0.0;
    final range = _currentPeriodRange(currentTimeFilter);
    double total = 0.0;
    for (final e in employees) {
      final goals = e.goals
          .where((g) => !g.createdAt.isBefore(range.start))
          .where((g) => g.createdAt.isBefore(range.endExclusive))
          .toList(growable: false);
      if (goals.isEmpty) {
        total += 0.0;
        continue;
      }
      final sum = goals.fold<double>(0.0, (a, g) => a + g.progress.toDouble());
      total += (sum / goals.length);
    }
    return (total / employees.length).clamp(0.0, 100.0);
  }

  _TrendSeries _buildWeeklySeries(List<MapEntry<String, double>> dailySeries) {
    const labels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final byLabel = <String, List<double>>{for (final l in labels) l: <double>[]};
    for (final e in dailySeries) {
      final dt = DateTime.tryParse(e.key);
      if (dt == null) continue;
      final idx = dt.weekday - 1;
      if (idx >= 0 && idx < labels.length) {
        byLabel[labels[idx]]!.add(e.value);
      }
    }
    final points = labels.map((l) {
      final values = byLabel[l]!;
      if (values.isEmpty) return 0.0;
      return values.reduce((a, b) => a + b) / values.length;
    }).toList(growable: false);
    return _TrendSeries(points: points, labels: labels);
  }

  _TrendSeries _buildMonthlySeries(List<MapEntry<String, double>> dailySeries) {
    final buckets = <List<double>>[<double>[], <double>[], <double>[], <double>[]];
    for (final e in dailySeries) {
      final dt = DateTime.tryParse(e.key);
      if (dt == null) continue;
      final bucket = ((dt.day - 1) / 8).floor().clamp(0, 3);
      buckets[bucket].add(e.value);
    }
    final points = buckets.map((values) {
      if (values.isEmpty) return 0.0;
      return values.reduce((a, b) => a + b) / values.length;
    }).toList(growable: false);
    return _TrendSeries(
      points: points,
      labels: const <String>['W1', 'W2', 'W3', 'W4'],
    );
  }

  _TrendSeries _buildQuarterlySeries(List<MapEntry<String, double>> dailySeries) {
    final buckets = <List<double>>[<double>[], <double>[], <double>[]];
    for (final e in dailySeries) {
      final dt = DateTime.tryParse(e.key);
      if (dt == null) continue;
      final monthBucket = ((dt.month - 1) % 3).clamp(0, 2);
      buckets[monthBucket].add(e.value);
    }
    final points = buckets.map((values) {
      if (values.isEmpty) return 0.0;
      return values.reduce((a, b) => a + b) / values.length;
    }).toList(growable: false);
    return _TrendSeries(
      points: points,
      labels: const <String>['M1', 'M2', 'M3'],
    );
  }

  _TrendSeries _buildYearlySeries(List<MapEntry<String, double>> dailySeries) {
    const monthLabels = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final buckets = List<List<double>>.generate(12, (_) => <double>[]);
    for (final e in dailySeries) {
      final dt = DateTime.tryParse(e.key);
      if (dt == null) continue;
      buckets[dt.month - 1].add(e.value);
    }
    final points = buckets.map((values) {
      if (values.isEmpty) return 0.0;
      return values.reduce((a, b) => a + b) / values.length;
    }).toList(growable: false);
    return _TrendSeries(points: points, labels: monthLabels);
  }

  List<String> _fallbackLabelsForFilter(int count) {
    int takeCount(List<String> source) => count <= 0 ? source.length : count;
    switch (currentTimeFilter) {
      case TimeFilter.week:
        return const <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
            .take(takeCount(const <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri']))
            .toList(growable: false);
      case TimeFilter.month:
        final c = count <= 0 ? 4 : count;
        return List<String>.generate(c, (i) => 'W${i + 1}', growable: false);
      case TimeFilter.quarter:
        final c = count <= 0 ? 3 : count;
        return List<String>.generate(c, (i) => 'M${i + 1}', growable: false);
      case TimeFilter.year:
        const months = <String>[
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
        ];
        return months.take(count <= 0 ? months.length : count).toList(growable: false);
      case TimeFilter.today:
        final c = count <= 0 ? 1 : count;
        return List<String>.generate(c, (i) => 'P${i + 1}', growable: false);
    }
  }

  List<double> _buildTrendPoints(TeamMetrics metrics, List<EmployeeData> employees) {
    // Fallback trend when no historical snapshots are available yet.
    final avg = metrics.avgTeamProgress.clamp(0.0, 100.0);
    if (currentTimeFilter == TimeFilter.week) {
      // Keep 5 points so weekday labels (Mon..Fri) always render in Week mode.
      final weekPoints = <double>[
        (avg * 0.88).clamp(0.0, 100.0),
        (avg * 0.92).clamp(0.0, 100.0),
        (avg * 0.96).clamp(0.0, 100.0),
        (avg * 0.98).clamp(0.0, 100.0),
        avg,
      ];
      if (avg < 1 && employees.isNotEmpty) {
        return <double>[10.0, 16.0, 24.0, 31.0, 40.0];
      }
      return weekPoints;
    }

    final points = <double>[
      (avg * 0.72).clamp(0.0, 100.0),
      (avg * 0.81).clamp(0.0, 100.0),
      (avg * 0.88).clamp(0.0, 100.0),
      avg,
    ];

    if (avg < 1 && employees.isNotEmpty) {
      return <double>[12.0, 24.0, 35.0, 40.0];
    }
    return points;
  }

  int _calculateTrendDeltaPercent(List<double> trendPoints) {
    if (trendPoints.length < 2) return 0;
    final previous = trendPoints[trendPoints.length - 2];
    final current = trendPoints.last;
    if (previous <= 0) return 0;
    return (((current - previous) / previous) * 100).round();
  }

  Widget _buildGoalStatusAndEngagementRow(
    Map<String, int> goalStatusCounts,
    List<int> engagementByDay,
    TeamMetrics metrics,
    {bool showHeaders = true}
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 600;
        return isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildGoalStatusDonut(
                    goalStatusCounts,
                    showHeader: showHeaders,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildTeamEngagementChart(
                    engagementByDay,
                    metrics.totalEmployees,
                    showHeader: showHeaders,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildGoalStatusDonut(
                      goalStatusCounts,
                      showHeader: showHeaders,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _buildTeamEngagementChart(
                      engagementByDay,
                      metrics.totalEmployees,
                      showHeader: showHeaders,
                    ),
                  ),
                ],
              );
      },
    );
  }

  Widget _buildGoalStatusDonut(
    Map<String, int> counts, {
    bool showHeader = true,
  }) {
    final total = counts['completed']! + counts['onTrack']! + counts['atRisk']! + counts['overdue']!;
    if (total == 0) {
      return _buildSectionCard(
        title: 'Goal Status',
        showHeader: showHeader,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Text(
              _isAdminManagerView ? 'No manager goals in this period' : 'No goals in this period',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    final completedPct = (100 * counts['completed']! / total).round();
    final onTrackPct = (100 * counts['onTrack']! / total).round();
    final atRiskPct = (100 * counts['atRisk']! / total).round();
    final overduePct = (100 * counts['overdue']! / total).round();

    final segments = <_DonutSegment>[
      _DonutSegment('Completed', completedPct / 100, AppColors.successColor),
      _DonutSegment('On Track', onTrackPct / 100, AppColors.infoColor),
      _DonutSegment('At Risk', atRiskPct / 100, AppColors.warningColor),
      _DonutSegment('Overdue', overduePct / 100, AppColors.dangerColor),
    ];

    return _buildSectionCard(
      title: 'Goal Status',
      showHeader: showHeader,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CustomPaint(
                painter: _DonutChartPainter(segments: segments),
                size: const Size(100, 100),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _donutLegendRow('Completed', completedPct, AppColors.successColor),
                  _donutLegendRow('On Track', onTrackPct, AppColors.infoColor),
                  _donutLegendRow('At Risk', atRiskPct, AppColors.warningColor),
                  _donutLegendRow('Overdue', overduePct, AppColors.dangerColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _donutLegendRow(String label, int pct, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            '$label $pct%',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamEngagementChart(
    List<int> engagementByDay,
    int totalEmployees,
    {bool showHeader = true}
  ) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    final maxVal = engagementByDay.isEmpty ? 1 : engagementByDay.reduce((a, b) => a > b ? a : b);
    final maxBar = maxVal < 1 ? 1.0 : maxVal.toDouble();

    return _buildSectionCard(
      title: _isAdminManagerView
          ? 'Manager Engagement (Active Managers)'
          : 'Team Engagement (Active Members)',
      showHeader: showHeader,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        child: Column(
          children: List.generate(5, (i) {
            final w = maxBar > 0 ? (engagementByDay[i] / maxBar) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      days[i],
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 20,
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: w,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.activeColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${engagementByDay[i]}/$totalEmployees',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTeamPerformanceRankingSection(
    List<EmployeeData> employees, {
    bool showHeader = true,
  }) {
    final sorted = List<EmployeeData>.from(employees)
      ..sort((a, b) => _averageProgressForEmployee(b).compareTo(_averageProgressForEmployee(a)));
    final bool showAll = _rankingDisplayMode == 'all';
    final List<EmployeeData> visibleEmployees =
        showAll ? sorted : sorted.take(3).toList();

    return _buildSectionCard(
      title: _isAdminManagerView
          ? 'Manager Performance Ranking'
          : 'Team Performance Ranking',
      showHeader: showHeader,
      child: sorted.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                _isAdminManagerView ? 'No managers' : 'No team members',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _rankingDisplayMode,
                        dropdownColor: AppColors.backgroundColor,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.textPrimary),
                        style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimary),
                        items: const [
                          DropdownMenuItem(value: 'top3', child: Text('Top 3')),
                          DropdownMenuItem(value: 'all', child: Text('Show all')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _rankingDisplayMode = value;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleEmployees.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final e = visibleEmployees[index];
                    final progress = _averageProgressForEmployee(e);
                    final name = e.profile.displayName.isNotEmpty
                        ? e.profile.displayName
                        : e.profile.email.split('@').first;
                    return Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            name,
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: LinearProgressIndicator(
                              value: (progress / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${progress.toStringAsFixed(0)}%',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (!showAll && sorted.length > 3) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '+${sorted.length - 3} more ${_populationPlural.toLowerCase()}',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildNeedsAttentionSection(List<_NeedsAttentionItem> items) {
    return _buildSectionCard(
      title: 'Needs Attention',
      icon: Icons.warning_amber_rounded,
      iconColor: AppColors.warningColor,
      child: items.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'No items needing attention',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.employeeName} — ${item.reason}',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    if (item.actionType == _NeedsAttentionAction.view)
                      TextButton(
                        onPressed: () => _viewEmployeeDetails(item.employee),
                        child: const Text('View'),
                      ),
                    if (item.actionType == _NeedsAttentionAction.nudge)
                      TextButton(
                        onPressed: () => _sendNudgeToEmployee(item.employeeName),
                        child: const Text('Send Nudge'),
                      ),
                    if (item.actionType == _NeedsAttentionAction.review)
                      TextButton(
                        onPressed: () => _viewEmployeeDetails(item.employee),
                        child: const Text('Review'),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildAiInsightPanel({
    required TeamMetrics metrics,
    required Map<String, int> goalStatusCounts,
    required List<int> engagementByDay,
    required List<_CategoryProgressItem> categoryProgress,
    required List<double> trendPoints,
    bool includeTrendSummary = true,
    bool showHeader = true,
  }) {
    final trendDelta = _calculateTrendDeltaPercent(trendPoints);
    final trendDirection = trendDelta > 0
        ? 'increased'
        : trendDelta < 0
        ? 'decreased'
        : 'stayed flat';
    final int overdueGoals = goalStatusCounts['overdue'] ?? 0;
    const weekdayLabels = <String>['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    int lowestDayIndex = 0;
    if (engagementByDay.isNotEmpty) {
      for (int i = 1; i < engagementByDay.length; i++) {
        if (engagementByDay[i] < engagementByDay[lowestDayIndex]) {
          lowestDayIndex = i;
        }
      }
    }

    _CategoryProgressItem? lowestCategory;
    if (categoryProgress.isNotEmpty) {
      lowestCategory = categoryProgress.reduce(
        (a, b) => a.progress <= b.progress ? a : b,
      );
    }

    return _buildSectionCard(
      title: 'Smart Insight',
      icon: Icons.auto_awesome,
      iconColor: AppColors.infoColor,
      showHeader: showHeader,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (includeTrendSummary)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.successColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.successColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                trendDirection == 'stayed flat'
                    ? (_isAdminManagerView
                          ? 'Manager progress stayed flat this month.'
                          : 'Team progress stayed flat this month.')
                    : (_isAdminManagerView
                          ? 'Manager progress $trendDirection by ${trendDelta.abs()}% this month.'
                          : 'Team progress $trendDirection by ${trendDelta.abs()}% this month.'),
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (includeTrendSummary) const SizedBox(height: AppSpacing.md),
          Text(
            'However:',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.warningColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '- $overdueGoals overdue goal${overdueGoals == 1 ? '' : 's'} need attention',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
          Text(
            '- Engagement is lowest on ${weekdayLabels[lowestDayIndex]}',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
          Text(
            '- ${lowestCategory?.label ?? 'Category'} goals have the lowest completion'
            '${lowestCategory != null ? ' (${lowestCategory.progress.toStringAsFixed(0)}%)' : ''}',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCategoryProgressSection(List<_CategoryProgressItem> categoryProgress) {
    return _buildSectionCard(
      title: 'Goal Category Progress',
      child: categoryProgress.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'No category data',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categoryProgress.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = categoryProgress[index];
                return Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        item.label,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: LinearProgressIndicator(
                          value: (item.progress / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.activeColor),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.progress.toStringAsFixed(0)}%',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    Widget? child,
    IconData? icon,
    Color? iconColor,
    bool showHeader = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader)
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: iconColor ?? AppColors.textSecondary),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          if (child != null) ...[
            if (showHeader) const SizedBox(height: AppSpacing.md),
            child,
          ],
        ],
      ),
    );
  }

  Widget _buildTeamMetricsCards(TeamMetrics metrics) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: _isAdminManagerView ? 'Managers' : 'Team Members',
                value: metrics.totalEmployees.toString(),
                icon: Icons.people_outline,
                iconWidget: const ImageIcon(
                  AssetImage(
                    'assets/Task_Management/Task_Management_White.png',
                  ),
                  size: 23,
                ),
                color: AppColors.activeColor,
                subtitle: '${metrics.activeEmployees} active (7d)',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Average Progress',
                value: '${metrics.avgTeamProgress.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                iconWidget: const ImageIcon(
                  AssetImage(
                    'assets/Project_Direction_Acceleration/Direction_Acceleration_White.png',
                  ),
                  size: 23,
                ),
                color: metrics.avgTeamProgress >= 70
                    ? AppColors.successColor
                    : metrics.avgTeamProgress >= 40
                    ? AppColors.warningColor
                    : AppColors.dangerColor,
                subtitle: _isAdminManagerView ? 'Manager average' : 'Team average',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Goals Completed',
                value: metrics.goalsCompleted.toString(),
                icon: Icons.check_circle_outline,
                iconWidget: const ImageIcon(
                  AssetImage('assets/Like_Thumbs_Up/Like_Thumbs_Up_White.png'),
                  size: 23,
                ),
                color: AppColors.successColor,
                subtitle: 'This period',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Overdue Goals',
                value: metrics.overdueGoals.toString(),
                icon: Icons.warning_outlined,
                iconWidget: const ImageIcon(
                  AssetImage(
                    'assets/Time_Allocation_Approval/Approval_Whie.png',
                  ),
                  size: 23,
                ),
                color: AppColors.dangerColor,
                subtitle: 'Needs attention',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: _isAdminManagerView
                    ? 'Manager Engagement'
                    : 'Team Engagement',
                value: '${metrics.teamEngagement.toStringAsFixed(1)}%',
                icon: Icons.group_work_outlined,
                iconWidget: const ImageIcon(
                  AssetImage('assets/Team_Meeting/Team_Meeting_White.png'),
                  size: 23,
                ),
                color: metrics.teamEngagement >= 70
                    ? AppColors.successColor
                    : metrics.teamEngagement >= 40
                    ? AppColors.warningColor
                    : AppColors.dangerColor,
                subtitle: 'Active in last 7 days',
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _buildMetricCard(
                title: 'Active Status',
                value: '${metrics.activeEmployees}/${metrics.totalEmployees}',
                icon: Icons.online_prediction,
                iconWidget: const ImageIcon(
                  AssetImage('assets/Data_Approval/Data_Approval_White.png'),
                  size: 23,
                ),
                color: AppColors.infoColor,
                subtitle: _isAdminManagerView
                    ? 'Currently active managers'
                    : 'Currently active',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    Widget? iconWidget,
    required Color color,
    String? subtitle,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
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
              iconWidget ?? Icon(icon, size: 23, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightCard(TeamInsight insight) {
    Color priorityColor;
    IconData priorityIcon;

    switch (insight.priority) {
      case InsightPriority.urgent:
        priorityColor = AppColors.dangerColor;
        priorityIcon = Icons.priority_high;
        break;
      case InsightPriority.high:
        priorityColor = AppColors.warningColor;
        priorityIcon = Icons.warning;
        break;
      case InsightPriority.medium:
        priorityColor = AppColors.infoColor;
        priorityIcon = Icons.info_outline;
        break;
      case InsightPriority.low:
        priorityColor = AppColors.successColor;
        priorityIcon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(priorityIcon, color: priorityColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                insight.priority.name.toUpperCase(),
                style: AppTypography.bodySmall.copyWith(
                  color: priorityColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: priorityColor, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    insight.actionRequired,
                    style: AppTypography.bodySmall.copyWith(
                      color: priorityColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (insight.priority == InsightPriority.urgent ||
              insight.priority == InsightPriority.high) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _sendNudgeToEmployee(insight.employeeName),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: priorityColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text('Send Nudge'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _scheduleMeeting(insight.employeeName),
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Meet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: priorityColor,
                    side: BorderSide(color: priorityColor),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(EmployeeData employee) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (employee.status) {
      case EmployeeStatus.onTrack:
        statusColor = AppColors.successColor;
        statusIcon = Icons.check_circle;
        statusText = 'On Track';
        break;
      case EmployeeStatus.atRisk:
        statusColor = AppColors.warningColor;
        statusIcon = Icons.warning;
        statusText = 'At Risk';
        break;
      case EmployeeStatus.overdue:
        statusColor = AppColors.dangerColor;
        statusIcon = Icons.error_outline;
        statusText = 'Overdue';
        break;
      case EmployeeStatus.inactive:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.pause_circle_outline;
        statusText = 'Inactive';
        break;
    }

    // Determine active status
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    bool isActiveToday = employee.lastActivity.isAfter(today);
    bool isActiveThisWeek = employee.lastActivity.isAfter(sevenDaysAgo);

    Color activeStatusColor;
    IconData activeStatusIcon;
    String activeStatusText;

    if (isActiveToday) {
      activeStatusColor = AppColors.successColor;
      activeStatusIcon = Icons.circle;
      activeStatusText = 'Active Today';
    } else if (isActiveThisWeek) {
      activeStatusColor = AppColors.warningColor;
      activeStatusIcon = Icons.circle;
      activeStatusText = 'Active This Week';
    } else {
      activeStatusColor = AppColors.textSecondary;
      activeStatusIcon = Icons.circle_outlined;
      activeStatusText = 'Inactive';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withValues(alpha: 0.1),
                child: Text(
                  employee.profile.displayName.isNotEmpty
                      ? employee.profile.displayName[0].toUpperCase()
                      : '?',
                  style: AppTypography.bodyMedium.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.profile.displayName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      employee.profile.jobTitle.isNotEmpty
                          ? employee.profile.jobTitle
                          : employee.profile.department,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: AppTypography.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: activeStatusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: activeStatusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          activeStatusIcon,
                          color: activeStatusColor,
                          size: 12,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          activeStatusText,
                          style: AppTypography.bodySmall.copyWith(
                            color: activeStatusColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildEmployeeMetricChip(
                  icon: Icons.track_changes,
                  iconWidget: const ImageIcon(
                    AssetImage('assets/Approved_Tick/Approved_White.png'),
                  ),
                  label: 'Active Goals',
                  value: employee.goals
                      .where(
                        (g) =>
                            g.approvalStatus == GoalApprovalStatus.approved &&
                            g.status != GoalStatus.completed,
                      )
                      .length
                      .toString(),
                  color: AppColors.activeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEmployeeMetricChip(
                  icon: Icons.check_circle_outline,
                  iconWidget: const ImageIcon(
                    AssetImage('assets/Process_Flows_Automation/points2.png'),
                  ),
                  label: 'Completed',
                  value: employee.completedGoalsCount.toString(),
                  color: AppColors.successColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEmployeeMetricChip(
                  icon: Icons.access_time,
                  iconWidget: const ImageIcon(
                    AssetImage(
                      'assets/Time_Allocation_Approval/Approval_Whie.png',
                    ),
                  ),
                  label: 'Progress',
                  value: '${employee.avgProgress.toStringAsFixed(1)}%',
                  color: employee.avgProgress >= 70
                      ? AppColors.successColor
                      : employee.avgProgress >= 40
                      ? AppColors.warningColor
                      : AppColors.dangerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Show last activity information
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: AppColors.textSecondary, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Last active: ${_formatLastActivity(employee.lastActivity)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${employee.weeklyActivityCount} activities this week',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (employee.goals.isNotEmpty) ...[
            Text(
              'Goals',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...employee.goals
                .take(3)
                .map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildGoalRow(goal),
                  ),
                ),
            if (employee.goals.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${employee.goals.length - 3} more goals',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.activeColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No goals yet',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _viewEmployeeDetails(employee),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.activeColor,
                    side: BorderSide(color: AppColors.activeColor),
                  ),
                  child: const Text('View Details'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      _sendNudgeToEmployee(employee.profile.displayName),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Send Nudge'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeMetricChip({
    required IconData icon,
    Widget? iconWidget,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          iconWidget ?? Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalRow(Goal goal) {
    Color priorityColor = _getPriorityColor(goal.priority);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: priorityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  goal.title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: LinearProgressIndicator(
                  value: goal.progress / 100.0,
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(priorityColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${goal.progress}%',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) =>
                      GoalTrendDialog(goalId: goal.id, goalTitle: goal.title),
                );
              },
              icon: const Icon(
                Icons.show_chart,
                size: 14,
                color: AppColors.activeColor,
              ),
              label: Text(
                'View Trend',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.activeColor,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return AppColors.dangerColor;
      case GoalPriority.medium:
        return AppColors.warningColor;
      case GoalPriority.low:
        return AppColors.successColor;
    }
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.dangerColor),
          const SizedBox(height: 16),
          Text(
            'Error loading team data',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            'No team data available',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isAdminManagerView
                ? 'Manager metrics and insights will appear here once managers start using the system.'
                : 'Team metrics and insights will appear here once employees start using the system.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoEmployeesState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            _isAdminManagerView ? 'No managers found' : 'No team members found',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isAdminManagerView
                ? 'Make sure managers are available for this view or check your filter settings.'
                : 'Make sure your team members have been added to your department or check your filter settings.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _sendNudgeToEmployee(String employeeName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Nudge sent to $employeeName'),
        backgroundColor: AppColors.activeColor,
      ),
    );
  }

  void _viewEmployeeDetails(EmployeeData employee) {
    Navigator.pushNamed(
      context,
      '/employee_profile_detail',
      arguments: employee.profile.uid,
    );
  }

  String _formatLastActivity(DateTime? lastActivity) {
    if (lastActivity == null) return 'Never';

    try {
      final now = DateTime.now();

      // Check if the date is valid (not in the future or too far in the past)
      if (lastActivity.isAfter(now) || lastActivity.year < 2000) {
        return 'Unknown';
      }

      final difference = now.difference(lastActivity);

      if (difference.inDays > 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      // Handle any unexpected errors when formatting the date
      return 'Unknown';
    }
  }

  Future<void> _showDebugInfo() async {
    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final FirebaseAuth auth = FirebaseAuth.instance;

      // Get manager info
      final managerDoc = await firestore
          .collection('users')
          .doc(auth.currentUser!.uid)
          .get();
      final managerData = managerDoc.data();

      // Get all employees the manager is allowed to view
      // Prefer same department if set; otherwise fallback to all employees
      Query<Map<String, dynamic>> employeesQueryRef = firestore
          .collection('users')
          .where('role', isEqualTo: 'employee');
      if ((managerData?['department'] as String?)?.isNotEmpty == true) {
        employeesQueryRef = employeesQueryRef.where(
          'department',
          isEqualTo: managerData!['department'],
        );
      }
      final employeesQuery = await employeesQueryRef.get();

      // Get Angel specifically if she exists
      final angelQuery = await firestore
          .collection('users')
          .where('displayName', isEqualTo: 'Angel')
          .get();

      // Get activities only for these employees (avoid cross-user reads)
      final employeeIds = employeesQuery.docs.map((d) => d.id).toList();
      // Avoid composite index by not combining whereIn with orderBy. Sort in-memory.
      final activitiesBaseRef = firestore.collection('activities');
      final activitiesSnapshot = employeeIds.isEmpty
          ? await activitiesBaseRef
                .orderBy('timestamp', descending: true)
                .limit(10)
                .get()
          : await activitiesBaseRef
                .where('userId', whereIn: employeeIds.take(10).toList())
                .limit(25)
                .get();
      // Sort and trim after fetch
      final activitiesDocs = activitiesSnapshot.docs
        ..sort((a, b) {
          final at =
              (a.data()['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bt =
              (b.data()['timestamp'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });

      // Get goals only for these employees
      final goalsBaseRef = firestore.collection('goals');
      final goalsSnapshot = employeeIds.isEmpty
          ? await goalsBaseRef
                .orderBy('createdAt', descending: true)
                .limit(10)
                .get()
          : await goalsBaseRef
                .where('userId', whereIn: employeeIds.take(10).toList())
                .limit(25)
                .get();
      final goalsDocs = goalsSnapshot.docs
        ..sort((a, b) {
          final at =
              (a.data()['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bt =
              (b.data()['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });

      // Get employee activity summary
      final employeeActivitySummary = <String, Map<String, dynamic>>{};
      for (final empDoc in employeesQuery.docs) {
        final empData = empDoc.data();
        final empId = empDoc.id;
        final empName = empData['displayName'] ?? 'Unknown';

        // Count activities for this employee
        final empActivities = activitiesDocs
            .where((act) => act.data()['userId'] == empId)
            .length;

        // Count goals for this employee
        final empGoals = goalsDocs
            .where((goal) => goal.data()['userId'] == empId)
            .length;

        // Get last activity time
        final lastActivity = activitiesDocs
            .where((act) => act.data()['userId'] == empId)
            .map((act) => (act.data()['timestamp'] as Timestamp?)?.toDate())
            .where((date) => date != null)
            .cast<DateTime>()
            .fold<DateTime?>(
              null,
              (latest, current) =>
                  latest == null || current.isAfter(latest) ? current : latest,
            );

        employeeActivitySummary[empName] = {
          'activities': empActivities,
          'goals': empGoals,
          'lastActivity': lastActivity?.toString() ?? 'Never',
          'department': empData['department'] ?? 'No Department',
        };
      }

      String debugInfo =
          '''
DEBUG INFORMATION:

MANAGER:
- UID: ${auth.currentUser!.uid}
- Department: ${managerData?['department'] ?? 'NULL'}
- Display Name: ${managerData?['displayName'] ?? 'NULL'}

ALL EMPLOYEES (${employeesQuery.docs.length}):
${employeesQuery.docs.map((doc) {
            final data = doc.data();
            return '- ${data['displayName'] ?? 'Unknown'}: Department=${data['department'] ?? 'NULL'}, Role=${data['role'] ?? 'NULL'}';
          }).join('\n')}

EMPLOYEE ACTIVITY SUMMARY:
${employeeActivitySummary.entries.map((entry) {
            final empName = entry.key;
            final summary = entry.value;
            return '- $empName: ${summary['activities']} activities, ${summary['goals']} goals, Last active: ${summary['lastActivity']}, Dept: ${summary['department']}';
          }).join('\n')}

ANGEL SPECIFICALLY:
${angelQuery.docs.isNotEmpty ? 'FOUND Angel: ${angelQuery.docs.first.data()}' : 'Angel NOT FOUND in employees collection!'}

RECENT ACTIVITIES (${activitiesDocs.length}):
${activitiesDocs.map((doc) {
            final data = doc.data();
            return '- User: ${data['userId']}, Type: ${data['activityType']}, Description: ${data['description']}';
          }).join('\n')}

RECENT GOALS (${goalsDocs.length}):
${goalsDocs.map((doc) {
            final data = doc.data();
            return '- User: ${data['userId']}, Title: ${data['title']}, Progress: ${data['progress']}%';
          }).join('\n')}
      ''';

      if (!mounted) return; // Add this line here
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          // Capture dialogContext here
          title: const Text('Debug Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  debugInfo,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(), // Use dialogContext
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return; // Re-added
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Debug Error: $e')));
    }
  }

  void _scheduleMeeting(String employeeName) {}
}

class EmployeeProgressVisualsContent extends StatefulWidget {
  final UserProfile userProfile;

  const EmployeeProgressVisualsContent({super.key, required this.userProfile});

  @override
  State<EmployeeProgressVisualsContent> createState() =>
      _EmployeeProgressVisualsContentState();
}

class _EmployeeProgressVisualsContentState
    extends State<EmployeeProgressVisualsContent> {
  GoalStatus? _selectedStatusFilter;
  String? _aiProgressSummary;
  bool _isGeneratingSummary = false;
  String _currentInsightPhase = '';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Your Progress Overview',
                  style: AppTypography.heading2.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _generateProgressInsights(context),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('AI Insights'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.activeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          StreamBuilder<List<Goal>>(
            stream: _getUserGoalsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.activeColor,
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              final goals = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Progress Summary Section
                  _buildAIProgressSummary(goals),
                  const SizedBox(height: AppSpacing.xl),
                  _buildPersonalOverview(goals),
                  const SizedBox(height: AppSpacing.lg),
                  _buildPortfolioView(goals),
                  const SizedBox(height: AppSpacing.lg),
                  _buildStreakSection(widget.userProfile.uid),
                  const SizedBox(height: AppSpacing.xl),
                  if (goals.isEmpty)
                    _buildEmptyGoalsState(context)
                  else ...[
                    _buildGoalsProgress(context, goals),
                    const SizedBox(height: AppSpacing.xl),
                    _buildMilestoneInsights(goals),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Stream<List<Goal>> _getUserGoalsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    // Use Goal.fromFirestore to properly parse all fields including approvalStatus
    return FirebaseFirestore.instance
        .collection('goals')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final goals = snapshot.docs
              .map((doc) => Goal.fromFirestore(doc))
              .toList();
          // Sort goals by createdAt descending (newest first)
          goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return goals;
        });
  }

  Widget _buildAIProgressSummary(List<Goal> goals) {
    if (goals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(Icons.auto_awesome, color: AppColors.activeColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Progress Summary',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // Reload button removed - AI insights button handles generation
            ],
          ),
          const SizedBox(height: 12),
          if (_aiProgressSummary == null && !_isGeneratingSummary)
            Text(
              'Click the AI Insights button to generate an AI-powered summary of your progress.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (_isGeneratingSummary)
            AIGenerationIndicator(
              currentPhase: _currentInsightPhase,
              onPhaseChange: (phase) {
                setState(() => _currentInsightPhase = phase);
              },
            )
          else
            Text(
              _aiProgressSummary!,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generateProgressSummary(
    List<Goal> goals, {
    bool keepGeneratingState = false,
  }) async {
    if (goals.isEmpty) return;

    if (!keepGeneratingState) {
      setState(() {
        _isGeneratingSummary = true;
        _currentInsightPhase = 'Analyzing progress data...';
      });
    }

    // Simulate phase progression (only if not already in generating state)
    Future<void> updatePhase(String phase) async {
      if (mounted && !keepGeneratingState) {
        setState(() => _currentInsightPhase = phase);
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }

    try {
      if (!keepGeneratingState) {
        await updatePhase('Collecting progress data...');
      }
      final progressData = _collectProgressData(goals);

      if (!keepGeneratingState) {
        await updatePhase('Generating summary...');
      }
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: Content.text(
          'You are an AI assistant specialized in analyzing personal development progress. '
          'Generate a concise, natural language summary (3-4 sentences) of the user\'s progress that includes:\n'
          '1. Overall progress status\n'
          '2. Key achievements\n'
          '3. Areas needing attention\n'
          '4. Progress trends over time\n\n'
          'Be motivational, specific, and actionable. Focus on what\'s working well and what needs improvement.',
        ),
      );

      final prompt = [
        Content.text(
          'Analyze this progress data and generate a summary:\n\n$progressData',
        ),
      ];

      await updatePhase('Finalizing summary...');

      final response = await model.generateContent(prompt);
      final summary = response.text?.replaceAll('*', '').trim() ?? '';

      if (!keepGeneratingState) {
        await updatePhase('Complete!');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        setState(() {
          _aiProgressSummary = summary;
          if (!keepGeneratingState) {
            _isGeneratingSummary = false;
            _currentInsightPhase = '';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingSummary = false;
          _currentInsightPhase = '';
        });
        await _showCenteredErrorDialog(context, 'Error generating summary: $e');
      }
    }
  }

  Future<void> _generateProgressInsights(BuildContext context) async {
    // Get goals from stream
    final goals = await _getUserGoalsStream().first;

    if (goals.isEmpty) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        await _showCenteredErrorDialog(
          // ignore: use_build_context_synchronously
          context,
          'No goals found. Create some goals to get AI insights!',
        );
      }
      return;
    }

    if (!mounted) return;

    bool isGenerating = false;
    String currentPhase = '';

    await showDialog<void>(
      // ignore: use_build_context_synchronously
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start generating immediately
            Future<void> generateInsights() async {
              // Simulate phase progression
              Future<void> updatePhase(String phase) async {
                setDialogState(() {
                  currentPhase = phase;
                });
                await Future.delayed(const Duration(milliseconds: 800));
              }

              setDialogState(() {
                isGenerating = true;
                currentPhase = 'Analyzing progress data...';
              });

              try {
                // Generate summary first (shown in AI Progress Summary section)
                await updatePhase('Generating progress summary...');
                await _generateProgressSummary(
                  goals,
                  keepGeneratingState: true,
                );

                // Then generate insights
                await updatePhase('Collecting progress data...');
                final progressData = _collectProgressData(goals);

                await updatePhase('Generating personalized insights...');
                final model = FirebaseAI.googleAI().generativeModel(
                  model: 'gemini-2.5-flash',
                  systemInstruction: Content.text(
                    'You are an AI assistant specialized in analyzing personal development progress and providing actionable insights. '
                    'Based on the progress data provided, generate a comprehensive analysis that includes:\n\n'
                    '1. PERSONALIZED INSIGHTS: Identify patterns in progress, strengths, and areas for improvement\n'
                    '2. RECOMMENDATIONS: Provide specific, actionable recommendations for improvement\n'
                    '3. TREND ANALYSIS: Analyze what\'s working well and what needs attention\n'
                    '4. ACTIONABLE NEXT STEPS: Suggest concrete next steps the user should take\n'
                    '5. MOTIVATIONAL FEEDBACK: Acknowledge achievements and provide encouragement\n\n'
                    'Format your response in clear sections with headings. Be specific, motivational, and actionable.',
                  ),
                );

                final prompt = [
                  Content.text(
                    'Analyze this progress data and provide comprehensive insights:\n\n$progressData\n\n'
                    'Provide personalized insights, recommendations, trend analysis, actionable next steps, and motivational feedback.',
                  ),
                ];

                await updatePhase('Finalizing insights...');

                final response = await model.generateContent(prompt);
                final insights =
                    response.text?.replaceAll('*', '').trim() ?? '';

                await updatePhase('Complete!');
                await Future.delayed(const Duration(milliseconds: 500));

                // Close the dialog
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(dialogContext).pop();
                }

                // Show insights in dialog
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  await _showInsightsDialog(context, insights);
                }
              } catch (e) {
                setDialogState(() => isGenerating = false);
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(dialogContext).pop();
                  // ignore: use_build_context_synchronously
                  await _showCenteredErrorDialog(
                    // ignore: use_build_context_synchronously
                    context,
                    'Error generating insights: $e',
                  );
                }
              }
            }

            // Start generating immediately when dialog opens
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!isGenerating) {
                generateInsights();
              }
            });

            return AlertDialog(
              backgroundColor: AppColors.elevatedBackground,
              title: Text(
                'Generating AI Insights',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AIGenerationIndicator(
                      currentPhase: currentPhase.isEmpty
                          ? 'Analyzing progress data...'
                          : currentPhase,
                      onPhaseChange: (phase) {
                        setDialogState(() => currentPhase = phase);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isGenerating
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _collectProgressData(List<Goal> goals) {
    final totalGoals = goals.length;
    final completedGoals = goals
        .where((g) => g.status == GoalStatus.completed || g.progress >= 100)
        .length;
    // Only count approved goals as active (pending/rejected goals should not appear)
    final activeGoals = goals
        .where(
          (g) =>
              g.approvalStatus == GoalApprovalStatus.approved &&
              g.status != GoalStatus.completed &&
              g.progress < 100,
        )
        .length;
    final overdueGoals = goals.where((g) {
      final now = DateTime.now();
      return g.targetDate.isBefore(now) && g.status != GoalStatus.completed;
    }).length;

    final avgProgress = goals.isEmpty
        ? 0.0
        : goals.map((g) => g.progress).fold(0, (a, b) => a + b) / goals.length;

    final totalPoints = goals.fold<int>(0, (total, g) => total + g.points);

    final categoryBreakdown = <String, int>{};
    for (final goal in goals) {
      final category = goal.category.name;
      categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + 1;
    }

    final priorityBreakdown = <String, int>{};
    for (final goal in goals) {
      final priority = goal.priority.name;
      priorityBreakdown[priority] = (priorityBreakdown[priority] ?? 0) + 1;
    }

    final progressDetails = goals
        .map((g) {
          final daysUntilDeadline = g.targetDate
              .difference(DateTime.now())
              .inDays;
          return 'Goal: ${g.title}\n'
              'Progress: ${g.progress}%\n'
              'Status: ${g.status.name}\n'
              'Priority: ${g.priority.name}\n'
              'Category: ${g.category.name}\n'
              'Days until deadline: $daysUntilDeadline\n'
              'Created: ${g.createdAt.toString().split(' ')[0]}\n';
        })
        .join('\n');

    return '''
PROGRESS OVERVIEW:
- Total Goals: $totalGoals
- Completed Goals: $completedGoals
- Active Goals: $activeGoals
- Overdue Goals: $overdueGoals
- Average Progress: ${avgProgress.toStringAsFixed(1)}%
- Total Points Earned: $totalPoints

CATEGORY BREAKDOWN:
${categoryBreakdown.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}

PRIORITY BREAKDOWN:
${priorityBreakdown.entries.map((e) => '- ${e.key}: ${e.value}').join('\n')}

GOAL DETAILS:
$progressDetails
''';
  }

  Future<void> _showInsightsDialog(
    BuildContext context,
    String insights,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.elevatedBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.activeColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'AI Progress Insights',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              insights,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: AppColors.activeColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCenteredErrorDialog(
    BuildContext context,
    String message,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.elevatedBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: AppColors.dangerColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('OK', style: TextStyle(color: AppColors.activeColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPersonalOverview(List<Goal> goals) {
    final totalGoals = goals.length;
    final completedGoals = goals
        .where(
          (goal) => goal.status == GoalStatus.completed || goal.progress >= 100,
        )
        .length;
    // Only count approved goals as active (pending/rejected goals should not appear)
    final activeGoals = goals
        .where(
          (goal) =>
              goal.approvalStatus == GoalApprovalStatus.approved &&
              goal.status != GoalStatus.completed &&
              goal.progress < 100,
        )
        .length;
    final overallProgress = totalGoals > 0
        ? (completedGoals / totalGoals)
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            title: 'Completion Rate',
            value: '${(overallProgress * 100).toInt()}%',
            progress: overallProgress,
            color: AppColors.successColor,
            iconWidget: SizedBox(
              width: 50,
              height: 50,
              child: Image.asset(
                'Approved_Tick/approved_red_badge_white.png', // Corrected path and filename
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildOverviewCard(
            title: 'Active Goals',
            value: activeGoals.toString(),
            progress: totalGoals > 0 ? (activeGoals / totalGoals) : 0.0,
            color: AppColors.activeColor,
            iconWidget: SizedBox(
              width: 50,
              height: 50,
              child: Image.asset(
                'Goal_Target/Goal_Target_White_Badge_Red_Badge_White.png', // Corrected path and filename
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required String value,
    required double progress,
    required Color color,
    IconData? icon, // Make icon optional
    Widget? iconWidget, // Add new iconWidget parameter
  }) {
    assert(
      icon != null || iconWidget != null,
      'Either icon or iconWidget must be provided.',
    );

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (iconWidget != null) ...[
                // Use iconWidget if provided
                SizedBox(
                  width: 20, // Default size for icons in these cards
                  height: 20,
                  child: iconWidget,
                ),
              ] else if (icon != null) ...[
                // Fallback to IconData if iconWidget is null
                Icon(icon, color: color, size: 20),
              ],
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioView(List<Goal> goals) {
    if (goals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.dashboard_customize, color: Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Portfolio view unlocks once you add your first goal.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final statusGroups = <GoalStatus, int>{
      for (final status in GoalStatus.values)
        status: goals.where((g) => g.status == status).length,
    };
    final categoryGroups = <GoalCategory, int>{
      for (final category in GoalCategory.values)
        category: goals.where((g) => g.category == category).length,
    };

    final overdue = goals
        .where(
          (goal) =>
              goal.targetDate.isBefore(now) &&
              goal.status != GoalStatus.completed,
        )
        .length;
    final dueSoon = goals
        .where(
          (goal) =>
              goal.targetDate.isAfter(now) &&
              goal.targetDate.difference(now).inDays <= 14 &&
              goal.status != GoalStatus.completed,
        )
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'Portfolio View',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildPortfolioMetric(
                label: 'Completed',
                value: '${statusGroups[GoalStatus.completed] ?? 0}',
                accent: AppColors.successColor,
              ),
              _buildPortfolioMetric(
                label: 'In Progress',
                value: '${statusGroups[GoalStatus.inProgress] ?? 0}',
                accent: AppColors.activeColor,
              ),
              _buildPortfolioMetric(
                label: 'Not Started',
                value: '${statusGroups[GoalStatus.notStarted] ?? 0}',
                accent: AppColors.textSecondary,
              ),
              _buildPortfolioMetric(
                label: 'On Hold',
                value:
                    '${(statusGroups[GoalStatus.paused] ?? 0) + (statusGroups[GoalStatus.burnout] ?? 0)}',
                accent: AppColors.warningColor,
              ),
              _buildPortfolioMetric(
                label: 'Overdue',
                value: '$overdue',
                accent: AppColors.dangerColor,
              ),
              _buildPortfolioMetric(
                label: 'Due soon (14d)',
                value: '$dueSoon',
                accent: AppColors.infoColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Category allocation',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: GoalCategory.values.map((category) {
              final count = categoryGroups[category] ?? 0;
              final ratio = goals.isEmpty ? 0.0 : count / goals.length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        category.name.toUpperCase(),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: AppColors.borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _categoryColor(category),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(ratio * 100).toInt()}%',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioMetric({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(GoalCategory category) {
    switch (category) {
      case GoalCategory.personal:
        return AppColors.successColor;
      case GoalCategory.work:
        return AppColors.activeColor;
      case GoalCategory.health:
        return AppColors.warningColor;
      case GoalCategory.learning:
        return AppColors.infoColor;
    }
  }

  Widget _buildStreakSection(String userId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: StreakService.getActivityHistory(userId, days: 56),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.activeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading streak insights…',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final history = snapshot.data ?? [];
        final dailyStreak = _calculateDailyStreak(history);
        final weeklyStreak = _calculateWeeklyStreak(history);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Streaks',
                    style: AppTypography.heading4.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStreakMetric(
                      label: 'Daily streak',
                      value: '$dailyStreak days',
                      icon: Icons.calendar_view_day_outlined,
                      accent: AppColors.activeColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStreakMetric(
                      label: 'Weekly streak',
                      value: '$weeklyStreak weeks',
                      icon: Icons.calendar_view_week_outlined,
                      accent: AppColors.successColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildWeeklyHeatmap(history),
              const SizedBox(height: 6),
              Text(
                'Log progress each week to grow your streak and stay on track.',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStreakMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyHeatmap(List<Map<String, dynamic>> history) {
    final now = DateTime.now();
    final last28Days = List<DateTime>.generate(
      28,
      (index) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 27 - index)),
    );
    final activityDates = history.map((h) => h['date'] as DateTime).toList();

    return SizedBox(
      height: 60,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: last28Days.length,
        itemBuilder: (context, index) {
          final date = last28Days[index];
          final hasActivity = activityDates.any(
            (d) =>
                d.year == date.year &&
                d.month == date.month &&
                d.day == date.day,
          );
          final isToday =
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
          return Tooltip(
            message:
                '${date.day}/${date.month}: ${hasActivity ? 'Progress logged' : 'No progress'}',
            child: Container(
              decoration: BoxDecoration(
                color: hasActivity
                    ? AppColors.successColor.withValues(
                        alpha: isToday ? 0.9 : 0.6,
                      )
                    : Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isToday
                      ? AppColors.activeColor
                      : Colors.white.withValues(alpha: 0.08),
                  width: isToday ? 1.5 : 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  int _calculateDailyStreak(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return 0;
    final sortedDates =
        history
            .map((h) => h['date'] as DateTime)
            .map((d) => DateTime(d.year, d.month, d.day))
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    DateTime cursor = DateTime(today.year, today.month, today.day);
    int streak = 0;

    for (final date in sortedDates) {
      final diff = cursor.difference(date).inDays;
      if (diff == 0) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (diff == 1 && streak > 0) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        if (streak == 0) {
          return 0;
        }
        break;
      }
    }
    return streak;
  }

  int _calculateWeeklyStreak(List<Map<String, dynamic>> history) {
    if (history.isEmpty) return 0;
    final activityWeeks = history
        .map((entry) => entry['date'] as DateTime)
        .map(_weekKey)
        .toSet();

    int streak = 0;
    DateTime cursor = _startOfWeek(DateTime.now());

    while (true) {
      final key = _weekKey(cursor);
      if (activityWeeks.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 7));
      } else {
        break;
      }
    }
    return streak;
  }

  DateTime _startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: weekday - 1));
  }

  String _weekKey(DateTime date) {
    final start = _startOfWeek(date);
    return '${start.year}-${start.month}-${start.day}';
  }

  Widget _buildGoalsProgress(BuildContext context, List<Goal> goals) {
    // Only show approved goals as active (pending/rejected goals should not appear)
    final activeGoals =
        goals
            .where(
              (goal) =>
                  goal.approvalStatus == GoalApprovalStatus.approved &&
                  goal.status != GoalStatus.completed &&
                  goal.progress < 100,
            )
            .toList()
          ..sort((a, b) => a.targetDate.compareTo(b.targetDate));

    final filteredGoals = activeGoals.where((goal) {
      if (_selectedStatusFilter == null) return true;
      return goal.status == _selectedStatusFilter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Goal Progress',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (activeGoals.isNotEmpty)
              TextButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, '/my_goal_workspace'),
                icon: Icon(Icons.add, color: AppColors.activeColor, size: 18),
                label: Text(
                  'Add Goal',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.activeColor,
                  ),
                ),
              ),
          ],
        ),
        if (activeGoals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusFilterChip(null, 'All', Icons.all_inclusive),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  GoalStatus.inProgress,
                  'In Progress',
                  Icons.play_arrow,
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  GoalStatus.notStarted,
                  'Not Started',
                  Icons.flag_outlined,
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  GoalStatus.paused,
                  'On Hold',
                  Icons.pause_circle_outline,
                ),
                const SizedBox(width: 8),
                _buildStatusFilterChip(
                  GoalStatus.burnout,
                  'Recovery',
                  Icons.local_hospital_outlined,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (activeGoals.isEmpty)
          _buildEmptyGoalsState(context)
        else if (filteredGoals.isEmpty)
          _buildFilteredGoalsState()
        else
          ...filteredGoals
              .take(5)
              .map(
                (goal) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _buildGoalProgressCard(context, goal: goal),
                ),
              ),
      ],
    );
  }

  Widget _buildFilteredGoalsState() {
    final label = _statusFilterLabel(_selectedStatusFilter);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No $label goals to show',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Switch filters or start a goal to see it here.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(
    GoalStatus? status,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedStatusFilter == status;
    return FilterChip(
      showCheckmark: false,
      selected: isSelected,
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(label),
      labelStyle: AppTypography.bodySmall.copyWith(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
      selectedColor: AppColors.activeColor,
      backgroundColor: Colors.black.withValues(alpha: 0.35),
      onSelected: (_) {
        setState(() {
          _selectedStatusFilter = status;
        });
      },
    );
  }

  String _statusFilterLabel(GoalStatus? status) {
    switch (status) {
      case GoalStatus.inProgress:
        return 'in-progress';
      case GoalStatus.notStarted:
        return 'not-started';
      case GoalStatus.paused:
        return 'on-hold';
      case GoalStatus.burnout:
        return 'recovery';
      case GoalStatus.acknowledged:
        return 'acknowledged';
      case GoalStatus.completed:
        return 'completed';
      default:
        return 'active';
    }
  }

  Widget _buildMilestoneInsights(List<Goal> goals) {
    if (goals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Milestone Analytics',
          style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.md),
        ...goals
            .take(3)
            .map(
              (goal) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: GoalMilestoneAnalyticsCard(goal: goal),
              ),
            ),
      ],
    );
  }

  Widget _buildEmptyGoalsState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 70,
            height: 70,
            child: Image.asset(
              'Business_Growth_Development/Growth_Development_Red.png', // Corrected path and filename
              fit: BoxFit.contain,
            ),
          ), // Replaced Icon with Image.asset
          const SizedBox(height: 16),
          Text(
            'No Active Goals',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first goal to start tracking your progress!',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalProgressCard(BuildContext context, {required Goal goal}) {
    final now = DateTime.now();
    final daysUntilDeadline = goal.targetDate.difference(now).inDays;
    final progress = goal.progress / 100.0;
    final createdText = _fmtDateTime(goal.createdAt);

    String deadlineText;
    Color deadlineColor;

    if (daysUntilDeadline < 0) {
      deadlineText =
          'Overdue by ${(-daysUntilDeadline)} day${(-daysUntilDeadline) == 1 ? '' : 's'}';
      deadlineColor = AppColors.dangerColor;
    } else if (daysUntilDeadline == 0) {
      deadlineText = 'Due today';
      deadlineColor = AppColors.warningColor;
    } else if (daysUntilDeadline <= 7) {
      deadlineText =
          'Due in $daysUntilDeadline day${daysUntilDeadline == 1 ? '' : 's'}';
      deadlineColor = AppColors.warningColor;
    } else {
      deadlineText = 'Due in $daysUntilDeadline days';
      deadlineColor = AppColors.textSecondary;
    }

    final totalDuration = goal.targetDate
        .difference(goal.createdAt)
        .inSeconds
        .abs();
    final elapsed = now.isBefore(goal.createdAt)
        ? 0
        : now.difference(goal.createdAt).inSeconds;
    final timeProgress = totalDuration == 0
        ? 1.0
        : (elapsed / totalDuration).clamp(0.0, 1.0);
    Color timeColor;
    if (daysUntilDeadline > 14) {
      timeColor = AppColors.successColor;
    } else if (daysUntilDeadline >= 7) {
      timeColor = AppColors.warningColor;
    } else {
      timeColor = AppColors.dangerColor;
    }

    Color progressColor = _getPriorityColor(goal.priority);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 30.0,
            lineWidth: 6.0,
            percent: progress.clamp(0.0, 1.0),
            center: Text(
              "${goal.progress}%",
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            progressColor: progressColor,
            backgroundColor: AppColors.borderColor,
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        goal.title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: progressColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: progressColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        goal.priority.name.toUpperCase(),
                        style: AppTypography.bodySmall.copyWith(
                          color: progressColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  deadlineText,
                  style: AppTypography.bodySmall.copyWith(color: deadlineColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Color(0xFF9E9E9E),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Created $createdText',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  minHeight: 3,
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.timelapse,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Time to due',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: timeProgress,
                            minHeight: 4,
                            backgroundColor: AppColors.borderColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              timeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      daysUntilDeadline >= 0
                          ? '$daysUntilDeadline d'
                          : 'Overdue',
                      style: AppTypography.bodySmall.copyWith(
                        color: timeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildMilestonePreview(goal.id),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => GoalTrendDialog(
                          goalId: goal.id,
                          goalTitle: goal.title,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.show_chart,
                      size: 16,
                      color: AppColors.activeColor,
                    ),
                    label: Text(
                      'View Trend',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.activeColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonePreview(String goalId) {
    return StreamBuilder<List<GoalMilestone>>(
      stream: DatabaseService.getGoalMilestonesStream(goalId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.activeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading milestones…',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        }

        final milestones = snapshot.data ?? const <GoalMilestone>[];
        if (milestones.isEmpty) {
          return Text(
            'No milestones added yet',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          );
        }

        final completed = milestones
            .where((m) => m.status == GoalMilestoneStatus.completed)
            .length;
        final chips = milestones
            .take(3)
            .map(_buildMilestoneChip)
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Milestones',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$completed/${milestones.length} complete',
                  style: AppTypography.caption,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
            if (milestones.length > chips.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${milestones.length - chips.length} more milestones',
                  style: AppTypography.caption,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMilestoneChip(GoalMilestone milestone) {
    final color = _milestoneStatusColor(milestone.status);
    final icon = _milestoneStatusIcon(milestone.status);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    milestone.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_milestoneSubtitle(milestone), style: AppTypography.caption),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return AppColors.dangerColor;
      case GoalPriority.medium:
        return AppColors.warningColor;
      case GoalPriority.low:
        return AppColors.successColor;
    }
  }

  Color _milestoneStatusColor(GoalMilestoneStatus status) {
    switch (status) {
      case GoalMilestoneStatus.completed:
        return AppColors.successColor;
      case GoalMilestoneStatus.inProgress:
        return AppColors.activeColor;
      case GoalMilestoneStatus.blocked:
        return AppColors.dangerColor;
      case GoalMilestoneStatus.notStarted:
        return AppColors.textSecondary;
      case GoalMilestoneStatus.pendingManagerReview:
        return Colors.orange; // Orange for pending review
      case GoalMilestoneStatus.completedAcknowledged:
        return Colors.purple; // Purple for acknowledged
    }
  }

  IconData _milestoneStatusIcon(GoalMilestoneStatus status) {
    switch (status) {
      case GoalMilestoneStatus.completed:
        return Icons.check_circle;
      case GoalMilestoneStatus.inProgress:
        return Icons.timelapse;
      case GoalMilestoneStatus.blocked:
        return Icons.block;
      case GoalMilestoneStatus.notStarted:
        return Icons.radio_button_unchecked;
      case GoalMilestoneStatus.pendingManagerReview:
        return Icons.pending_actions; // Icon for pending review
      case GoalMilestoneStatus.completedAcknowledged:
        return Icons.verified; // Icon for acknowledged
    }
  }

  String _milestoneSubtitle(GoalMilestone milestone) {
    if (milestone.status == GoalMilestoneStatus.completed &&
        milestone.completedAt != null) {
      return 'Completed ${_formatShortDate(milestone.completedAt!)}';
    }
    if (milestone.status == GoalMilestoneStatus.blocked) {
      return 'Updated ${_formatShortDate(milestone.updatedAt)}';
    }
    if (milestone.status == GoalMilestoneStatus.inProgress) {
      return 'Due ${_formatShortDate(milestone.dueDate)}';
    }
    return 'Due ${_formatShortDate(milestone.dueDate)}';
  }

  String _formatShortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final index = (date.month - 1).clamp(0, 11).toInt();
    final month = months[index];
    return '$month ${date.day}';
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.elevatedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.dangerColor),
          const SizedBox(height: 16),
          Text(
            'Error loading progress data',
            style: AppTypography.heading4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _fmtDateTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }
}

class GoalTrendDialog extends StatelessWidget {
  final String goalId;
  final String goalTitle;
  const GoalTrendDialog({
    super.key,
    required this.goalId,
    required this.goalTitle,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 30));
    final sinceKey =
        '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
    final screenW = MediaQuery.sizeOf(context).width;
    final dialogWidth = (screenW * 0.92).clamp(320.0, 720.0);
    return AlertDialog(
      backgroundColor: AppColors.elevatedBackground,
      scrollable: true,
      contentPadding: const EdgeInsets.all(16),
      title: Text(
        'Trends • $goalTitle',
        style: AppTypography.heading4.copyWith(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: dialogWidth,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirestoreSafe.stream(
            FirebaseFirestore.instance
                .collection('goal_daily_progress')
                .where('goalId', isEqualTo: goalId)
                .where('date', isGreaterThanOrEqualTo: sinceKey)
                .orderBy('date')
                .limit(90)
                .snapshots(),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 260,
                child: Center(
                  child: Text(
                    'Could not load trend data. Please try again.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return SizedBox(
                height: 260,
                child: Center(
                  child: Text(
                    'No daily data yet. Come back tomorrow.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }
            final progress = <double>[];
            final remaining = <double>[];
            for (final d in docs) {
              final data = d.data() as Map<String, dynamic>;
              progress.add(
                ((data['progress'] ?? 0) as num).toDouble().clamp(0.0, 100.0),
              );
              remaining.add(
                ((data['remaining'] ?? 0) as num).toDouble().clamp(0.0, 100.0),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ChartCard(
                  title: 'Burnup (Progress %)',
                  color: AppColors.successColor,
                  values: progress,
                ),
                const SizedBox(height: 12),
                _ChartCard(
                  title: 'Burndown (Remaining %)',
                  color: AppColors.warningColor,
                  values: remaining,
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Color color;
  final List<double> values;
  const _ChartCard({
    required this.title,
    required this.color,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(values: values, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values; // 0..100
  final Color color;
  _LineChartPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..color = AppColors.elevatedBackground
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = AppColors.borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final gridPaint = Paint()
      ..color = AppColors.borderColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Padding for axes
    const leftPad = 28.0;
    const bottomPad = 18.0;
    final chartRect = Rect.fromLTWH(
      leftPad,
      8,
      size.width - leftPad - 8,
      size.height - bottomPad - 8,
    );

    // Background & border
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    canvas.drawRect(chartRect, border);

    // Grid lines (5 horizontal)
    final gridCount = 5;
    for (int i = 0; i <= gridCount; i++) {
      final y = chartRect.top + (chartRect.height / gridCount) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    if (values.isEmpty) return;

    // Map values to points
    final n = values.length;
    final dx = n > 1 ? chartRect.width / (n - 1) : 0;
    final path = Path();
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final v = values[i].clamp(0.0, 100.0);
      final x = chartRect.left + dx * i;
      final y = chartRect.bottom - (v / 100.0) * chartRect.height;
      final pt = Offset(x, y);
      points.add(pt);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    // Draw markers so a single data point is still visible.
    for (final p in points) {
      canvas.drawCircle(p, 3.0, pointPaint);
    }

    // Axes tick labels (0, 25, 50, 75, 100)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final tick in [0, 25, 50, 75, 100]) {
      final y = chartRect.bottom - (tick / 100.0) * chartRect.height;
      textPainter.text = TextSpan(
        text: '$tick',
        style: const TextStyle(color: Color(0xFF9AA0AA), fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(2, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class GoalMilestoneAnalyticsCard extends StatelessWidget {
  final Goal goal;

  const GoalMilestoneAnalyticsCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GoalMilestone>>(
      stream: DatabaseService.getGoalMilestonesStream(goal.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.activeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading milestones for ${goal.title}…',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final milestones = snapshot.data ?? const <GoalMilestone>[];
        if (milestones.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add milestones to unlock burn-up, burn-down, and streak analytics.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        final total = milestones.length;
        final completed = milestones
            .where((m) => m.status == GoalMilestoneStatus.completed)
            .length;
        final remaining = total - completed;
        final blocked = milestones
            .where((m) => m.status == GoalMilestoneStatus.blocked)
            .length;

        final burnUp = _buildBurnSeries(milestones);
        final burnDown = burnUp
            .map((value) => (100 - value).clamp(0.0, 100.0))
            .toList();
        final weeklyStreak = _calculateWeeklyStreak(milestones);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.activeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$completed/$total milestones',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.activeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metricChip(
                    label: 'Completed',
                    value: '$completed',
                    color: AppColors.successColor,
                  ),
                  _metricChip(
                    label: 'Remaining',
                    value: '$remaining',
                    color: AppColors.activeColor,
                  ),
                  _metricChip(
                    label: 'Blocked',
                    value: '$blocked',
                    color: AppColors.dangerColor,
                  ),
                  _metricChip(
                    label: 'Weekly streak',
                    value: '$weeklyStreak w',
                    color: AppColors.infoColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ChartCard(
                title: 'Milestone Burn-up',
                color: AppColors.successColor,
                values: burnUp,
              ),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'Milestone Burn-down',
                color: AppColors.warningColor,
                values: burnDown,
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _metricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static List<double> _buildBurnSeries(List<GoalMilestone> milestones) {
    if (milestones.isEmpty) return const [0];
    final total = milestones.length;
    final completionEvents =
        milestones.where((m) => m.completedAt != null).toList()
          ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
    if (completionEvents.isEmpty) {
      return const [0, 0];
    }
    final values = <double>[0];
    int completed = 0;
    for (final _ in completionEvents) {
      completed++;
      values.add(((completed / total) * 100).clamp(0.0, 100.0));
    }
    return values;
  }

  static int _calculateWeeklyStreak(List<GoalMilestone> milestones) {
    if (milestones.isEmpty) return 0;
    final weeks = milestones
        .map((milestone) => milestone.completedAt ?? milestone.updatedAt)
        .whereType<DateTime>()
        .map(_weekKey)
        .toSet();

    int streak = 0;
    DateTime cursor = _startOfWeek(DateTime.now());
    while (true) {
      final key = _weekKey(cursor);
      if (weeks.contains(key)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 7));
      } else {
        break;
      }
    }
    return streak;
  }

  static DateTime _startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: weekday - 1));
  }

  static String _weekKey(DateTime date) {
    final start = _startOfWeek(date);
    return '${start.year}-${start.month}-${start.day}';
  }
}

extension _Rx on Stream<List<Goal>> {
  Stream<R> combineLatest<T, R>(
    Stream<T> other,
    R Function(List<Goal>, T) combiner,
  ) {
    late List<Goal> aCache;
    late T bCache;
    bool hasA = false, hasB = false;
    final controller = StreamController<R>();
    final subA = listen((a) {
      hasA = true;
      aCache = a;
      if (hasB) controller.add(combiner(aCache, bCache));
    });
    final subB = other.listen((b) {
      hasB = true;
      bCache = b;
      if (hasA) controller.add(combiner(aCache, bCache));
    });
    controller.onCancel = () {
      subA.cancel();
      subB.cancel();
    };
    return controller.stream;
  }
}
