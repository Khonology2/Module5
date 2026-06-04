import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:pdh/services/backend_auth_service.dart';
import 'package:pdh/services/cloudinary_service.dart';
import 'package:pdh/utils/backend_polling_stream.dart';

class EvidenceFile {
  final String id;
  final String goalId;
  final String userId;
  final String fileName;
  final String url;
  final DateTime uploadedAt;
  final bool acknowledged;
  final String? auditEntryId;
  final String fileType;
  final int fileSize;

  EvidenceFile({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.fileName,
    required this.url,
    required this.uploadedAt,
    required this.acknowledged,
    this.auditEntryId,
    required this.fileType,
    required this.fileSize,
  });

  factory EvidenceFile.fromMap(Map<String, dynamic> data, {String? id}) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
    }

    return EvidenceFile(
      id: id ?? data['id']?.toString() ?? '',
      goalId: data['goalId']?.toString() ?? '',
      userId: data['userId']?.toString() ?? '',
      fileName: data['fileName']?.toString() ?? '',
      url: data['url']?.toString() ?? '',
      uploadedAt: parseDate(data['uploadedAt']),
      acknowledged: data['acknowledged'] == true,
      auditEntryId: data['auditEntryId']?.toString(),
      fileType: data['fileType']?.toString() ?? '',
      fileSize: data['fileSize'] is int
          ? data['fileSize'] as int
          : int.tryParse(data['fileSize']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goalId': goalId,
      'userId': userId,
      'fileName': fileName,
      'url': url,
      'uploadedAt': uploadedAt.toIso8601String(),
      'acknowledged': acknowledged,
      'auditEntryId': auditEntryId,
      'fileType': fileType,
      'fileSize': fileSize,
    };
  }
}

class EvidenceUploadService {
  static final BackendAuthService _backend = BackendAuthService.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static List<EvidenceFile> _mapEvidenceFiles(List<Map<String, dynamic>> items) {
    return items
        .map((item) => EvidenceFile.fromMap(item, id: item['id']?.toString()))
        .toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  // Pick and upload files
  static Future<List<EvidenceFile>> pickAndUploadFiles({
    required String goalId,
    String? auditEntryId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        allowedExtensions: null,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final uploadedFiles = <EvidenceFile>[];

      for (final platformFile in result.files) {
        if (platformFile.bytes != null) {
          final evidenceFile = await _uploadFile(
            bytes: platformFile.bytes!,
            fileName: platformFile.name,
            goalId: goalId,
            userId: user.uid,
            auditEntryId: auditEntryId,
          );
          uploadedFiles.add(evidenceFile);
        }
      }

      return uploadedFiles;
    } catch (e) {
      developer.log('Error picking and uploading files: $e');
      rethrow;
    }
  }

  static Future<EvidenceFile> _uploadFile({
    required List<int> bytes,
    required String fileName,
    required String goalId,
    required String userId,
    String? auditEntryId,
  }) async {
    try {
      final cloudinaryUrl = await CloudinaryService.uploadFileUnsigned(
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
        goalId: goalId,
      );

      final fileExtension = path.extension(fileName);
      final evidenceFile = EvidenceFile(
        id: '',
        goalId: goalId,
        userId: userId,
        fileName: fileName,
        url: cloudinaryUrl,
        uploadedAt: DateTime.now(),
        acknowledged: false,
        auditEntryId: auditEntryId,
        fileType: fileExtension,
        fileSize: bytes.length,
      );

      final created = await _backend.createEvidenceFile(evidenceFile.toMap());
      final updatedFile = EvidenceFile.fromMap(
        created,
        id: created['id']?.toString(),
      );

      developer.log('File uploaded successfully: $fileName');
      return updatedFile;
    } catch (e) {
      developer.log('Error uploading file: $e');
      rethrow;
    }
  }

  static Stream<List<EvidenceFile>> getEvidenceFilesStream(String goalId) {
    return backendPollingStream<List<EvidenceFile>>(
      initialValue: const [],
      fetch: () async {
        final items = await _backend.getEvidenceFiles(goalId: goalId);
        return _mapEvidenceFiles(items);
      },
    );
  }

  static Stream<List<EvidenceFile>> getEvidenceFilesForAuditStream(
    String auditEntryId,
  ) {
    return backendPollingStream<List<EvidenceFile>>(
      initialValue: const [],
      fetch: () async {
        final items = await _backend.getEvidenceFiles(
          auditEntryId: auditEntryId,
        );
        return _mapEvidenceFiles(items);
      },
    );
  }

  static Future<void> deleteEvidenceFile(String fileId) async {
    try {
      developer.log('Note: Cloudinary files are not deleted automatically');
      await _backend.deleteEvidenceFile(fileId);
      developer.log('Evidence file deleted: $fileId');
    } catch (e) {
      developer.log('Error deleting evidence file: $e');
      rethrow;
    }
  }

  static Future<void> acknowledgeEvidenceFile(String fileId) async {
    try {
      await _backend.patchEvidenceFile(fileId, {
        'acknowledged': true,
        'acknowledgedAt': DateTime.now().toIso8601String(),
      });
      developer.log('Evidence file acknowledged: $fileId');
    } catch (e) {
      developer.log('Error acknowledging evidence file: $e');
      rethrow;
    }
  }
}
