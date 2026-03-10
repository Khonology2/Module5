import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/services/manager_realtime_service.dart';

class AdminManagerOversightScreen extends StatefulWidget {
  final bool embedded;

  const AdminManagerOversightScreen({super.key, this.embedded = false});

  @override
  State<AdminManagerOversightScreen> createState() =>
      _AdminManagerOversightScreenState();
}

class _AdminManagerOversightScreenState
    extends State<AdminManagerOversightScreen> {
  late final Stream<List<EmployeeData>> _managersStream;

  @override
  void initState() {
    super.initState();
    _managersStream = ManagerRealtimeService.getManagersDataStream();
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = StreamBuilder<List<EmployeeData>>(
      stream: _managersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.dangerColor),
                const SizedBox(height: 8),
                Text(
                  'Error loading managers',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }
        final managers = snapshot.data ?? [];
        final now = DateTime.now();
        final sevenDaysAgo = now.subtract(const Duration(days: 7));
        final total = managers.length;
        final active = managers
            .where((e) => e.lastActivity.isAfter(sevenDaysAgo))
            .length;
        final avgProgress = total > 0
            ? managers.map((e) => e.avgProgress).fold(0.0, (a, b) => a + b) /
                total
            : 0.0;
        final engagement =
            total > 0 ? (active / total) * 100.0 : 0.0;

        return SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress & Visuals',
                      style: AppTypography.heading3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Overview of all managers: progress, activity, and comparison.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildMetricsCard(total, avgProgress, engagement),
              const SizedBox(height: AppSpacing.xl),
              _buildProgressTrends(managers),
              const SizedBox(height: AppSpacing.xl),
              _buildManagerProgressComparison(managers),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text(
          'Progress & Visuals',
          style: AppTypography.heading2.copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/khono_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildMetricsCard(int total, double avgProgress, double engagement) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Managers at a glance', style: AppTypography.heading2),
          const SizedBox(height: 4),
          Text(
            'Key metrics for all managers.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _kpi('Managers', total.toString()),
              _kpi('Avg progress', '${avgProgress.toStringAsFixed(0)}%'),
              _kpi('Engagement (7d)', '${engagement.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AppTypography.bodySmall.copyWith(
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

  Widget _buildProgressTrends(List<EmployeeData> managers) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayCounts = List<int>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final dayStart = today.subtract(Duration(days: 6 - i));
      final dayEnd = dayStart.add(const Duration(days: 1));
      for (final e in managers) {
        for (final a in e.recentActivities) {
          if (!a.timestamp.isBefore(dayStart) && a.timestamp.isBefore(dayEnd)) {
            dayCounts[i]++;
          }
        }
      }
    }
    final maxCount =
        dayCounts.isEmpty ? 1 : dayCounts.reduce((a, b) => a > b ? a : b);
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

  Widget _buildManagerProgressComparison(List<EmployeeData> managers) {
    final sorted = [...managers]
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
              Icon(Icons.bar_chart_rounded,
                  color: AppColors.activeColor, size: 22),
              const SizedBox(width: 8),
              Text('Manager progress comparison', style: AppTypography.heading2),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Compare progress across managers. Top to low performers.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...sorted.map((e) {
            final idx = sorted.indexOf(e);
            final isTop = idx < 3;
            final isLow =
                idx >= sorted.length - 2 && sorted.length >= 3;
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
                        style: const TextStyle(
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
}
