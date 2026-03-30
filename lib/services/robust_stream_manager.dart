import 'dart:developer' as developer;
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Robust Stream Manager to prevent Firestore conflicts
/// Implements single-source-of-truth pattern for each dataset
class RobustStreamManager {
  static final RobustStreamManager _instance = RobustStreamManager._internal();
  factory RobustStreamManager() => _instance;
  RobustStreamManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, StreamController> _controllers = {};
  final Map<String, int> _listenerCounts = {};

  /// Get audit entries stream with proper conflict prevention
  Stream<QuerySnapshot> getAuditEntriesStream({
    String? userId,
    bool isManager = false,
    int limit = 500,
  }) {
    developer.log('RobustStreamManager: Creating audit entries stream - userId: $userId, isManager: $isManager');
    
    final streamKey = isManager ? 'audit_entries_manager_all' : 'audit_entries_user_$userId';
    
    // Cancel existing subscription if any
    _cancelSubscription(streamKey);
    
    // Create new stream controller
    final controller = StreamController<QuerySnapshot>.broadcast();
    _controllers[streamKey] = controller;
    
    try {
      // Build query with proper constraints
      Query query = _firestore.collection('audit_entries');
      
      if (!isManager && userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      // Only filter by goalId to ensure valid entries
      query = query.where('goalId', isGreaterThan: '');
      
      // Order by submittedDate (must be indexed)
      query = query.orderBy('submittedDate', descending: true);
      
      if (limit > 0) {
        query = query.limit(limit);
      }
      
      developer.log('RobustStreamManager: Query built: ${query.toString()}');
      
      // Create single subscription
      final subscription = query.snapshots().listen(
        (snapshot) {
          developer.log('RobustStreamManager: Stream event - ${snapshot.docs.length} documents');
          controller.add(snapshot);
        },
        onError: (error) {
          developer.log('RobustStreamManager: Stream error: $error', error: error);
          controller.addError(error);
        },
        onDone: () {
          developer.log('RobustStreamManager: Stream completed for $streamKey');
        },
      );
      
      _activeSubscriptions[streamKey] = subscription;
      _listenerCounts[streamKey] = (_listenerCounts[streamKey] ?? 0) + 1;
      
      return controller.stream;
      
    } catch (error) {
      developer.log('RobustStreamManager: Failed to create stream: $error', error: error);
      controller.addError(error);
      return controller.stream;
    }
  }

  /// Get goals stream
  Stream<QuerySnapshot> getGoalsStream({String? userId}) {
    final streamKey = 'goals_${userId ?? 'all'}';
    
    _cancelSubscription(streamKey);
    
    final controller = StreamController<QuerySnapshot>.broadcast();
    _controllers[streamKey] = controller;
    
    try {
      Query query = _firestore.collection('goals');
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      query = query.orderBy('createdAt', descending: true);
      
      final subscription = query.snapshots().listen(
        (snapshot) {
          developer.log('RobustStreamManager: Goals stream event - ${snapshot.docs.length} documents');
          controller.add(snapshot);
        },
        onError: (error) {
          developer.log('RobustStreamManager: Goals stream error: $error', error: error);
          controller.addError(error);
        },
      );
      
      _activeSubscriptions[streamKey] = subscription;
      _listenerCounts[streamKey] = (_listenerCounts[streamKey] ?? 0) + 1;
      
      return controller.stream;
      
    } catch (error) {
      developer.log('RobustStreamManager: Failed to create goals stream: $error', error: error);
      controller.addError(error);
      return controller.stream;
    }
  }

  /// Get milestone audits stream
  Stream<QuerySnapshot> getMilestoneAuditsStream() {
    const streamKey = 'milestone_audits';
    
    _cancelSubscription(streamKey);
    
    final controller = StreamController<QuerySnapshot>.broadcast();
    _controllers[streamKey] = controller;
    
    try {
      final query = _firestore
          .collection('audit_entries')
          .where(
            'action',
            whereIn: [
              'milestone_created',
              'milestone_updated',
              'milestone_status_changed',
              'milestone_completed',
              'milestone_acknowledged',
              'milestone_pending_review',
              'milestone_rejected',
              'milestone_dismissed',
            ],
          )
          .orderBy('timestamp', descending: true);
      
      final subscription = query.snapshots().listen(
        (snapshot) {
          developer.log('RobustStreamManager: Milestone audits stream event - ${snapshot.docs.length} documents');
          controller.add(snapshot);
        },
        onError: (error) {
          developer.log(
            'RobustStreamManager: Milestone audits stream error: $error',
            error: error,
          );
          controller.addError(error);
        },
      );
      
      _activeSubscriptions[streamKey] = subscription;
      _listenerCounts[streamKey] = (_listenerCounts[streamKey] ?? 0) + 1;
      
      return controller.stream;
      
    } catch (error) {
      developer.log('RobustStreamManager: Failed to create milestone audits stream: $error', error: error);
      controller.addError(error);
      return controller.stream;
    }
  }

  /// Cancel subscription and clean up resources
  void _cancelSubscription(String streamKey) {
    if (_activeSubscriptions.containsKey(streamKey)) {
      developer.log('RobustStreamManager: Cancelling existing subscription: $streamKey');
      _activeSubscriptions[streamKey]?.cancel();
      _activeSubscriptions.remove(streamKey);
      _listenerCounts[streamKey] = 0;
    }
    
    // Clean up controller if exists
    if (_controllers.containsKey(streamKey)) {
      _controllers[streamKey]?.close();
      _controllers.remove(streamKey);
    }
  }

  /// Dispose all streams and clean up
  void dispose() {
    developer.log('RobustStreamManager: Disposing all streams');
    
    for (final key in _activeSubscriptions.keys.toList()) {
      _cancelSubscription(key);
    }
    
    _activeSubscriptions.clear();
    _controllers.clear();
    _listenerCounts.clear();
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'activeSubscriptions': _activeSubscriptions.length,
      'activeControllers': _controllers.length,
      'listenerCounts': _listenerCounts,
    };
  }
}
