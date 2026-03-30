import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/design_system/app_typography.dart';
import 'package:pdh/design_system/app_spacing.dart';
import 'package:pdh/design_system/app_components.dart';
import 'package:pdh/design_system/sidebar_config.dart';
import 'package:pdh/services/season_service.dart';
import 'package:pdh/models/season.dart';
import 'package:pdh/auth_service.dart';
import 'package:pdh/widgets/app_scaffold.dart';
import 'package:pdh/goal_detail_screen.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/widgets/season_milestone_progress_card.dart';
import 'package:pdh/season_celebration_screen.dart';
import 'package:pdh/widgets/employee_dashboard_theme.dart';

class _SeasonChrome {
  _SeasonChrome._();

  static bool get light => employeeDashboardLightModeNotifier.value;
  static const Color _darkCard = Color(0xFF3D3F40);

  static Color get cardFill => light ? const Color(0xFFFFFFFF) : _darkCard;
  static Color get border =>
      light ? const Color(0x33000000) : Colors.white.withValues(alpha: 0.2);
  static Color get fg => light ? const Color(0xFF000000) : Colors.white;
  static List<Color>? get lightGradient => light
      ? [
          Colors.white.withValues(alpha: 0.2),
          Colors.white.withValues(alpha: 0.08),
        ]
      : null;
}

class EmployeeSeasonChallengesScreen extends StatefulWidget {
  const EmployeeSeasonChallengesScreen({
    super.key,
    this.forManagerGwMenu = false,
    this.managerGwMenuRoute,
    this.embedded = false,
    this.forAdminOversight = false,
    this.selectedManagerId,
  });

  /// When true, use manager sidebar and [managerGwMenuRoute] (for manager Goal Workspace menu).
  final bool forManagerGwMenu;
  final String? managerGwMenuRoute;
  /// When true, only build content (no AppScaffold/sidebar); for use inside ManagerPortalScreen.
  final bool embedded;
  final bool forAdminOversight;
  final String? selectedManagerId;

  @override
  State<EmployeeSeasonChallengesScreen> createState() =>
      _EmployeeSeasonChallengesScreenState();
}

class _EmployeeSeasonChallengesScreenState
    extends State<EmployeeSeasonChallengesScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserDepartment;
  Set<String> _adminUserIds = <String>{};
  bool _adminUsersLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentUser();
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
        _currentUserName = user.displayName ?? 'Employee';
      });

      // Get user department
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _currentUserDepartment = userDoc.data()?['department'];
        });
      }

      // Sync season challenge points into the employee profile.
      await SeasonService.syncCurrentEmployeeSeasonPoints();

      await _loadAdminUserIds();
    }
  }

  Future<void> _loadAdminUserIds() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      if (!mounted) return;
      setState(() {
        _adminUserIds = snap.docs.map((d) => d.id).toSet();
        _adminUsersLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adminUserIds = <String>{};
        _adminUsersLoaded = true;
      });
    }
  }

  List<Season> _filterSeasonsForContext(List<Season> seasons) {
    if (!_adminUsersLoaded) return seasons;
    if (widget.forManagerGwMenu) {
      // Manager workspace season challenges should show admin-authored seasons only.
      return seasons
          .where((season) => _adminUserIds.contains(season.createdBy))
          .toList();
    }
    // Employee context should never show admin-authored seasons.
    return seasons
        .where((season) => !_adminUserIds.contains(season.createdBy))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final sidebarItems = widget.forManagerGwMenu && widget.managerGwMenuRoute != null
        ? SidebarConfig.managerItems
        : SidebarConfig.employeeItems;
    final routeName = widget.forManagerGwMenu && widget.managerGwMenuRoute != null
        ? widget.managerGwMenuRoute!
        : '/season_challenges';
    return ValueListenableBuilder<bool>(
      valueListenable: employeeDashboardLightModeNotifier,
      builder: (context, light, _) {
        return EmployeeDashboardThemeScope(
          light: light,
          child: AppScaffold(
            title: 'Season Challenges',
            showAppBar: false,
            embedded: widget.embedded,
            items: sidebarItems,
            currentRouteName: routeName,
            onNavigate: (route) {
              final current = ModalRoute.of(context)?.settings.name;
              if (current != route) {
                Navigator.pushNamed(context, route);
              }
            },
            onLogout: () async {
              final navigator = Navigator.of(context);
              await _authService.signOut();
              if (!mounted) return;
              navigator.pushNamedAndRemoveUntil('/sign_in', (route) => false);
            },
            content: AppComponents.backgroundWithImage(
              blurSigma: 0,
              imagePath: light
                  ? 'assets/light_mode_bg.png'
                  : 'assets/khono_bg.png',
              gradientColors: _SeasonChrome.lightGradient,
              child: Column(
                children: [
                  Container(
                    color: light
                        ? const Color(0xFFFFFFFF)
                        : AppColors.activeColor,
                    padding: const EdgeInsets.only(
                      top: AppSpacing.lg,
                      left: AppSpacing.lg,
                      right: AppSpacing.lg,
                      bottom: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Season Challenges',
                              style: AppTypography.heading2.copyWith(
                                color: _SeasonChrome.fg,
                              ),
                            ),
                          ],
                        ),
                        TabBar(
                          controller: _tabController,
                          indicatorColor: light
                              ? AppColors.activeColor
                              : Colors.white,
                          labelColor: _SeasonChrome.fg,
                          unselectedLabelColor: _SeasonChrome.fg,
                          tabs: const [
                            Tab(text: 'Available'),
                            Tab(text: 'My Seasons'),
                            Tab(text: 'Completed'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SafeArea(
                      top: false,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAvailableSeasonsTab(),
                          _buildMySeasonsTab(),
                          _buildCompletedSeasonsTab(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvailableSeasonsTab() {
    return StreamBuilder<List<Season>>(
      stream: SeasonService.getActiveSeasonsStream(
        department: _currentUserDepartment,
        includeAdminCreated: widget.forManagerGwMenu,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading seasons: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyAvailableSeasonsState();
        }

        final seasons = _filterSeasonsForContext(snapshot.data!);
        final availableSeasons = seasons.where((season) {
          return !season.participantIds.contains(_currentUserId);
        }).toList();

        if (availableSeasons.isEmpty) {
          return _buildEmptyAvailableSeasonsState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: availableSeasons.length,
          itemBuilder: (context, index) {
            return _buildAvailableSeasonCard(availableSeasons[index]);
          },
        );
      },
    );
  }

  Widget _buildMySeasonsTab() {
    return StreamBuilder<List<Season>>(
      stream: SeasonService.getActiveSeasonsStream(
        department: _currentUserDepartment,
        includeAdminCreated: widget.forManagerGwMenu,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading seasons: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyMySeasonsState();
        }

        final seasons = _filterSeasonsForContext(snapshot.data!);
        final mySeasons = seasons.where((season) {
          return season.participantIds.contains(_currentUserId);
        }).toList();

        if (mySeasons.isEmpty) {
          return _buildEmptyMySeasonsState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: mySeasons.length,
          itemBuilder: (context, index) {
            return _buildMySeasonCard(mySeasons[index]);
          },
        );
      },
    );
  }

  Widget _buildCompletedSeasonsTab() {
    final uid = _currentUserId;
    if (uid == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<Season>>(
      stream: SeasonService.getParticipantSeasonsStream(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState('Error loading seasons: ${snapshot.error}');
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyCompletedSeasonsState();
        }

        final seasons = _filterSeasonsForContext(snapshot.data!);
        final completedSeasons = seasons.where((season) {
          return season.status == SeasonStatus.completed;
        }).toList();

        if (completedSeasons.isEmpty) {
          return _buildEmptyCompletedSeasonsState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: completedSeasons.length,
          itemBuilder: (context, index) {
            return _buildCompletedSeasonCard(completedSeasons[index]);
          },
        );
      },
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry? margin,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _SeasonChrome.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _SeasonChrome.border),
      ),
      child: child,
    );
  }

  Widget _buildAvailableSeasonCard(Season season) {
    final daysLeft = season.endDate.difference(DateTime.now()).inDays;
    // final progress = _calculateSeasonProgress(season);

    return _glassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                  color: AppColors.activeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  season.theme.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.activeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.schedule, size: 16, color: _SeasonChrome.fg),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$daysLeft days left',
                style: AppTypography.caption.copyWith(
                  color: _SeasonChrome.fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            season.title,
            style: AppTypography.heading3.copyWith(
              color: _SeasonChrome.fg,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            season.description,
            style: AppTypography.bodyMedium.copyWith(
              color: _SeasonChrome.fg,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.people, size: 16, color: _SeasonChrome.fg),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${season.metrics.totalParticipants} participants',
                style: AppTypography.caption.copyWith(
                  color: _SeasonChrome.fg,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Icon(Icons.star, size: 16, color: AppColors.warningColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${season.challenges.length} challenges',
                style: AppTypography.caption.copyWith(
                  color: _SeasonChrome.fg,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _joinSeason(season),
              icon: const Icon(Icons.add),
              label: const Text('Join Season'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMySeasonCard(Season season) {
    final participation = season.participations[_currentUserId];
    final progress = participation?.totalPoints ?? 0;
    final totalPossiblePoints = season.challenges.fold<int>(
      0,
      (acc, challenge) => acc + challenge.points,
    );
    final progressPercentage = totalPossiblePoints > 0
        ? (progress / totalPossiblePoints * 100).round()
        : 0;

    return _glassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                  color: AppColors.activeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  season.theme.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.activeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$progress/$totalPossiblePoints pts',
                style: AppTypography.caption.copyWith(
                  color: _SeasonChrome.fg,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            season.title,
            style: AppTypography.heading3.copyWith(
              color: _SeasonChrome.fg,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: progressPercentage / 100,
            backgroundColor: _SeasonChrome.light
                ? const Color(0xFFE0E0E0)
                : Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$progressPercentage% Complete',
            style: AppTypography.caption.copyWith(
              color: _SeasonChrome.fg,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewSeasonDetails(season),
                  icon: const Icon(Icons.visibility),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.activeColor,
                    side: const BorderSide(color: AppColors.activeColor),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _completeSeasonGoals(season),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Complete Goals'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (season.challenges.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Challenges & Milestones',
              style: AppTypography.bodySmall.copyWith(
                color: _SeasonChrome.fg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...season.challenges.map(
              (challenge) => _buildChallengeMilestoneTile(
                season,
                challenge,
                participation,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChallengeMilestoneTile(
    Season season,
    SeasonChallenge challenge,
    SeasonParticipation? participation,
  ) {
    final totalMilestones = challenge.milestones.length;
    final completedMilestones = _completedMilestonesForChallenge(
      challenge,
      participation,
    );
    final progress = totalMilestones > 0
        ? completedMilestones / totalMilestones
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: _SeasonChrome.cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _SeasonChrome.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_circle, color: AppColors.activeColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  challenge.title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: _SeasonChrome.fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: AppTypography.caption.copyWith(
                  color: AppColors.activeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (challenge.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              challenge.description,
              style: AppTypography.bodySmall.copyWith(
                color: _SeasonChrome.fg,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: _SeasonChrome.light
                ? const Color(0xFFE0E0E0)
                : Colors.white.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.activeColor),
            minHeight: 4,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completedMilestones/$totalMilestones milestones',
                style: AppTypography.caption.copyWith(
                  color: _SeasonChrome.fg,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _currentUserId == null
                    ? null
                    : () => _openMilestoneSheet(season, challenge),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Update'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.activeColor,
                  side: BorderSide(color: AppColors.activeColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _completedMilestonesForChallenge(
    SeasonChallenge challenge,
    SeasonParticipation? participation,
  ) {
    if (participation == null) return 0;
    final statuses = participation.milestoneProgress;
    int completed = 0;
    for (final milestone in challenge.milestones) {
      final keyDot = '${challenge.id}.${milestone.id}';
      final status = statuses[keyDot] ?? statuses[milestone.id];
      if (status == MilestoneStatus.completed) {
        completed++;
      }
    }
    return completed;
  }

  void _openMilestoneSheet(Season season, SeasonChallenge challenge) {
    if (_currentUserId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SeasonMilestoneProgressCard(
              season: season,
              challenge: challenge,
              userId: _currentUserId!,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedSeasonCard(Season season) {
    final participation = season.participations[_currentUserId];
    final progress = participation?.totalPoints ?? 0;
    final badges = participation?.badgesEarned ?? [];

    return _glassCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                  color: AppColors.successColor.withValues(alpha: 0.1),
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
              const Spacer(),
              Text(
                '$progress points earned',
                style: AppTypography.caption.copyWith(
                  color: _SeasonChrome.fg,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            season.title,
            style: AppTypography.heading3.copyWith(
              color: _SeasonChrome.fg,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (badges.isNotEmpty) ...[
            Text(
              'Badges Earned:',
              style: AppTypography.bodySmall.copyWith(
                color: _SeasonChrome.fg,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: badges.take(3).map((badgeId) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeId,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warningColor,
                      fontSize: 10,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (badges.length > 3)
              Text(
                ' +${badges.length - 3} more',
                style: AppTypography.caption.copyWith(
                  color: _SeasonChrome.fg,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _viewSeasonCelebration(season),
              icon: const Icon(Icons.celebration),
              label: const Text('View Celebration'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.successColor,
                side: const BorderSide(color: AppColors.successColor),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return SingleChildScrollView(
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: AppColors.dangerColor),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Error',
              style: AppTypography.heading3.copyWith(
                color: _SeasonChrome.fg,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: Text(
                message,
                style: AppTypography.bodyLarge.copyWith(
                  color: _SeasonChrome.fg,
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

  Widget _buildEmptyAvailableSeasonsState() {
    return SingleChildScrollView(
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 60,
              color: _SeasonChrome.fg,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Available Seasons',
              style: AppTypography.heading3.copyWith(
                color: _SeasonChrome.fg,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: Text(
                'Check back later for new growth seasons from your manager',
                style: AppTypography.bodyLarge.copyWith(
                  color: _SeasonChrome.fg,
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

  Widget _buildEmptyMySeasonsState() {
    return SingleChildScrollView(
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 60, color: _SeasonChrome.fg),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Active Seasons',
              style: AppTypography.heading3.copyWith(
                color: _SeasonChrome.fg,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: Text(
                'Join available seasons to start earning points and badges',
                style: AppTypography.bodyLarge.copyWith(
                  color: _SeasonChrome.fg,
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

  Widget _buildEmptyCompletedSeasonsState() {
    return SingleChildScrollView(
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration, size: 60, color: _SeasonChrome.fg),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No Completed Seasons',
              style: AppTypography.heading3.copyWith(
                color: _SeasonChrome.fg,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: Text(
                'Complete season challenges to see your achievements here',
                style: AppTypography.bodyLarge.copyWith(
                  color: _SeasonChrome.fg,
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

  Future<void> _joinSeason(Season season) async {
    if (_currentUserId == null || _currentUserName == null) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await SeasonService.joinSeason(
        seasonId: season.id,
        userId: _currentUserId!,
        userName: _currentUserName!,
      );

      // Close loading
      if (mounted) Navigator.of(context).pop();

      // Ensure widget is still mounted before using context after async gap
      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully joined "${season.title}"!'),
          backgroundColor: AppColors.successColor,
        ),
      );

      // Switch to "My Seasons" tab
      _tabController.animateTo(1);
    } catch (e) {
      // Close loading
      if (mounted) Navigator.of(context).pop();

      // Ensure widget is still mounted before using context after async gap
      if (!mounted) return;

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error joining season: $e'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
    }
  }

  Future<void> _viewSeasonDetails(Season season) async {
    if (_currentUserId == null) return;
    try {
      // Load this user's goals for the season
      final snap = await FirebaseFirestore.instance
          .collection('goals')
          .where('userId', isEqualTo: _currentUserId)
          .where('seasonId', isEqualTo: season.id)
          .where('isSeasonGoal', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No season goals found for "${season.title}" yet.'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
        return;
      }

      // Prefer the first non-completed goal, else the first one
      final docs = snap.docs;
      var selected = docs.first;
      for (final d in docs) {
        final status = (d.data()['status'] ?? 'notStarted').toString();
        if (status != 'completed') {
          selected = d;
          break;
        }
      }

      final goal = Goal.fromFirestore(selected);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => GoalDetailScreen(goal: goal)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open goal details: $e'),
          backgroundColor: AppColors.dangerColor,
        ),
      );
    }
  }

  void _viewSeasonCelebration(Season season) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SeasonCelebrationScreen(season: season),
      ),
    );
  }

  void _completeSeasonGoals(Season season) {
    // Navigate to season goal completion screen
    Navigator.pushNamed(
      context,
      '/season_goal_completion',
      arguments: {'seasonId': season.id},
    );
  }
}
