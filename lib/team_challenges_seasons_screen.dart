import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/season_service.dart';
import 'package:pdh/season_details_screen.dart';
import 'package:pdh/season_celebration_screen.dart';
import 'package:pdh/services/role_service.dart';

class TeamChallengesSeasonsScreen extends StatefulWidget {
  const TeamChallengesSeasonsScreen({super.key});

  @override
  State<TeamChallengesSeasonsScreen> createState() =>
      _TeamChallengesSeasonsScreenState();
}

class _TeamChallengesSeasonsScreenState
    extends State<TeamChallengesSeasonsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _redirectIfManagerStandalone();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _redirectIfManagerStandalone() async {
    try {
      final role = await RoleService.instance.getRole();
      if (!mounted) return;
      final routeName = ModalRoute.of(context)?.settings.name;
      if (role == 'manager' && routeName != '/manager_portal') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(
            context,
            '/manager_portal',
            arguments: {'initialRoute': '/team_challenges_seasons'},
          );
        });
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Team Challenges & Growth Seasons'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              text: 'Active Seasons',
              icon: ImageIcon(
                AssetImage(
                  'assets/Calendar_Date_Picker/Date_Picker_Red_Badge_White.png',
                ),
              ),
            ),
            Tab(text: 'Create Season', icon: Icon(Icons.add_circle)),
            Tab(
              text: 'Season History',
              icon: ImageIcon(
                AssetImage(
                  'assets/Deadline Notification_Reminder/Notification_Reminder_Red.png',
                ),
                size: 38,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildActiveSeasonsTab(),
          _buildCreateSeasonTab(),
          _buildSeasonHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildActiveSeasonsTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        48,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
              horizontal: AppSpacing.lg,
            ),
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
                    Icon(
                      Icons.emoji_events,
                      color: AppColors.activeColor,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Growth Seasons',
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Create themed challenges that employees can opt into. Each season has milestones, badges, and team progress tracking.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          Text(
            'Active Seasons',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Expanded(
            child: StreamBuilder<List<Season>>(
              stream: SeasonService.getManagerSeasonsStream(),
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
                  return SingleChildScrollView(
                    child: Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.dangerColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Error loading seasons',
                            style: AppTypography.heading4,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              snapshot.error.toString(),
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final seasons = snapshot.data ?? [];
                final activeSeasons = seasons
                    .where((s) => s.status == SeasonStatus.active)
                    .toList();

                if (activeSeasons.isEmpty) {
                  return _buildEmptyActiveSeasonsState();
                }

                return ListView.builder(
                  itemCount: activeSeasons.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _buildSeasonCard(activeSeasons[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateSeasonTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        60,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.lg,
            ),
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
                    Icon(
                      Icons.add_circle,
                      color: AppColors.activeColor,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Create New Season',
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Design a themed growth season with challenges, milestones, and rewards. Employees can opt in and track their progress.',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          _buildCreateSeasonForm(),
        ],
      ),
    );
  }

  Widget _buildSeasonHistoryTab() {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Season History',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Expanded(
            child: StreamBuilder<List<Season>>(
              stream: SeasonService.getManagerSeasonsStream(),
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
                  return SingleChildScrollView(
                    child: Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.dangerColor,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Error loading season history',
                            style: AppTypography.heading4,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              snapshot.error.toString(),
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.dangerColor,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final seasons = snapshot.data ?? [];
                final completedSeasons = seasons
                    .where((s) => s.status == SeasonStatus.completed)
                    .toList();

                if (completedSeasons.isEmpty) {
                  return SingleChildScrollView(
                    child: Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 48,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No Completed Seasons',
                            style: AppTypography.heading4,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              'Completed seasons will appear here',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: completedSeasons.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _buildSeasonHistoryCard(completedSeasons[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyActiveSeasonsState() {
    return SingleChildScrollView(
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 60, color: AppColors.textSecondary),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Active Seasons',
              style: AppTypography.heading3.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: Text(
                'Create your first growth season to engage your team',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.add),
              label: const Text('Create Season'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeasonCard(Season season) {
    final now = DateTime.now();
    final daysLeft = season.endDate.difference(now).inDays;
    final progress = season.metrics.totalChallenges > 0
        ? (season.metrics.completedChallenges / season.metrics.totalChallenges)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.activeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getThemeIcon(season.theme),
                  color: AppColors.activeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      season.title,
                      style: AppTypography.heading4.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      season.theme.toUpperCase(),
                      style: AppTypography.bodySmall.copyWith(
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
                  color: AppColors.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.successColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${daysLeft}d left',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            season.description,
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
                    'Team Progress',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.activeColor,
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
                  AppColors.activeColor,
                ),
                minHeight: 6,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Metrics row
          Row(
            children: [
              _buildMetricChip(
                icon: Icons.people,
                iconWidget: ImageIcon(
                  AssetImage('assets/Team_Meeting/Team Meeting_Red.png'),
                ),
                label: 'Participants',
                value: '${season.metrics.totalParticipants}',
                color: AppColors.infoColor,
              ),
              const SizedBox(width: AppSpacing.md),
              _buildMetricChip(
                icon: Icons.emoji_events,
                label: 'Challenges',
                value:
                    '${season.metrics.completedChallenges}/${season.metrics.totalChallenges}',
                color: AppColors.warningColor,
              ),
              const Spacer(),
              _buildMetricChip(
                icon: Icons.stars,
                iconWidget: ImageIcon(AssetImage('assets/Star.png')),
                label: 'Points',
                value: '${season.metrics.totalPointsEarned}',
                color: AppColors.successColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Employee Progress Section
          if (season.participantIds.isNotEmpty) ...[
            Text(
              'Employee Progress',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: season.participantIds.length,
                itemBuilder: (context, index) {
                  final participantId = season.participantIds[index];
                  final participation = season.participations[participantId];
                  if (participation == null) return const SizedBox.shrink();

                  final participantProgress = _calculateParticipantProgress(
                    participation,
                    season,
                  );

                  final displayName = (participation.userName).trim().isNotEmpty
                      ? participation.userName
                      : 'Employee ${participantId.substring(0, participantId.length >= 6 ? 6 : participantId.length)}';

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.activeColor,
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'E',
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              LinearProgressIndicator(
                                value: participantProgress,
                                backgroundColor: AppColors.borderColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  participantProgress >= 1.0
                                      ? AppColors.successColor
                                      : AppColors.activeColor,
                                ),
                                minHeight: 3,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${(participantProgress * 100).toInt()}%',
                          style: AppTypography.bodySmall.copyWith(
                            color: participantProgress >= 1.0
                                ? AppColors.successColor
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewSeasonDetails(season),
                  icon: const ImageIcon(
                    AssetImage('assets/Concentration_Key_Focus/eye.png'),
                    size: 16,
                  ),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.activeColor,
                    side: BorderSide(color: AppColors.activeColor),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _manageSeason(season),
                  icon: const ImageIcon(
                    AssetImage('assets/gear.png'),
                    size: 24,
                  ),
                  label: const Text('Manage'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.activeColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonHistoryCard(Season season) {
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
                  color: AppColors.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.successColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      season.title,
                      style: AppTypography.heading4.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Completed • ${season.theme.toUpperCase()}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${season.metrics.totalParticipants} participants',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            season.description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              _buildMetricChip(
                icon: Icons.emoji_events,
                label: 'Challenges',
                value:
                    '${season.metrics.completedChallenges}/${season.metrics.totalChallenges}',
                color: AppColors.warningColor,
              ),
              const SizedBox(width: AppSpacing.md),
              _buildMetricChip(
                icon: Icons.stars,
                label: 'Points',
                value: '${season.metrics.totalPointsEarned}',
                color: AppColors.successColor,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _viewSeasonCelebration(season),
                icon: const Icon(Icons.celebration, size: 16),
                label: const Text('Celebration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warningColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    Widget? iconWidget,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget ?? Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              Text(
                value,
                style: AppTypography.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCreateSeasonForm() {
    return CreateSeasonForm(
      onSeasonCreated: () {
        _tabController.animateTo(0);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Season created successfully!'),
            backgroundColor: AppColors.successColor,
          ),
        );
      },
    );
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

  double _calculateParticipantProgress(
    SeasonParticipation participation,
    Season season,
  ) {
    if (season.challenges.isEmpty) return 0.0;

    int totalMilestones = 0;
    int completedMilestones = 0;
    int totalMilestonePoints = 0;

    for (final challenge in season.challenges) {
      totalMilestones += challenge.milestones.length;
      for (final milestone in challenge.milestones) {
        totalMilestonePoints += milestone.points;

        // Support both flat and dotted milestone keys
        final keyDot = '${challenge.id}.${milestone.id}';
        final keyFlat = milestone.id;
        final status =
            participation.milestoneProgress[keyDot] ??
            participation.milestoneProgress[keyFlat];

        if (status == MilestoneStatus.completed) {
          completedMilestones++;
        }
      }
    }

    final progressByStatus = totalMilestones > 0
        ? completedMilestones / totalMilestones
        : 0.0;

    // Fallback: points-based progress if statuses are missing or partial
    final pointsPossible = totalMilestonePoints;
    final progressByPoints = pointsPossible > 0
        ? (participation.totalPoints / pointsPossible).clamp(0.0, 1.0)
        : 0.0;

    // Use the better signal between status and points
    return progressByStatus > 0 ? progressByStatus : progressByPoints;
  }

  void _viewSeasonDetails(Season season) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeasonDetailsScreen(season: season),
      ),
    );
  }

  void _manageSeason(Season season) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeasonManagementScreen(season: season),
      ),
    );
  }

  void _viewSeasonCelebration(Season season) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeasonCelebrationScreen(season: season),
      ),
    );
  }
}

// Create Season Form Widget
class CreateSeasonForm extends StatefulWidget {
  final VoidCallback onSeasonCreated;

  const CreateSeasonForm({super.key, required this.onSeasonCreated});

  @override
  State<CreateSeasonForm> createState() => _CreateSeasonFormState();
}

class _CreateSeasonFormState extends State<CreateSeasonForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _themeController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCreating = false;
  String _selectedTheme = 'Learning';

  final List<String> _themes = [
    'Learning',
    'Skill',
    'Collaboration',
    'Innovation',
    'Wellness',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Season Details',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Season Title',
              hintText: 'e.g., Q2 Learning Sprint',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a season title';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Describe the season and its goals',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),

          DropdownButtonFormField<String>(
            initialValue: _selectedTheme,
            decoration: const InputDecoration(
              labelText: 'Theme',
              border: OutlineInputBorder(),
            ),
            items: _themes.map((theme) {
              return DropdownMenuItem(value: theme, child: Text(theme));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTheme = value!;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectStartDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _startDate != null
                          ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                          : 'Select start date',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: InkWell(
                  onTap: _selectEndDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End Date',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      _endDate != null
                          ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                          : 'Select end date',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCreating ? null : _createSeason,
              icon: _isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_isCreating ? 'Creating...' : 'Create Season'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  Future<void> _createSeason() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select start and end dates'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final challenges = SeasonService.createDefaultChallenges(_selectedTheme);

      await SeasonService.createSeason(
        title: _titleController.text,
        description: _descriptionController.text,
        theme: _selectedTheme,
        startDate: _startDate!,
        endDate: _endDate!,
        challenges: challenges,
      );
      if (!mounted) return;
      widget.onSeasonCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating season: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isCreating = false;
      });
    }
  }
}

// Season Management Screen
class SeasonManagementScreen extends StatelessWidget {
  final Season season;

  const SeasonManagementScreen({super.key, required this.season});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage ${season.title}'),
        backgroundColor: AppColors.activeColor,
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('Season Management Screen - Coming Soon')),
    );
  }
}
