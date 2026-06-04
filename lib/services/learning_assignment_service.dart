import 'package:pdh/models/learning_assignment.dart';
import 'package:pdh/models/learning_tutorial.dart';
import 'package:pdh/services/backend_auth_service.dart';

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
    String managerId, {
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
