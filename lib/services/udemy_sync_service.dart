import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:pdh/models/goal.dart';
import 'package:pdh/services/database_service.dart';

class UdemySyncResult {
  final int progressPercent;
  final int? completedSteps;
  final int? totalSteps;
  final DateTime syncedAt;
  final String syncStatus;
  final String? courseExternalId;
  final String? courseTitle;

  const UdemySyncResult({
    required this.progressPercent,
    required this.syncedAt,
    required this.syncStatus,
    this.completedSteps,
    this.totalSteps,
    this.courseExternalId,
    this.courseTitle,
  });
}

class UdemySyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String? extractCourseId(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;

    final queryValue = uri.queryParameters['courseId'] ??
        uri.queryParameters['course_id'] ??
        uri.queryParameters['course'];
    if (queryValue != null && queryValue.trim().isNotEmpty) {
      return queryValue.trim();
    }

    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index].toLowerCase();
      if ((segment == 'course' || segment == 'courses') &&
          index + 1 < segments.length) {
        final value = segments[index + 1].trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    if (segments.isNotEmpty) {
      final fallback = segments.last.trim();
      if (fallback.isNotEmpty) {
        return fallback;
      }
    }
    return null;
  }

  static Future<UdemySyncResult> syncGoal({
    required Goal goal,
    required String userId,
    String? userEmail,
  }) async {
    if (!goal.isUdemyCourseGoal) {
      throw Exception('This goal is not linked to a Udemy course.');
    }

    final courseUrl = (goal.courseUrl ?? '').trim();
    if (courseUrl.isEmpty) {
      await _updateGoalSyncError(
        goal.id,
        status: 'link_error',
        message: 'The linked Udemy course is missing its URL.',
      );
      throw Exception('The linked Udemy course is missing its URL.');
    }

    final courseExternalId =
        (goal.courseExternalId ?? extractCourseId(courseUrl) ?? '').trim();
    if (courseExternalId.isEmpty) {
      await _updateGoalSyncError(
        goal.id,
        status: 'link_error',
        message:
            'The linked Udemy URL could not be matched to a course id for sync.',
      );
      throw Exception(
        'The linked Udemy URL could not be matched to a course id for sync.',
      );
    }

    await _firestore.collection('goals').doc(goal.id).set({
      'courseExternalId': courseExternalId,
      'courseSyncStatus': 'syncing',
      'courseSyncError': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      final mirroredProgress = await _loadMirroredProgress(
        userId: userId,
        courseExternalId: courseExternalId,
      );
      if (mirroredProgress != null) {
        await DatabaseService.applyCourseSyncProgress(
          goalId: goal.id,
          progress: mirroredProgress.progressPercent,
          completedSteps: mirroredProgress.completedSteps,
          totalSteps: mirroredProgress.totalSteps,
          syncStatus: mirroredProgress.syncStatus,
          syncError: null,
          syncedAt: mirroredProgress.syncedAt,
          courseExternalId: courseExternalId,
          courseTitle: mirroredProgress.courseTitle ?? goal.courseTitle,
        );
        return mirroredProgress;
      }

      final config = await _loadApiConfig();
      if (config == null || !config.enabled) {
        await _updateGoalSyncError(
          goal.id,
          status: 'setup_required',
          message:
              'Udemy sync has not been configured yet. Open the course and ask an admin to connect the integration.',
        );
        throw Exception(
          'Udemy sync has not been configured yet. Ask an admin to connect it first.',
        );
      }

      final normalizedEmail = (userEmail ?? '').trim();
      if (normalizedEmail.isEmpty) {
        await _updateGoalSyncError(
          goal.id,
          status: 'setup_required',
          message:
              'Your account email is missing, so Udemy progress cannot be matched yet.',
        );
        throw Exception(
          'Your account email is missing, so Udemy progress cannot be matched yet.',
        );
      }

      final requestUri = config.buildProgressUri(
        courseExternalId: courseExternalId,
        userEmail: normalizedEmail,
      );
      if (requestUri == null) {
        await _updateGoalSyncError(
          goal.id,
          status: 'setup_required',
          message:
              'Udemy sync needs a progress endpoint template in the integration settings.',
        );
        throw Exception(
          'Udemy sync needs a progress endpoint template in the integration settings.',
        );
      }

      final response = await http.get(
        requestUri,
        headers: config.headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message =
            'Udemy sync failed with status ${response.statusCode}.';
        await _updateGoalSyncError(
          goal.id,
          status: 'error',
          message: message,
        );
        throw Exception(message);
      }

      final payload = jsonDecode(response.body);
      final result = _parseProgressPayload(
        payload,
        fallbackCourseExternalId: courseExternalId,
        fallbackCourseTitle: goal.courseTitle ?? goal.title,
      );

      await DatabaseService.applyCourseSyncProgress(
        goalId: goal.id,
        progress: result.progressPercent,
        completedSteps: result.completedSteps,
        totalSteps: result.totalSteps,
        syncStatus: result.syncStatus,
        syncError: null,
        syncedAt: result.syncedAt,
        courseExternalId: result.courseExternalId ?? courseExternalId,
        courseTitle: result.courseTitle ?? goal.courseTitle,
      );
      return result;
    } catch (e) {
      developer.log('Udemy sync failed for ${goal.id}: $e');
      rethrow;
    }
  }

  static Future<UdemySyncResult?> _loadMirroredProgress({
    required String userId,
    required String courseExternalId,
  }) async {
    final doc = await _firestore
        .collection('users')
        .doc(userId)
        .collection('udemyCourseProgress')
        .doc(courseExternalId)
        .get();
    if (!doc.exists) return null;
    return _parseProgressPayload(
      doc.data() ?? const <String, dynamic>{},
      fallbackCourseExternalId: courseExternalId,
    );
  }

  static Future<_UdemyApiConfig?> _loadApiConfig() async {
    final doc = await _firestore
        .collection('integrations')
        .doc('udemy_business')
        .get();
    if (!doc.exists) return null;
    return _UdemyApiConfig.fromMap(doc.data() ?? const <String, dynamic>{});
  }

  static Future<void> _updateGoalSyncError(
    String goalId, {
    required String status,
    required String message,
  }) {
    return _firestore.collection('goals').doc(goalId).set({
      'courseSyncStatus': status,
      'courseSyncError': message,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static UdemySyncResult _parseProgressPayload(
    dynamic payload, {
    required String fallbackCourseExternalId,
    String? fallbackCourseTitle,
  }) {
    final source = _normalizePayload(payload);
    if (source == null) {
      throw Exception('Udemy progress response was empty.');
    }

    final progressPercent =
        _coercePercent(
          _readFirst(source, const [
            ['progressPercent'],
            ['progress_percentage'],
            ['percent_complete'],
            ['progress'],
            ['completion_percentage'],
            ['result', 'score', 'scaled'],
          ]),
        ) ??
        _derivePercent(source);

    if (progressPercent == null) {
      throw Exception('Udemy progress data did not include a usable percentage.');
    }

    final completedSteps = _coerceInt(
      _readFirst(source, const [
        ['completedSteps'],
        ['completed_lectures'],
        ['completedLectures'],
        ['num_completed_lectures'],
        ['lecture_completed_count'],
        ['progress', 'completed'],
      ]),
    );
    final totalSteps = _coerceInt(
      _readFirst(source, const [
        ['totalSteps'],
        ['total_lectures'],
        ['totalLectures'],
        ['num_lectures'],
        ['lecture_count'],
        ['progress', 'total'],
      ]),
    );

    final syncedAtValue = _readFirst(source, const [
      ['courseLastSyncedAt'],
      ['lastSyncedAt'],
      ['syncedAt'],
      ['updatedAt'],
      ['createdAt'],
    ]);

    return UdemySyncResult(
      progressPercent: progressPercent.clamp(0, 100),
      completedSteps: completedSteps,
      totalSteps: totalSteps,
      syncedAt: _coerceDateTime(syncedAtValue) ?? DateTime.now(),
      syncStatus: progressPercent >= 100 ? 'completed' : 'synced',
      courseExternalId:
          _readFirst(source, const [
            ['courseExternalId'],
            ['courseId'],
            ['course_id'],
            ['courseKey'],
          ])?.toString() ??
          fallbackCourseExternalId,
      courseTitle:
          _readFirst(source, const [
            ['courseTitle'],
            ['title'],
            ['course_name'],
            ['name'],
          ])?.toString() ??
          fallbackCourseTitle,
    );
  }

  static Map<String, dynamic>? _normalizePayload(dynamic payload) {
    if (payload is! Map) return null;
    final source = Map<String, dynamic>.from(payload);

    if (source['results'] is List && (source['results'] as List).isNotEmpty) {
      final first = (source['results'] as List).first;
      if (first is Map) {
        return {
          ...source,
          ...Map<String, dynamic>.from(first),
        };
      }
    }

    if (source['data'] is Map) {
      return {
        ...source,
        ...Map<String, dynamic>.from(source['data'] as Map),
      };
    }

    return source;
  }

  static dynamic _readFirst(
    Map<String, dynamic> source,
    List<List<String>> paths,
  ) {
    for (final path in paths) {
      dynamic current = source;
      var found = true;
      for (final segment in path) {
        if (current is Map && current.containsKey(segment)) {
          current = current[segment];
        } else {
          found = false;
          break;
        }
      }
      if (found && current != null) {
        return current;
      }
    }
    return null;
  }

  static int? _derivePercent(Map<String, dynamic> source) {
    final completed = _coerceInt(
      _readFirst(source, const [
        ['completedSteps'],
        ['completed_lectures'],
        ['completedLectures'],
        ['num_completed_lectures'],
        ['lecture_completed_count'],
        ['progress', 'completed'],
      ]),
    );
    final total = _coerceInt(
      _readFirst(source, const [
        ['totalSteps'],
        ['total_lectures'],
        ['totalLectures'],
        ['num_lectures'],
        ['lecture_count'],
        ['progress', 'total'],
      ]),
    );
    if (completed == null || total == null || total <= 0) {
      return null;
    }
    return ((completed / total) * 100).round();
  }

  static int? _coercePercent(dynamic value) {
    if (value is num) {
      final raw = value.toDouble();
      if (raw <= 1) {
        return (raw * 100).round();
      }
      return raw.round();
    }
    if (value is String) {
      final trimmed = value.trim().replaceAll('%', '');
      final parsed = double.tryParse(trimmed);
      if (parsed == null) return null;
      if (parsed <= 1) {
        return (parsed * 100).round();
      }
      return parsed.round();
    }
    return null;
  }

  static int? _coerceInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static DateTime? _coerceDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }
}

class _UdemyApiConfig {
  final bool enabled;
  final String progressEndpointTemplate;
  final String? basicAuthUsername;
  final String? basicAuthPassword;
  final Map<String, String> headers;

  const _UdemyApiConfig({
    required this.enabled,
    required this.progressEndpointTemplate,
    required this.headers,
    this.basicAuthUsername,
    this.basicAuthPassword,
  });

  factory _UdemyApiConfig.fromMap(Map<String, dynamic> data) {
    final rawHeaders = data['headers'];
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        final key = entry.key.toString().trim();
        final value = entry.value?.toString().trim() ?? '';
        if (key.isNotEmpty && value.isNotEmpty) {
          headers[key] = value;
        }
      }
    }

    final username = (data['basicAuthUsername'] ?? data['clientId'] ?? '')
        .toString()
        .trim();
    final password = (data['basicAuthPassword'] ?? data['clientSecret'] ?? '')
        .toString()
        .trim();
    if (username.isNotEmpty && password.isNotEmpty) {
      headers['Authorization'] = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    }

    return _UdemyApiConfig(
      enabled: data['enabled'] == true,
      progressEndpointTemplate:
          (data['progressEndpointTemplate'] ?? '').toString().trim(),
      headers: headers,
      basicAuthUsername: username.isNotEmpty ? username : null,
      basicAuthPassword: password.isNotEmpty ? password : null,
    );
  }

  Uri? buildProgressUri({
    required String courseExternalId,
    required String userEmail,
  }) {
    final template = progressEndpointTemplate.trim();
    if (template.isEmpty) return null;
    final resolved = template
        .replaceAll('{courseExternalId}', Uri.encodeComponent(courseExternalId))
        .replaceAll('{courseId}', Uri.encodeComponent(courseExternalId))
        .replaceAll('{userEmail}', Uri.encodeComponent(userEmail));
    return Uri.tryParse(resolved);
  }
}
