import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/audit_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/repository_service.dart';
import 'package:pdh/models/repository_goal.dart';
import 'package:pdh/services/repository_export_service.dart';
import 'package:pdh/design_system/app_colors.dart';

class RepositoryAuditScreen extends StatefulWidget {
  const RepositoryAuditScreen({super.key});

  @override
  State<RepositoryAuditScreen> createState() => _RepositoryAuditScreenState();
}

class _RepositoryAuditScreenState extends State<RepositoryAuditScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _statusFilter;
  String? _monthFilter; // YYYY-MM
  double? _minScore;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/khono_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Repository & Audit',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _buildSearchAndFilters(),
              const SizedBox(height: 25),
              _buildHeader(),
              StreamBuilder<String?>(
                stream: RoleService.instance.roleStream(),
                builder: (context, roleSnapshot) {
                  final isManager = roleSnapshot.data == 'manager';
                  return Column(
                    children: [
                      _buildRoleSummaryBar(isManager: isManager),
                      const SizedBox(height: 16),
                      _buildAuditEntriesList(isManager: isManager),
                      const SizedBox(height: 24),
                      _buildRepositorySection(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search completed goals, audit logs...',
            hintStyle: TextStyle(color: AppColors.textMuted),
            prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.4),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(15.0)),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(15.0)),
              borderSide: BorderSide(color: AppColors.activeColor),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          style: TextStyle(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                decoration: InputDecoration(
                  labelText: 'Filter by Status',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.activeColor),
                  ),
                  isDense: true,
                ),
                dropdownColor: Colors.black.withValues(alpha: 0.9),
                style: TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(value: 'verified', child: Text('Verified')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Month (YYYY-MM)',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.activeColor),
                  ),
                  isDense: true,
                ),
                style: TextStyle(color: AppColors.textPrimary),
                onChanged: (v) => setState(() => _monthFilter = v.trim()),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Min Score',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.4),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.activeColor),
                  ),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.textPrimary),
                onChanged: (v) =>
                    setState(() => _minScore = double.tryParse(v)),
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _statusFilter = null;
                  _monthFilter = null;
                  _minScore = null;
                });
              },
              icon: Icon(Icons.clear, color: AppColors.textMuted),
              tooltip: 'Clear filters',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            'Completed Goals Archive',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
            IconButton(
              tooltip: 'Export',
              onPressed: _showExportSheet,
              icon: const Icon(Icons.ios_share),
              color: AppColors.textPrimary,
        ),
      ],
    );
  }

  Widget _buildRoleSummaryBar({required bool isManager}) {
    return StreamBuilder<Map<String, int>>(
      stream: Stream.fromFuture(AuditService.getAuditStats()),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {'verified': 0, 'pending': 0, 'rejected': 0};
        
        return Container(
          padding: const EdgeInsets.all(16),
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
                    isManager ? Icons.manage_accounts : Icons.person,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isManager ? 'Manager View' : 'Employee View',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildStatusChip('Verified', stats['verified'] ?? 0, AppColors.successColor),
                  _buildStatusChip('Pending', stats['pending'] ?? 0, AppColors.warningColor),
                  if (isManager)
                    _buildStatusChip('Rejected', stats['rejected'] ?? 0, AppColors.dangerColor),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$label $count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditEntriesList({required bool isManager}) {
    return StreamBuilder<List<AuditEntry>>(
      stream: isManager
          ? AuditService.getManagerAuditEntriesStream(
              status: _statusFilter,
              searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
            )
          : AuditService.getEmployeeAuditEntriesStream(
              status: _statusFilter,
              searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
            ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.activeColor),
          );
        }

        if (snapshot.hasError) {
          developer.log('Audit entries error: ${snapshot.error}', name: 'RepositoryAuditScreen');
          return _buildErrorState('Failed to load audit entries: ${snapshot.error}');
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: entries.map((entry) => _buildAuditEntryCard(entry, isManager)).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.archive_outlined,
            color: AppColors.textMuted,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No audit entries found',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some goals to see them here for audit',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: AppColors.dangerColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Data',
            style: TextStyle(
              color: AppColors.dangerColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAuditEntryCard(AuditEntry entry, bool isManager) {
    Color statusColor;
    switch (entry.status) {
      case 'verified':
        statusColor = AppColors.successColor;
        break;
      case 'pending':
        statusColor = AppColors.warningColor;
        break;
      case 'rejected':
        statusColor = AppColors.dangerColor;
        break;
      default:
        statusColor = AppColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
              Expanded(
                child: Text(
                  entry.goalTitle,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  entry.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Completed: ${_formatDate(entry.completedDate)}',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              if (isManager) ...[
                const SizedBox(width: 16),
                Text(
                  'By: ${entry.userDisplayName}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Text(
                  entry.userDepartment,
                  style: TextStyle(color: AppColors.activeColor, fontSize: 14),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Evidence & Documentation:',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ...entry.evidence.map((evidence) => _buildEvidenceItem(evidence)),

          if (isManager && entry.status == 'pending') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showVerifyDialog(entry),
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Verify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(entry),
                    icon: const Icon(Icons.comment, size: 16),
                    label: const Text('Request Changes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dangerColor,
                      side: BorderSide(color: AppColors.dangerColor),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (entry.acknowledgedBy != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.person, color: AppColors.textMuted, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Acknowledged by ${entry.acknowledgedBy}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                if (entry.score != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(Score: ${entry.score!.toStringAsFixed(1)})',
                    style: TextStyle(
                      color: AppColors.successColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ],

          if (entry.comments != null && entry.comments!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comments:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.comments!,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          if (entry.rejectionReason != null && entry.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.dangerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Requested Changes:',
                    style: TextStyle(
                      color: AppColors.dangerColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.rejectionReason!,
                    style: TextStyle(
                      color: AppColors.dangerColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showVerifyDialog(AuditEntry entry) {
    final scoreController = TextEditingController();
    final commentsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Verify Goal',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Score (1.0 - 5.0)',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.4),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Comments (optional)',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.4),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.activeColor),
                ),
              ),
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final score = double.tryParse(scoreController.text);
              if (score != null && score >= 1.0 && score <= 5.0) {
                try {
                  await AuditService.verifyAuditEntry(
                    entry.id,
                    score,
                    commentsController.text.isEmpty ? null : commentsController.text,
                  );
                  if (mounted) navigator.pop();
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error verifying entry: $e')),
                    );
                  }
                }
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Please enter a valid score between 1.0 and 5.0')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successColor,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(AuditEntry entry) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Request Changes',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Reason for changes',
            labelStyle: TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.4),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.dangerColor),
            ),
          ),
          style: TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              if (reasonController.text.isNotEmpty) {
                try {
                  await AuditService.requestChanges(entry.id, reasonController.text);
                  if (mounted) navigator.pop();
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error requesting changes: $e')),
                    );
                  }
                }
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Please provide a reason for the changes')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerColor,
            ),
            child: const Text('Request Changes'),
          ),
        ],
      ),
    );
  }


  Widget _buildRepositorySection() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.cloud_done_outlined, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Text(
              'Repository Results',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: StreamBuilder<List<RepositoryGoal>>(
            stream: RepositoryService.queryRepositoryGoals(
              uid,
              search: _searchQuery,
              dateFilter: _monthFilter,
              minScore: _minScore,
            ),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading repository: ${snapshot.error}',
                    style: TextStyle(color: AppColors.dangerColor),
                  ),
                );
              }
              
              final items = snapshot.data ?? const <RepositoryGoal>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No repository items found. Complete and verify some goals to see them here.'),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.borderColor),
                itemBuilder: (context, index) {
                  final g = items[index];
                  final date = g.completedDate ?? g.verifiedDate;
                  return ListTile(
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    title: Text(
                      g.goalTitle,
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      '${date != null ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' : 'Unknown date'} • Score: ${g.score?.toStringAsFixed(1) ?? '-'}',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    trailing: Text(
                      '${g.evidence.length} evidence',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // (Manager section removed per request; employee-focused for now)

  void _showExportSheet() {
    // Capture the parent ScaffoldMessenger before opening the sheet
    final messenger = ScaffoldMessenger.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('Export as CSV'),
                onTap: () async {
                  Navigator.pop(context);
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  try {
                    // Fire-and-forget export to avoid keeping sheet context alive
                    // and use parent messenger for feedback
                    // ignore: unawaited_futures
                    RepositoryExportService.exportRepositoryAsCSV(uid);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Export started (CSV)')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Export as PDF'),
                onTap: () async {
                  Navigator.pop(context);
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  try {
                    // ignore: unawaited_futures
                    RepositoryExportService.exportRepositoryAsPDF(uid);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Export started (PDF)')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // Helper widget to build individual evidence items.
  Widget _buildEvidenceItem(String text) {
    IconData icon;
    if (text.toLowerCase().contains('report') ||
        text.toLowerCase().contains('document') ||
        text.toLowerCase().contains('files')) {
      icon = Icons.description;
    } else if (text.toLowerCase().contains('link') ||
        text.toLowerCase().contains('repository')) {
      icon = Icons.link;
    } else {
      icon = Icons.attachment;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
