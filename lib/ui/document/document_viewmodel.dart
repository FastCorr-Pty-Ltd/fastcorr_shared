import 'dart:developer';
import 'dart:typed_data';

import 'package:fastcorr_shared/models/upload_file_data.dart';
import 'package:fastcorr_shared/services/document_service.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:stacked/stacked.dart';
import 'package:universal_html/html.dart' as html;

class DocumentViewModel extends BaseViewModel {
  final DocumentService _docServ = DocumentService();
  late final PdfController? pdfController;

  UploadFileData? _pickedFile;

  UploadFileData? get pickedFile => _pickedFile;

  void initModel(UploadFileData pickedFile) {
    setBusy(true);
    _pickedFile = pickedFile;
    notifyListeners();
    final document = openPdfFromUrl(pickedFile.fileUrl!);

    pdfController = PdfController(document: document);
    setBusy(false);
    notifyListeners();
  }

  Future<PdfDocument> openPdfFromUrl(String url) async {
    try {
      log('Attempting to load PDF from URL: $url');

      if (url.isEmpty) {
        throw Exception('PDF URL is empty');
      }

      final response = await http.get(Uri.parse(url));

      log('HTTP Response Status: ${response.statusCode}');
      log('Response Content-Length: ${response.contentLength}');
      log('Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        final Uint8List bytes = response.bodyBytes;
        log('PDF file size: ${bytes.length} bytes');

        try {
          return await PdfDocument.openData(bytes);
        } catch (e) {
          // Handle PDF library exceptions (like empty file)
          if (e.toString().contains('empty') ||
              e.toString().contains('zero bytes')) {
            log(
              'PDF appears empty but URL is valid - opening in browser instead',
            );
            // Open in browser as fallback
            html.window.open(url, '_blank');
            throw Exception('PDF opened in browser due to library limitations');
          }
          rethrow;
        }
      } else {
        // Handle HTTP errors (e.g., 404 Not Found)
        log('Failed to load PDF. Status code: ${response.statusCode}');
        log('Response body: ${response.body}');
        throw Exception(
          'Failed to load PDF. Status code: ${response.statusCode}. Response: ${response.body}',
        );
      }
    } catch (e) {
      // Handle other exceptions (e.g., network issues, invalid URL)
      log('Error opening PDF from URL: $e');
      throw Exception('Failed to open PDF from URL: $e');
    }
  }

  void downloadDoc(UploadFileData file) {
    _docServ.downloadPdf(file);
  }
}
