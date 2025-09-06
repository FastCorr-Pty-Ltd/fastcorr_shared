/// Message Detail Panel
/// Right panel showing selected message content

import 'package:flutter/material.dart';
import 'package:fastcorr_shared/fastcorr_shared.dart';
import 'package:iconly/iconly.dart';
import '../shared_communication_viewmodel.dart';

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
          // Navigation Bar
          _buildNavigationBar(),

          // Message Header
          _buildMessageHeader(message),

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
              IconlyBroken.chat,
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

  Widget _buildNavigationBar() {
    final currentIndex = viewModel.currentMessageIndex;
    final totalMessages = viewModel.totalFilteredMessages;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button (for mobile)
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            ),
            const SizedBox(width: 8),
          ],

          // Message position indicator
          if (totalMessages > 0) ...[
            IconButton(
              onPressed: currentIndex > 0
                  ? viewModel.navigateToPreviousMessage
                  : null,
              icon: Icon(
                Icons.chevron_left,
                color: currentIndex > 0
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
            Text(
              '${currentIndex + 1} of $totalMessages',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            IconButton(
              onPressed: currentIndex < totalMessages - 1
                  ? viewModel.navigateToNextMessage
                  : null,
              icon: Icon(
                Icons.chevron_right,
                color: currentIndex < totalMessages - 1
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ],

          const Spacer(),

          // Action buttons
          IconButton(
            onPressed: () =>
                viewModel.deleteMessage(viewModel.selectedMessage!.id),
            icon: Icon(IconlyBroken.delete, color: colorScheme.error),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageHeader(UnifiedCaseMessage message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender info
          Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: _getSenderColor(
                  message.senderRole,
                ).withOpacity(0.1),
                child: Text(
                  message.senderName[0].toUpperCase(),
                  style: TextStyle(
                    color: _getSenderColor(message.senderRole),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Sender details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          message.senderName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getSenderColor(
                              message.senderRole,
                            ).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            message.senderRoleDisplayName,
                            style: textTheme.labelSmall?.copyWith(
                              color: _getSenderColor(message.senderRole),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From: ${message.senderId} • To: Case Participants',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Timestamp
              Text(
                _formatDateTime(message.timestamp),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Subject/Content preview
          Text(
            message.content.isNotEmpty ? message.content : 'No content',
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    viewModel.startComposing(replyToMessageId: message.id),
                icon: Icon(Icons.reply, size: 16, color: colorScheme.primary),
                label: Text(
                  'Reply',
                  style: TextStyle(color: colorScheme.primary),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              // const SizedBox(width: 8),
              // ElevatedButton.icon(
              //   onPressed: () {
              //     // TODO: Share message
              //   },

              //   icon: Icon(Icons.share, size: 16, color: colorScheme.secondary),
              //   label: Text(
              //     'Share',
              //     style: TextStyle(color: colorScheme.secondary),
              //   ),
              //   style: ElevatedButton.styleFrom(
              //     backgroundColor: colorScheme.secondary.withOpacity(0.1),
              //     elevation: 0,
              //     padding: const EdgeInsets.symmetric(
              //       horizontal: 12,
              //       vertical: 8,
              //     ),
              //   ),
              // ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  // TODO: Star message
                },
                icon: Icon(
                  Icons.star_outline,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                tooltip: 'Star',
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'share':
                    // TODO: Share message
                    case 'copy':
                      // TODO: Copy message content to clipboard
                      break;
                    case 'print':
                      // TODO: Print message
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(IconlyBroken.send, color: colorScheme.onSurface),
                        const SizedBox(width: 8),
                        Text('Share Message'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy, color: colorScheme.onSurface),
                        const SizedBox(width: 8),
                        Text('Copy Content'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'print',
                    child: Row(
                      children: [
                        Icon(Icons.print, color: colorScheme.onSurface),
                        const SizedBox(width: 8),
                        Text('Print'),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  IconlyBroken.more_square,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
                tooltip: 'More options',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(UnifiedCaseMessage message) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Message content
          Text(
            message.content,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.8),
              height: 1.5,
              fontStyle: message.type == UnifiedMessageType.systemLog
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),

          // Attachments
          if (message.hasAttachments) ...[
            const SizedBox(height: 24),
            _buildAttachmentsSection(message.attachments),
          ],

          // Message metadata
          const SizedBox(height: 24),
          _buildMessageMetadata(message),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(List<DocumentAttachment> attachments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ATTACHMENTS',
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...attachments.map((attachment) => _buildAttachmentCard(attachment)),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            // TODO: Download all attachments
          },
          icon: Icon(Icons.download, color: colorScheme.primary),
          label: Text(
            'Download All',
            style: TextStyle(color: colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentCard(DocumentAttachment attachment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(attachment.fileType),
            color: colorScheme.primary,
            size: 24,
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
                  '${_formatFileSize(attachment.fileSize)} • ${attachment.fileType}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Download file
            },
            icon: Icon(Icons.download, color: colorScheme.primary),
            tooltip: 'Download',
          ),
        ],
      ),
    );
  }

  Widget _buildMessageMetadata(UnifiedCaseMessage message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Message Details',
            style: textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildMetadataRow('Type', message.typeDisplayName),
          _buildMetadataRow('Status', message.status.name.toUpperCase()),
          _buildMetadataRow('Sent', _formatDateTime(message.timestamp)),
          if (message.readBy.isNotEmpty)
            _buildMetadataRow(
              'Read by',
              '${message.readBy.length} participant${message.readBy.length > 1 ? 's' : ''}',
            ),
          if (message.replyToMessageId != null)
            _buildMetadataRow(
              'Reply to',
              'Message ${message.replyToMessageId}',
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

  Color _getSenderColor(UnifiedParticipantRole role) {
    switch (role) {
      case UnifiedParticipantRole.lawyer:
        return colorScheme.primary;
      case UnifiedParticipantRole.client:
        return colorScheme.secondary;
      case UnifiedParticipantRole.driver:
        return Colors.orange;
      case UnifiedParticipantRole.admin:
        return Colors.red;
      case UnifiedParticipantRole.secretary:
        return Colors.blue;
      case UnifiedParticipantRole.courtClerk:
        return Colors.purple;
      case UnifiedParticipantRole.observer:
        return colorScheme.onSurface.withOpacity(0.6);
    }
  }

  IconData _getFileIcon(String fileType) {
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    if (fileType.contains('image')) return Icons.image;
    if (fileType.contains('word')) return Icons.description;
    if (fileType.contains('excel') || fileType.contains('spreadsheet'))
      return Icons.table_chart;
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
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
