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

    log('Downloading file: ${file.fileName} from URL: ${file.fileUrl}');
    html.AnchorElement(href: file.fileUrl)
      ..setAttribute('download', file.fileName)
      ..click();
  }

  Future<void> printPdfFromStorage(String fileUrl) async {
    html.window.open(fileUrl, '_blank');
  }

  Future<String> uploadFileToStorage(PlatformFile file) async {
    try {
      final fileName = Uri.decodeComponent(file.name).replaceAll(' ', '_');

      // Create storage reference
      final storageRef = _storage.ref().child('task_files/$fileName');

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
}
