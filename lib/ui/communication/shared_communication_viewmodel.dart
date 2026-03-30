// Shared Communication ViewModel
// Gmail-like interface for case communications across FastCorr apps.

import 'dart:async';
import 'dart:developer';
import 'package:fastcorr_shared/fastcorr_shared.dart';
import 'package:stacked/stacked.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

/// Communication tab types
enum CommunicationTabType { messages, sharedDocs }

/// Shared communication view model for Gmail-like interface
class SharedCommunicationViewModel extends ReactiveViewModel {
  // Service dependencies - to be injected by the consuming app
  late final UnifiedCaseCommunicationService _commService;

  // Stream subscriptions
  StreamSubscription<List<UnifiedCaseMessage>>? _messagesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _participantsSubscription;

  // Core data
  String? _caseId;
  String? _orgId;
  String? _currentUserId;
  String? _currentUserName;
  UnifiedParticipantRole? _currentUserRole;

  List<UnifiedCaseMessage> _messages = [];
  List<Map<String, dynamic>> _participants = [];
  Map<String, dynamic>? _currentUserParticipant;

  // UI state
  CommunicationTabType _activeTab = CommunicationTabType.messages;
  UnifiedCaseMessage? _selectedMessage;
  String _searchQuery = '';
  UnifiedMessageType? _filterMessageType;
  String? _lastErrorMessage;

  // Compose state
  bool _isComposing = false;
  String _composeContent = '';
  List<DocumentAttachment> _composeAttachments = [];
  String? _replyToMessageId;

  // Getters
  String? get caseId => _caseId;
  String? get orgId => _orgId;
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  UnifiedParticipantRole? get currentUserRole => _currentUserRole;

  List<UnifiedCaseMessage> get messages => _messages;
  List<Map<String, dynamic>> get participants => _participants;
  Map<String, dynamic>? get currentUserParticipant => _currentUserParticipant;

  CommunicationTabType get activeTab => _activeTab;
  UnifiedCaseMessage? get selectedMessage => _selectedMessage;
  String get searchQuery => _searchQuery;
  UnifiedMessageType? get filterMessageType => _filterMessageType;
  String? get lastErrorMessage => _lastErrorMessage;

  bool get isComposing => _isComposing;
  String get composeContent => _composeContent;
  List<DocumentAttachment> get composeAttachments => _composeAttachments;
  String? get replyToMessageId => _replyToMessageId;

  /// Check if current user has access to this case
  bool get hasAccess => _currentUserParticipant != null;
  @override
  bool get hasError => _lastErrorMessage != null && _lastErrorMessage!.isNotEmpty;

  /// Get filtered messages based on search and filter
  List<UnifiedCaseMessage> get filteredMessages {
    var filtered = _messages;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (message) =>
                message.content.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                message.senderName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    // Apply message type filter
    if (_filterMessageType != null) {
      filtered = filtered
          .where((message) => message.type == _filterMessageType)
          .toList();
    }

    return filtered;
  }

  /// Get shared documents (messages with attachments)
  List<UnifiedCaseMessage> get sharedDocuments {
    return _messages.where((message) => message.hasAttachments).toList();
  }

  /// Get unread message count for current user
  int get unreadMessageCount {
    if (_currentUserId == null) return 0;
    return _messages
        .where((message) => !message.isReadBy(_currentUserId!))
        .length;
  }

  /// Get messages grouped by date
  Map<String, List<UnifiedCaseMessage>> get messagesByDate {
    final Map<String, List<UnifiedCaseMessage>> grouped = {};

    for (final message in filteredMessages) {
      final dateKey = _formatDateKey(message.timestamp);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(message);
    }

    return grouped;
  }

  /// Get current message index in filtered list
  int get currentMessageIndex {
    if (_selectedMessage == null) return -1;
    return filteredMessages.indexWhere((msg) => msg.id == _selectedMessage!.id);
  }

  /// Get total filtered messages count
  int get totalFilteredMessages => filteredMessages.length;

  /// Initialize the view model
  Future<void> initialize({
    required UnifiedCaseCommunicationService commService,
    required String caseId,
    required String orgId,
    required String currentUserId,
    required String currentUserName,
    required UnifiedParticipantRole currentUserRole,
  }) async {
    setBusy(true);

    try {
      _commService = commService;
      _caseId = caseId;
      _orgId = orgId;
      _currentUserId = currentUserId;
      _currentUserName = currentUserName;
      _currentUserRole = currentUserRole;

      // Set up streams
      await _setupStreams();

      log('SharedCommunicationViewModel initialized for case: $caseId');
    } catch (e, stackTrace) {
      log('Error initializing SharedCommunicationViewModel: $e');
      log('Stack trace: $stackTrace');
    } finally {
      setBusy(false);
    }
  }

  /// Set up Firestore streams
  Future<void> _setupStreams() async {
    if (_caseId == null || _orgId == null) return;

    // Messages stream
    _messagesSubscription = _commService
        .getCaseMessagesStream(_orgId!, _caseId!)
        .listen(
          (messages) {
            _messages = messages;
            notifyListeners();
          },
          onError: (error) {
            log('Error in messages stream: $error');
          },
        );

    // Participants stream (placeholder - can be enhanced)
    _participantsSubscription = Stream.value(<Map<String, dynamic>>[]).listen(
      (participants) {
        _participants = participants;
        _currentUserParticipant = participants.firstWhere(
          (p) => p['userId'] == _currentUserId,
          orElse: () => <String, dynamic>{},
        );
        notifyListeners();
      },
      onError: (error) {
        log('Error in participants stream: $error');
      },
    );
  }

  /// Switch between tabs
  void switchTab(CommunicationTabType tab) {
    _activeTab = tab;
    notifyListeners();
  }

  /// Select a message to view
  void selectMessage(UnifiedCaseMessage message) {
    _selectedMessage = message;

    // Mark as read if not already
    if (_currentUserId != null && !message.isReadBy(_currentUserId!)) {
      _markMessageAsRead(message.id);
    }

    notifyListeners();
  }

  /// Clear selected message
  void clearSelectedMessage() {
    _selectedMessage = null;
    notifyListeners();
  }

  /// Navigate to previous message
  void navigateToPreviousMessage() {
    final currentIndex = currentMessageIndex;
    if (currentIndex > 0) {
      selectMessage(filteredMessages[currentIndex - 1]);
    }
  }

  /// Navigate to next message
  void navigateToNextMessage() {
    final currentIndex = currentMessageIndex;
    if (currentIndex < filteredMessages.length - 1) {
      selectMessage(filteredMessages[currentIndex + 1]);
    }
  }

  /// Update search query
  void updateSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Update message type filter
  void updateMessageTypeFilter(UnifiedMessageType? messageType) {
    _filterMessageType = messageType;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _searchQuery = '';
    _filterMessageType = null;
    notifyListeners();
  }

  void clearError() {
    _lastErrorMessage = null;
    notifyListeners();
  }

  /// Start composing a new message
  void startComposing({String? replyToMessageId}) {
    _isComposing = true;
    _replyToMessageId = replyToMessageId;
    _composeContent = '';
    _composeAttachments = [];
    notifyListeners();
  }

  /// Cancel composing
  void cancelComposing() {
    _isComposing = false;
    _replyToMessageId = null;
    _composeContent = '';
    _composeAttachments = [];
    notifyListeners();
  }

  /// Update compose content
  void updateComposeContent(String content) {
    _composeContent = content;
    notifyListeners();
  }

  /// Add attachment to compose
  void addAttachment(DocumentAttachment attachment) {
    _composeAttachments = [..._composeAttachments, attachment];
    notifyListeners();
  }

  /// Remove attachment from compose
  void removeAttachment(String attachmentId) {
    _composeAttachments = _composeAttachments
        .where((attachment) => attachment.id != attachmentId)
        .toList();
    notifyListeners();
  }

  /// Pick and add files to compose
  Future<void> pickAndAddFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'jpg',
          'jpeg',
          'png',
          'gif',
        ],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final uuid = const Uuid();

        for (final file in result.files) {
          if (file.bytes != null) {
            final attachment = DocumentAttachment(
              id: uuid.v4(),
              fileName: file.name,
              fileUrl: '', // Will be set after upload
              fileType: _getFileTypeFromName(file.name),
              fileSize: file.size,
              uploadedAt: DateTime.now(),
              uploadedBy: _currentUserId ?? 'unknown',
            );

            addAttachment(attachment);
          }
        }
      }
    } catch (e) {
      log('Error picking files: $e');
      _lastErrorMessage = 'Could not pick files. Please try again.';
      notifyListeners();
    }
  }

  /// Send the composed message
  Future<void> sendMessage() async {
    if (_currentUserId == null ||
        _caseId == null ||
        _orgId == null ||
        _composeContent.trim().isEmpty) {
      return;
    }

    setBusy(true);

    try {
      // Upload attachments first if any
      List<DocumentAttachment> uploadedAttachments = [];
      for (final attachment in _composeAttachments) {
        if (attachment.fileUrl.isEmpty) {
          // Upload the file
          final uploadedAttachmentUrl = await _commService.uploadDocument(
            caseId: _caseId!,
            orgId: _orgId!,
            fileName: attachment.fileName,
            fileBytes: [], // This would need to be passed from the file picker
            fileType: attachment.fileType,
            uploadedBy: _currentUserId!,
          );
          final uploadedAttachment = DocumentAttachment(
            id: attachment.id,
            fileName: attachment.fileName,
            fileUrl: uploadedAttachmentUrl,
            fileType: attachment.fileType,
            fileSize: attachment.fileSize,
            uploadedAt: attachment.uploadedAt,
            uploadedBy: attachment.uploadedBy,
          );

          uploadedAttachments.add(uploadedAttachment);
        } else {
          uploadedAttachments.add(attachment);
        }
      }

      // Send the message
      await _commService.sendChatMessage(
        caseId: _caseId!,
        orgId: _orgId!,
        senderId: _currentUserId!,
        senderName: _currentUserName!,
        senderRole: _currentUserRole!,
        content: _composeContent.trim(),
        attachments: uploadedAttachments,
        replyToMessageId: _replyToMessageId,
      );

      // Clear compose state
      cancelComposing();

      log('Message sent successfully');
    } catch (e, stackTrace) {
      log('Error sending message: $e');
      log('Stack trace: $stackTrace');
      _lastErrorMessage = 'Failed to send message. Please try again.';
      notifyListeners();
    } finally {
      setBusy(false);
    }
  }

  /// Mark a message as read
  Future<void> _markMessageAsRead(String messageId) async {
    if (_currentUserId == null || _caseId == null || _orgId == null) return;

    try {
      await _commService.markMessageAsRead(
        messageId,
        _orgId!,
        _caseId!,
        _currentUserId!,
      );
    } catch (e) {
      log('Error marking message as read: $e');
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId) async {
    if (_caseId == null || _orgId == null) return;

    try {
      await _commService.deleteMessage(messageId, _orgId!, _caseId!);

      // Clear selection if deleted message was selected
      if (_selectedMessage?.id == messageId) {
        _selectedMessage = null;
      }

      notifyListeners();
    } catch (e) {
      log('Error deleting message: $e');
    }
  }

  /// Archive a message (placeholder implementation)
  Future<void> archiveMessage(String messageId) async {
    // This would be implemented based on your archiving requirements
    log('Archive message: $messageId');
  }

  /// Get file type from file name
  String _getFileTypeFromName(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }

  // /// Share a message content to third parties
  // Future<void> shareMessage(UnifiedCaseMessage message) async {
  //   try {
  //     final shareText = _formatMessageForSharing(message);
  //     await Share.share(
  //       shareText,
  //       subject: 'FastCorr Case Message - ${message.typeDisplayName}',
  //     );
  //     log('Message shared successfully');
  //   } catch (e) {
  //     log('Error sharing message: $e');
  //   }
  // }

  // /// Format message for sharing
  // String _formatMessageForSharing(UnifiedCaseMessage message) {
  //   final buffer = StringBuffer();

  //   buffer.writeln('FastCorr Case Communication');
  //   buffer.writeln('=' * 30);
  //   buffer.writeln();
  //   buffer.writeln('Type: ${message.typeDisplayName}');
  //   buffer.writeln('From: ${message.senderName}');
  //   buffer.writeln('Date: ${formatDate(message.timestamp)}');
  //   buffer.writeln();
  //   buffer.writeln('Content:');
  //   buffer.writeln('-' * 20);
  //   buffer.writeln(message.content);
  //   buffer.writeln();

  //   if (message.attachments.isNotEmpty) {
  //     buffer.writeln('Attachments:');
  //     buffer.writeln('-' * 20);
  //     for (final attachment in message.attachments) {
  //       buffer.writeln(
  //         '• ${attachment.fileName} (${_formatFileSize(attachment.fileSize)})',
  //       );
  //     }
  //     buffer.writeln();
  //   }

  //   buffer.writeln('---');
  //   buffer.writeln('Shared from FastCorr Case Management System');

  //   return buffer.toString();
  // }

  /// Format date key for grouping messages
  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Format time for display
  String formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Format date for display
  String formatDate(DateTime dateTime) {
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

  /// View a document attachment
  void viewDocument(DocumentAttachment attachment) {
    // This method will be overridden by the consuming app to handle navigation
    // The consuming app should use DocumentViewHelper.navigateToDocumentView()
    log('Viewing document: ${attachment.fileName}');
  }

  /// Download a document attachment
  void downloadDocument(DocumentAttachment attachment) {
    // Create a temporary UploadFileData for download
    final uploadFileData = UploadFileData(
      fileId: const Uuid().v4(),
      fileName: attachment.fileName,
      fileUrl: attachment.fileUrl,
      size: attachment.fileSize.toDouble(),
      caseFileId: 'attachment.caseFileId',
      litNumber: 'attachment.litNumber',
    );

    // Use the document service to download
    final docService = DocumentService();
    docService.downloadPdf(uploadFileData);
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _participantsSubscription?.cancel();
    super.dispose();
  }
}
