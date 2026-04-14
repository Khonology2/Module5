import 'dart:io';
import 'dart:developer' as developer;
import 'package:path_provider/path_provider.dart';

Future<String> savePdfBytes(String fileName, List<int> bytes) async {
  final safeFileName = fileName.replaceAll(RegExp(r'[<>:\"|?*]'), '_');
  final directory = await getApplicationDocumentsDirectory();
  final safePath = '${directory.path}/$safeFileName'.replaceAll('\\', '/');
  final file = File(safePath);
  await file.writeAsBytes(bytes);
  developer.log('PDF saved to: $safePath');
  return safePath;
}
