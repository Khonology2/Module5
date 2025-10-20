import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<String> uploadEvidence({
    required String goalId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final user = _auth.currentUser;
    final uid = user?.uid ?? 'anonymous';
    final path = 'evidence/$uid/$goalId/$fileName';
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: contentType);
    final task = await ref.putData(bytes, metadata);
    return await task.ref.getDownloadURL();
  }

  static Future<void> deleteAllEvidenceForUser(String uid) async {
    final baseRef = _storage.ref().child('evidence/$uid');
    try {
      final list = await baseRef.listAll();
      for (final prefix in list.prefixes) {
        final inner = await prefix.listAll();
        for (final item in inner.items) {
          await item.delete();
        }
      }
      for (final item in list.items) {
        await item.delete();
      }
    } catch (_) {}
  }
}
