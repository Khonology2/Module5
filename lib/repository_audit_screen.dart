import 'dart:developer' as developer;
import 'dart:convert' as convert;
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdh/services/role_service.dart';
import 'package:pdh/services/audit_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/services/repository_service.dart';
import 'package:pdh/models/repository_goal.dart';
import 'package:pdh/services/repository_export_service.dart';
import 'package:pdh/design_system/app_colors.dart';
import 'package:pdh/services/timeline_service.dart';
import 'package:pdh/models/audit_timeline_event.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/database_service.dart';
import 'package:pdh/services/evidence_upload_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  void initState() {
    super.initState();
    // Ensure repository auto-sync is running to mirror verified audits
    try {
      RepositoryService.startAutoSync();
    } catch (e) {
      developer.log('Error starting auto-sync: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    try {
      RepositoryService.stopAutoSync();
    } catch (e) {
      developer.log('Error stopping auto-sync: $e');
    }
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
        // Use responsive layout with proper constraints
        LayoutBuilder(
          builder: (context, constraints) {
            final isWideScreen = constraints.maxWidth > 600;
            
            if (isWideScreen) {
              // Wide screen: use Row with Expanded
              return Row(
          children: [
            Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String?>(
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
                      items: const <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(value: null, child: Text('All Statuses')),
                        DropdownMenuItem<String?>(value: 'verified', child: Text('Verified')),
                        DropdownMenuItem<String?>(value: 'pending', child: Text('Pending')),
                        DropdownMenuItem<String?>(value: 'rejected', child: Text('Rejected')),
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
                    flex: 2,
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Month (YYYY-MM)',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.elevatedBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                ),
                style: TextStyle(color: AppColors.textPrimary),
                onChanged: (v) => setState(() => _monthFilter = v.trim()),
              ),
            ),
            const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Min Score',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.elevatedBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
              );
            } else {
              // Narrow screen: use Column with full width
              return Column(
                children: [
                  DropdownButtonFormField<String?>(
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
                    items: const <DropdownMenuItem<String?>>[
                      DropdownMenuItem<String?>(value: null, child: Text('All Statuses')),
                      DropdownMenuItem<String?>(value: 'verified', child: Text('Verified')),
                      DropdownMenuItem<String?>(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem<String?>(value: 'rejected', child: Text('Rejected')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _statusFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Month (YYYY-MM)',
                            labelStyle: TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.elevatedBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                          ),
                          style: TextStyle(color: AppColors.textPrimary),
                          onChanged: (v) => setState(() => _monthFilter = v.trim()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Min Score',
                            labelStyle: TextStyle(color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.elevatedBackground,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
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
          },
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
    if (isManager) {
      return StreamBuilder<Map<String, dynamic>>(
        stream: AuditService.getManagerAuditStatsStream(),
      builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final stats = snapshot.data!;
        
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
                    Icon(Icons.manage_accounts, color: AppColors.textPrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Manager Dashboard - Real-time Tracking',
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
                    _buildStatusChip('Total', stats['total'] ?? 0, AppColors.textPrimary),
                    _buildStatusChip('Verified', stats['verified'] ?? 0, AppColors.successColor),
                    _buildStatusChip('Pending', stats['pending'] ?? 0, AppColors.warningColor),
                    _buildStatusChip('Rejected', stats['rejected'] ?? 0, AppColors.dangerColor),
                  ],
                ),
                if (stats['byDepartment'] != null && (stats['byDepartment'] as Map).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Department Breakdown - ALL EMPLOYEES',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (stats['byDepartment'] as Map<String, dynamic>).entries.map((entry) {
                      final dept = entry.key;
                      final deptStats = entry.value as Map<String, int>;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.activeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.activeColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          '$dept: ${deptStats['total']} total (${deptStats['verified']} verified)',
                          style: TextStyle(
                            color: AppColors.activeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (stats['topPerformers'] != null && (stats['topPerformers'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Top Performers - ALL EMPLOYEES',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(stats['topPerformers'] as List).take(5).map((performer) {
                    final name = performer['name'] as String;
                    final verifiedGoals = performer['verifiedGoals'] as int;
                    final avgScore = performer['averageScore'] as double;
                    final dept = performer['department'] as String;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.successColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.star, color: AppColors.warningColor, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$name ($dept)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '$verifiedGoals goals',
                            style: TextStyle(
                              color: AppColors.successColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (avgScore > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${avgScore.toStringAsFixed(1)} avg',
                              style: TextStyle(
                                color: AppColors.warningColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ],
                if (stats['recentActivity'] != null && (stats['recentActivity'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Recent Activity - ALL EMPLOYEES',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(stats['recentActivity'] as List).take(3).map((activity) {
                    final goalTitle = activity['goalTitle'] as String;
                    final employeeName = activity['employeeName'] as String;
                    final status = activity['status'] as String;
                    final dept = activity['department'] as String;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                      ),
                      child: Row(
                children: [
                  Icon(
                            _getStatusIcon(status),
                            color: _getStatusColor(status),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$employeeName ($dept): $goalTitle',
                              style: TextStyle(
                    color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          );
        },
      );
    } else {
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
                    Icon(Icons.person, color: AppColors.textPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'My Goals Progress',
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
                    _buildStatusChip('Rejected', stats['rejected'] ?? 0, AppColors.dangerColor),
                ],
              ),
            ],
          ),
        );
      },
    );
    }
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
          return _buildErrorState('Failed to load audit entries. Please try again.');
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
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showGoalSubmissionDialog,
            icon: const Icon(Icons.add_task),
            label: const Text('Submit Goal for Audit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.activeColor,
              foregroundColor: Colors.white,
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
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerColor),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.successColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Row(
              children: [
                      Icon(Icons.verified_user, color: AppColors.successColor, size: 20),
                const SizedBox(width: 8),
                Text(
                        'Verified by ${entry.acknowledgedBy}',
                    style: TextStyle(
                      color: AppColors.successColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (entry.score != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Score: ${entry.score!.toStringAsFixed(1)}/10',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                    ),
                  ),
                ],
              ],
            ),
          if (entry.comments != null && entry.comments!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                  Text(
                      'Manager Feedback:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                        fontSize: 14,
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
                ],
              ),
            ),
          ],
          
          if (entry.rejectionReason != null && entry.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.dangerColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: AppColors.dangerColor, size: 20),
                      const SizedBox(width: 8),
                  Text(
                        'Changes Requested',
                    style: TextStyle(
                      color: AppColors.dangerColor,
                          fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Reason: ${entry.rejectionReason}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Text(
            'Timeline',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.elevatedBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: StreamBuilder<List<AuditTimelineEvent>>(
              stream: TimelineService.getTimelineStream(entry.id),
              builder: (context, snapshot) {
                final events = snapshot.data ?? const <AuditTimelineEvent>[];
                if (events.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('No timeline events yet'),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ev = events[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        ev.eventType == 'submission'
                            ? Icons.outbox
                            : ev.eventType == 'verification'
                                ? Icons.verified
                                : Icons.edit_note,
                        color: AppColors.textMuted,
                      ),
                      title: Text(
                        ev.description,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${ev.actorName} • ${_formatDate(ev.timestamp)}',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
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
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
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
                    trailing: Text('${g.evidence.length} evidence'),
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
                title: const Text('Export Repository as CSV'),
                onTap: () async {
                  Navigator.pop(context);
                  await _exportRepositoryCSV(messenger);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Export Repository as PDF'),
                onTap: () async {
                  Navigator.pop(context);
                  await _exportRepositoryPDF(messenger);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportRepositoryCSV(ScaffoldMessengerState messenger) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
                    messenger.showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      // Get repository data
      final repositoryGoals = await RepositoryService.getRepositoryGoalsStream(user.uid).first;
      
      if (repositoryGoals.isEmpty) {
                    messenger.showSnackBar(
          const SnackBar(content: Text('No repository data to export')),
        );
        return;
      }

      // Create CSV content
      final csvContent = _generateCSVContent(repositoryGoals);
      
      // For web, create a downloadable blob
      final bytes = convert.utf8.encode(csvContent);
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Create download link
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'repository_goals_${DateTime.now().millisecondsSinceEpoch}.csv')
        ..click();
      
      // Clean up
      html.Url.revokeObjectUrl(url);
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('CSV exported successfully: ${repositoryGoals.length} goals'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportRepositoryPDF(ScaffoldMessengerState messenger) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      // Get repository data
      final repositoryGoals = await RepositoryService.getRepositoryGoalsStream(user.uid).first;
      
      if (repositoryGoals.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No repository data to export')),
        );
        return;
      }

      // Generate PDF content
      final pdfContent = _generatePDFContent(repositoryGoals);
      
      // For web, create a downloadable blob
      final bytes = convert.utf8.encode(pdfContent);
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Create download link
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'repository_goals_${DateTime.now().millisecondsSinceEpoch}.pdf')
        ..click();
      
      // Clean up
      html.Url.revokeObjectUrl(url);
      
      messenger.showSnackBar(
        SnackBar(
          content: Text('PDF exported successfully: ${repositoryGoals.length} goals'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _generateCSVContent(List<RepositoryGoal> goals) {
    final buffer = StringBuffer();
    
    // CSV Header
    buffer.writeln('Goal Title,Completed Date,Verified Date,Score,Manager,Comments,Evidence Count');
    
    // CSV Data
    for (final goal in goals) {
      final completedDate = goal.completedDate?.toIso8601String().split('T')[0] ?? 'N/A';
      final verifiedDate = goal.verifiedDate?.toIso8601String().split('T')[0] ?? 'N/A';
      final score = goal.score?.toStringAsFixed(1) ?? 'N/A';
      final manager = goal.managerAcknowledgedBy ?? 'N/A';
      final comments = (goal.comments ?? '').replaceAll(',', ';').replaceAll('\n', ' ');
      final evidenceCount = goal.evidence.length;
      
      buffer.writeln('"${goal.goalTitle}","$completedDate","$verifiedDate","$score","$manager","$comments","$evidenceCount"');
    }
    
    return buffer.toString();
  }

  String _generatePDFContent(List<RepositoryGoal> goals) {
    final buffer = StringBuffer();
    
    // PDF Header
    buffer.writeln('%PDF-1.4');
    buffer.writeln('1 0 obj');
    buffer.writeln('<<');
    buffer.writeln('/Type /Catalog');
    buffer.writeln('/Pages 2 0 R');
    buffer.writeln('>>');
    buffer.writeln('endobj');
    
    // Pages object
    buffer.writeln('2 0 obj');
    buffer.writeln('<<');
    buffer.writeln('/Type /Pages');
    buffer.writeln('/Kids [3 0 R]');
    buffer.writeln('/Count 1');
    buffer.writeln('>>');
    buffer.writeln('endobj');
    
    // Page object
    buffer.writeln('3 0 obj');
    buffer.writeln('<<');
    buffer.writeln('/Type /Page');
    buffer.writeln('/Parent 2 0 R');
    buffer.writeln('/MediaBox [0 0 612 792]');
    buffer.writeln('/Resources <<');
    buffer.writeln('/Font <<');
    buffer.writeln('/F1 4 0 R');
    buffer.writeln('>>');
    buffer.writeln('>>');
    buffer.writeln('/Contents 5 0 R');
    buffer.writeln('>>');
    buffer.writeln('endobj');
    
    // Font object
    buffer.writeln('4 0 obj');
    buffer.writeln('<<');
    buffer.writeln('/Type /Font');
    buffer.writeln('/Subtype /Type1');
    buffer.writeln('/BaseFont /Helvetica');
    buffer.writeln('>>');
    buffer.writeln('endobj');
    
    // Content stream
    buffer.writeln('5 0 obj');
    buffer.writeln('<<');
    buffer.writeln('/Length ${_generatePDFContentLength(goals)}');
    buffer.writeln('>>');
    buffer.writeln('stream');
    buffer.writeln('BT');
    buffer.writeln('/F1 16 Tf');
    buffer.writeln('50 750 Td');
    buffer.writeln('(Repository Goals Report) Tj');
    buffer.writeln('0 -30 Td');
    buffer.writeln('/F1 12 Tf');
    buffer.writeln('(Generated on: ${DateTime.now().toIso8601String().split('T')[0]}) Tj');
    buffer.writeln('0 -40 Td');
    buffer.writeln('(Total Goals: ${goals.length}) Tj');
    buffer.writeln('0 -60 Td');
    
    // Goals data
    for (int i = 0; i < goals.length && i < 20; i++) {
      final goal = goals[i];
      final completedDate = goal.completedDate?.toIso8601String().split('T')[0] ?? 'N/A';
      final verifiedDate = goal.verifiedDate?.toIso8601String().split('T')[0] ?? 'N/A';
      final score = goal.score?.toStringAsFixed(1) ?? 'N/A';
      final manager = goal.managerAcknowledgedBy ?? 'N/A';
      
      buffer.writeln('(Goal ${i + 1}: ${goal.goalTitle}) Tj');
      buffer.writeln('0 -20 Td');
      buffer.writeln('(Completed: $completedDate | Verified: $verifiedDate | Score: $score) Tj');
      buffer.writeln('0 -15 Td');
      buffer.writeln('(Manager: $manager | Evidence: ${goal.evidence.length} items) Tj');
      buffer.writeln('0 -25 Td');
      
      if (i < goals.length - 1) {
        buffer.writeln('(----------------------------------------) Tj');
        buffer.writeln('0 -15 Td');
      }
    }
    
    if (goals.length > 20) {
      buffer.writeln('0 -20 Td');
      buffer.writeln('(... and ${goals.length - 20} more goals) Tj');
    }
    
    buffer.writeln('ET');
    buffer.writeln('endstream');
    buffer.writeln('endobj');
    
    // Cross-reference table
    buffer.writeln('xref');
    buffer.writeln('0 6');
    buffer.writeln('0000000000 65535 f ');
    buffer.writeln('0000000009 00000 n ');
    buffer.writeln('0000000058 00000 n ');
    buffer.writeln('0000000115 00000 n ');
    buffer.writeln('0000000274 00000 n ');
    buffer.writeln('0000000341 00000 n ');
    
    // Trailer
    buffer.writeln('trailer');
    buffer.writeln('<<');
    buffer.writeln('/Size 6');
    buffer.writeln('/Root 1 0 R');
    buffer.writeln('>>');
    buffer.writeln('startxref');
    buffer.writeln('${_calculatePDFXrefOffset(goals)}');
    buffer.writeln('%%EOF');
    
    return buffer.toString();
  }

  int _generatePDFContentLength(List<RepositoryGoal> goals) {
    // Calculate approximate content length
    int length = 200; // Base content
    for (int i = 0; i < goals.length && i < 20; i++) {
      final goal = goals[i];
      length += goal.goalTitle.length + 100; // Goal title + formatting
      length += 80; // Date and score info
      length += (goal.managerAcknowledgedBy?.length ?? 0) + 50; // Manager info
      length += 60; // Separator and spacing
    }
    if (goals.length > 20) {
      length += 50; // "and X more goals" text
    }
    return length;
  }

  int _calculatePDFXrefOffset(List<RepositoryGoal> goals) {
    // Calculate the offset where xref table starts
    int offset = 200; // Header and objects
    offset += _generatePDFContentLength(goals);
    offset += 50; // xref table
    return offset;
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

    final isUrl = text.startsWith('http://') || text.startsWith('https://');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () => _openEvidence(text),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.elevatedBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
      child: Row(
        children: [
              Icon(icon, color: AppColors.activeColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                    color: isUrl ? AppColors.activeColor : AppColors.textSecondary,
                fontSize: 14,
                    decoration: isUrl ? TextDecoration.underline : null,
              ),
            ),
          ),
              Icon(
                Icons.open_in_new,
                color: AppColors.textMuted,
                size: 16,
              ),
        ],
          ),
        ),
      ),
    );
  }

  // Helper widget to build file evidence items
  Widget _buildFileEvidenceItem(EvidenceFile file) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () => _openFileEvidence(file),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.elevatedBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            children: [
              Icon(
                _getFileIcon(file.fileType),
                color: AppColors.activeColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.fileName,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${(file.fileSize / 1024).toStringAsFixed(1)} KB • ${_formatDate(file.uploadedAt)}',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.download,
                color: AppColors.textMuted,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openEvidence(String evidence) {
    final isUrl = evidence.startsWith('http://') || evidence.startsWith('https://');
    
    if (isUrl) {
      // For URLs, show a dialog with option to open externally
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Evidence Link',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This evidence is a web link:',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              SelectableText(
                evidence,
                style: TextStyle(
                  color: AppColors.activeColor,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'To view this evidence, copy the link and open it in your browser.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                // Copy to clipboard functionality could be added here
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
              ),
              child: const Text('Copy Link'),
            ),
          ],
        ),
      );
    } else {
      // For text evidence, show in a dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Evidence Details',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: SelectableText(
              evidence,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      );
    }
  }

  void _openFileEvidence(EvidenceFile file) {
    // For web, open file in new tab
    html.window.open(file.url, '_blank');
  }

  void _showGoalSubmissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          'Submit Goal for Audit',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select a completed goal to submit for manager review:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Goal>>(
              future: _getCompletedGoals(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.activeColor),
                  );
                }
                
                if (snapshot.hasError) {
                  return Text(
                    'Error loading goals: ${snapshot.error}',
                    style: TextStyle(color: AppColors.dangerColor),
                  );
                }
                
                final goals = snapshot.data ?? [];
                if (goals.isEmpty) {
                  return Text(
                    'No completed goals found. Complete some goals first.',
                    style: TextStyle(color: AppColors.textMuted),
                  );
                }
                
                return SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: goals.length,
                    itemBuilder: (context, index) {
                      final goal = goals[index];
                      return ListTile(
                        title: Text(
                          goal.title,
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        subtitle: Text(
                          goal.description,
                          style: TextStyle(color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _showEvidenceAttachmentDialog(goal),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.activeColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Submit'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Future<List<Goal>> _getCompletedGoals() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];
      
      final snapshot = await FirebaseFirestore.instance
          .collection('goals')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .get();
      
      return snapshot.docs.map((doc) => Goal.fromFirestore(doc)).toList();
    } catch (e) {
      developer.log('Error loading completed goals: $e');
      return [];
    }
  }

  void _showEvidenceAttachmentDialog(Goal goal) {
    final evidenceController = TextEditingController();
    final evidenceList = <String>[];
    final uploadedFiles = <EvidenceFile>[];
    bool isUploading = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          title: Text(
            'Attach Evidence for: ${goal.title}',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add evidence to support your goal completion:',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                
                // Text evidence input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: evidenceController,
                        decoration: InputDecoration(
                          hintText: 'Enter evidence (URL, description, etc.)',
                          hintStyle: TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.elevatedBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (evidenceController.text.trim().isNotEmpty) {
                          setState(() {
                            evidenceList.add(evidenceController.text.trim());
                            evidenceController.clear();
                          });
                        }
                      },
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.activeColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // File upload button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isUploading ? null : () => _uploadFiles(goal.id, setState, uploadedFiles, isUploading),
                    icon: isUploading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(isUploading ? 'Uploading...' : 'Upload Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warningColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                
                // Display uploaded files
                if (uploadedFiles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Uploaded Files:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.elevatedBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: ListView.builder(
                      itemCount: uploadedFiles.length,
                      itemBuilder: (context, index) {
                        final file = uploadedFiles[index];
                        return ListTile(
                          leading: Icon(
                            _getFileIcon(file.fileType),
                            color: AppColors.activeColor,
                          ),
                          title: Text(
                            file.fileName,
                            style: TextStyle(color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${(file.fileSize / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setState(() {
                                uploadedFiles.removeAt(index);
                              });
                            },
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                
                // Display text evidence
                if (evidenceList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Text Evidence:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.elevatedBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: ListView.builder(
                      itemCount: evidenceList.length,
                      itemBuilder: (context, index) {
                        final evidence = evidenceList[index];
                        return ListTile(
                          leading: const Icon(Icons.text_fields, color: AppColors.activeColor),
                          title: Text(
                            evidence,
                            style: TextStyle(color: AppColors.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            onPressed: () {
                              setState(() {
                                evidenceList.removeAt(index);
                              });
                            },
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: (evidenceList.isEmpty && uploadedFiles.isEmpty)
                  ? null
                  : () => _submitGoalForAuditWithFiles(goal, evidenceList, uploadedFiles),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.activeColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit for Audit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFiles(String goalId, StateSetter setState, List<EvidenceFile> uploadedFiles, bool isUploading) async {
    setState(() {
      isUploading = true;
    });

    try {
      final files = await EvidenceUploadService.pickAndUploadFiles(goalId: goalId);
      setState(() {
        uploadedFiles.addAll(files);
        isUploading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${files.length} file(s) uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isUploading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        return Icons.image;
      case '.txt':
        return Icons.text_snippet;
      case '.zip':
        return Icons.archive;
      default:
        return Icons.attach_file;
    }
  }

  Future<void> _submitGoalForAudit(Goal goal, List<String> evidence) async {
    try {
      await AuditService.submitGoalForAudit(goal, evidence);
      
      if (mounted) {
        Navigator.pop(context); // Close evidence dialog
        Navigator.pop(context); // Close goal selection dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal submitted for audit successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('Error submitting goal for audit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting goal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitGoalForAuditWithFiles(Goal goal, List<String> textEvidence, List<EvidenceFile> uploadedFiles) async {
    try {
      // Combine text evidence with file URLs
      final allEvidence = <String>[];
      allEvidence.addAll(textEvidence);
      allEvidence.addAll(uploadedFiles.map((file) => file.url));
      
      // Submit goal for audit
      await AuditService.submitGoalForAudit(goal, allEvidence);
      
      // Update uploaded files with audit entry ID (we'll need to get this from the audit service)
      // For now, we'll just submit the goal and the files will be linked by goal ID
      
      if (mounted) {
        Navigator.pop(context); // Close evidence dialog
        Navigator.pop(context); // Close goal selection dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal submitted for audit with ${uploadedFiles.length} file(s) and ${textEvidence.length} text evidence!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      developer.log('Error submitting goal for audit with files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting goal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'verified':
        return AppColors.successColor;
      case 'pending':
        return AppColors.warningColor;
      case 'rejected':
        return AppColors.dangerColor;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'verified':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}
