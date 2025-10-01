/// Document View Helper
/// Provides utility methods for navigating to document views

import 'package:flutter/material.dart';
import 'package:fastcorr_shared/fastcorr_shared.dart';
import 'package:stacked/stacked.dart';

class DocumentViewHelper {
  /// Debug document attachment information
  static void debugDocumentAttachment(DocumentAttachment attachment) {
    print('=== Document Attachment Debug Info ===');
    print('File Name: ${attachment.fileName}');
    print('File URL: ${attachment.fileUrl}');
    print('File Type: ${attachment.fileType}');
    print('File Size: ${attachment.fileSize} bytes');
    print('Uploaded At: ${attachment.uploadedAt}');
    print('Uploaded By: ${attachment.uploadedBy}');
    print('=====================================');
  }

  /// Validate document attachment before viewing
  static bool validateDocumentAttachment(DocumentAttachment attachment) {
    if (attachment.fileUrl.isEmpty) {
      print('Error: File URL is empty for ${attachment.fileName}');
      return false;
    }

    return true;
  }

  /// Navigate to document view
  static void navigateToDocumentView(
    BuildContext context,
    DocumentAttachment attachment,
  ) {
    // Debug the attachment
    debugDocumentAttachment(attachment);

    // Validate the attachment
    if (!validateDocumentAttachment(attachment)) {
      _showValidationError(context, attachment);
      return;
    }
    // Convert DocumentAttachment to UploadFileData
    final uploadFileData = UploadFileData(
      fileName: attachment.fileName,
      fileUrl: attachment.fileUrl,
      size: attachment.fileSize.toDouble(),
      caseFileId: 'attachment.caseFileId',
      litNumber: 'attachment.litNumber',
      // Add other fields as needed
    );

    // Navigate to document view
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ViewModelBuilder<DocumentViewModel>.reactive(
          viewModelBuilder: () => DocumentViewModel(),
          onViewModelReady: (viewModel) => viewModel.initModel(uploadFileData),
          builder: (context, viewModel, child) =>
              DocumentView(file: uploadFileData),
        ),
      ),
    );
  }

  /// Show document in a dialog
  static void showDocumentDialog(
    BuildContext context,
    DocumentAttachment attachment,
  ) {
    // Convert DocumentAttachment to UploadFileData
    final uploadFileData = UploadFileData(
      fileName: attachment.fileName,
      fileUrl: attachment.fileUrl,
      size: attachment.fileSize.toDouble(),
      caseFileId: 'attachment.caseFileId',
      litNumber: 'attachment.litNumber',
      // Add other fields as needed
    );

    // Show document in dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          child: ViewModelBuilder<DocumentViewModel>.reactive(
            viewModelBuilder: () => DocumentViewModel(),
            onViewModelReady: (viewModel) =>
                viewModel.initModel(uploadFileData),
            builder: (context, viewModel, child) =>
                DocumentView(file: uploadFileData),
          ),
        ),
      ),
    );
  }

  /// Show validation error dialog
  static void _showValidationError(
    BuildContext context,
    DocumentAttachment attachment,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            const Text('Document Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cannot open document: ${attachment.fileName}'),
            const SizedBox(height: 12),
            if (attachment.fileUrl.isEmpty) const Text('• File URL is empty'),
            const SizedBox(height: 12),
            const Text(
              'This usually means the file was not properly uploaded or the file URL is invalid.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
