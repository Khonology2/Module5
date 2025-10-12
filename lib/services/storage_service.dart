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
}


