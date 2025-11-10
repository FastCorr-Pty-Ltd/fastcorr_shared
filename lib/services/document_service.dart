import 'dart:developer';

import 'package:fastcorr_shared/models/upload_file_data.dart';
import 'package:universal_html/html.dart' as html;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class DocumentService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  void downloadPdf(UploadFileData file) {
    if (file.fileUrl == null || file.fileUrl!.isEmpty) {
      log('Error: File URL is null or empty for file: ${file.fileName}');
      return;
    }

    final sanitizedFileName = _sanitizeFileName(file.fileName);

    log('Downloading file: $sanitizedFileName from URL: ${file.fileUrl}');
    html.AnchorElement(href: file.fileUrl)
      ..setAttribute('download', sanitizedFileName)
      ..click();
  }

  Future<void> printPdfFromStorage(String fileUrl) async {
    html.window.open(fileUrl, '_blank');
  }

  Future<String> uploadFileToStorage(PlatformFile file) async {
    try {
      // Decode and sanitize filename for cross-platform consistency
      final fileName = _sanitizeFileName(file.name);

      // Create unique timestamp folder to prevent overwrites
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Create storage reference with timestamp folder for overwrite-safety
      final storageRef = _storage.ref().child('task_files/$timestamp/$fileName');

      // Upload file
      Uint8List? fileBytes = file.bytes;
      if (fileBytes == null) {
        // For web, we might need to handle this differently
        throw Exception('File bytes not available');
      }

      final uploadTask = storageRef.putData(fileBytes);
      final snapshot = await uploadTask;

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  String _sanitizeFileName(String fileName) {
    try {
      String sanitized = Uri.decodeComponent(fileName);

      sanitized = sanitized.replaceAll('../', '');
      sanitized = sanitized.replaceAll('..\\', '');
      sanitized = sanitized.replaceAll(RegExp(r'[\\/:]'), '_');
      sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
      sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

      if (sanitized.isEmpty) {
        sanitized = 'document';
      }

      if (sanitized.length > 200) {
        final parts = sanitized.split('.');
        if (parts.length > 1) {
          final extension = parts.removeLast();
          final maxBaseLength = 195;
          final nameWithoutExt = parts.join('.');
          final truncated = nameWithoutExt.length > maxBaseLength
              ? nameWithoutExt.substring(0, maxBaseLength)
              : nameWithoutExt;
          sanitized = '$truncated.$extension';
        } else {
          sanitized = sanitized.substring(0, 200);
        }
      }

      return sanitized;
    } catch (_) {
      return fileName;
    }
  }
}
