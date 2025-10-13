import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal.dart';
import 'package:pdh/models/audit_entry.dart';
import 'package:pdh/services/repository_service.dart';
import 'package:pdh/services/timeline_service.dart';
import 'package:pdh/services/audit_logger.dart';

// AuditEntry model moved to lib/models/audit_entry.dart

class AuditService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Submit a completed goal for audit
<<<<<<< HEAD
  static Future<void> submitGoalForAudit(
    Goal goal,
    List<String> evidence,
  ) async {
=======
  static Future<void> submitGoalForAudit(Goal goal, List<String> evidence) async {
>>>>>>> origin/lihle-manager
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

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
<<<<<<< HEAD
        userDisplayName:
            userData['displayName'] ?? user.displayName ?? 'Unknown User',
        userDepartment: userData['department'] ?? 'Unknown',
      );

      final docRef = await _firestore
          .collection('audit_entries')
          .add(auditEntry.toFirestore());

      // Timeline: Goal submitted for verification
      await TimelineService.logEvent(
        docRef.id,
        TimelineService.buildEvent(
          eventType: 'submission',
          description: 'Goal submitted for verification.',
        ),
      );
=======
        userDisplayName: userData['displayName'] ?? user.displayName ?? 'Unknown User',
        userDepartment: userData['department'] ?? 'Unknown',
      );

      await _firestore.collection('audit_entries').add(auditEntry.toFirestore());
>>>>>>> origin/lihle-manager
    } catch (e) {
      developer.log('Error submitting goal for audit: $e');
      rethrow;
    }
  }

  // Get audit entries stream for managers (all entries)
  static Stream<List<AuditEntry>> getManagerAuditEntriesStream({
    String? department,
    String? status,
    String? searchQuery,
  }) {
    Query query = _firestore.collection('audit_entries');

    // Add filters
    if (department != null && department.isNotEmpty) {
      query = query.where('userDepartment', isEqualTo: department);
    }
<<<<<<< HEAD

=======
    
>>>>>>> origin/lihle-manager
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    // Order by submission date (most recent first)
    query = query.orderBy('submittedDate', descending: true);

    return query.snapshots().map((snapshot) {
      List<AuditEntry> entries = snapshot.docs
          .map((doc) => AuditEntry.fromFirestore(doc))
          .toList();

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowercaseQuery = searchQuery.toLowerCase();
        entries = entries.where((entry) {
          return entry.goalTitle.toLowerCase().contains(lowercaseQuery) ||
<<<<<<< HEAD
              entry.userDisplayName.toLowerCase().contains(lowercaseQuery) ||
              entry.userDepartment.toLowerCase().contains(lowercaseQuery) ||
              entry.evidence.any(
                (evidence) => evidence.toLowerCase().contains(lowercaseQuery),
              );
=======
                 entry.userDisplayName.toLowerCase().contains(lowercaseQuery) ||
                 entry.userDepartment.toLowerCase().contains(lowercaseQuery) ||
                 entry.evidence.any((evidence) => 
                     evidence.toLowerCase().contains(lowercaseQuery));
>>>>>>> origin/lihle-manager
        }).toList();
      }

      return entries;
    });
  }

  // Get audit entries stream for employees (their own entries)
  static Stream<List<AuditEntry>> getEmployeeAuditEntriesStream({
    String? status,
    String? searchQuery,
  }) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    Query query = _firestore
        .collection('audit_entries')
        .where('userId', isEqualTo: user.uid);

    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    query = query.orderBy('submittedDate', descending: true);

    return query.snapshots().map((snapshot) {
      List<AuditEntry> entries = snapshot.docs
          .map((doc) => AuditEntry.fromFirestore(doc))
          .toList();

      // Apply search filter if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowercaseQuery = searchQuery.toLowerCase();
        entries = entries.where((entry) {
          return entry.goalTitle.toLowerCase().contains(lowercaseQuery) ||
<<<<<<< HEAD
              entry.evidence.any(
                (evidence) => evidence.toLowerCase().contains(lowercaseQuery),
              );
=======
                 entry.evidence.any((evidence) => 
                     evidence.toLowerCase().contains(lowercaseQuery));
>>>>>>> origin/lihle-manager
        }).toList();
      }

      return entries;
    });
  }

  // Verify an audit entry (manager action)
<<<<<<< HEAD
  static Future<void> verifyAuditEntry(
    String entryId,
    double score,
    String? comments,
  ) async {
=======
  static Future<void> verifyAuditEntry(String entryId, double score, String? comments) async {
>>>>>>> origin/lihle-manager
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
<<<<<<< HEAD
        'acknowledgedBy':
            userData['displayName'] ?? user.displayName ?? 'Manager',
        'acknowledgedById': user.uid,
        'verifiedDate': Timestamp.now(),
      });
      // Sync to repository as completed goal
      final updatedDoc = await _firestore
          .collection('audit_entries')
          .doc(entryId)
          .get();
      final updatedEntry = AuditEntry.fromFirestore(updatedDoc);
      await RepositoryService.addVerifiedGoalToRepository(updatedEntry);

      // Timeline: Goal verified by Manager
      await TimelineService.logEvent(
        entryId,
        TimelineService.buildEvent(
          eventType: 'verification',
          description: 'Goal verified by Manager.',
        ),
      );

      // Auto audit log: manager acknowledgment/verification
      await AuditLogger.logAuditAction(
        goalId: entryId,
        actionType: 'manager_acknowledgment',
        description: 'Manager verified goal with score $score',
      );
=======
        'acknowledgedBy': userData['displayName'] ?? user.displayName ?? 'Manager',
        'acknowledgedById': user.uid,
        'verifiedDate': Timestamp.now(),
      });
>>>>>>> origin/lihle-manager
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
<<<<<<< HEAD
        'acknowledgedBy':
            userData['displayName'] ?? user.displayName ?? 'Manager',
        'acknowledgedById': user.uid,
        'rejectedDate': Timestamp.now(),
      });

      // Timeline: Goal returned for changes
      await TimelineService.logEvent(
        entryId,
        TimelineService.buildEvent(
          eventType: 'rejection',
          description: 'Goal returned for changes.',
        ),
      );
=======
        'acknowledgedBy': userData['displayName'] ?? user.displayName ?? 'Manager',
        'acknowledgedById': user.uid,
        'rejectedDate': Timestamp.now(),
      });
>>>>>>> origin/lihle-manager
    } catch (e) {
      developer.log('Error requesting changes: $e');
      rethrow;
    }
  }

  // Get audit statistics
<<<<<<< HEAD
  static Future<Map<String, int>> getAuditStats({
    String? userId,
    String? department,
  }) async {
=======
  static Future<Map<String, int>> getAuditStats({String? userId, String? department}) async {
>>>>>>> origin/lihle-manager
    try {
      Query query = _firestore.collection('audit_entries');

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      } else if (department != null) {
        query = query.where('userDepartment', isEqualTo: department);
      }

      final snapshot = await query.get();
<<<<<<< HEAD
      final entries = snapshot.docs
          .map((doc) => AuditEntry.fromFirestore(doc))
          .toList();
=======
      final entries = snapshot.docs.map((doc) => AuditEntry.fromFirestore(doc)).toList();
>>>>>>> origin/lihle-manager

      return {
        'total': entries.length,
        'verified': entries.where((e) => e.status == 'verified').length,
        'pending': entries.where((e) => e.status == 'pending').length,
        'rejected': entries.where((e) => e.status == 'rejected').length,
      };
    } catch (e) {
      developer.log('Error getting audit stats: $e');
<<<<<<< HEAD
      return {'total': 0, 'verified': 0, 'pending': 0, 'rejected': 0};
=======
      return {
        'total': 0,
        'verified': 0,
        'pending': 0,
        'rejected': 0,
      };
>>>>>>> origin/lihle-manager
    }
  }

  // Get mock data for development/fallback
  static List<AuditEntry> getMockAuditEntries() {
    return [
      AuditEntry(
        id: 'mock1',
        userId: 'user1',
        goalId: 'goal1',
        goalTitle: 'Increase Customer Satisfaction Score',
        completedDate: DateTime(2024, 3, 15),
        submittedDate: DateTime(2024, 3, 16),
        status: 'verified',
        evidence: [
          'Survey Results Report',
          'Dashboard Analytics Link',
          'Customer Feedback Files',
        ],
        acknowledgedBy: 'Sarah Chen',
        score: 4.8,
        userDisplayName: 'John Doe',
        userDepartment: 'Customer Success',
      ),
      AuditEntry(
        id: 'mock2',
        userId: 'user2',
        goalId: 'goal2',
        goalTitle: 'Launch New Product Feature',
        completedDate: DateTime(2024, 2, 28),
        submittedDate: DateTime(2024, 3, 1),
        status: 'pending',
<<<<<<< HEAD
        evidence: ['Feature Specification Document', 'GitHub Repository Link'],
=======
        evidence: [
          'Feature Specification Document',
          'GitHub Repository Link',
        ],
>>>>>>> origin/lihle-manager
        userDisplayName: 'Jane Smith',
        userDepartment: 'Engineering',
      ),
      AuditEntry(
        id: 'mock3',
        userId: 'user3',
        goalId: 'goal3',
        goalTitle: 'Strategic Market Expansion Plan',
        completedDate: DateTime(2024, 1, 20),
        submittedDate: DateTime(2024, 1, 22),
        status: 'verified',
        evidence: [
          'Market Research Summary',
          'Competitor Analysis',
          'Expansion Proposal Document',
        ],
        acknowledgedBy: 'Mike Johnson',
        score: 4.5,
        userDisplayName: 'Alice Brown',
        userDepartment: 'Strategy',
      ),
    ];
  }
}
