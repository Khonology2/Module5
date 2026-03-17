import 'dart:developer' as developer;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Global Stream Broker to prevent concurrent Firestore streams
/// Shares streams across all services to eliminate conflicts
class FirestoreStreamBroker {
  static final FirestoreStreamBroker _instance =
      FirestoreStreamBroker._internal();
  factory FirestoreStreamBroker() => _instance;
  FirestoreStreamBroker._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _subscriptions = {};
  final Map<String, StreamController> _controllers = {};
  final Map<String, List<StreamSubscription>> _listeners = {};

  /// Get or create a shared stream for a specific query
  Stream<QuerySnapshot> getSharedStream({
    required String collection,
    Map<String, dynamic>? whereConditions,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    // Create unique key for the query
    final key = _createQueryKey(
      collection: collection,
      whereConditions: whereConditions,
      orderBy: orderBy,
      descending: descending,
      limit: limit,
    );

    // Return existing stream or create new one
    if (_controllers.containsKey(key)) {
      return _controllers[key]!.stream.cast<QuerySnapshot>();
    }

    // Create new stream controller and subscription
    final controller = StreamController<QuerySnapshot>.broadcast();
    _controllers[key] = controller;

    Query query = _firestore.collection(collection);

    // Apply where conditions
    if (whereConditions != null) {
      whereConditions.forEach((field, value) {
        if (value is List && value.length > 1) {
          query = query.where(field, whereIn: value);
        } else {
          query = query.where(field, isEqualTo: value);
        }
      });
    }

    // Apply ordering
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    // Apply limit
    if (limit != null) {
      query = query.limit(limit);
    }

    // Create subscription and broadcast to all listeners
    final subscription = query.snapshots().listen(
      (snapshot) {
        controller.add(snapshot);
      },
      onError: (error) {
        developer.log('Stream broker error for $key: $error');
        controller.addError(error);
      },
    );

    _subscriptions[key] = subscription;
    _listeners[key] = [];

    developer.log('Created shared stream for: $key');

    return controller.stream;
  }

  /// Create a unique key for a query
  String _createQueryKey({
    required String collection,
    Map<String, dynamic>? whereConditions,
    String? orderBy,
    bool descending = false,
    int? limit,
  }) {
    final parts = [collection];

    if (whereConditions != null) {
      whereConditions.forEach((field, value) {
        parts.add('$field=$value');
      });
    }

    if (orderBy != null) {
      parts.add('orderBy=$orderBy');
      parts.add('desc=$descending');
    }

    if (limit != null) {
      parts.add('limit=$limit');
    }

    return parts.join('|');
  }

  /// Get a stream for audit entries (shared across all services)
  Stream<QuerySnapshot> getAuditEntriesStream({
    String? userId,
    bool isManager = false,
    int limit = 500,
  }) {
    // For managers, we need to filter by their department or get all entries
    // For now, let managers see all entries (can be refined later)
    final whereConditions = isManager ? null : {'userId': userId};

    developer.log(
      'Stream broker: Getting audit entries - isManager: $isManager, userId: $userId, conditions: $whereConditions',
    );

    return getSharedStream(
      collection: 'audit_entries',
      whereConditions: whereConditions,
      orderBy: 'submittedDate',
      descending: true,
      limit: limit,
    );
  }

  /// Get a stream for user document (shared across services)
  Stream<DocumentSnapshot> getUserDocumentStream(String userId) {
    final key = 'user_doc_$userId';

    if (_controllers.containsKey(key)) {
      return _controllers[key]!.stream.cast<DocumentSnapshot>();
    }

    final controller = StreamController<DocumentSnapshot>.broadcast();
    _controllers[key] = controller;

    final subscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            controller.add(snapshot);
          },
          onError: (error) {
            developer.log('User doc stream error for $userId: $error');
            controller.addError(error);
          },
        );

    _subscriptions[key] = subscription;
    _listeners[key] = [];

    return controller.stream;
  }

  /// Get a stream for goals (shared across services)
  Stream<QuerySnapshot> getGoalsStream({String? userId}) {
    return getSharedStream(
      collection: 'goals',
      whereConditions: userId != null ? {'userId': userId} : null,
      orderBy: 'createdAt',
      descending: true,
    );
  }

  /// Get a stream for seasons (shared across services)
  Stream<QuerySnapshot> getSeasonsStream({String? participantId}) {
    return getSharedStream(
      collection: 'seasons',
      whereConditions: participantId != null
          ? {'participantIds': participantId}
          : null,
      orderBy: 'createdAt',
      descending: true,
    );
  }

  /// Get a stream for milestone audits (shared across services)
  Stream<QuerySnapshot> getMilestoneAuditsStream() {
    return getSharedStream(
      collection: 'audit_entries',
      whereConditions: {
        'action': [
          'milestone_created',
          'milestone_updated',
          'milestone_status_changed',
          'milestone_completed',
          'milestone_acknowledged',
          'milestone_pending_review',
          'milestone_rejected',
          'milestone_dismissed',
        ],
      },
      orderBy: 'timestamp',
      descending: true,
      limit: 100,
    );
  }

  /// Cleanup all streams (call when app is disposed)
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    for (final controller in _controllers.values) {
      controller.close();
    }
    _subscriptions.clear();
    _controllers.clear();
    _listeners.clear();
    developer.log('FirestoreStreamBroker disposed');
  }

  /// Get statistics for debugging
  Map<String, dynamic> getStats() {
    return {
      'activeSubscriptions': _subscriptions.length,
      'activeControllers': _controllers.length,
      'queries': _subscriptions.keys.toList(),
    };
  }
}
