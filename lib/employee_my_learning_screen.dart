// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/models/learning_assignment.dart';
import 'package:pdh/services/learning_assignment_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';
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
  String? _employeeId;
  int _reloadToken = 0;

  @override
  void initState() {
    super.initState();
    _employeeId = AuthService().currentUser?.uid;
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
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
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

  void _openWatch(LearningAssignment assignment) {
    Navigator.pushNamed(
      context,
      '/my_learning_watch',
      arguments: {
        'assignmentId': assignment.id,
        'tutorialId': assignment.tutorialId,
        'employeeUserId': _employeeId,
        'title': assignment.tutorialTitle ?? assignment.title,
        'videoUrl': assignment.videoUrl,
      },
    ).then((_) {
      if (mounted) setState(() => _reloadToken++);
    });
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

        return StreamBuilder<List<LearningAssignment>>(
          key: ValueKey('employee_learning_$_reloadToken'),
          stream: backendPollingStream<List<LearningAssignment>>(
            fetch: () =>
                _learningService.listAssignmentsForEmployee(employeeId),
            initialValue: const [],
          ),
          builder: (context, snap) {
            final assignments = snap.data ?? const [];
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

            if (snap.connectionState == ConnectionState.waiting &&
                assignments.isEmpty) {
              return const SizedBox(
                height: 360,
                child: CustomLogoLoader(centerInViewport: true),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopStatsGrid(
                    columns: statsColumns,
                    assigned: open,
                    inProgress: inProgress,
                    completedPct: completedPct,
                    dueThisWeek: dueThisWeek,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'My tutorials',
                    style: AppTypography.heading3.copyWith(
                      color: DashboardChrome.fg,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (assignments.isEmpty)
                    _card(
                      child: Text(
                        'No learning assignments yet. Your manager will assign Udemy tutorials here.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: DashboardChrome.fg,
                        ),
                      ),
                    )
                  else
                    ...assignments.map((a) {
                      final due = a.dueDate;
                      final displayTitle =
                          a.tutorialTitle ?? a.title;
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
                                    a.effectiveStatus == 'completed'
                                        ? 'assets/Approved_Tick/Approved_White_Badge_Red.png'
                                        : 'assets/Innovation_Brainstorm.png',
                                    size: 40,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayTitle,
                                          style: AppTypography.bodyLarge
                                              .copyWith(
                                            color: DashboardChrome.fg,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (due != null)
                                          Text(
                                            'Due ${DateFormat.yMMMd().format(due)}',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              color: DashboardChrome.fg
                                                  .withValues(alpha: 0.75),
                                            ),
                                          ),
                                        if (a.notes != null &&
                                            a.notes!.isNotEmpty)
                                          Text(
                                            a.notes!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              color: DashboardChrome.fg
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  _statusChip(a.effectiveStatus),
                                ],
                              ),
                              if (a.watchProgress > 0 &&
                                  a.effectiveStatus != 'completed') ...[
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: a.watchProgress / 100,
                                  backgroundColor: _dashboardCardBorder(),
                                  color: AppColors.activeColor,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${a.watchProgress}% watched',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: DashboardChrome.fg.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: a.effectiveStatus == 'completed'
                                      ? null
                                      : () => _openWatch(a),
                                  icon: Icon(
                                    a.effectiveStatus == 'in_progress'
                                        ? Icons.play_circle_outline
                                        : Icons.school_outlined,
                                  ),
                                  label: Text(
                                    a.effectiveStatus == 'in_progress'
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
              ),
            );
          },
        );
      },
    );
  }
}
