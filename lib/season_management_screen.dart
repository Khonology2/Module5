import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/services/season_service.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/auth_service.dart';

class SeasonManagementScreen extends StatefulWidget {
  final Season? season;
  final String? seasonId;

  const SeasonManagementScreen({super.key, this.season, this.seasonId});

  @override
  State<SeasonManagementScreen> createState() => _SeasonManagementScreenState();
}

class _SeasonManagementScreenState extends State<SeasonManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  String? _currentUserId;
  bool _isLoading = false;
  Season? _season;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
    _loadSeason();
  }

  Future<void> _loadSeason() async {
    if (widget.season != null) {
      setState(() {
        _season = widget.season;
      });
    } else if (widget.seasonId != null) {
      final season = await SeasonService.getSeason(widget.seasonId!);
      if (season != null) {
        setState(() {
          _season = season;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = _authService.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_season == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Season Management'),
          backgroundColor: AppColors.activeColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _buildSeasonBackground(
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Manage ${_season!.title}'),
        backgroundColor: AppColors.activeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Participants'),
            Tab(text: 'Actions'),
          ],
        ),
      ),
      body: _buildSeasonBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildParticipantsTab(),
            _buildActionsTab(),
          ],
        ),
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
            colors: [
              Color(0x880A0F1F),
              Color(0x88040610),
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Season Status Card
          Card(
            color: _glassCardColor,
            elevation: 0,
            shape: _glassCardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            _season!.status,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _season!.status.name.toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            color: _getStatusColor(_season!.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_season!.endDate.difference(DateTime.now()).inDays} days left',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _season!.title,
                    style: AppTypography.heading3.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _season!.description,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Participants',
                  value: '${_season!.metrics.totalParticipants}',
                  icon: Icons.people,
                  color: AppColors.infoColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildMetricCard(
                  title: 'Challenges',
                  value:
                      '${_season!.metrics.completedChallenges}/${_season!.metrics.totalChallenges}',
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
                  value: '${_season!.metrics.totalPointsEarned}',
                  icon: Icons.stars,
                  color: AppColors.successColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildMetricCard(
                  title: 'Avg Progress',
                  value: '${_season!.metrics.averageProgress.toInt()}%',
                  icon: Icons.trending_up,
                  color: AppColors.activeColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsTab() {
    return StreamBuilder<Season>(
      stream: SeasonService.getSeasonStream(_season!.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Text(
              'Error loading participants',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final season = snapshot.data!;
        final participants = season.participantIds;

        if (participants.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 60,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No Participants Yet',
                  style: AppTypography.heading3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Employees will appear here when they join the season',
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final participantId = participants[index];
            final participation = season.participations[participantId];
            if (participation == null) return const SizedBox.shrink();

            final progress = _calculateParticipantProgress(
              participation,
              season,
            );
            final isCompleted = progress >= 1.0;

            return Card(
              color: _glassCardColor,
              elevation: 0,
              shape: _glassCardShape(),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isCompleted
                              ? AppColors.successColor
                              : AppColors.activeColor,
                          child: Text(
                            participation.userName.isNotEmpty
                                ? participation.userName[0].toUpperCase()
                                : 'E',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                participation.userName,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Joined ${_formatDate(participation.joinedAt)}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'COMPLETED',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.successColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progress',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: AppColors.borderColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCompleted
                                      ? AppColors.successColor
                                      : AppColors.activeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: AppTypography.bodyLarge.copyWith(
                            color: isCompleted
                                ? AppColors.successColor
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        _buildParticipantMetric(
                          icon: Icons.stars,
                          label: 'Points',
                          value: '${participation.totalPoints}',
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        _buildParticipantMetric(
                          icon: Icons.emoji_events,
                          label: 'Badges',
                          value: '${participation.badgesEarned.length}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Season Actions',
            style: AppTypography.heading3.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Complete Season Action
          Card(
            color: _glassCardColor,
            elevation: 0,
            shape: _glassCardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag, color: AppColors.successColor, size: 24),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Complete Season',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Mark this season as completed. This will award final badges to all participants and create a celebration summary.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _completeSeason,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.flag),
                      label: Text(
                        _isLoading ? 'Completing...' : 'Complete Season',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Extend Season Action
          Card(
            color: _glassCardColor,
            elevation: 0,
            shape: _glassCardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        color: AppColors.warningColor,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Extend Season',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Extend the season end date to give participants more time to complete their challenges.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _extendSeason,
                      icon: const Icon(Icons.schedule),
                      label: const Text('Extend Season'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warningColor,
                        side: const BorderSide(color: AppColors.warningColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // View Celebration Action
          if (_season!.status == SeasonStatus.completed)
            Card(
              color: _glassCardColor,
              elevation: 0,
              shape: _glassCardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.celebration,
                          color: AppColors.warningColor,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'View Celebration',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'View the season celebration summary with achievements, top performers, and team statistics.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _viewCelebration,
                        icon: const Icon(Icons.celebration),
                        label: const Text('View Celebration'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warningColor,
                          side: const BorderSide(color: AppColors.warningColor),
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

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final cardColor = _glassCardColor;
    return Card(
      color: cardColor,
      elevation: 0,
      shape: _glassCardShape(radius: 14),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: AppTypography.heading4.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _glassCardColor => Colors.black.withValues(alpha: 0.45);

  ShapeBorder _glassCardShape({double radius = 16}) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: Colors.white.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _buildParticipantMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$label: $value',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  double _calculateParticipantProgress(
    SeasonParticipation participation,
    Season season,
  ) {
    if (season.challenges.isEmpty) return 0.0;

    int totalMilestones = 0;
    int completedMilestones = 0;

    for (final challenge in season.challenges) {
      totalMilestones += challenge.milestones.length;
      for (final milestone in challenge.milestones) {
        final milestoneStatus =
            participation.milestoneProgress['${challenge.id}.${milestone.id}'];
        if (milestoneStatus == MilestoneStatus.completed) {
          completedMilestones++;
        }
      }
    }

    return totalMilestones > 0 ? completedMilestones / totalMilestones : 0.0;
  }

  Color _getStatusColor(SeasonStatus status) {
    switch (status) {
      case SeasonStatus.active:
        return AppColors.successColor;
      case SeasonStatus.completed:
        return AppColors.warningColor;
      case SeasonStatus.planning:
        return AppColors.dangerColor;
      case SeasonStatus.cancelled:
        return AppColors.dangerColor;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _completeSeason() async {
    if (_currentUserId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await SeasonService.updateSeasonStatus(
        _season!.id,
        SeasonStatus.completed,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Season "${_season!.title}" completed successfully!'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing season: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _extendSeason() {
   
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Season extension feature coming soon!'),
        backgroundColor: AppColors.warningColor,
      ),
    );
  }

  void _viewCelebration() {
    Navigator.pushNamed(
      context,
      '/season_celebration',
      arguments: {'seasonId': _season!.id},
    );
  }
}
