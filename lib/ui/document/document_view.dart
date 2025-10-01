import 'package:fastcorr_shared/models/upload_file_data.dart';
import 'package:fastcorr_shared/ui/document/document_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:stacked/stacked.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentView extends ViewModelWidget<DocumentViewModel> {
  const DocumentView({super.key, required this.file});
  final UploadFileData file;

  @override
  Widget build(BuildContext context, DocumentViewModel viewModel) {
    return Scaffold(
      appBar: _buildAppBar(context, viewModel),
      body: _buildBody(context, viewModel),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    DocumentViewModel viewModel,
  ) {
    return AppBar(
      title: Text(
        file.fileName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        // Document actions
        _buildAppBarActionButton(
          context: context,
          icon: Icons.info_outline,
          label: 'Info',
          onPressed: () => _showDocumentInfo(context, viewModel),
        ),
        _buildAppBarActionButton(
          context: context,
          icon: Icons.download_outlined,
          label: 'Download',
          onPressed: () => viewModel.downloadDoc(file),
        ),
        _buildAppBarActionButton(
          context: context,
          icon: Icons.print_outlined,
          label: 'Print',
          onPressed: () => viewModel.downloadDoc(file),
        ),
        _buildAppBarActionButton(
          context: context,
          icon: Icons.share_outlined,
          label: 'Share',
          onPressed: () => _showShareOptions(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildAppBarActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, DocumentViewModel viewModel) {
    if (viewModel.isBusy) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading document...'),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Document viewer (main content)
        Expanded(flex: 3, child: _buildDocumentViewer(context, viewModel)),

        // Document sidebar with information
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: _buildDocumentSidebar(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildDocumentViewer(
    BuildContext context,
    DocumentViewModel viewModel,
  ) {
    if (viewModel.pdfController == null) {
      return _buildErrorState(context);
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Document viewer header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getFileIcon(file.fileName),
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.fileName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _getFileType(file.fileName),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildViewerControls(context, viewModel),
              ],
            ),
          ),

          // PDF viewer
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: PdfView(
                controller: viewModel.pdfController!,
                scrollDirection: Axis.vertical,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerControls(
    BuildContext context,
    DocumentViewModel viewModel,
  ) {
    return Row(
      children: [
        IconButton(
          onPressed: () {
            // Zoom out
          },
          icon: Icon(
            Icons.zoom_out,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'Zoom Out',
        ),
        IconButton(
          onPressed: () {
            // Zoom in
          },
          icon: Icon(
            Icons.zoom_in,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'Zoom In',
        ),
        IconButton(
          onPressed: () {
            // Fit to page
          },
          icon: Icon(
            Icons.fit_screen,
            color: Theme.of(context).colorScheme.primary,
          ),
          tooltip: 'Fit to Page',
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Document',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The document could not be loaded. This might be because:\n\n'
              '• The file URL is invalid\n'
              '• The file was not properly uploaded\n'
              '• Network connection issues\n\n'
              'Please check the file and try again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Retry loading
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    // Go back
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Go Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSidebar(
    BuildContext context,
    DocumentViewModel viewModel,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document info header
          _buildSectionHeader(context, 'Document Information'),
          const SizedBox(height: 16),

          // File details
          _buildInfoCard(context, [
            _buildInfoRow(context, 'File Name', file.fileName),
            if (file.size != null)
              _buildInfoRow(context, 'File Size', _formatFileSize(file.size!)),
            if (file.pages != null)
              _buildInfoRow(context, 'Pages', '${file.pages}'),
            _buildInfoRow(context, 'File Type', _getFileType(file.fileName)),
            _buildInfoRow(
              context,
              'Extension',
              _getFileExtension(file.fileName),
            ),
          ]),
          const SizedBox(height: 24),

          // Document status
          if (file.docStatus != null) ...[
            _buildSectionHeader(context, 'Document Status'),
            const SizedBox(height: 16),
            _buildStatusCard(context, file.docStatus!),
            const SizedBox(height: 24),
          ],

          // Timestamps
          if (file.takenAt != null || file.returnedAt != null) ...[
            _buildSectionHeader(context, 'Timeline'),
            const SizedBox(height: 16),
            _buildTimelineCard(context, file),
            const SizedBox(height: 24),
          ],

          // Actions
          _buildSectionHeader(context, 'Actions'),
          const SizedBox(height: 16),
          _buildActionsCard(context, viewModel),
          const SizedBox(height: 24),

          // QR Code (if available)
          if (file.barcodeUrl != null) ...[
            _buildSectionHeader(context, 'QR Code'),
            const SizedBox(height: 16),
            _buildQRCodeCard(context, file),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, DocStatus status) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case DocStatus.pending:
        statusColor = Colors.orange;
        statusText = 'Pending';
        statusIcon = Icons.schedule;
        break;

      case DocStatus.returned:
        statusColor = Colors.green;
        statusText = 'Returned';
        statusIcon = Icons.check_circle;
        break;
      case DocStatus.docOut:
        statusColor = Colors.red;
        statusText = 'Document Out';
        statusIcon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getStatusDescription(status),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(BuildContext context, UploadFileData file) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          if (file.takenAt != null) ...[
            _buildTimelineItem(
              context,
              icon: Icons.upload,
              title: 'Document Taken',
              date: _formatTimestamp(file.takenAt!),
              itemColor: Theme.of(context).colorScheme.primary,
            ),
            if (file.returnedAt != null) ...[
              const SizedBox(height: 8),
              Container(
                width: 2,
                height: 20,
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
              const SizedBox(height: 8),
            ],
          ],
          if (file.returnedAt != null)
            _buildTimelineItem(
              context,
              icon: Icons.download,
              title: 'Document Returned',
              date: _formatTimestamp(file.returnedAt!),
              itemColor: Colors.green,
            ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String date,
    required Color itemColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: itemColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: itemColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                date,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionsCard(BuildContext context, DocumentViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          _buildSidebarActionButton(
            context,
            icon: Icons.download_outlined,
            label: 'Download Document',
            onPressed: () => viewModel.downloadDoc(file),
          ),
          const SizedBox(height: 8),
          _buildSidebarActionButton(
            context,
            icon: Icons.print_outlined,
            label: 'Print Document',
            onPressed: () => viewModel.downloadDoc(file),
          ),
          const SizedBox(height: 8),
          _buildSidebarActionButton(
            context,
            icon: Icons.share_outlined,
            label: 'Share Document',
            onPressed: () => _showShareOptions(context, viewModel),
          ),
          const SizedBox(height: 8),
          _buildSidebarActionButton(
            context,
            icon: Icons.info_outline,
            label: 'Document Details',
            onPressed: () => _showDocumentInfo(context, viewModel),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQRCodeCard(BuildContext context, UploadFileData file) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                file.barcodeUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.qr_code,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Document QR Code',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan to access document information',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Utility methods
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'PDF Document';
      case 'doc':
      case 'docx':
        return 'Word Document';
      case 'xls':
      case 'xlsx':
        return 'Excel Spreadsheet';
      case 'ppt':
      case 'pptx':
        return 'PowerPoint Presentation';
      case 'jpg':
      case 'jpeg':
        return 'JPEG Image';
      case 'png':
        return 'PNG Image';
      case 'gif':
        return 'GIF Image';
      case 'txt':
        return 'Text File';
      case 'zip':
      case 'rar':
        return 'Archive File';
      default:
        return 'Unknown File Type';
    }
  }

  String _getFileExtension(String fileName) {
    return '.${fileName.split('.').last.toLowerCase()}';
  }

  String _formatFileSize(double sizeInBytes) {
    if (sizeInBytes < 1024) {
      return '${sizeInBytes.toStringAsFixed(1)} B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else if (sizeInBytes < 1024 * 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.parse(timestamp);
    } else {
      return '';
    }

    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusDescription(DocStatus status) {
    switch (status) {
      case DocStatus.pending:
        return 'Document is waiting to be processed';
      case DocStatus.returned:
        return 'Document has been returned successfully';
      case DocStatus.docOut:
        return 'Document is currently out for delivery';
    }
  }

  // Dialog methods
  void _showDocumentInfo(BuildContext context, DocumentViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Document Information'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow(context, 'File Name', file.fileName),
              if (file.size != null)
                _buildInfoRow(
                  context,
                  'File Size',
                  _formatFileSize(file.size!),
                ),
              if (file.pages != null)
                _buildInfoRow(context, 'Pages', '${file.pages}'),
              _buildInfoRow(context, 'File Type', _getFileType(file.fileName)),
              if (file.docStatus != null)
                _buildInfoRow(context, 'Status', file.docStatus!.name),
              if (file.takenAt != null)
                _buildInfoRow(
                  context,
                  'Taken At',
                  _formatTimestamp(file.takenAt!),
                ),
              if (file.returnedAt != null)
                _buildInfoRow(
                  context,
                  'Returned At',
                  _formatTimestamp(file.returnedAt!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showShareOptions(BuildContext context, DocumentViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.share_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Share Document'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share options will be implemented here.'),
            SizedBox(height: 16),
            Text(
              'This will allow users to share the document via email, link, or other methods.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement share functionality
              Navigator.pop(context);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }
}
