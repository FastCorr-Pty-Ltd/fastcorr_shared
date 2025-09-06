/// Compose Dialog
/// Dialog for composing new messages with big text field and attachment option

import 'package:flutter/material.dart';
import 'package:fastcorr_shared/fastcorr_shared.dart';
import 'package:iconly/iconly.dart';
import '../shared_communication_viewmodel.dart';

class ComposeDialog extends StatelessWidget {
  final SharedCommunicationViewModel viewModel;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const ComposeDialog({
    super.key,
    required this.viewModel,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.outline.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Content
          Expanded(child: _buildContent()),

          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(IconlyBroken.edit, color: colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Text(
            'Compose Message',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: viewModel.cancelComposing,
            icon: Icon(
              IconlyBroken.close_square,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message Content
          Text(
            'Message Content',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),

          // Big text field
          Expanded(
            child: TextField(
              onChanged: viewModel.updateComposeContent,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Attachments Section
          _buildAttachmentsSection(),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attach Docs or Follow-up memos',
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              if (viewModel.composeAttachments.isEmpty) ...[
                Icon(
                  IconlyBroken.paper_plus,
                  size: 48,
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No attachments added',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: viewModel.pickAndAddFiles,
                  icon: Icon(Icons.add, color: colorScheme.onPrimary),
                  label: Text(
                    'Add Files',
                    style: TextStyle(color: colorScheme.onPrimary),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ] else ...[
                ...viewModel.composeAttachments.map(
                  (attachment) => _buildAttachmentItem(attachment),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: viewModel.pickAndAddFiles,
                  icon: Icon(Icons.add, color: colorScheme.primary),
                  label: Text(
                    'Add More Files',
                    style: TextStyle(color: colorScheme.primary),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentItem(DocumentAttachment attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(attachment.fileType),
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileSize(attachment.fileSize),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => viewModel.removeAttachment(attachment.id),
            icon: Icon(
              IconlyBroken.close_square,
              color: colorScheme.error,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: viewModel.cancelComposing,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: colorScheme.outline.withOpacity(0.3)),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: viewModel.composeContent.trim().isEmpty
                  ? null
                  : viewModel.sendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: viewModel.isBusy
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : Text(
                      'Send Message',
                      style: TextStyle(color: colorScheme.onPrimary),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileType) {
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    if (fileType.contains('image')) return IconlyBroken.image;
    if (fileType.contains('word')) return IconlyBroken.document;
    if (fileType.contains('excel') || fileType.contains('spreadsheet'))
      return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
