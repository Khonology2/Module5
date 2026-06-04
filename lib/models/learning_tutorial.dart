import 'package:pdh/utils/date_parse.dart';

class LearningTutorial {
  final String id;
  final String managerId;
  final String title;
  final String? description;
  final String videoUrl;
  final String provider;
  final int? durationMinutes;
  final String? thumbnailUrl;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LearningTutorial({
    required this.id,
    required this.managerId,
    required this.title,
    this.description,
    required this.videoUrl,
    this.provider = 'udemy',
    this.durationMinutes,
    this.thumbnailUrl,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';

  factory LearningTutorial.fromMap(Map<String, dynamic> map) {
    return LearningTutorial(
      id: (map['id'] ?? '').toString(),
      managerId: (map['managerId'] ?? map['manager_id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: map['description']?.toString(),
      videoUrl: (map['videoUrl'] ?? map['video_url'] ?? '').toString(),
      provider: (map['provider'] ?? 'udemy').toString(),
      durationMinutes: _parseInt(map['durationMinutes'] ?? map['duration_minutes']),
      thumbnailUrl: map['thumbnailUrl']?.toString() ?? map['thumbnail_url']?.toString(),
      status: (map['status'] ?? 'active').toString(),
      createdAt: parseNullableDate(map['createdAt'] ?? map['created_at']),
      updatedAt: parseNullableDate(map['updatedAt'] ?? map['updated_at']),
    );
  }

  Map<String, dynamic> toCreatePayload({required String managerId}) {
    return {
      'managerId': managerId,
      'title': title,
      if (description != null && description!.isNotEmpty) 'description': description,
      'videoUrl': videoUrl,
      'provider': provider,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
        'thumbnailUrl': thumbnailUrl,
      'status': status,
    };
  }

  Map<String, dynamic> toUpdatePayload() {
    return {
      'title': title,
      if (description != null) 'description': description,
      'videoUrl': videoUrl,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'status': status,
    };
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
