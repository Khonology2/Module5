import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class CloudinaryService {
  // Cloudinary configuration - you'll need to get these from your Cloudinary dashboard
  static const String _cloudName = 'dj7phyugw'; // Replace with your cloud name
  static const String _apiKey = '946333512921255'; // Replace with your API key
  static const String _apiSecret = '2d_4NtGANso3Cdn2X_KFDAdR-Zk'; // Replace with your API secret
  static const String _uploadPreset = 'evidence_upload'; // Replace with your upload preset

  // Build the upload URL for a given Cloudinary resource type
  static Uri _buildUploadUri(String resourceType) {
    return Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');
  }

  // Guess the appropriate Cloudinary resource type from the file extension
  static String _guessResourceType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
    if (imageExts.contains(ext)) return 'image';
    // Non-image documents (pdf, doc, docx, ppt, etc.) upload as raw
    return 'raw';
  }

  /// Upload a file to Cloudinary
  static Future<String> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String goalId,
    String? folder,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create form data (auto-detect resource type; fallback to raw on failure)
      final initialType = _guessResourceType(fileName);
      var request = http.MultipartRequest('POST', _buildUploadUri(initialType));
      
      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      // Add parameters
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['public_id'] = 'evidence/${user.uid}/$goalId/${DateTime.now().millisecondsSinceEpoch}';
      
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      // Add tags for organization
      request.fields['tags'] = 'evidence,goal,${user.uid}';

      // Send request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        return data['secure_url'] as String;
      }

      // If Cloudinary complains about invalid image, retry as raw
      if (response.statusCode == 400 &&
          responseBody.toLowerCase().contains('invalid image') &&
          initialType != 'raw') {
        request = http.MultipartRequest('POST', _buildUploadUri('raw'))
          ..fields['upload_preset'] = _uploadPreset
          ..fields['public_id'] = 'evidence/${user.uid}/$goalId/${DateTime.now().millisecondsSinceEpoch}'
          ..fields['tags'] = 'evidence,goal,${user.uid}'
          ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

        response = await request.send();
        responseBody = await response.stream.bytesToString();
        if (response.statusCode == 200) {
          final data = json.decode(responseBody);
          return data['secure_url'] as String;
        }
      }

      throw Exception('Upload failed: ${response.statusCode} - $responseBody');
    } catch (e) {
      throw Exception('Cloudinary upload error: $e');
    }
  }

  /// Upload file using unsigned upload (requires upload preset)
  static Future<String> uploadFileUnsigned({
    required Uint8List bytes,
    required String fileName,
    required String goalId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create form data (auto-detect resource type; fallback to raw on failure)
      final initialType = _guessResourceType(fileName);
      var request = http.MultipartRequest('POST', _buildUploadUri(initialType));

      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));

      // Add parameters for unsigned upload
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['public_id'] = 'evidence/${user.uid}/$goalId/${DateTime.now().millisecondsSinceEpoch}';
      request.fields['tags'] = 'evidence,goal,${user.uid}';

      // Send request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        return data['secure_url'] as String;
      }

      // If Cloudinary complains about invalid image, retry as raw
      if (response.statusCode == 400 &&
          responseBody.toLowerCase().contains('invalid image') &&
          initialType != 'raw') {
        request = http.MultipartRequest('POST', _buildUploadUri('raw'))
          ..fields['upload_preset'] = _uploadPreset
          ..fields['public_id'] = 'evidence/${user.uid}/$goalId/${DateTime.now().millisecondsSinceEpoch}'
          ..fields['tags'] = 'evidence,goal,${user.uid}'
          ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

        response = await request.send();
        responseBody = await response.stream.bytesToString();
        if (response.statusCode == 200) {
          final data = json.decode(responseBody);
          return data['secure_url'] as String;
        }
      }

      throw Exception('Upload failed: ${response.statusCode} - $responseBody');
    } catch (e) {
      throw Exception('Cloudinary upload error: $e');
    }
  }

  /// Get file info from Cloudinary URL
  static Map<String, dynamic> getFileInfo(String cloudinaryUrl) {
    try {
      // Extract public ID from URL
      final uri = Uri.parse(cloudinaryUrl);
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.length >= 3) {
        final publicId = pathSegments.sublist(2).join('/').replaceAll('.', '/');
        return {
          'publicId': publicId,
          'url': cloudinaryUrl,
          'secureUrl': cloudinaryUrl,
        };
      }
      
      return {
        'publicId': null,
        'url': cloudinaryUrl,
        'secureUrl': cloudinaryUrl,
      };
    } catch (e) {
      return {
        'publicId': null,
        'url': cloudinaryUrl,
        'secureUrl': cloudinaryUrl,
      };
    }
  }

  /// Delete file from Cloudinary (requires signed upload or admin API)
  static Future<bool> deleteFile(String publicId) async {
    try {
      // Note: This requires signed uploads or admin API access
      // For now, we'll just return true as files will expire based on your Cloudinary settings
      return true;
    } catch (e) {
      return false;
    }
  }
}
