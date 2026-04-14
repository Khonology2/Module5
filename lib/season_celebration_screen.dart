import 'package:flutter/material.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/services/season_service.dart';

class SeasonCelebrationScreen extends StatefulWidget {
  final Season season;

  const SeasonCelebrationScreen({super.key, required this.season});

  @override
  State<SeasonCelebrationScreen> createState() =>
      _SeasonCelebrationScreenState();
}

class _SeasonCelebrationScreenState extends State<SeasonCelebrationScreen>
    with TickerProviderStateMixin {
  late AnimationController _celebrationController;
  late AnimationController _slideController;
  late Animation<double> _celebrationAnimation;
  late Animation<Offset> _slideAnimation;

  Map<String, dynamic>? celebrationData;
  bool _isLoadingCelebration = true;
  String? _celebrationError;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    _loadCelebrationData();
    _startAnimations();
  }

  @override
  void dispose() {
    _celebrationController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadCelebrationData() async {
    try {
      final data =
          await SeasonService.getOrCreateSeasonCelebrationDoc(widget.season.id);
      if (!mounted) return;
      setState(() {
        celebrationData = data;
        _isLoadingCelebration = false;
        _celebrationError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _celebrationError = e.toString();
        _isLoadingCelebration = false;
      });
    }
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 500), () {
      _celebrationController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _slideController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingCelebration) {
      return const Scaffold(
        backgroundColor: AppColors.cardBackground,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
          ),
        ),
      );
    }

    if (_celebrationError != null || celebrationData == null) {
      return Scaffold(
        backgroundColor: AppColors.cardBackground,
        body: Center(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: AppColors.dangerColor, size: 48),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Unable to load celebration',
                  style: AppTypography.heading4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_celebrationError != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _celebrationError!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.warningColor.withValues(alpha: 0.1),
              AppColors.successColor.withValues(alpha: 0.1),
              AppColors.activeColor.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: AppSpacing.screenPadding,
            child: Column(
              children: [
                _buildCelebrationHeader(),
                const SizedBox(height: AppSpacing.xl),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildSeasonSummary(),
                ),
                const SizedBox(height: AppSpacing.xl),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildAchievementsSection(),
                ),
                const SizedBox(height: AppSpacing.xl),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildTopPerformersSection(),
                ),
                const SizedBox(height: AppSpacing.xl),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildChallengeBreakdown(),
                ),
                const SizedBox(height: AppSpacing.xl),
                SlideTransition(
                  position: _slideAnimation,
                  child: _buildCelebrationActions(),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? get _summary =>
      celebrationData?['summary'] as Map<String, dynamic>?;

  int _summaryInt(String key, int fallback) {
    final value = _summary?[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  String get _seasonTitle =>
      celebrationData?['title'] as String? ?? widget.season.title;

  String get _seasonTheme =>
      celebrationData?['theme'] as String? ?? widget.season.theme;

  List<Map<String, dynamic>> get _topPerformersData {
    final list = celebrationData?['topPerformers'] as List<dynamic>? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> get _challengeBreakdownData {
    final map =
        celebrationData?['challengeBreakdown'] as Map<String, dynamic>? ?? {};
    return Map<String, dynamic>.from(map);
  }

  int get _badgesAwardedFallback {
    return widget.season.participations.values
        .map((p) => p.badgesEarned.length)
        .fold(0, (sum, count) => sum + count);
  }

  Widget _buildCelebrationHeader() {
    return Column(
      children: [
        ScaleTransition(
          scale: _celebrationAnimation,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.warningColor, AppColors.successColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.warningColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 60,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ScaleTransition(
          scale: _celebrationAnimation,
          child: Text(
            '🎉 Season Complete! 🎉',
            style: AppTypography.heading1.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ScaleTransition(
          scale: _celebrationAnimation,
          child: Text(
            _seasonTitle,
            style: AppTypography.heading2.copyWith(
              color: AppColors.activeColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ScaleTransition(
          scale: _celebrationAnimation,
          child: Text(
            '${_seasonTheme.toUpperCase()} SEASON',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonSummary() {
    final totalParticipants = _summaryInt(
      'totalParticipants',
      widget.season.metrics.totalParticipants,
    );
    final completedChallenges = _summaryInt(
      'completedChallenges',
      widget.season.metrics.completedChallenges,
    );
    final totalChallenges = _summaryInt(
      'totalChallenges',
      widget.season.metrics.totalChallenges,
    );
    final totalPoints = _summaryInt(
      'totalPointsEarned',
      widget.season.metrics.totalPointsEarned,
    );
    final badgesAwarded =
        _summaryInt('badgesAwarded', _badgesAwardedFallback);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppColors.warningColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, color: AppColors.activeColor, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Season Summary',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Participants',
                  value: '$totalParticipants',
                  icon: Icons.people,
                  color: AppColors.infoColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Challenges',
                  value: '$completedChallenges',
                  subtitle: 'of $totalChallenges',
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
                child: _buildSummaryCard(
                  title: 'Points Earned',
                  value: '$totalPoints',
                  icon: Icons.stars,
                  color: AppColors.successColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Badges Awarded',
                  value: '$badgesAwarded',
                  icon: Icons.military_tech,
                  color: AppColors.dangerColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final totalParticipants = _summaryInt(
      'totalParticipants',
      widget.season.metrics.totalParticipants,
    );
    final totalPoints = _summaryInt(
      'totalPointsEarned',
      widget.season.metrics.totalPointsEarned,
    );
    final completedChallenges = _summaryInt(
      'completedChallenges',
      widget.season.metrics.completedChallenges,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: AppColors.warningColor, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Team Achievements',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildAchievementItem(
            icon: '🏆',
            title: 'Season Champions',
            description:
                '$totalParticipants team members participated',
            color: AppColors.warningColor,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildAchievementItem(
            icon: '⭐',
            title: 'Point Masters',
            description:
                '$totalPoints total points earned',
            color: AppColors.successColor,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildAchievementItem(
            icon: '🎯',
            title: 'Challenge Conquerors',
            description:
                '$completedChallenges challenges completed',
            color: AppColors.activeColor,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildAchievementItem(
            icon: '🏅',
            title: 'Badge Collectors',
            description: '${_summaryInt('badgesAwarded', _badgesAwardedFallback)} badges awarded',
            color: AppColors.dangerColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformersSection() {
    final topPerformers = _topPerformersData;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.leaderboard, color: AppColors.activeColor, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Top Performers',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (topPerformers.isEmpty)
            Center(
              child: Text(
                'No participants yet',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...topPerformers.asMap().entries.map((entry) {
              final index = entry.key;
              final performer = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildPerformerCard(performer, index + 1),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildChallengeBreakdown() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppColors.infoColor, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Challenge Breakdown',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...widget.season.challenges.map((challenge) {
            final docValue = _challengeBreakdownData[challenge.type.name];
            final completions = docValue is num
                ? docValue.toInt()
                : widget
                        .season.metrics.challengeCompletions[challenge.type] ??
                    0;
            final progress = challenge.milestones.isNotEmpty
                ? (completions / challenge.milestones.length).clamp(0.0, 1.0)
                : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _buildChallengeProgressCard(challenge, progress),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCelebrationActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _shareCelebration,
            icon: const Icon(Icons.share, size: 20),
            label: const Text('Share Celebration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _createNewSeason,
            icon: const Icon(Icons.add_circle, size: 20),
            label: const Text('Create New Season'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.activeColor,
              side: BorderSide(color: AppColors.activeColor),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievementItem({
    required String icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
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
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
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

  Widget _buildPerformerCard(Map<String, dynamic> performer, int rank) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _getRankColor(rank).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getRankColor(rank).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getRankColor(rank).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
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
                  performer['userName'] ?? 'Unknown',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${performer['badgesEarned'] ?? 0} badges earned',
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
              Text(
                '${performer['totalPoints'] ?? 0}',
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

  Widget _buildChallengeProgressCard(
    SeasonChallenge challenge,
    double progress,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _getChallengeTypeColor(challenge.type).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getChallengeTypeColor(challenge.type).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getChallengeTypeIcon(challenge.type),
                color: _getChallengeTypeColor(challenge.type),
                size: 24,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  challenge.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: AppTypography.bodyMedium.copyWith(
                  color: _getChallengeTypeColor(challenge.type),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
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
    );
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

  void _shareCelebration() {
    // Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Celebration shared!'),
        backgroundColor: AppColors.successColor,
      ),
    );
  }

  void _createNewSeason() {
    Navigator.pop(context);
    // Navigate to create season screen
  }
}
