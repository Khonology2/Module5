// ignore_for_file: avoid_types_as_parameter_names, deprecated_member_use, unused_field

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../design_system/app_colors.dart';
import '../design_system/app_typography.dart';
import '../design_system/app_spacing.dart';
import '../services/unified_milestone_audit.dart';

class MilestoneAuditScreen extends StatefulWidget {
  const MilestoneAuditScreen({super.key});

  @override
  State<MilestoneAuditScreen> createState() => _MilestoneAuditScreenState();
}

class _MilestoneAuditScreenState extends State<MilestoneAuditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, int> _auditCounts = {};
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAuditCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAuditCounts() async {
    setState(() => _isLoadingCounts = true);

    try {
      // Count audit entries from stream to get real counts
      final stream = UnifiedMilestoneAudit.getAllMilestoneAuditStream();
      final counts = {
        'milestone_created': 0,
        'milestone_updated': 0,
        'milestone_pending_review': 0,
        'milestone_acknowledged': 0,
        'milestone_rejected': 0,
        'milestone_dismissed': 0,
      };

      await for (final batch in stream) {
        for (final entry in batch) {
          final action = entry['action'] as String?;
          if (action != null && counts.containsKey(action)) {
            counts[action] = (counts[action] ?? 0) + 1;
          }
        }
        break; // Just get first batch for initial counts
      }

      setState(() {
        _auditCounts = counts;
        _isLoadingCounts = false;
      });
    } catch (e) {
      setState(() => _isLoadingCounts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading audit counts: $e'),
            backgroundColor: AppColors.dangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return content without Scaffold - MainLayout already provides Scaffold via AppScaffold
    return Column(
      children: [
        // Custom header with TabBar (since we don't have AppBar)
        Container(
          color: AppColors.elevatedBackground.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Milestone Audit Trail',
                      style: AppTypography.heading2.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: AppColors.activeColor),
                    onPressed: _loadAuditCounts,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                labelStyle: AppTypography.bodyLarge.copyWith(
                  color: AppColors.activeColor,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
                indicatorColor: AppColors.activeColor,
                tabs: const [
                  Tab(text: 'Timeline'),
                  Tab(text: 'Statistics'),
                ],
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildTimelineTab(), _buildStatisticsTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundColor.withValues(alpha: 0.3),
            AppColors.backgroundColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: UnifiedMilestoneAudit.getAllMilestoneAuditStream(),
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
                  Text(
                    'Error loading audit trail',
                    style: AppTypography.heading3.copyWith(
                      color: AppColors.dangerColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final auditEntries = snapshot.data ?? [];

          if (auditEntries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'No milestone audit history found',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: AppColors.activeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.activeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Start Creating Milestones',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.activeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '1. Go to My Goal Workspace\n'
                          '2. Create a new goal and get it approved\n'
                          '3. Open goal details and add milestones\n'
                          '4. Track milestone progress and status changes\n'
                          '5. All activities will appear here automatically',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to goal workspace
                            Navigator.of(
                              context,
                            ).pushNamed('/my_goal_workspace');
                          },
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Go to Goal Workspace'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.activeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
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

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: auditEntries.length,
            itemBuilder: (context, index) {
              final entry = auditEntries[index];
              return MilestoneAuditCard(entry: entry);
            },
          );
        },
      ),
    );
  }

  Widget _buildStatisticsTab() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundColor.withValues(alpha: 0.3),
            AppColors.backgroundColor.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: _isLoadingCounts
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.activeColor,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Milestone Status Overview',
                    style: AppTypography.heading2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStatusGrid(),
                  const SizedBox(height: 32),
                  _buildTotalStatsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status counter cards row
        Row(
          children: [
            Expanded(
              child: _buildStatusCounterCard(
                title: 'Created',
                count: _auditCounts['milestone_created'] ?? 0,
                icon: Icons.add_circle,
                color: AppColors.successColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCounterCard(
                title: 'Updated',
                count: _auditCounts['milestone_updated'] ?? 0,
                icon: Icons.edit,
                color: AppColors.warningColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatusCounterCard(
                title: 'Pending Review',
                count: _auditCounts['milestone_pending_review'] ?? 0,
                icon: Icons.pending_actions,
                color: AppColors.warningColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCounterCard(
                title: 'Acknowledged',
                count: _auditCounts['milestone_acknowledged'] ?? 0,
                icon: Icons.verified,
                color: AppColors.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatusCounterCard(
                title: 'Rejected',
                count: _auditCounts['milestone_rejected'] ?? 0,
                icon: Icons.cancel,
                color: AppColors.dangerColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCounterCard(
                title: 'Dismissed',
                count: _auditCounts['milestone_dismissed'] ?? 0,
                icon: Icons.block,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCounterCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: AppTypography.heading3.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalStatsCard() {
    final total = _auditCounts.values.fold<int>(0, (acc, n) => acc + n);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.activeColor.withValues(alpha: 0.1),
            AppColors.activeColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.activeColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: AppColors.activeColor, size: 28),
              const SizedBox(width: 12),
              Text(
                'Total Audit Events',
                style: AppTypography.heading2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            total.toString(),
            style: AppTypography.heading1.copyWith(
              color: AppColors.activeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Across all milestone statuses',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class MilestoneAuditCard extends StatefulWidget {
  final Map<String, dynamic> entry;

  const MilestoneAuditCard({super.key, required this.entry});

  @override
  State<MilestoneAuditCard> createState() => MilestoneAuditCardState();
}

class MilestoneAuditCardState extends State<MilestoneAuditCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.entry['action'] as String? ?? 'unknown';
    final timestamp = widget.entry['timestamp'] as Timestamp?;
    final milestoneTitle =
        widget.entry['milestoneTitle'] as String? ?? 'Unknown Milestone';
    final isHistorical = widget.entry['metadata']?['isHistorical'] == true;

    final actionInfo = _getActionInfo(action);
    final formattedDate = _formatDate(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              (actionInfo['color'] as Color?)?.withValues(alpha: 0.2) ??
              Colors.transparent,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: _toggleExpand,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with action and timestamp
              Row(
                children: [
                  // Action Icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: (actionInfo['color'] as Color).withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      actionInfo['icon'] as IconData,
                      color: actionInfo['color'] as Color,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Action Title and Status Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionInfo['title'] as String,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              milestoneTitle,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status Badge in collapsed view
                            _buildCompactStatusBadge(action),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Historical Badge
                  if (isHistorical)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.infoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Historical',
                        style: AppTypography.bodyXSmall.copyWith(
                          color: AppColors.infoColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Timestamp
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      formattedDate,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              // Divider
              if (_isExpanded)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  height: 1,
                  color: AppColors.backgroundColor.withValues(alpha: 0.3),
                ),

              // Expanded Details
              if (_isExpanded) _buildExpandedDetails(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDetails() {
    final action = widget.entry['action'] as String? ?? 'unknown';
    final userName = widget.entry['userName'] as String? ?? 'System';
    final userRole = widget.entry['userRole'] as String? ?? 'system';
    final description = widget.entry['description'] as String? ?? '';
    final milestoneTitle =
        widget.entry['milestoneTitle'] as String? ?? 'Unknown Milestone';
    final goalTitle = widget.entry['goalTitle'] as String? ?? 'Unknown Goal';

    // Extract status from action or metadata
    String status = 'Unknown';
    Color statusColor = AppColors.textSecondary;

    if (action.contains('pending_review')) {
      status = 'Pending Review';
      statusColor = AppColors.warningColor;
    } else if (action.contains('acknowledged')) {
      status = 'Acknowledged';
      statusColor = AppColors.successColor;
    } else if (action.contains('rejected')) {
      status = 'Rejected';
      statusColor = AppColors.dangerColor;
    } else if (action.contains('dismissed')) {
      status = 'Dismissed';
      statusColor = AppColors.textMuted;
    } else if (action.contains('created')) {
      status = 'Created';
      statusColor = AppColors.infoColor;
    } else if (action.contains('updated')) {
      status = 'Updated';
      statusColor = AppColors.warningColor;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

        // Status Badge
        Row(
          children: [
            Text(
              'Status:',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                status,
                style: AppTypography.bodySmall.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Milestone Information
        _buildInfoRow(
          label: 'Milestone:',
          value: milestoneTitle,
          icon: Icons.flag,
        ),

        const SizedBox(height: 12),

        // Goal Information
        _buildInfoRow(
          label: 'Goal:',
          value: goalTitle,
          icon: Icons.track_changes,
        ),

        const SizedBox(height: 12),

        // Owner Information
        _buildInfoRow(
          label: 'Created By:',
          value: '$userName ($userRole)',
          icon: Icons.person,
        ),

        const SizedBox(height: 12),

        // Acknowledged By (if applicable)
        if (action == 'milestone_acknowledged' &&
            widget.entry['acknowledgedByName'] != null) ...[
          _buildInfoRow(
            label: 'Acknowledged By:',
            value: '${widget.entry['acknowledgedByName']}',
            icon: Icons.verified_user,
            valueColor: AppColors.successColor,
          ),
          const SizedBox(height: 12),
        ],

        // Rejected By (if applicable)
        if (action == 'milestone_rejected' &&
            widget.entry['rejectedByName'] != null) ...[
          _buildInfoRow(
            label: 'Rejected By:',
            value: '${widget.entry['rejectedByName']}',
            icon: Icons.cancel,
            valueColor: AppColors.dangerColor,
          ),
          const SizedBox(height: 12),
        ],

        // Description (if available)
        if (description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Description:',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactStatusBadge(String action) {
    String status = 'Unknown';
    Color statusColor = AppColors.textSecondary;

    if (action.contains('pending_review')) {
      status = 'Pending';
      statusColor = AppColors.warningColor;
    } else if (action.contains('acknowledged')) {
      status = 'Acknowledged';
      statusColor = AppColors.successColor;
    } else if (action.contains('rejected')) {
      status = 'Rejected';
      statusColor = AppColors.dangerColor;
    } else if (action.contains('dismissed')) {
      status = 'Dismissed';
      statusColor = AppColors.textMuted;
    } else if (action.contains('created')) {
      status = 'Created';
      statusColor = AppColors.infoColor;
    } else if (action.contains('updated')) {
      status = 'Updated';
      statusColor = AppColors.warningColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        status,
        style: AppTypography.bodyXSmall.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getActionInfo(String action) {
    switch (action) {
      case 'milestone_created':
        return {
          'title': 'Milestone Created',
          'icon': Icons.add_circle,
          'color': AppColors.successColor,
        };
      case 'milestone_updated':
        return {
          'title': 'Milestone Updated',
          'icon': Icons.edit,
          'color': AppColors.warningColor,
        };
      case 'milestone_pending_review':
        return {
          'title': 'Pending Review',
          'icon': Icons.pending_actions,
          'color': AppColors.warningColor,
        };
      case 'milestone_acknowledged':
        return {
          'title': 'Acknowledged',
          'icon': Icons.verified,
          'color': AppColors.successColor,
        };
      case 'milestone_rejected':
        return {
          'title': 'Rejected',
          'icon': Icons.cancel,
          'color': AppColors.dangerColor,
        };
      case 'milestone_dismissed':
        return {
          'title': 'Dismissed',
          'icon': Icons.block,
          'color': AppColors.textMuted,
        };
      default:
        return {
          'title': 'Unknown Action',
          'icon': Icons.help_outline,
          'color': AppColors.textSecondary,
        };
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';

    final now = DateTime.now();
    final eventTime = timestamp.toDate();
    final difference = now.difference(eventTime);

    // Relative time for recent events
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) {
          return 'Just now';
        } else if (difference.inMinutes == 1) {
          return '1 minute ago';
        } else {
          return '${difference.inMinutes} minutes ago';
        }
      } else if (difference.inHours == 1) {
        return '1 hour ago';
      } else {
        return '${difference.inHours} hours ago';
      }
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    // Absolute date for older events
    return DateFormat('MMM dd, yyyy').format(eventTime);
  }
}
