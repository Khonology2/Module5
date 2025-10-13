import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/models/season.dart';

class SeasonDetailsScreen extends StatefulWidget {
  final Season season;

  const SeasonDetailsScreen({super.key, required this.season});

  @override
  State<SeasonDetailsScreen> createState() => _SeasonDetailsScreenState();
}

class _SeasonDetailsScreenState extends State<SeasonDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

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
    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      appBar: AppBar(
        title: Text(widget.season.title),
        backgroundColor: AppColors.activeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Challenges', icon: Icon(Icons.emoji_events)),
            Tab(text: 'Participants', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildChallengesTab(),
          _buildParticipantsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final now = DateTime.now();
    final daysLeft = widget.season.endDate.difference(now).inDays;
    final totalDays = widget.season.endDate
        .difference(widget.season.startDate)
        .inDays;
    final daysElapsed = now.difference(widget.season.startDate).inDays;
    final seasonProgress = totalDays > 0
        ? (daysElapsed / totalDays).clamp(0.0, 1.0)
        : 0.0;
    final challengeProgress = widget.season.metrics.totalChallenges > 0
        ? (widget.season.metrics.completedChallenges /
              widget.season.metrics.totalChallenges)
        : 0.0;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Season Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.activeColor.withValues(alpha: 0.1),
                  AppColors.successColor.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.activeColor.withValues(alpha: 0.3),
              ),
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
                        _getThemeIcon(widget.season.theme),
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
                            widget.season.title,
                            style: AppTypography.heading2.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.season.theme.toUpperCase(),
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
                        color: _getStatusColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor().withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        widget.season.status.name.toUpperCase(),
                        style: AppTypography.bodySmall.copyWith(
                          color: _getStatusColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.season.description,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

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
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
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
                          '${widget.season.startDate.day}/${widget.season.startDate.month}/${widget.season.startDate.year}',
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
                          '${widget.season.endDate.day}/${widget.season.endDate.month}/${widget.season.endDate.year}',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: daysLeft > 0
                        ? AppColors.successColor.withValues(alpha: 0.1)
                        : AppColors.dangerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        daysLeft > 0 ? Icons.schedule : Icons.schedule_outlined,
                        color: daysLeft > 0
                            ? AppColors.successColor
                            : AppColors.dangerColor,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        daysLeft > 0
                            ? '$daysLeft days remaining'
                            : 'Season ended',
                        style: AppTypography.bodyMedium.copyWith(
                          color: daysLeft > 0
                              ? AppColors.successColor
                              : AppColors.dangerColor,
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
                  value: '${widget.season.metrics.totalParticipants}',
                  subtitle:
                      '${widget.season.metrics.activeParticipants} active',
                  icon: Icons.people,
                  color: AppColors.infoColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildMetricCard(
                  title: 'Challenges',
                  value: '${widget.season.metrics.completedChallenges}',
                  subtitle: 'of ${widget.season.metrics.totalChallenges}',
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
                  value: '${widget.season.metrics.totalPointsEarned}',
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
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor),
            ),
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
                ...widget.season.challenges.map((challenge) {
                  final challengeCompletions =
                      widget.season.metrics.challengeCompletions[challenge
                          .type] ??
                      0;
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

  Widget _buildChallengesTab() {
    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: widget.season.challenges.length,
      itemBuilder: (context, index) {
        final challenge = widget.season.challenges[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildChallengeCard(challenge),
        );
      },
    );
  }

  Widget _buildParticipantsTab() {
    final participants = widget.season.participations.values.toList();
    participants.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

    return ListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildParticipantCard(participant, index + 1),
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

  Widget _buildChallengeCard(SeasonChallenge challenge) {
    final challengeCompletions =
        widget.season.metrics.challengeCompletions[challenge.type] ?? 0;
    final progress = challenge.milestones.isNotEmpty
        ? (challengeCompletions / challenge.milestones.length).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
        ],
      ),
    );
  }

  Widget _buildParticipantCard(SeasonParticipation participant, int rank) {
    final completedMilestones = participant.milestoneProgress.values
        .where((status) => status == MilestoneStatus.completed)
        .length;
    final totalMilestones = widget.season.challenges.fold<int>(
      0,
      (sum, challenge) => sum + challenge.milestones.length,
    );
    final progress = totalMilestones > 0
        ? (completedMilestones / totalMilestones)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
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

  Color _getStatusColor() {
    switch (widget.season.status) {
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
}
