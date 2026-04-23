import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/goal_detail_screen.dart';
import 'package:pdh/services/season_service.dart';
import 'package:pdh/season_celebration_screen.dart';
import 'package:pdh/utils/attachment_opener_io.dart';

class SeasonDetailsScreen extends StatefulWidget {
  final Season season;
  final String? participantUserId;
  final String? participantUserName;

  const SeasonDetailsScreen({
    super.key,
    required this.season,
    this.participantUserId,
    this.participantUserName,
  });

  @override
  State<SeasonDetailsScreen> createState() => _SeasonDetailsScreenState();
}

class _SeasonDetailsScreenState extends State<SeasonDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  bool get _isParticipantView => widget.participantUserId?.trim().isNotEmpty == true;

  Future<void> _showCenterNotice(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.cardBackground,
          content: Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'OK',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.activeColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Season>(
      stream: SeasonService.getSeasonStream(widget.season.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildSeasonBackground(
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.activeColor,
                  ),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildSeasonBackground(
              child: const Center(
                child: Text('Season not found', style: AppTypography.heading4),
              ),
            ),
          );
        }

        final season = snapshot.data!;
        final tabs = _isParticipantView
            ? const [
                Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                Tab(text: 'Challenges', icon: Icon(Icons.emoji_events)),
                Tab(text: 'My Progress', icon: Icon(Icons.track_changes)),
              ]
            : const [
                Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                Tab(text: 'Challenges', icon: Icon(Icons.emoji_events)),
                Tab(text: 'Participants', icon: Icon(Icons.people)),
              ];

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(season.title),
            backgroundColor: AppColors.activeColor,
            foregroundColor: Colors.white,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: tabs,
            ),
          ),
          body: _buildSeasonBackground(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(season),
                _buildChallengesTab(season),
                _isParticipantView
                    ? _buildMyProgressTab(season)
                    : _buildParticipantsTab(season),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildManagerActions(Season season, double challengeProgress) {
    final isCompleted = season.status == SeasonStatus.completed;
    final isPaused = (season.settings['paused'] == true);
    final canComplete = !isCompleted; // allow at any progress; confirm if <100%

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _glassBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Manager Actions',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md.toDouble(),
            runSpacing: AppSpacing.sm.toDouble(),
            children: [
              ElevatedButton.icon(
                onPressed: canComplete
                    ? () => _onCompleteSeason(season, challengeProgress)
                    : null,
                icon: const Icon(Icons.flag, size: 18),
                label: const Text('Complete Season'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successColor,
                  foregroundColor: Colors.white,
                ),
              ),
              if (!isCompleted)
                OutlinedButton.icon(
                  onPressed: () => _onExtendSeason(season),
                  icon: const Icon(Icons.event, size: 18),
                  label: const Text('Extend Season'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.activeColor,
                    side: BorderSide(color: AppColors.activeColor),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => _onTogglePause(season, !isPaused),
                icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 18),
                label: Text(isPaused ? 'Resume' : 'Pause'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warningColor,
                  side: BorderSide(color: AppColors.warningColor),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _onViewSeasonCelebration(season),
                icon: const Icon(Icons.celebration, size: 18),
                label: const Text('Celebrate'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warningColor,
                  side: BorderSide(color: AppColors.warningColor),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _onRecomputeMetrics(season),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Recompute'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.infoColor,
                  side: BorderSide(color: AppColors.infoColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            challengeProgress >= 1.0
                ? 'All challenges complete. You can finalize the season.'
                : 'Completing now will remove zero-progress participants and finalize the season.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCompleteSeason(
    Season season,
    double challengeProgress,
  ) async {
    try {
      if (challengeProgress >= 1.0) {
        try {
          await SeasonService.completeSeasonIfEligible(season.id);
        } catch (e) {
          if (!mounted) return;
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('Force Complete Season?'),
                content: const Text(
                  'Some participants may still have zero or partial progress. You can force-complete the season now. Zero-progress participants will be removed. Proceed?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Force Complete'),
                  ),
                ],
              );
            },
          );
          if (confirm == true) {
            await SeasonService.completeSeasonManagerOverride(
              season.id,
              removeZeroProgress: true,
            );
          } else {
            return;
          }
        }
      } else {
        if (!mounted) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Complete Season?'),
              content: const Text(
                'Progress is below 100%. Completing now will remove zero-progress participants and finalize the season. Proceed?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Complete'),
                ),
              ],
            );
          },
        );
        if (confirm != true) return;
        await SeasonService.completeSeasonManagerOverride(
          season.id,
          removeZeroProgress: true,
        );
      }

      if (!mounted) return;
      await _showCenterNotice(context, 'Season completed successfully.');
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(context, 'Cannot complete season: $e');
    }
  }

  Future<void> _onExtendSeason(Season season) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: season.endDate.isAfter(DateTime.now())
          ? season.endDate
          : DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    try {
      await SeasonService.extendSeason(season.id, picked);
      if (!mounted) return;
      await _showCenterNotice(context, 'Season extended.');
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(context, 'Failed to extend season: $e');
    }
  }

  Future<void> _onTogglePause(Season season, bool paused) async {
    try {
      await SeasonService.setSeasonPaused(season.id, paused);
      if (!mounted) return;
      await _showCenterNotice(
        context,
        paused ? 'Season paused.' : 'Season resumed.',
      );
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(context, 'Failed to update pause: $e');
    }
  }

  
  Future<void> _onViewSeasonCelebration(Season season) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SeasonCelebrationScreen(season: season),
      ),
    );
  }

  Future<void> _onRecomputeMetrics(Season season) async {
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await SeasonService.recomputeSeasonMetrics(season.id);
      if (!mounted) return;
      await _showCenterNotice(context, 'Season metrics recomputed');
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(context, 'Failed to recompute metrics: $e');
    } finally {
      navigator.pop();
    }
  }

  Widget _buildOverviewTab(Season season) {
    final now = DateTime.now();
    final daysLeft = season.endDate.difference(now).inDays;
    final hasStarted = now.isAfter(season.startDate);
    final hasEnded = now.isAfter(season.endDate);
    final startsInDays = season.startDate.difference(now).inDays;
    final totalDays = season.endDate.difference(season.startDate).inDays;
    final daysElapsed = now.difference(season.startDate).inDays;
    final seasonProgress = totalDays > 0
        ? (daysElapsed / totalDays).clamp(0.0, 1.0)
        : 0.0;
    // Derive overall challenge progress as average of per-challenge progress
    double challengeProgress = 0.0;
    if (season.challenges.isNotEmpty) {
      double sum = 0.0;
      for (final challenge in season.challenges) {
        final completions =
            season.metrics.challengeCompletions[challenge.type] ?? 0;
        final per = challenge.milestones.isNotEmpty
            ? (completions / challenge.milestones.length).clamp(0.0, 1.0)
            : 0.0;
        sum += per;
      }
      challengeProgress = (sum / season.challenges.length).clamp(0.0, 1.0);
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Season Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: _glassBoxDecoration(
              borderColor: AppColors.activeColor.withValues(alpha: 0.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.activeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getThemeIcon(season.theme),
                        color: AppColors.activeColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            season.title,
                            style: AppTypography.heading2.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            season.theme.toUpperCase(),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.activeColor,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(season).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(season).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        season.status.name.toUpperCase(),
                        style: AppTypography.bodySmall.copyWith(
                          color: _getStatusColor(season),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  season.description,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          if (!_isParticipantView) ...[
            _buildManagerActions(season, challengeProgress),
            const SizedBox(height: AppSpacing.xl),
          ],
          if (_isParticipantView) ...[
            _buildParticipantSummaryCard(season),
            const SizedBox(height: AppSpacing.xl),
          ],

          // Season Timeline
          Text(
            'Season Timeline',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: _glassBoxDecoration(),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Season Progress',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(seasonProgress * 100).toInt()}%',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.activeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: seasonProgress,
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.activeColor,
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Date',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${season.startDate.day}/${season.startDate.month}/${season.startDate.year}',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'End Date',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${season.endDate.day}/${season.endDate.month}/${season.endDate.year}',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // ...
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: !hasStarted
                        ? AppColors.infoColor.withValues(alpha: 0.1)
                        : (!hasEnded
                              ? AppColors.successColor.withValues(alpha: 0.1)
                              : (season.status != SeasonStatus.completed
                                    ? AppColors.warningColor.withValues(
                                        alpha: 0.1,
                                      )
                                    : AppColors.infoColor.withValues(
                                        alpha: 0.1,
                                      ))),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        !hasStarted
                            ? Icons.event
                            : (!hasEnded ? Icons.schedule : Icons.flag),
                        color: !hasStarted
                            ? AppColors.infoColor
                            : (!hasEnded
                                  ? AppColors.successColor
                                  : (season.status != SeasonStatus.completed
                                        ? AppColors.warningColor
                                        : AppColors.infoColor)),
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        !hasStarted
                            ? 'Starts in ${startsInDays.abs()} days'
                            : (!hasEnded
                                  ? '$daysLeft days remaining'
                                  : (season.status != SeasonStatus.completed
                                        ? 'Awaiting manager completion'
                                        : 'Season completed')),
                        style: AppTypography.bodyMedium.copyWith(
                          color: !hasStarted
                              ? AppColors.infoColor
                              : (!hasEnded
                                    ? AppColors.successColor
                                    : (season.status != SeasonStatus.completed
                                          ? AppColors.warningColor
                                          : AppColors.infoColor)),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Key Metrics
          Text(
            'Key Metrics',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Participants',
                  value: '${season.metrics.totalParticipants}',
                  subtitle: '${season.metrics.activeParticipants} active',
                  icon: Icons.people,
                  color: AppColors.infoColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildMetricCard(
                  title: 'Challenges',
                  value: '${season.metrics.completedChallenges}',
                  subtitle: 'of ${season.metrics.totalChallenges}',
                  icon: Icons.emoji_events,
                  color: AppColors.warningColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Points Earned',
                  value: '${season.metrics.totalPointsEarned}',
                  subtitle: 'Total team points',
                  icon: Icons.stars,
                  color: AppColors.successColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildMetricCard(
                  title: 'Progress',
                  value: '${(challengeProgress * 100).toInt()}%',
                  subtitle: 'Challenge completion',
                  icon: Icons.trending_up,
                  color: AppColors.activeColor,
                ),
              ),
            ],
          ),
          if (_linkedCourseChallengeCount(season) > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Linked Courses',
                    value: '${_linkedCourseChallengeCount(season)}',
                    subtitle: 'Course-based challenges',
                    icon: Icons.school,
                    color: AppColors.infoColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Pending Proofs',
                    value: '${_proofSubmissionCount(season, ChallengeSubmissionStatus.submitted)}',
                    subtitle:
                        '${_proofSubmissionCount(season, ChallengeSubmissionStatus.approved)} approved',
                    icon: Icons.fact_check,
                    color: AppColors.warningColor,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          // Challenge Progress
          Text(
            'Challenge Progress',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: _glassBoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall Challenge Progress',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${(challengeProgress * 100).toInt()}%',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.activeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: challengeProgress,
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.activeColor,
                  ),
                  minHeight: 8,
                ),
                const SizedBox(height: AppSpacing.md),
                ...season.challenges.map((challenge) {
                  final challengeCompletions =
                      season.metrics.challengeCompletions[challenge.type] ?? 0;
                  final challengeProgress = challenge.milestones.isNotEmpty
                      ? (challengeCompletions / challenge.milestones.length)
                            .clamp(0.0, 1.0)
                      : 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          _getChallengeTypeIcon(challenge.type),
                          color: _getChallengeTypeColor(challenge.type),
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                challenge.title,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              LinearProgressIndicator(
                                value: challengeProgress,
                                backgroundColor: AppColors.borderColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getChallengeTypeColor(challenge.type),
                                ),
                                minHeight: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${(challengeProgress * 100).toInt()}%',
                          style: AppTypography.bodySmall.copyWith(
                            color: _getChallengeTypeColor(challenge.type),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesTab(Season season) {
    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: season.challenges.length,
      itemBuilder: (context, index) {
        final challenge = season.challenges[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildChallengeCard(season, challenge),
        );
      },
    );
  }

  Widget _buildMyProgressTab(Season season) {
    final participant = _participantForSeason(season);
    if (participant == null) {
      return Center(
        child: Text(
          'Join this season to track your progress.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        _buildParticipantSummaryCard(season),
        const SizedBox(height: AppSpacing.md),
        ...season.challenges.map(
          (challenge) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: _buildChallengeCard(season, challenge),
          ),
        ),
      ],
    );
  }

  Widget _buildParticipantsTab(Season season) {
    final participants = season.participations.values.toList();
    participants.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildParticipantCard(season, participant, index + 1),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _glassBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: AppSpacing.sm),
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
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(Season season, SeasonChallenge challenge) {
    final participant = _participantForSeason(season);
    final completedForParticipant = participant == null
        ? 0
        : challenge.milestones.where((milestone) {
            final keyDot = '${challenge.id}.${milestone.id}';
            final status =
                participant.milestoneProgress[keyDot] ??
                participant.milestoneProgress[milestone.id];
            return status == MilestoneStatus.completed;
          }).length;
    final challengeCompletions =
        season.metrics.challengeCompletions[challenge.type] ?? 0;
    final progress = _isParticipantView
        ? (challenge.milestones.isNotEmpty
              ? (completedForParticipant / challenge.milestones.length).clamp(0.0, 1.0)
              : 0.0)
        : (challenge.milestones.isNotEmpty
              ? (challengeCompletions / challenge.milestones.length).clamp(0.0, 1.0)
              : 0.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _glassBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _getChallengeTypeColor(
                    challenge.type,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getChallengeTypeIcon(challenge.type),
                  color: _getChallengeTypeColor(challenge.type),
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      style: AppTypography.heading4.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      challenge.type.name.toUpperCase(),
                      style: AppTypography.bodySmall.copyWith(
                        color: _getChallengeTypeColor(challenge.type),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warningColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${challenge.points} pts',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            challenge.description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: AppTypography.bodySmall.copyWith(
                      color: _getChallengeTypeColor(challenge.type),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _getChallengeTypeColor(challenge.type),
                ),
                minHeight: 6,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Milestones
          Text(
            'Milestones',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...challenge.milestones.map((milestone) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_unchecked,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      milestone.title,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${milestone.points} pts',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.warningColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (challenge.resources.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Linked Resources',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...challenge.resources.map((resource) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.link, color: AppColors.infoColor, size: 16),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '${resource.title.isNotEmpty ? resource.title : challenge.title} • ${resource.provider}${resource.isFreeResource ? ' • Free' : ''}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openLinkedResource(resource.url),
                      child: const Text('Open'),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (challenge.proofRequired) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Proof Review',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Required proof: ${challenge.proofType ?? 'Completion evidence'}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _isParticipantView
                ? _buildParticipantProofPanel(season, challenge)
                : _buildProofReviewPanel(season, challenge),
          ],
          if (_isParticipantView) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _openChallengeGoal(season, challenge),
                icon: const Icon(Icons.track_changes, size: 16),
                label: const Text('Update Goal'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantProofPanel(Season season, SeasonChallenge challenge) {
    final participant = _participantForSeason(season);
    final submission = participant?.challengeSubmissions[challenge.id];
    final status = submission?.status;
    final label = switch (status) {
      ChallengeSubmissionStatus.submitted => 'Pending manager review',
      ChallengeSubmissionStatus.approved => 'Approved',
      ChallengeSubmissionStatus.rejected => 'Needs updates',
      _ => 'Not submitted yet',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: status == ChallengeSubmissionStatus.approved
                  ? AppColors.successColor
                  : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (submission?.evidence.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              submission!.evidence,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (submission?.feedback?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Manager feedback: ${submission!.feedback}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.warningColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProofReviewPanel(Season season, SeasonChallenge challenge) {
    final submissions = <MapEntry<SeasonParticipation, SeasonChallengeSubmission>>[];
    for (final participation in season.participations.values) {
      final submission = participation.challengeSubmissions[challenge.id];
      if (submission != null) {
        submissions.add(MapEntry(participation, submission));
      }
    }

    if (submissions.isEmpty) {
      return Text(
        'No proof submissions yet.',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textSecondary,
        ),
      );
    }

    return Column(
      children: submissions.map((entry) {
        final participant = entry.key;
        final submission = entry.value;
        final isPending = submission.status == ChallengeSubmissionStatus.submitted;
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      participant.userName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildSubmissionStatusChip(submission.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                submission.evidence,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (submission.feedback?.trim().isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Feedback: ${submission.feedback}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (isPending) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _reviewSubmission(
                        season: season,
                        challenge: challenge,
                        participant: participant,
                        approved: false,
                      ),
                      icon: const Icon(Icons.reply, size: 16),
                      label: const Text('Request Update'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton.icon(
                      onPressed: () => _reviewSubmission(
                        season: season,
                        challenge: challenge,
                        participant: participant,
                        approved: true,
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParticipantCard(
    Season season,
    SeasonParticipation participant,
    int rank,
  ) {
    final completedMilestones = participant.milestoneProgress.values
        .where((status) => status == MilestoneStatus.completed)
        .length;
    final totalMilestones = season.challenges.fold<int>(
      0,
      (runningTotal, challenge) => runningTotal + challenge.milestones.length,
    );
    final progress = totalMilestones > 0
        ? (completedMilestones / totalMilestones)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _glassBoxDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getRankColor(rank).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getRankColor(rank).withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: AppTypography.bodyMedium.copyWith(
                  color: _getRankColor(rank),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.userName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedMilestones/$totalMilestones milestones',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.borderColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getRankColor(rank),
                  ),
                  minHeight: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${participant.totalPoints}',
                style: AppTypography.heading4.copyWith(
                  color: _getRankColor(rank),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'points',
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

  Widget _buildParticipantSummaryCard(Season season) {
    final participant = _participantForSeason(season);
    final totalMilestones = season.challenges.fold<int>(
      0,
      (runningTotal, challenge) => runningTotal + challenge.milestones.length,
    );
    final completedMilestones = participant == null
        ? 0
        : participant.milestoneProgress.values
              .where((status) => status == MilestoneStatus.completed)
              .length;
    final progress = totalMilestones > 0
        ? (completedMilestones / totalMilestones).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _glassBoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Season Progress',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            participant == null
                ? 'You have not joined this season yet.'
                : '${participant.userName} • ${participant.totalPoints} points earned',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.borderColor,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            minHeight: 8,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$completedMilestones/$totalMilestones milestones completed',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonBackground({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/khono_bg.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Color(0x880A0F1F), Color(0x88040610)],
            stops: [0.0, 1.0],
          ),
        ),
        child: child,
      ),
    );
  }

  Color get _glassCardColor => Colors.black.withValues(alpha: 0.45);

  BoxDecoration _glassBoxDecoration({double radius = 12, Color? borderColor}) {
    return BoxDecoration(
      color: _glassCardColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.2),
      ),
    );
  }

  Color _getStatusColor(Season season) {
    switch (season.status) {
      case SeasonStatus.active:
        return AppColors.successColor;
      case SeasonStatus.planning:
        return AppColors.warningColor;
      case SeasonStatus.completed:
        return AppColors.infoColor;
      case SeasonStatus.cancelled:
        return AppColors.dangerColor;
    }
  }

  IconData _getThemeIcon(String theme) {
    switch (theme.toLowerCase()) {
      case 'learning':
        return Icons.school;
      case 'skill':
        return Icons.build;
      case 'collaboration':
        return Icons.group_work;
      case 'innovation':
        return Icons.lightbulb;
      case 'wellness':
        return Icons.favorite;
      default:
        return Icons.emoji_events;
    }
  }

  IconData _getChallengeTypeIcon(ChallengeType type) {
    switch (type) {
      case ChallengeType.learning:
        return Icons.school;
      case ChallengeType.skill:
        return Icons.build;
      case ChallengeType.collaboration:
        return Icons.group_work;
      case ChallengeType.innovation:
        return Icons.lightbulb;
      case ChallengeType.wellness:
        return Icons.favorite;
    }
  }

  Color _getChallengeTypeColor(ChallengeType type) {
    switch (type) {
      case ChallengeType.learning:
        return AppColors.infoColor;
      case ChallengeType.skill:
        return AppColors.warningColor;
      case ChallengeType.collaboration:
        return AppColors.activeColor;
      case ChallengeType.innovation:
        return AppColors.successColor;
      case ChallengeType.wellness:
        return AppColors.dangerColor;
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.warningColor; // Gold
      case 2:
        return AppColors.textSecondary; // Silver
      case 3:
        return AppColors.dangerColor; // Bronze
      default:
        return AppColors.activeColor;
    }
  }

  int _linkedCourseChallengeCount(Season season) {
    return season.challenges.where((challenge) => challenge.resources.isNotEmpty).length;
  }

  int _proofSubmissionCount(
    Season season,
    ChallengeSubmissionStatus status,
  ) {
    var count = 0;
    for (final participation in season.participations.values) {
      for (final submission in participation.challengeSubmissions.values) {
        if (submission.status == status) {
          count++;
        }
      }
    }
    return count;
  }

  Widget _buildSubmissionStatusChip(ChallengeSubmissionStatus status) {
    final (label, color) = switch (status) {
      ChallengeSubmissionStatus.notSubmitted => ('Not submitted', AppColors.textSecondary),
      ChallengeSubmissionStatus.submitted => ('Pending', AppColors.warningColor),
      ChallengeSubmissionStatus.approved => ('Approved', AppColors.successColor),
      ChallengeSubmissionStatus.rejected => ('Needs updates', AppColors.dangerColor),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _openLinkedResource(String url) async {
    final opened = await openAttachmentUrl(url);
    if (!mounted || opened) return;
    await _showCenterNotice(context, 'Unable to open the linked resource.');
  }

  Future<void> _reviewSubmission({
    required Season season,
    required SeasonChallenge challenge,
    required SeasonParticipation participant,
    required bool approved,
  }) async {
    final feedbackController = TextEditingController();
    try {
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(approved ? 'Approve proof' : 'Request update'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  approved
                      ? 'Approve ${participant.userName}\'s submission for "${challenge.title}"?'
                      : 'Add optional feedback for ${participant.userName}.',
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: feedbackController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Feedback',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(approved ? 'Approve' : 'Send back'),
              ),
            ],
          );
        },
      );

      if (shouldProceed != true) return;
      await SeasonService.reviewChallengeProof(
        seasonId: season.id,
        employeeId: participant.userId,
        challengeId: challenge.id,
        approved: approved,
        feedback: feedbackController.text.trim(),
      );
      if (!mounted) return;
      await _showCenterNotice(
        context,
        approved ? 'Proof approved.' : 'Feedback sent to employee.',
      );
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(context, 'Unable to review submission: $e');
    } finally {
      feedbackController.dispose();
    }
  }

  SeasonParticipation? _participantForSeason(Season season) {
    final participantId = widget.participantUserId;
    if (participantId == null || participantId.trim().isEmpty) {
      return null;
    }
    return season.participations[participantId];
  }

  Future<void> _openChallengeGoal(
    Season season,
    SeasonChallenge challenge,
  ) async {
    final participantId = widget.participantUserId;
    if (participantId == null || participantId.trim().isEmpty) return;

    try {
      final participantName = widget.participantUserName ?? 'Employee';
      try {
        await SeasonService.ensureSeasonGoalsForEmployee(
          season: season,
          userId: participantId,
          userName: participantName,
        );
      } catch (_) {
        // Best-effort only; continue with any existing goals.
      }

      final goalDocs = await FirebaseFirestore.instance
          .collection('goals')
          .where('userId', isEqualTo: participantId)
          .get();
      final matchingDocs = goalDocs.docs.where((doc) {
        final data = doc.data();
        return data['isSeasonGoal'] == true &&
            (data['seasonId'] ?? '').toString() == season.id &&
            (data['challengeId'] ?? '').toString() == challenge.id;
      }).toList()
        ..sort((a, b) {
          final aCreated = a.data()['createdAt'];
          final bCreated = b.data()['createdAt'];
          final aDate = aCreated is Timestamp ? aCreated.toDate() : DateTime(1970);
          final bDate = bCreated is Timestamp ? bCreated.toDate() : DateTime(1970);
          return bDate.compareTo(aDate);
        });

      Goal? selectedGoal;
      for (final doc in matchingDocs) {
        final goal = Goal.fromFirestore(doc);
        if (goal.status != GoalStatus.completed) {
          selectedGoal = goal;
          break;
        }
      }
      selectedGoal ??= matchingDocs.isNotEmpty
          ? Goal.fromFirestore(matchingDocs.first)
          : null;
      if (selectedGoal == null) {
        if (!mounted) return;
        await _showCenterNotice(
          context,
          'No linked goal found for "${challenge.title}" yet.',
        );
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GoalDetailScreen(goal: selectedGoal!),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await _showCenterNotice(context, 'Unable to open goal: $e');
    }
  }
}
