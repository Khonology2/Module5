import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdh/models/goal.dart';

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

      await _firestore.collection('audit_entries').add(auditEntry.toFirestore());
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
                 entry.userDisplayName.toLowerCase().contains(lowercaseQuery) ||
                 entry.userDepartment.toLowerCase().contains(lowercaseQuery) ||
                 entry.evidence.any((evidence) => 
                     evidence.toLowerCase().contains(lowercaseQuery));
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
                 entry.evidence.any((evidence) => 
                     evidence.toLowerCase().contains(lowercaseQuery));
        }).toList();
      }

      return entries;
    });
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
        evidence: [
          'Feature Specification Document',
          'GitHub Repository Link',
        ],
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
