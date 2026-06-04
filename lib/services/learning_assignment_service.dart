import 'package:pdh/models/learning_assignment.dart';
import 'package:pdh/models/learning_tutorial.dart';
import 'package:pdh/services/backend_auth_service.dart';

class LearningAssignmentService {
  LearningAssignmentService._();
  static final LearningAssignmentService instance = LearningAssignmentService._();

  final BackendAuthService _backend = BackendAuthService.instance;

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
      managerId,
      employeeUserId: employeeUserId,
      status: status,
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
}
