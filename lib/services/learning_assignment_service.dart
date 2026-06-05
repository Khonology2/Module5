import 'package:flutter/foundation.dart';
import 'package:pdh/models/learning_assignment.dart';
import 'package:pdh/models/learning_tutorial.dart';
import 'package:pdh/services/backend_auth_service.dart';

typedef LearningFeedItem = ({
  LearningTutorial tutorial,
  LearningAssignment? assignment,
});

class LearningFeedException implements Exception {
  LearningFeedException({this.feedError, this.fallbackError});

  final Object? feedError;
  final Object? fallbackError;

  bool get isTimeout {
    final feedMsg = feedError?.toString() ?? '';
    final fallbackMsg = fallbackError?.toString() ?? '';
    return feedMsg.contains('timeout') || fallbackMsg.contains('timeout');
  }

  @override
  String toString() {
    if (isTimeout) {
      return 'The server is taking longer than usual to load tutorials. '
          'Please wait a moment and tap Retry.';
    }
    return 'Could not load tutorials right now. Please tap Retry.';
  }
}

class LearningAssignmentService {
  LearningAssignmentService._();
  static final LearningAssignmentService instance = LearningAssignmentService._();

  final BackendAuthService _backend = BackendAuthService.instance;

  static const Duration _feedCacheTtl = Duration(minutes: 15);
  static const int _employeeFeedLimit = 50;

  String? _cachedFeedEmployeeId;
  List<LearningFeedItem>? _cachedFeed;
  DateTime? _cachedFeedAt;
  final Map<String, Future<List<LearningFeedItem>>> _inFlightFeeds = {};

  /// Bumps when employee feed cache is updated (for background prefetch listeners).
  final ValueNotifier<int> feedRevision = ValueNotifier<int>(0);

  List<LearningFeedItem>? cachedFeedForEmployee(String employeeUserId) {
    if (_cachedFeedEmployeeId != employeeUserId ||
        _cachedFeed == null ||
        _cachedFeedAt == null) {
      return null;
    }
    if (DateTime.now().difference(_cachedFeedAt!) > _feedCacheTtl) {
      return null;
    }
    return List<LearningFeedItem>.from(_cachedFeed!);
  }

  void _storeFeedCache(String employeeUserId, List<LearningFeedItem> feed) {
    _cachedFeedEmployeeId = employeeUserId;
    _cachedFeed = List<LearningFeedItem>.from(feed);
    _cachedFeedAt = DateTime.now();
    feedRevision.value++;
  }

  void invalidateEmployeeFeedCache([String? employeeUserId]) {
    if (employeeUserId != null &&
        _cachedFeedEmployeeId != null &&
        _cachedFeedEmployeeId != employeeUserId) {
      return;
    }
    _cachedFeedEmployeeId = null;
    _cachedFeed = null;
    _cachedFeedAt = null;
    if (employeeUserId != null) {
      _inFlightFeeds.remove(employeeUserId);
    } else {
      _inFlightFeeds.clear();
    }
  }

  /// Prefetch tutorials in the background so My Learning opens instantly.
  Future<void> warmupEmployeeFeed(String employeeUserId) async {
    if (cachedFeedForEmployee(employeeUserId) != null) return;
    try {
      await _fetchAndCacheFeed(employeeUserId);
    } catch (e) {
      debugPrint('Learning feed warmup failed: $e');
    }
  }

  Future<({
    List<LearningTutorial> tutorials,
    List<LearningAssignment> assignments,
  })> loadManagerDashboard(String managerId) async {
    try {
      final decoded = await _backend.getLearningManagerDashboard(managerId);
      return _parseManagerDashboard(decoded);
    } catch (_) {
      final tutorials = await listTutorials(managerId);
      final assignments = await listAssignments(managerId);
      return (tutorials: tutorials, assignments: assignments);
    }
  }

  ({
    List<LearningTutorial> tutorials,
    List<LearningAssignment> assignments,
  }) _parseManagerDashboard(Map<String, dynamic> decoded) {
    final tutorialItems = decoded['tutorials'];
    final assignmentItems = decoded['assignments'];
    final tutorials = (tutorialItems is List ? tutorialItems : const <dynamic>[])
        .whereType<Map>()
        .map((e) => LearningTutorial.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    final assignments =
        (assignmentItems is List ? assignmentItems : const <dynamic>[])
            .whereType<Map>()
            .map((e) => LearningAssignment.fromMap(Map<String, dynamic>.from(e)))
            .toList();
    return (tutorials: tutorials, assignments: assignments);
  }

  Future<List<LearningTutorial>> listTutorials(
    String? managerId, {
    String? status,
  }) async {
    final items = await _backend.getLearningTutorials(
      managerId,
      status: status,
    );
    return items.map(LearningTutorial.fromMap).toList();
  }

  Future<LearningTutorial> getTutorial(String tutorialId) async {
    final row = await _backend.getLearningTutorial(tutorialId);
    return LearningTutorial.fromMap(row);
  }

  Future<LearningTutorial> createTutorial(LearningTutorial tutorial) async {
    final row = await _backend.createLearningTutorial(
      tutorial.toCreatePayload(managerId: tutorial.managerId),
    );
    return LearningTutorial.fromMap(row);
  }

  Future<LearningTutorial> updateTutorial(
    String tutorialId,
    Map<String, dynamic> payload,
  ) async {
    final row = await _backend.patchLearningTutorial(tutorialId, payload);
    return LearningTutorial.fromMap(row);
  }

  Future<List<LearningAssignment>> listAssignments(
    String managerId, {
    String? employeeUserId,
    String? status,
  }) async {
    final items = await _backend.getLearningAssignments(
      managerId: managerId,
      employeeUserId: employeeUserId,
      status: status,
    );
    return items.map(LearningAssignment.fromMap).toList();
  }

  Future<List<LearningAssignment>> listAssignmentsForEmployee(
    String employeeUserId, {
    String? status,
  }) async {
    final items = await _backend.getLearningAssignmentsForEmployee(
      employeeUserId,
      status: status,
      enrichTutorial: true,
    );
    return items.map(LearningAssignment.fromMap).toList();
  }

  Future<List<LearningFeedItem>> listFeedForEmployee(
    String employeeUserId, {
    String? status,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = cachedFeedForEmployee(employeeUserId);
      if (cached != null) {
        return cached;
      }
      final inFlight = _inFlightFeeds[employeeUserId];
      if (inFlight != null) {
        return inFlight;
      }
    } else {
      invalidateEmployeeFeedCache(employeeUserId);
    }

    return _fetchAndCacheFeed(employeeUserId, status: status);
  }

  Future<List<LearningFeedItem>> _fetchAndCacheFeed(
    String employeeUserId, {
    String? status,
  }) async {
    final existing = _inFlightFeeds[employeeUserId];
    if (existing != null) {
      return existing;
    }

    final future = _loadFeedFromNetwork(employeeUserId, status: status);
    _inFlightFeeds[employeeUserId] = future;
    try {
      final feed = await future;
      _storeFeedCache(employeeUserId, feed);
      return feed;
    } finally {
      _inFlightFeeds.remove(employeeUserId);
    }
  }

  Future<List<LearningFeedItem>> _loadFeedFromNetwork(
    String employeeUserId, {
    String? status,
  }) async {
    Object? feedError;
    try {
      final decoded = await _backend.getLearningEmployeeFeed(
        employeeUserId,
        limit: _employeeFeedLimit,
      );
      return _parseEmployeeFeed(decoded);
    } catch (e) {
      feedError = e;
      debugPrint('Learning employee feed failed, using fallback: $e');
    }

    try {
      return await _fetchFeedFallback(employeeUserId, status: status);
    } catch (fallbackError) {
      debugPrint('Learning feed fallback failed: $fallbackError');
      throw LearningFeedException(
        feedError: feedError,
        fallbackError: fallbackError,
      );
    }
  }

  Future<List<LearningFeedItem>> refreshFeedForEmployee(
    String employeeUserId, {
    String? status,
  }) {
    invalidateEmployeeFeedCache(employeeUserId);
    return listFeedForEmployee(
      employeeUserId,
      status: status,
      forceRefresh: true,
    );
  }

  Future<List<LearningFeedItem>> _fetchFeedFallback(
    String employeeUserId, {
    String? status,
  }) async {
    // Sequential requests avoid overloading the single-worker dev backend.
    final tutorials = await listTutorials(null, status: 'active');
    final assignments = await listAssignmentsForEmployee(
      employeeUserId,
      status: status,
    );
    return _mergeTutorialsAndAssignments(tutorials, assignments);
  }

  List<LearningFeedItem> _parseEmployeeFeed(Map<String, dynamic> decoded) {
    final tutorialItems = decoded['tutorials'];
    final assignmentItems = decoded['assignments'];
    final tutorials = (tutorialItems is List ? tutorialItems : const <dynamic>[])
        .whereType<Map>()
        .map((e) => LearningTutorial.fromMap(Map<String, dynamic>.from(e)))
        .where((t) => t.id.isNotEmpty && t.isActive)
        .toList();
    final assignments =
        (assignmentItems is List ? assignmentItems : const <dynamic>[])
            .whereType<Map>()
            .map((e) => LearningAssignment.fromMap(Map<String, dynamic>.from(e)))
            .toList();
    return _mergeTutorialsAndAssignments(tutorials, assignments);
  }

  List<LearningFeedItem> _mergeTutorialsAndAssignments(
    List<LearningTutorial> tutorials,
    List<LearningAssignment> assignments,
  ) {
    final tutorialsById = <String, LearningTutorial>{
      for (final tutorial in tutorials) tutorial.id: tutorial,
    };
    final assignmentsByTutorialId = <String, LearningAssignment>{
      for (final assignment in assignments) assignment.tutorialId: assignment,
    };

    for (final assignment in assignments) {
      if (assignment.tutorialId.isEmpty) continue;
      if (tutorialsById.containsKey(assignment.tutorialId)) continue;
      final title = assignment.tutorialTitle ?? assignment.title;
      tutorialsById[assignment.tutorialId] = LearningTutorial(
        id: assignment.tutorialId,
        managerId: assignment.managerId,
        title: title,
        description: assignment.tutorialDescription,
        videoUrl: assignment.videoUrl ?? '',
        durationMinutes: assignment.durationMinutes,
        status: 'active',
      );
    }

    return _sortTutorialsNewestFirst(tutorialsById.values.toList())
        .map((tutorial) {
      return (
        tutorial: tutorial,
        assignment: assignmentsByTutorialId[tutorial.id],
      );
    }).toList();
  }

  List<LearningTutorial> _sortTutorialsNewestFirst(
    List<LearningTutorial> tutorials,
  ) {
    return tutorials
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
  }

  Future<LearningAssignment> assignTutorialToEmployee({
    required String managerId,
    required String tutorialId,
    required String employeeUserId,
    required DateTime dueDate,
    int points = 10,
    String? notes,
  }) async {
    final payload = LearningAssignment(
      id: '',
      tutorialId: tutorialId,
      employeeUserId: employeeUserId,
      managerId: managerId,
      title: '',
      status: 'assigned',
      dueDate: dueDate,
      points: points,
      notes: notes,
    ).toAssignPayload(
      managerId: managerId,
      tutorialId: tutorialId,
      employeeUserId: employeeUserId,
      dueDate: dueDate,
      points: points,
      notes: notes,
    );
    final row = await _backend.createLearningAssignment(payload);
    return LearningAssignment.fromMap(row);
  }

  Future<LearningAssignment> patchAssignment(
    String assignmentId,
    Map<String, dynamic> payload,
  ) async {
    final row = await _backend.patchLearningAssignment(assignmentId, payload);
    return LearningAssignment.fromMap(row);
  }

  Future<LearningAssignment> startAssignment({
    required String assignmentId,
    required String employeeUserId,
  }) {
    return patchAssignment(assignmentId, {
      'employeeUserId': employeeUserId,
      'status': 'in_progress',
    });
  }

  Future<LearningAssignment> updateWatchProgress({
    required String assignmentId,
    required String employeeUserId,
    required int watchProgress,
  }) {
    return patchAssignment(assignmentId, {
      'employeeUserId': employeeUserId,
      'watchProgress': watchProgress,
      'status': watchProgress >= 100 ? 'completed' : 'in_progress',
    });
  }

  Future<LearningAssignment> completeAssignment({
    required String assignmentId,
    required String employeeUserId,
  }) {
    return patchAssignment(assignmentId, {
      'employeeUserId': employeeUserId,
      'status': 'completed',
      'watchProgress': 100,
    });
  }
}
