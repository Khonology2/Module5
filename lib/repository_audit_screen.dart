import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/audit_service.dart';
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
          color: AppColors.backgroundColor,
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
            fillColor: AppColors.elevatedBackground,
            border: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(15.0)),
              borderSide: BorderSide.none,
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
                  fillColor: AppColors.elevatedBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                dropdownColor: AppColors.elevatedBackground,
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
            IconButton(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _statusFilter = null;
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.archive_outlined,
            color: AppColors.textPrimary,
            size: 24,
          ),
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
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
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
          // Fallback to mock data
          final mockEntries = AuditService.getMockAuditEntries();
          return Column(
            children: mockEntries.map((entry) => _buildAuditEntryCard(entry, isManager)).toList(),
          );
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
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
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
                color: AppColors.elevatedBackground,
                borderRadius: BorderRadius.circular(8),
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
                fillColor: AppColors.elevatedBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
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
                fillColor: AppColors.elevatedBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
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
            fillColor: AppColors.elevatedBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
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
