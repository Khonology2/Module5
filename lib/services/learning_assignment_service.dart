import 'package:pdh/models/learning_assignment.dart';
import 'package:pdh/models/learning_tutorial.dart';
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/onboarding_service.dart';
import 'package:pdh/services/role_service.dart';

typedef LearningFeedItem = ({
  LearningTutorial tutorial,
  LearningAssignment? assignment,
});

class LearningAssignmentService {
  LearningAssignmentService._();
  static final LearningAssignmentService instance = LearningAssignmentService._();

  final BackendAuthService _backend = BackendAuthService.instance;

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
  }) async {
    try {
      final decoded = await _backend.getLearningEmployeeFeed(employeeUserId);
      return _parseEmployeeFeed(decoded);
    } catch (_) {
      // Fallback if the combined feed endpoint is unavailable.
    }

    final tutorials = await _fetchVisibleTutorialsForEmployee(employeeUserId);
    List<LearningAssignment> assignments = [];
    try {
      assignments = await listAssignmentsForEmployee(
        employeeUserId,
        status: status,
      );
    } catch (_) {}

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

  Future<List<LearningTutorial>> _fetchVisibleTutorialsForEmployee(
    String employeeUserId,
  ) async {
    final tutorials = <String, LearningTutorial>{};

    void addTutorials(Iterable<LearningTutorial> items) {
      for (final tutorial in items) {
        if (tutorial.id.isNotEmpty && tutorial.isActive) {
          tutorials[tutorial.id] = tutorial;
        }
      }
    }

    try {
      addTutorials(await listTutorials(null, status: 'active'));
    } catch (_) {}

    if (tutorials.isEmpty) {
      try {
        addTutorials(await _fetchTutorialsFromManagerAccounts());
      } catch (_) {}
    }

    return _sortTutorialsNewestFirst(tutorials.values.toList());
  }

  Future<List<LearningTutorial>> _fetchTutorialsFromManagerAccounts() async {
    final tutorials = <String, LearningTutorial>{};
    try {
      final users = await _backend.listUsers(limit: 500);
      for (final user in users) {
        if (!_isManagerLikeUser(user)) continue;
        final managerId =
            (user['userId'] ?? user['id'] ?? '').toString().trim();
        if (managerId.isEmpty) continue;
        try {
          final items = await listTutorials(managerId);
          for (final tutorial in items) {
            if (tutorial.isActive) {
              tutorials[tutorial.id] = tutorial;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return tutorials.values.toList();
  }

  bool _isManagerLikeUser(Map<String, dynamic> user) {
    final moduleAccess = user['moduleAccessRole']?.toString() ??
        user['module_access_role']?.toString();
    final persona = OnboardingService.extractPersonaForApp(moduleAccess);
    final role = RoleService.instance.normalizeRoleLabel(
      persona ?? user['role']?.toString(),
    );
    return role == 'manager' || role == 'admin';
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
