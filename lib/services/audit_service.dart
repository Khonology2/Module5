import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/timeline_service.dart';

class AuditEntry {
  final String id;
  final String userId;
  final String goalId;
  final String goalTitle;
  final DateTime completedDate;
  final DateTime submittedDate;
  final String status; // 'pending', 'verified', 'rejected'
  final List<String> evidence;
  final String? acknowledgedBy;
  final String? acknowledgedById;
  final double? score;
  final String? comments;
  final String? rejectionReason;
  final String userDisplayName;
  final String userDepartment;

  AuditEntry({
    required this.id,
    required this.userId,
    required this.goalId,
    required this.goalTitle,
    required this.completedDate,
    required this.submittedDate,
    required this.status,
    required this.evidence,
    this.acknowledgedBy,
    this.acknowledgedById,
    this.score,
    this.comments,
    this.rejectionReason,
    required this.userDisplayName,
    required this.userDepartment,
  });

  factory AuditEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditEntry(
      id: doc.id,
      userId: data['userId'] ?? '',
      goalId: data['goalId'] ?? '',
      goalTitle: data['goalTitle'] ?? '',
      completedDate: (data['completedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      submittedDate: (data['submittedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      evidence: List<String>.from(data['evidence'] ?? []),
      acknowledgedBy: data['acknowledgedBy'],
      acknowledgedById: data['acknowledgedById'],
      score: data['score']?.toDouble(),
      comments: data['comments'],
      rejectionReason: data['rejectionReason'],
      userDisplayName: data['userDisplayName'] ?? 'Unknown User',
      userDepartment: data['userDepartment'] ?? 'Unknown',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'goalId': goalId,
      'goalTitle': goalTitle,
      'completedDate': Timestamp.fromDate(completedDate),
      'submittedDate': Timestamp.fromDate(submittedDate),
      'status': status,
      'evidence': evidence,
      'acknowledgedBy': acknowledgedBy,
      'acknowledgedById': acknowledgedById,
      'score': score,
      'comments': comments,
      'rejectionReason': rejectionReason,
      'userDisplayName': userDisplayName,
      'userDepartment': userDepartment,
    };
  }
}

class AuditService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Submit a completed goal for audit
  static Future<void> submitGoalForAudit(Goal goal, List<String> evidence) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if this goal is already submitted for audit to prevent duplicates
      final existingEntries = await _firestore
          .collection('audit_entries')
          .where('userId', isEqualTo: user.uid)
          .where('goalId', isEqualTo: goal.id)
          .get();

      if (existingEntries.docs.isNotEmpty) {
        throw Exception('This goal has already been submitted for audit');
      }

      // Get user profile for display name and department
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final auditEntry = AuditEntry(
        id: '', // Will be set by Firestore
        userId: user.uid,
        goalId: goal.id,
        goalTitle: goal.title,
        completedDate: DateTime.now(), // Use current date as completed date
        submittedDate: DateTime.now(),
        status: 'pending',
        evidence: evidence,
        userDisplayName: userData['displayName'] ?? user.displayName ?? 'Unknown User',
        userDepartment: userData['department'] ?? 'Unknown',
      );

      final ref = await _firestore.collection('audit_entries').add(auditEntry.toFirestore());

      // Log timeline event: submission
      try {
        final event = TimelineService.buildEvent(
          eventType: 'submission',
          description: 'Goal submitted for audit: ${goal.title}',
        );
        await TimelineService.logEvent(ref.id, event);
      } catch (e) {
        developer.log('Failed to log submission timeline event: $e');
      }
    } catch (e) {
      developer.log('Error submitting goal for audit: $e');
      rethrow;
    }
  }

  // Get audit entries stream for managers (all entries)
  static Stream<List<AuditEntry>> getManagerAuditEntriesStream({
    String? status,
    String? searchQuery,
  }) {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(<AuditEntry>[]);
    }

    try {
      Query query = _firestore.collection('audit_entries');

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.orderBy('submittedDate', descending: true).limit(100);

      return query.snapshots().map((snapshot) {
        try {
          List<AuditEntry> entries = snapshot.docs
              .map((doc) {
                try {
                  return AuditEntry.fromFirestore(doc);
                } catch (e) {
                  developer.log('Error parsing audit entry ${doc.id}: $e');
                  return null;
                }
              })
              .where((entry) => entry != null)
              .cast<AuditEntry>()
              .toList();

          if (searchQuery != null && searchQuery.isNotEmpty) {
            final lowercaseQuery = searchQuery.toLowerCase();
            entries = entries.where((entry) {
              return entry.goalTitle.toLowerCase().contains(lowercaseQuery) ||
                     entry.userDisplayName.toLowerCase().contains(lowercaseQuery) ||
                     entry.userDepartment.toLowerCase().contains(lowercaseQuery) ||
                     entry.evidence.any((evidence) =>
                         evidence.toLowerCase().contains(lowercaseQuery));
            }).toList();
          }

          return entries;
        } catch (e) {
          developer.log('Error processing manager audit entries: $e');
          return <AuditEntry>[];
        }
      }).handleError((error, stackTrace) {
        developer.log('Manager audit entries stream error: $error', error: error, stackTrace: stackTrace);
        return <AuditEntry>[];
      });
    } catch (e) {
      developer.log('Error building manager audit entries stream: $e');
      return Stream.value(<AuditEntry>[]);
    }
  }

  // Get comprehensive audit statistics for managers - ALL EMPLOYEES DATA
  static Stream<Map<String, dynamic>> getManagerAuditStatsStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(<String, dynamic>{
        'total': 0,
        'pending': 0,
        'verified': 0,
        'rejected': 0,
        'byDepartment': <String, Map<String, int>>{},
        'byEmployee': <String, Map<String, int>>{},
        'recentActivity': <Map<String, dynamic>>[],
        'topPerformers': <Map<String, dynamic>>[],
      });
    }

    return Stream.fromFuture(
      _firestore.collection('users').doc(user.uid).get(),
    ).asyncExpand((userDoc) {
      final managerDept = (userDoc.data() ?? const {})['department'] as String?;
      if (managerDept == null || managerDept.isEmpty) {
        return Stream.value(<String, dynamic>{
          'total': 0,
          'pending': 0,
          'verified': 0,
          'rejected': 0,
          'byDepartment': <String, Map<String, int>>{},
          'byEmployee': <String, Map<String, int>>{},
          'recentActivity': <Map<String, dynamic>>[],
          'topPerformers': <Map<String, dynamic>>[],
        });
      }

      final query = _firestore
          .collection('audit_entries')
          .where('userDepartment', isEqualTo: managerDept)
          .orderBy('submittedDate', descending: true)
          .limit(200);

      return query.snapshots().map((snapshot) {
        final entries = snapshot.docs.map((doc) {
          try {
            return AuditEntry.fromFirestore(doc);
          } catch (e) {
            developer.log('Error parsing audit entry ${doc.id}: $e');
            return null;
          }
        }).where((entry) => entry != null).cast<AuditEntry>().toList();
        
        final stats = <String, dynamic>{
          'total': entries.length,
          'pending': entries.where((e) => e.status == 'pending').length,
          'verified': entries.where((e) => e.status == 'verified').length,
          'rejected': entries.where((e) => e.status == 'rejected').length,
          'byDepartment': <String, Map<String, int>>{},
          'byEmployee': <String, Map<String, int>>{},
          'recentActivity': <Map<String, dynamic>>[],
          'topPerformers': <Map<String, dynamic>>[],
        };

        // Group by department - ALL DEPARTMENTS
        final departmentGroups = <String, List<AuditEntry>>{};
        for (final entry in entries) {
          departmentGroups.putIfAbsent(entry.userDepartment, () => []).add(entry);
        }
        
        for (final dept in departmentGroups.keys) {
          final deptEntries = departmentGroups[dept]!;
          stats['byDepartment'][dept] = {
            'total': deptEntries.length,
            'pending': deptEntries.where((e) => e.status == 'pending').length,
            'verified': deptEntries.where((e) => e.status == 'verified').length,
            'rejected': deptEntries.where((e) => e.status == 'rejected').length,
          };
        }

        // Group by employee - ALL EMPLOYEES
        final employeeGroups = <String, List<AuditEntry>>{};
        for (final entry in entries) {
          employeeGroups.putIfAbsent(entry.userId, () => []).add(entry);
        }
        
        for (final empId in employeeGroups.keys) {
          final empEntries = employeeGroups[empId]!;
          final empName = empEntries.first.userDisplayName;
          final empDept = empEntries.first.userDepartment;
          final verifiedCount = empEntries.where((e) => e.status == 'verified').length;
          final totalScore = empEntries
              .where((e) => e.score != null)
              .fold(0.0, (acc, e) => acc + e.score!);
          final avgScore = verifiedCount > 0 ? totalScore / verifiedCount : 0.0;
          
          stats['byEmployee'][empName] = {
            'total': empEntries.length,
            'pending': empEntries.where((e) => e.status == 'pending').length,
            'verified': verifiedCount,
            'rejected': empEntries.where((e) => e.status == 'rejected').length,
            'department': empDept,
            'averageScore': avgScore,
            'userId': empId,
          };
        }

        // Recent activity - ALL EMPLOYEES
        final recentEntries = entries.take(10).map((entry) => {
          'goalTitle': entry.goalTitle,
          'employeeName': entry.userDisplayName,
          'department': entry.userDepartment,
          'status': entry.status,
          'submittedDate': entry.submittedDate.toIso8601String(),
          'score': entry.score,
        }).toList();
        stats['recentActivity'] = recentEntries;

        // Top performers - ALL EMPLOYEES ranked by verified goals and scores
        final employeePerformance = <String, Map<String, dynamic>>{};
        for (final empId in employeeGroups.keys) {
          final empEntries = employeeGroups[empId]!;
          final verifiedEntries = empEntries.where((e) => e.status == 'verified').toList();
          final totalScore = verifiedEntries
              .where((e) => e.score != null)
              .fold(0.0, (acc, e) => acc + e.score!);
          final avgScore = verifiedEntries.isNotEmpty && verifiedEntries.any((e) => e.score != null) 
              ? totalScore / verifiedEntries.where((e) => e.score != null).length 
              : 0.0;
          
          employeePerformance[empId] = {
            'name': empEntries.first.userDisplayName,
            'department': empEntries.first.userDepartment,
            'verifiedGoals': verifiedEntries.length,
            'averageScore': avgScore,
            'totalScore': totalScore,
            'userId': empId,
          };
        }
        
        // Sort by verified goals count, then by average score
        final sortedPerformers = employeePerformance.values.toList()
          ..sort((a, b) {
            final goalComparison = (b['verifiedGoals'] as int).compareTo(a['verifiedGoals'] as int);
            if (goalComparison != 0) return goalComparison;
            return (b['averageScore'] as double).compareTo(a['averageScore'] as double);
          });
        
        stats['topPerformers'] = sortedPerformers.take(10).toList();

        return stats;
      }).handleError((error, stackTrace) {
        developer.log('Manager audit stats stream error: $error', error: error, stackTrace: stackTrace);
        return <String, dynamic>{
          'total': 0,
          'pending': 0,
          'verified': 0,
          'rejected': 0,
          'byDepartment': <String, Map<String, int>>{},
          'byEmployee': <String, Map<String, int>>{},
          'recentActivity': <Map<String, dynamic>>[],
          'topPerformers': <Map<String, dynamic>>[],
        };
      });
    }).handleError((error, stackTrace) {
      developer.log('Error building manager audit stats stream: $error', error: error, stackTrace: stackTrace);
      return Stream.value(<String, dynamic>{
        'total': 0,
        'pending': 0,
        'verified': 0,
        'rejected': 0,
        'byDepartment': <String, Map<String, int>>{},
        'byEmployee': <String, Map<String, int>>{},
        'recentActivity': <Map<String, dynamic>>[],
        'topPerformers': <Map<String, dynamic>>[],
      });
    });
  }

  // Get audit entries stream for employees (their own entries)
  static Stream<List<AuditEntry>> getEmployeeAuditEntriesStream({
    String? status,
    String? searchQuery,
  }) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    try {
      Query query = _firestore
          .collection('audit_entries')
          .where('userId', isEqualTo: user.uid);

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.orderBy('submittedDate', descending: true).limit(100);

      return query.snapshots().map((snapshot) {
        try {
          List<AuditEntry> entries = snapshot.docs
              .map((doc) {
                try {
                  return AuditEntry.fromFirestore(doc);
                } catch (e) {
                  developer.log('Error parsing audit entry ${doc.id}: $e');
                  return null;
                }
              })
              .where((entry) => entry != null)
              .cast<AuditEntry>()
              .toList();

          // Apply search filter if provided
          if (searchQuery != null && searchQuery.isNotEmpty) {
            final lowercaseQuery = searchQuery.toLowerCase();
            entries = entries.where((entry) {
              return entry.goalTitle.toLowerCase().contains(lowercaseQuery) ||
                     entry.evidence.any((evidence) => 
                         evidence.toLowerCase().contains(lowercaseQuery));
            }).toList();
          }

          return entries;
        } catch (e) {
          developer.log('Error processing employee audit entries: $e');
          return <AuditEntry>[];
        }
      }).handleError((error, stackTrace) {
        developer.log('Employee audit entries stream error: $error', error: error, stackTrace: stackTrace);
        return <AuditEntry>[];
      });
    } catch (e) {
      developer.log('Error building employee audit entries stream: $e');
      return Stream.value(<AuditEntry>[]);
    }
  }

  // Verify an audit entry (manager action)
  static Future<void> verifyAuditEntry(String entryId, double score, String? comments) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get manager info
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      await _firestore.collection('audit_entries').doc(entryId).update({
        'status': 'verified',
        'score': score,
        'comments': comments,
        'acknowledgedBy': userData['displayName'] ?? user.displayName ?? 'Manager',
        'acknowledgedById': user.uid,
        'verifiedDate': Timestamp.now(),
      });

      // Log timeline event: verification
      try {
        final event = TimelineService.buildEvent(
          eventType: 'verification',
          description: 'Entry verified with score ${score.toStringAsFixed(1)}',
        );
        await TimelineService.logEvent(entryId, event);
      } catch (e) {
        developer.log('Failed to log verification timeline event: $e');
      }
    } catch (e) {
      developer.log('Error verifying audit entry: $e');
      rethrow;
    }
  }

  // Request changes for an audit entry (manager action)
  static Future<void> requestChanges(String entryId, String reason) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get manager info
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      await _firestore.collection('audit_entries').doc(entryId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'acknowledgedBy': userData['displayName'] ?? user.displayName ?? 'Manager',
        'acknowledgedById': user.uid,
        'rejectedDate': Timestamp.now(),
      });

      // Log timeline event: rejection
      try {
        final event = TimelineService.buildEvent(
          eventType: 'rejection',
          description: 'Changes requested: $reason',
        );
        await TimelineService.logEvent(entryId, event);
      } catch (e) {
        developer.log('Failed to log rejection timeline event: $e');
      }
    } catch (e) {
      developer.log('Error requesting changes: $e');
      rethrow;
    }
  }

  // Get audit statistics
  static Future<Map<String, int>> getAuditStats({String? userId, String? department}) async {
    try {
      Query query = _firestore.collection('audit_entries');

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      } else if (department != null) {
        query = query.where('userDepartment', isEqualTo: department);
      }

      final snapshot = await query.get();
      final entries = snapshot.docs.map((doc) => AuditEntry.fromFirestore(doc)).toList();

      return {
        'total': entries.length,
        'verified': entries.where((e) => e.status == 'verified').length,
        'pending': entries.where((e) => e.status == 'pending').length,
        'rejected': entries.where((e) => e.status == 'rejected').length,
      };
    } catch (e) {
      developer.log('Error getting audit stats: $e');
      return {
        'total': 0,
        'verified': 0,
        'pending': 0,
        'rejected': 0,
      };
    }
  }

}
