/// Unified case communication service for cross-app communication
/// This service is shared between fastcorr_user and fastcorr_admin apps

import 'dart:developer';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:stacked/stacked.dart';
import 'package:uuid/uuid.dart';
import '../comms_observability.dart';
import '../models/case_message_metadata.dart';
import '../models/unified_case_message.dart';

/// Service for managing unified case communications across apps
class UnifiedCaseCommunicationService with ListenableServiceMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  static const int kDefaultCaseMessagesLimit = 100;
  static const int _fullScanPageSize = 200;

  /// Get the communications collection reference for a specific case
  CollectionReference _getCommunicationsRef(String orgId, String caseId) {
    return _firestore
        .collection('cases')
        .doc(caseId)
        .collection('communications');
  }

  /// Get the cases collection reference (top-level)
  CollectionReference _getCasesRef(String orgId) {
    return _firestore.collection('cases');
  }

  String _newMessageId(String caseId, String? idempotencyKey) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) {
      return _uuid.v4();
    }
    return caseMessageDocumentId(caseId: caseId, idempotencyKey: idempotencyKey);
  }

  Map<String, dynamic> _mergeIdempotencyMeta(
    Map<String, dynamic> metadata,
    String? idempotencyKey,
  ) {
    if (idempotencyKey == null || idempotencyKey.isEmpty) return metadata;
    return {
      ...metadata,
      kCaseMessageMetaIdempotencyKey: idempotencyKey,
    };
  }

  /// Send a chat message
  Future<String> sendChatMessage({
    required String caseId,
    required String orgId,
    required String senderId,
    required String senderName,
    required UnifiedParticipantRole senderRole,
    required String content,
    List<DocumentAttachment> attachments = const [],
    String? replyToMessageId,
    Map<String, dynamic> metadata = const {},
    String? idempotencyKey,
  }) async {
    final messageId = _newMessageId(caseId, idempotencyKey);
    final mergedMeta = _mergeIdempotencyMeta(metadata, idempotencyKey);
    final message = UnifiedCaseMessage.chat(
      id: messageId,
      caseId: caseId,
      orgId: orgId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
      attachments: attachments,
      replyToMessageId: replyToMessageId,
      metadata: mergedMeta,
    );

    try {
      await _getCommunicationsRef(
        orgId,
        caseId,
      ).doc(messageId).set(message.toJson());
    } catch (e) {
      log('❌ Error writing chat message doc: $e');
      logCaseCommsSendFailed(
        caseId: caseId,
        orgId: orgId,
        messageId: messageId,
        stage: CaseCommsSendStage.messageWrite,
        type: UnifiedMessageType.chatMessage,
        component: 'UnifiedCaseCommunicationService',
        error: e,
      );
      throw CaseCommsSendException(CaseCommsSendStage.messageWrite, e);
    }

    try {
      await _markAsReadBy(messageId, orgId, caseId, senderId);
      await _updateCaseLastActivity(orgId, caseId);
    } catch (e) {
      log('❌ Error post-write (chat): $e');
      logCaseCommsPostWritePartial(
        caseId: caseId,
        orgId: orgId,
        messageId: messageId,
        type: UnifiedMessageType.chatMessage,
        component: 'UnifiedCaseCommunicationService',
        error: e,
      );
      throw CaseCommsSendException(CaseCommsSendStage.postWrite, e);
    }

    logCaseCommsMessageWriteOk(
      caseId: caseId,
      orgId: orgId,
      messageId: messageId,
      type: UnifiedMessageType.chatMessage,
      component: 'UnifiedCaseCommunicationService',
    );
    log('✅ Chat message sent: $messageId');
    return messageId;
  }

  /// Send a document message
  Future<String> sendDocumentMessage({
    required String caseId,
    required String orgId,
    required String senderId,
    required String senderName,
    required UnifiedParticipantRole senderRole,
    required String content,
    required List<DocumentAttachment> attachments,
    Map<String, dynamic> metadata = const {},
    String? idempotencyKey,
  }) async {
    final messageId = _newMessageId(caseId, idempotencyKey);
    final mergedMeta = _mergeIdempotencyMeta(metadata, idempotencyKey);
    final message = UnifiedCaseMessage.document(
      id: messageId,
      caseId: caseId,
      orgId: orgId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
      attachments: attachments,
      metadata: mergedMeta,
    );

    try {
      await _getCommunicationsRef(
        orgId,
        caseId,
      ).doc(messageId).set(message.toJson());
    } catch (e) {
      log('❌ Error writing document message doc: $e');
      logCaseCommsSendFailed(
        caseId: caseId,
        orgId: orgId,
        messageId: messageId,
        stage: CaseCommsSendStage.messageWrite,
        type: UnifiedMessageType.document,
        component: 'UnifiedCaseCommunicationService',
        error: e,
      );
      throw CaseCommsSendException(CaseCommsSendStage.messageWrite, e);
    }

    try {
      await _markAsReadBy(messageId, orgId, caseId, senderId);
      await _updateCaseLastActivity(orgId, caseId);
    } catch (e) {
      log('❌ Error post-write (document): $e');
      logCaseCommsPostWritePartial(
        caseId: caseId,
        orgId: orgId,
        messageId: messageId,
        type: UnifiedMessageType.document,
        component: 'UnifiedCaseCommunicationService',
        error: e,
      );
      throw CaseCommsSendException(CaseCommsSendStage.postWrite, e);
    }

    logCaseCommsMessageWriteOk(
      caseId: caseId,
      orgId: orgId,
      messageId: messageId,
      type: UnifiedMessageType.document,
      component: 'UnifiedCaseCommunicationService',
    );
    log('✅ Document message sent: $messageId');
    return messageId;
  }

  /// Create a system log
  Future<String> createSystemLog({
    required String caseId,
    required String orgId,
    required String content,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final messageId = _uuid.v4();
      final message = UnifiedCaseMessage.systemLog(
        id: messageId,
        caseId: caseId,
        orgId: orgId,
        content: content,
        metadata: metadata,
      );

      await _getCommunicationsRef(
        orgId,
        caseId,
      ).doc(messageId).set(message.toJson());

      // Update case last activity
      await _updateCaseLastActivity(orgId, caseId);

      log('✅ System log created: $messageId');
      return messageId;
    } catch (e) {
      log('❌ Error creating system log: $e');
      rethrow;
    }
  }

  /// Create a system notification
  Future<String> createSystemNotification({
    required String caseId,
    required String orgId,
    required String content,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final messageId = _uuid.v4();
      final message = UnifiedCaseMessage.systemNotification(
        id: messageId,
        caseId: caseId,
        orgId: orgId,
        content: content,
        metadata: metadata,
      );

      await _getCommunicationsRef(
        orgId,
        caseId,
      ).doc(messageId).set(message.toJson());

      // Update case last activity
      await _updateCaseLastActivity(orgId, caseId);

      log('✅ System notification created: $messageId');
      return messageId;
    } catch (e) {
      log('❌ Error creating system notification: $e');
      rethrow;
    }
  }

  /// Real-time window (latest [limit] messages, newest first).
  Stream<List<UnifiedCaseMessage>> getCaseMessagesStream(
    String orgId,
    String caseId, {
    int limit = kDefaultCaseMessagesLimit,
  }) {
    return getCaseMessagesLiveStream(orgId, caseId, limit: limit)
        .map((b) => b.messages);
  }

  Stream<CaseMessagesLiveBatch> getCaseMessagesLiveStream(
    String orgId,
    String caseId, {
    int limit = kDefaultCaseMessagesLimit,
  }) {
    return _getCommunicationsRef(orgId, caseId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => CaseMessagesLiveBatch(
            messages: snapshot.docs
                .map(
                  (doc) => UnifiedCaseMessage.fromJson(
                    doc.data() as Map<String, dynamic>,
                  ),
                )
                .toList(),
            orderedQueryDocuments: snapshot.docs,
          ),
        );
  }

  Future<CaseMessagesPageResult> getCaseMessagesPage(
    String orgId,
    String caseId, {
    int pageSize = kDefaultCaseMessagesLimit,
    DocumentSnapshot<Object?>? startAfter,
  }) async {
    try {
      Query query = _getCommunicationsRef(orgId, caseId)
          .orderBy('timestamp', descending: true)
          .limit(pageSize);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();
      final messages = snapshot.docs
          .map(
            (doc) => UnifiedCaseMessage.fromJson(
              doc.data() as Map<String, dynamic>,
            ),
          )
          .toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return CaseMessagesPageResult(
        messages: messages,
        lastDocument: lastDoc,
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (e) {
      log('❌ Error getting case messages page: $e');
      rethrow;
    }
  }

  Future<List<UnifiedCaseMessage>> getCaseMessages(
    String orgId,
    String caseId, {
    int limit = kDefaultCaseMessagesLimit,
  }) async {
    final page = await getCaseMessagesPage(
      orgId,
      caseId,
      pageSize: limit,
    );
    return page.messages;
  }

  Future<List<UnifiedCaseMessage>> _getAllCaseMessagesBatched(
    String orgId,
    String caseId,
  ) async {
    final all = <UnifiedCaseMessage>[];
    DocumentSnapshot<Object?>? cursor;
    while (true) {
      final page = await getCaseMessagesPage(
        orgId,
        caseId,
        pageSize: _fullScanPageSize,
        startAfter: cursor,
      );
      all.addAll(page.messages);
      if (!page.hasMore || page.lastDocument == null) break;
      cursor = page.lastDocument;
    }
    return all;
  }

  /// Mark a message as read by a user
  Future<void> markMessageAsRead(
    String messageId,
    String orgId,
    String caseId,
    String userId,
  ) async {
    try {
      await _markAsReadBy(messageId, orgId, caseId, userId);
      log('✅ Message marked as read: $messageId by $userId');
    } catch (e) {
      log('❌ Error marking message as read: $e');
      rethrow;
    }
  }

  /// Private method to mark message as read
  Future<void> _markAsReadBy(
    String messageId,
    String orgId,
    String caseId,
    String userId,
  ) async {
    final messageRef = _getCommunicationsRef(orgId, caseId).doc(messageId);

    await _firestore.runTransaction((transaction) async {
      final messageDoc = await transaction.get(messageRef);
      if (!messageDoc.exists) return;

      final messageData = messageDoc.data() as Map<String, dynamic>;
      final readBy = List<String>.from(messageData['readBy'] ?? []);

      if (!readBy.contains(userId)) {
        readBy.add(userId);
        transaction.update(messageRef, {'readBy': readBy, 'status': 'read'});
      }
    });
  }

  /// Update case last activity timestamp
  Future<void> _updateCaseLastActivity(String orgId, String caseId) async {
    try {
      await _getCasesRef(
        orgId,
      ).doc(caseId).update({'lastActivity': FieldValue.serverTimestamp()});
    } catch (e) {
      log('❌ Error updating case last activity: $e');
      // Don't rethrow as this is not critical
    }
  }

  /// Get unread message count for a user
  Future<int> getUnreadMessageCount(
    String orgId,
    String caseId,
    String userId,
  ) async {
    try {
      final snapshot = await _getCommunicationsRef(
        orgId,
        caseId,
      ).where('readBy', arrayContains: userId).get();

      final allMessages = await _getAllCaseMessagesBatched(orgId, caseId);
      final readMessageIds = snapshot.docs.map((doc) => doc.id).toSet();

      return allMessages
          .where((message) => !readMessageIds.contains(message.id))
          .length;
    } catch (e) {
      log('❌ Error getting unread message count: $e');
      return 0;
    }
  }

  /// Sanitize filename to prevent path traversal and malicious characters
  /// Mirrors the litigation instruction upload sanitization for consistent behaviour
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

  /// Upload document attachment
  Future<String> uploadDocument({
    required String caseId,
    required String orgId,
    required String fileName,
    required List<int> fileBytes,
    required String fileType,
    required String uploadedBy,
  }) async {
    try {
      // Preserve original filename for display while sanitizing storage path
      final originalFileName = fileName;
      final safeFileName = _sanitizeFileName(fileName);

      log(
        '[UnifiedCaseCommunicationService] Original filename: $originalFileName',
      );
      log(
        '[UnifiedCaseCommunicationService] Sanitized filename: $safeFileName',
      );

      // Create unique UUID for this upload
      final attachmentId = _uuid.v4();

      // Store with UUID subfolder to preserve clean filename
      final storagePath = 'cases/$caseId/documents/$attachmentId/$safeFileName';

      log(
        '[UnifiedCaseCommunicationService] 📁 Storage path (canonical): $storagePath',
      );

      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putData(Uint8List.fromList(fileBytes));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      log('✅ Document uploaded: $attachmentId');
      return downloadUrl;
    } catch (e) {
      log('❌ Error uploading document: $e');
      rethrow;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(
    String messageId,
    String orgId,
    String caseId,
  ) async {
    try {
      await _getCommunicationsRef(orgId, caseId).doc(messageId).delete();
      log('✅ Message deleted: $messageId');
    } catch (e) {
      log('❌ Error deleting message: $e');
      rethrow;
    }
  }

  /// Get messages by type
  Future<List<UnifiedCaseMessage>> getMessagesByType(
    String orgId,
    String caseId,
    UnifiedMessageType type,
  ) async {
    try {
      final snapshot = await _getCommunicationsRef(orgId, caseId)
          .where('type', isEqualTo: type.name)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) =>
                UnifiedCaseMessage.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      log('❌ Error getting messages by type: $e');
      rethrow;
    }
  }

  /// Search messages by content
  Future<List<UnifiedCaseMessage>> searchMessages(
    String orgId,
    String caseId,
    String query,
  ) async {
    try {
      final allMessages = await _getAllCaseMessagesBatched(orgId, caseId);
      return allMessages
          .where(
            (message) =>
                message.content.toLowerCase().contains(query.toLowerCase()) ||
                message.senderName.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    } catch (e) {
      log('❌ Error searching messages: $e');
      rethrow;
    }
  }

  /// Get message statistics for a case
  Future<Map<String, int>> getMessageStatistics(
    String orgId,
    String caseId,
  ) async {
    try {
      final allMessages = await _getAllCaseMessagesBatched(orgId, caseId);

      final stats = <String, int>{
        'total': allMessages.length,
        'chatMessages': 0,
        'systemLogs': 0,
        'documents': 0,
        'systemNotifications': 0,
      };

      for (final message in allMessages) {
        switch (message.type) {
          case UnifiedMessageType.chatMessage:
            stats['chatMessages'] = (stats['chatMessages'] ?? 0) + 1;
            break;
          case UnifiedMessageType.systemLog:
            stats['systemLogs'] = (stats['systemLogs'] ?? 0) + 1;
            break;
          case UnifiedMessageType.document:
            stats['documents'] = (stats['documents'] ?? 0) + 1;
            break;
          case UnifiedMessageType.systemNotification:
            stats['systemNotifications'] =
                (stats['systemNotifications'] ?? 0) + 1;
            break;
        }
      }

      return stats;
    } catch (e) {
      log('❌ Error getting message statistics: $e');
      return {
        'total': 0,
        'chatMessages': 0,
        'systemLogs': 0,
        'documents': 0,
        'systemNotifications': 0,
      };
    }
  }
}
