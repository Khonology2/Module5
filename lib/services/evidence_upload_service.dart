import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:pdh/services/cloudinary_service.dart';

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

  factory EvidenceFile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EvidenceFile(
      id: doc.id,
      goalId: data['goalId'] ?? '',
      userId: data['userId'] ?? '',
      fileName: data['fileName'] ?? '',
      url: data['url'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acknowledged: data['acknowledged'] ?? false,
      auditEntryId: data['auditEntryId'],
      fileType: data['fileType'] ?? '',
      fileSize: data['fileSize'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'goalId': goalId,
      'userId': userId,
      'fileName': fileName,
      'url': url,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'acknowledged': acknowledged,
      'auditEntryId': auditEntryId,
      'fileType': fileType,
      'fileSize': fileSize,
    };
  }
}

class EvidenceUploadService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Pick and upload files
  static Future<List<EvidenceFile>> pickAndUploadFiles({
    required String goalId,
    String? auditEntryId,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Pick files
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        allowedExtensions: null, // Allow all file types
        withData: true, // Ensure bytes are available on Web/Desktop
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

  // Upload file to Cloudinary
  static Future<EvidenceFile> _uploadFile({
    required List<int> bytes,
    required String fileName,
    required String goalId,
    required String userId,
    String? auditEntryId,
  }) async {
    try {
      // Upload to Cloudinary
      final cloudinaryUrl = await CloudinaryService.uploadFileUnsigned(
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
        goalId: goalId,
      );

      // Create evidence file record
      final fileExtension = path.extension(fileName);
      final evidenceFile = EvidenceFile(
        id: '', // Will be set by Firestore
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

      // Save metadata to Firestore
      final docRef = await _firestore
          .collection('evidence_files')
          .add(evidenceFile.toFirestore());

      // Update the ID
      final updatedFile = EvidenceFile(
        id: docRef.id,
        goalId: evidenceFile.goalId,
        userId: evidenceFile.userId,
        fileName: evidenceFile.fileName,
        url: evidenceFile.url,
        uploadedAt: evidenceFile.uploadedAt,
        acknowledged: evidenceFile.acknowledged,
        auditEntryId: evidenceFile.auditEntryId,
        fileType: evidenceFile.fileType,
        fileSize: evidenceFile.fileSize,
      );

      developer.log('File uploaded successfully: $fileName');
      return updatedFile;
    } catch (e) {
      developer.log('Error uploading file: $e');
      rethrow;
    }
  }

  // Get content type based on file extension
  static String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.ppt':
      case '.pptx':
        return 'application/vnd.ms-powerpoint';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.txt':
        return 'text/plain';
      case '.zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  // Get evidence files for a goal
  static Stream<List<EvidenceFile>> getEvidenceFilesStream(String goalId) {
    return _firestore
        .collection('evidence_files')
        .where('goalId', isEqualTo: goalId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EvidenceFile.fromFirestore(doc))
            .toList());
  }

  // Get evidence files for an audit entry
  static Stream<List<EvidenceFile>> getEvidenceFilesForAuditStream(String auditEntryId) {
    return _firestore
        .collection('evidence_files')
        .where('auditEntryId', isEqualTo: auditEntryId)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EvidenceFile.fromFirestore(doc))
            .toList());
  }

  // Delete evidence file
  static Future<void> deleteEvidenceFile(String fileId) async {
    try {
      // Get file document
      final doc = await _firestore.collection('evidence_files').doc(fileId).get();
      if (!doc.exists) return;

      // Note: Cloudinary files are not deleted automatically
      // They will be cleaned up by Cloudinary's lifecycle policies
      developer.log('Note: Cloudinary files are not deleted automatically');

      // Delete from Firestore
      await _firestore.collection('evidence_files').doc(fileId).delete();

      developer.log('Evidence file deleted: $fileId');
    } catch (e) {
      developer.log('Error deleting evidence file: $e');
      rethrow;
    }
  }

  // Acknowledge evidence file (for managers)
  static Future<void> acknowledgeEvidenceFile(String fileId) async {
    try {
      await _firestore.collection('evidence_files').doc(fileId).update({
        'acknowledged': true,
        'acknowledgedAt': Timestamp.now(),
      });
      developer.log('Evidence file acknowledged: $fileId');
    } catch (e) {
      developer.log('Error acknowledging evidence file: $e');
      rethrow;
    }
  }
}
