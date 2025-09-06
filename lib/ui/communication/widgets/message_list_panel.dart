/// Message List Panel
/// Left panel showing list of messages and shared documents

import 'package:flutter/material.dart';
import 'package:fastcorr_shared/fastcorr_shared.dart';
import 'package:iconly/iconly.dart';
import '../shared_communication_viewmodel.dart';

class MessageListPanel extends StatelessWidget {
  final SharedCommunicationViewModel viewModel;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const MessageListPanel({
    super.key,
    required this.viewModel,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Search and Filter
          _buildSearchAndFilter(),

          // Tab Bar
          _buildTabBar(),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
          Icon(IconlyBroken.message, color: colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Communication & Follow-up',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (viewModel.unreadMessageCount > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${viewModel.unreadMessageCount} unread',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => viewModel.startComposing(),
            icon: Icon(IconlyBroken.plus, color: colorScheme.primary),
            label: Text(
              'Compose Message',
              style: TextStyle(color: colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            onChanged: viewModel.updateSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search messages...',
              prefixIcon: Icon(
                IconlyBroken.search,
                color: colorScheme.onSurface.withOpacity(0.6),
              ),
              suffixIcon: viewModel.searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () => viewModel.updateSearchQuery(''),
                      icon: Icon(
                        IconlyBroken.close_square,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
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
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips
          Row(
            children: [
              Text(
                'Filter:',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        'All',
                        viewModel.filterMessageType == null,
                        () => viewModel.updateMessageTypeFilter(null),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Chat',
                        viewModel.filterMessageType ==
                            UnifiedMessageType.chatMessage,
                        () => viewModel.updateMessageTypeFilter(
                          UnifiedMessageType.chatMessage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Documents',
                        viewModel.filterMessageType ==
                            UnifiedMessageType.document,
                        () => viewModel.updateMessageTypeFilter(
                          UnifiedMessageType.document,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'System Logs',
                        viewModel.filterMessageType ==
                            UnifiedMessageType.systemLog,
                        () => viewModel.updateMessageTypeFilter(
                          UnifiedMessageType.systemLog,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              'Messages',
              CommunicationTabType.messages,
              IconlyBroken.message,
            ),
          ),
          Expanded(
            child: _buildTabButton(
              'Shared Docs',
              CommunicationTabType.sharedDocs,
              IconlyBroken.folder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    String label,
    CommunicationTabType tab,
    IconData icon,
  ) {
    final isSelected = viewModel.activeTab == tab;

    return InkWell(
      onTap: () => viewModel.switchTab(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (viewModel.activeTab == CommunicationTabType.messages) {
      return _buildMessagesList();
    } else {
      return _buildSharedDocsList();
    }
  }

  Widget _buildMessagesList() {
    if (viewModel.filteredMessages.isEmpty) {
      return _buildEmptyState(
        icon: IconlyBroken.message,
        title: 'No messages found',
        subtitle:
            viewModel.searchQuery.isNotEmpty ||
                viewModel.filterMessageType != null
            ? 'Try adjusting your search or filter criteria'
            : 'Start a conversation by sending a message',
      );
    }

    return ListView.builder(
      itemCount: viewModel.filteredMessages.length,
      itemBuilder: (context, index) {
        final message = viewModel.filteredMessages[index];
        return _buildMessageItem(message);
      },
    );
  }

  Widget _buildSharedDocsList() {
    final sharedDocs = viewModel.sharedDocuments;

    if (sharedDocs.isEmpty) {
      return _buildEmptyState(
        icon: IconlyBroken.folder,
        title: 'No shared documents',
        subtitle: 'Documents will appear here when shared in messages',
      );
    }

    return ListView.builder(
      itemCount: sharedDocs.length,
      itemBuilder: (context, index) {
        final message = sharedDocs[index];
        return _buildDocumentItem(message);
      },
    );
  }

  Widget _buildMessageItem(UnifiedCaseMessage message) {
    final isSelected = viewModel.selectedMessage?.id == message.id;
    final isUnread =
        viewModel.currentUserId != null &&
        !message.isReadBy(viewModel.currentUserId!);

    return InkWell(
      onTap: () => viewModel.selectMessage(message),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isUnread ? colorScheme.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            // Unread indicator
            if (isUnread) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              const SizedBox(width: 20),
            ],

            // Avatar
            CircleAvatar(
              radius: 16,
              backgroundColor: _getSenderColor(
                message.senderRole,
              ).withOpacity(0.1),
              child: Text(
                message.senderName[0].toUpperCase(),
                style: TextStyle(
                  color: _getSenderColor(message.senderRole),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.senderName,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: isUnread
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(message.timestamp),
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message.hasAttachments) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          IconlyBroken.paper_plus,
                          size: 12,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${message.attachments.length} attachment${message.attachments.length > 1 ? 's' : ''}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentItem(UnifiedCaseMessage message) {
    final isSelected = viewModel.selectedMessage?.id == message.id;

    return InkWell(
      onTap: () => viewModel.selectMessage(message),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        ),
        child: Row(
          children: [
            // Document icon
            Icon(
              Icons.description_outlined,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content.isNotEmpty
                        ? message.content
                        : 'Shared Document',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.attachments.length} file${message.attachments.length > 1 ? 's' : ''} • ${message.senderName}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(message.timestamp)} ${_formatTime(message.timestamp)}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
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

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
