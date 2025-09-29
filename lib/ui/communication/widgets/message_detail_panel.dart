/// Message Detail Panel
/// Right panel showing selected message content

import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:fastcorr_shared/fastcorr_shared.dart';

class MessageDetailPanel extends StatelessWidget {
  final SharedCommunicationViewModel viewModel;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onBack;

  const MessageDetailPanel({
    super.key,
    required this.viewModel,
    required this.colorScheme,
    required this.textTheme,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final message = viewModel.selectedMessage;
    if (message == null) {
      return _buildEmptyState();
    }

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Message Header
          _buildMessageHeader(message, context),

          // Message Content
          Expanded(child: _buildMessageContent(message)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Select a message',
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a message from the list to view its content',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageHeader(UnifiedCaseMessage message, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Clean sender info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.senderName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'To: Case Participants',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),

          // Clean timestamp
          Text(
            _formatDateTime(message.timestamp),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),

          const SizedBox(width: 16),

          // Minimal action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () =>
                    viewModel.startComposing(replyToMessageId: message.id),
                icon: Icon(Icons.reply, color: colorScheme.primary),
                tooltip: 'Reply',
              ),
              IconButton(
                onPressed: () => _showMessageDetails(context, message),
                icon: Icon(
                  Icons.info_outline,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                tooltip: 'Message Details',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(UnifiedCaseMessage message) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clean message content - main focus
          Text(
            message.content,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface,
              height: 1.6,
              fontSize: 16,
              fontStyle: message.type == UnifiedMessageType.systemLog
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),

          // Attachments section - clean and organized
          if (message.hasAttachments) ...[
            const SizedBox(height: 32),
            _buildAttachmentsSection(message.attachments),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(List<DocumentAttachment> attachments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clean horizontal line separator
        Container(height: 1, color: colorScheme.outline.withOpacity(0.2)),
        const SizedBox(height: 20),

        // Attachments in clean horizontal layout
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: attachments
              .map((attachment) => _buildAttachmentCard(attachment))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildAttachmentCard(DocumentAttachment attachment) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // File name
          Text(
            attachment.fileName,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          // Download icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatFileSize(attachment.fileSize),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              IconButton(
                onPressed: () => viewModel.downloadDocument(attachment),
                tooltip: 'Download',
                icon: Icon(
                  IconlyBold.download,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessageDetails(BuildContext context, UnifiedCaseMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMetadataRow('Type', message.typeDisplayName),
              _buildMetadataRow('Status', message.status.name.toUpperCase()),
              _buildMetadataRow('Sent', _formatDateTime(message.timestamp)),
              if (message.readBy.isNotEmpty)
                _buildMetadataRow(
                  'Read by',
                  '${message.readBy.length} participant${message.readBy.length > 1 ? 's' : ''}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today, ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago, ${_formatTime(dateTime)}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}, ${_formatTime(dateTime)}';
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
