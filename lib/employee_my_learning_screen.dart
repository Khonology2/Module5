// ignore_for_file: use_build_context_synchronously

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/learning_assignment.dart';
import 'package:pdh/models/learning_tutorial.dart';
import 'package:pdh/services/learning_assignment_service.dart';
import 'package:pdh/widgets/custom_logo_loader.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

class EmployeeMyLearningScreen extends StatefulWidget {
  const EmployeeMyLearningScreen({super.key});

  @override
  State<EmployeeMyLearningScreen> createState() =>
      _EmployeeMyLearningScreenState();
}

class _EmployeeMyLearningScreenState extends State<EmployeeMyLearningScreen> {
  final _learningService = LearningAssignmentService.instance;
  List<LearningFeedItem>? _feedItems;
  bool _isRefreshing = false;
  bool _initialLoad = true;
  String? _loadError;

  String? get _employeeId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _learningService.feedRevision.addListener(_onFeedCacheUpdated);
    _primeFromCache();
    final employeeId = _employeeId;
    if (employeeId != null && employeeId.isNotEmpty) {
      _learningService.warmupEmployeeFeed(employeeId);
    }
    _loadFeed();
  }

  @override
  void dispose() {
    _learningService.feedRevision.removeListener(_onFeedCacheUpdated);
    super.dispose();
  }

  void _onFeedCacheUpdated() {
    _primeFromCache();
  }

  void _primeFromCache() {
    final employeeId = _employeeId;
    if (employeeId == null) return;
    final cached = _learningService.cachedFeedForEmployee(employeeId);
    if (cached == null || !mounted) return;
    setState(() {
      _feedItems = cached;
      _loadError = null;
      _initialLoad = false;
    });
  }

  Future<void> _loadFeed({bool forceRefresh = false}) async {
    final employeeId = _employeeId;
    if (employeeId == null || employeeId.isEmpty) return;

    final hadCache = _feedItems != null && _feedItems!.isNotEmpty;
    if (!hadCache) {
      setState(() {
        _isRefreshing = true;
        _loadError = null;
      });
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final feed = forceRefresh
          ? await _learningService.refreshFeedForEmployee(employeeId)
          : await _learningService.listFeedForEmployee(employeeId);
      if (!mounted) return;
      setState(() {
        _feedItems = feed;
        _loadError = null;
        _initialLoad = false;
        _isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_feedItems == null || _feedItems!.isEmpty) {
          _loadError = e is LearningFeedException
              ? e.toString()
              : 'Could not load tutorials. Pull to refresh or tap Retry.';
        }
        _initialLoad = false;
        _isRefreshing = false;
      });
    }
  }

  int _topStatsColumnsForWidth(double width) {
    if (width >= 920) return 4;
    if (width >= 640) return 2;
    return 1;
  }

  Color _dashboardCardFill() {
    return DashboardChrome.light
        ? const Color(0x99FFFFFF)
        : const Color(0x993D3F40);
  }

  Color _dashboardCardBorder() {
    return DashboardChrome.light
        ? const Color(0x1E000000)
        : Colors.white.withValues(alpha: 0.12);
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
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
      errorBuilder: (context, error, stackTrace) =>
          SizedBox(width: size, height: size),
    );
  }

  Widget _topStatTile({
    required String title,
    required String subtitle,
    required String value,
    required String assetPath,
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
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _assetIcon(assetPath, size: 74),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatsGrid({
    required int columns,
    required int assigned,
    required int inProgress,
    required int completedPct,
    required int dueThisWeek,
  }) {
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: AppSpacing.md,
      mainAxisSpacing: AppSpacing.md,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: columns == 1 ? 3.4 : 2.9,
      children: [
        _topStatTile(
          title: 'Assigned',
          subtitle: 'Tutorials your manager assigned to you.',
          value: '$assigned',
          assetPath: 'assets/manager_dashboard/2.png',
        ),
        _topStatTile(
          title: 'In Progress',
          subtitle: 'Tutorials you have started watching.',
          value: '$inProgress',
          assetPath: 'assets/manager_dashboard/3.png',
        ),
        _topStatTile(
          title: 'Completed',
          subtitle: 'Share of assignments you finished.',
          value: '$completedPct%',
          assetPath: 'assets/manager_dashboard/6.png',
        ),
        _topStatTile(
          title: 'Due This Week',
          subtitle: 'Open assignments due in the next 7 days.',
          value: '$dueThisWeek',
          assetPath: 'assets/manager_dashboard/4.png',
        ),
      ],
    );
  }

  Widget _skeletonBox({double height = 16, double? width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: _dashboardCardBorder(),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildSkeleton(int statsColumns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: statsColumns,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: statsColumns == 1 ? 3.4 : 2.9,
          children: List.generate(
            4,
            (_) => _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBox(height: 14, width: 100),
                  const SizedBox(height: 8),
                  _skeletonBox(height: 10, width: 180),
                  const Spacer(),
                  _skeletonBox(height: 28, width: 48),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _skeletonBox(height: 20, width: 120),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _skeletonBox(height: 18, width: 220),
                  const SizedBox(height: 8),
                  _skeletonBox(height: 12, width: 140),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _skeletonBox(height: 36, width: 130),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'completed':
        color = AppColors.successColor;
        break;
      case 'in_progress':
        color = AppColors.warningColor;
        break;
      case 'overdue':
        color = AppColors.activeColor;
        break;
      default:
        color = AppColors.infoColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }

  void _openWatch({
    required LearningTutorial tutorial,
    LearningAssignment? assignment,
  }) {
    Navigator.pushNamed(
      context,
      '/my_learning_watch',
      arguments: {
        if (assignment != null) 'assignmentId': assignment.id,
        'tutorialId': tutorial.id,
        'employeeUserId': _employeeId,
        'title': assignment?.tutorialTitle ?? assignment?.title ?? tutorial.title,
        'videoUrl': assignment?.videoUrl ?? tutorial.videoUrl,
      },
    ).then((_) {
      if (mounted) _loadFeed(forceRefresh: true);
    });
  }

  ({
    int assigned,
    int inProgress,
    int completedPct,
    int dueThisWeek,
  }) _computeStats(List<LearningFeedItem> feedItems) {
    final assignments = feedItems
        .where((item) => item.assignment != null)
        .map((item) => item.assignment!)
        .toList();
    final open = assignments
        .where(
          (a) =>
              a.effectiveStatus != 'completed' &&
              a.effectiveStatus != 'cancelled',
        )
        .length;
    final inProgress = assignments
        .where((a) => a.effectiveStatus == 'in_progress')
        .length;
    final completedCount = assignments
        .where((a) => a.effectiveStatus == 'completed')
        .length;
    final completedPct = assignments.isEmpty
        ? 0
        : ((completedCount / assignments.length) * 100).round();
    final weekEnd = DateTime.now().add(const Duration(days: 7));
    final dueThisWeek = assignments.where((a) {
      final due = a.dueDate;
      return due != null &&
          due.isBefore(weekEnd) &&
          a.effectiveStatus != 'completed';
    }).length;
    return (
      assigned: open,
      inProgress: inProgress,
      completedPct: completedPct,
      dueThisWeek: dueThisWeek,
    );
  }

  Widget _buildFeedContent({
    required List<LearningFeedItem> feedItems,
    required int statsColumns,
  }) {
    final stats = _computeStats(feedItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopStatsGrid(
          columns: statsColumns,
          assigned: stats.assigned,
          inProgress: stats.inProgress,
          completedPct: stats.completedPct,
          dueThisWeek: stats.dueThisWeek,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                'My tutorials',
                style: AppTypography.heading3.copyWith(
                  color: DashboardChrome.fg,
                ),
              ),
            ),
            if (_isRefreshing)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.activeColor,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (feedItems.isEmpty)
          _card(
            child: Text(
              'No tutorials available yet. Your manager will add Udemy tutorials here.',
              style: AppTypography.bodyMedium.copyWith(
                color: DashboardChrome.fg,
              ),
            ),
          )
        else
          ...feedItems.map((item) {
            final assignment = item.assignment;
            final tutorial = item.tutorial;
            final due = assignment?.dueDate;
            final displayTitle = assignment?.tutorialTitle ??
                assignment?.title ??
                tutorial.title;
            final canWatch = tutorial.videoUrl.trim().isNotEmpty &&
                (assignment == null ||
                    assignment.effectiveStatus != 'completed');
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _assetIcon(
                          assignment?.effectiveStatus == 'completed'
                              ? 'assets/Approved_Tick/Approved_White_Badge_Red.png'
                              : 'assets/Innovation_Brainstorm.png',
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: DashboardChrome.fg,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (due != null)
                                Text(
                                  'Due ${DateFormat.yMMMd().format(due)}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: DashboardChrome.fg
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                              if (assignment != null &&
                                  assignment.notes != null &&
                                  assignment.notes!.isNotEmpty)
                                Text(
                                  assignment.notes!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: DashboardChrome.fg
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _statusChip(
                          assignment?.effectiveStatus ?? 'available',
                        ),
                      ],
                    ),
                    if (assignment != null &&
                        assignment.watchProgress > 0 &&
                        assignment.effectiveStatus != 'completed') ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: assignment.watchProgress / 100,
                        backgroundColor: _dashboardCardBorder(),
                        color: AppColors.activeColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${assignment.watchProgress}% watched',
                        style: AppTypography.bodySmall.copyWith(
                          color: DashboardChrome.fg.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: canWatch
                            ? () => _openWatch(
                                  tutorial: tutorial,
                                  assignment: assignment,
                                )
                            : null,
                        icon: Icon(
                          assignment?.effectiveStatus == 'in_progress'
                              ? Icons.play_circle_outline
                              : Icons.school_outlined,
                        ),
                        label: Text(
                          assignment?.effectiveStatus == 'in_progress'
                              ? 'Continue tutorial'
                              : 'Start tutorial',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.activeColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeeId = _employeeId;
    if (employeeId == null) {
      return const Center(child: CustomLogoLoader());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rawW = constraints.maxWidth;
        final layoutW =
            rawW.isFinite ? rawW : MediaQuery.sizeOf(context).width;
        final width = layoutW.clamp(0.0, double.infinity);
        final statsColumns = _topStatsColumnsForWidth(width);

        if (_initialLoad && _feedItems == null && _loadError == null) {
          return _buildSkeleton(statsColumns);
        }

        if (_loadError != null && _feedItems == null) {
          return _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load tutorials. Pull to refresh or try again.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: DashboardChrome.fg,
                  ),
                ),
                if (_loadError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _loadError!,
                    style: AppTypography.bodySmall.copyWith(
                      color: DashboardChrome.fg.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _loadFeed(forceRefresh: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final feedItems = _feedItems ?? const <LearningFeedItem>[];

        return RefreshIndicator(
          color: AppColors.activeColor,
          onRefresh: () => _loadFeed(forceRefresh: true),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: _buildFeedContent(
              feedItems: feedItems,
              statsColumns: statsColumns,
            ),
          ),
        );
      },
    );
  }
}
