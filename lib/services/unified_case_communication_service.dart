/// Unified case communication service for cross-app communication
/// This service is shared between fastcorr_user and fastcorr_admin apps

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:stacked/stacked.dart';
import 'package:uuid/uuid.dart';
import '../models/unified_case_message.dart';

/// Service for managing unified case communications across apps
class UnifiedCaseCommunicationService with ListenableServiceMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

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
  }) async {
    try {
      final messageId = _uuid.v4();
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
        metadata: metadata,
      );

      await _getCommunicationsRef(
        orgId,
        caseId,
      ).doc(messageId).set(message.toJson());

      // Mark as read by sender
      await _markAsReadBy(messageId, orgId, caseId, senderId);

      // Update case last activity
      await _updateCaseLastActivity(orgId, caseId);

      print('✅ Chat message sent: $messageId');
      return messageId;
    } catch (e) {
      print('❌ Error sending chat message: $e');
      rethrow;
    }
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
  }) async {
    try {
      final messageId = _uuid.v4();
      final message = UnifiedCaseMessage.document(
        id: messageId,
        caseId: caseId,
        orgId: orgId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        content: content,
        attachments: attachments,
        metadata: metadata,
      );

      await _getCommunicationsRef(
        orgId,
        caseId,
      ).doc(messageId).set(message.toJson());

      // Mark as read by sender
      await _markAsReadBy(messageId, orgId, caseId, senderId);

      // Update case last activity
      await _updateCaseLastActivity(orgId, caseId);

      print('✅ Document message sent: $messageId');
      return messageId;
    } catch (e) {
      print('❌ Error sending document message: $e');
      rethrow;
    }
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

      print('✅ System log created: $messageId');
      return messageId;
    } catch (e) {
      print('❌ Error creating system log: $e');
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

      print('✅ System notification created: $messageId');
      return messageId;
    } catch (e) {
      print('❌ Error creating system notification: $e');
      rethrow;
    }
  }

  /// Get real-time stream of case messages
  Stream<List<UnifiedCaseMessage>> getCaseMessagesStream(
    String orgId,
    String caseId,
  ) {
    return _getCommunicationsRef(orgId, caseId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => UnifiedCaseMessage.fromJson(
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  /// Get case messages (one-time fetch)
  Future<List<UnifiedCaseMessage>> getCaseMessages(
    String orgId,
    String caseId,
  ) async {
    try {
      final snapshot = await _getCommunicationsRef(
        orgId,
        caseId,
      ).orderBy('timestamp', descending: true).get();

      return snapshot.docs
          .map(
            (doc) =>
                UnifiedCaseMessage.fromJson(doc.data() as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('❌ Error getting case messages: $e');
      rethrow;
    }
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
      print('✅ Message marked as read: $messageId by $userId');
    } catch (e) {
      print('❌ Error marking message as read: $e');
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
      print('❌ Error updating case last activity: $e');
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

      final allMessages = await getCaseMessages(orgId, caseId);
      final readMessageIds = snapshot.docs.map((doc) => doc.id).toSet();

      return allMessages
          .where((message) => !readMessageIds.contains(message.id))
          .length;
    } catch (e) {
      print('❌ Error getting unread message count: $e');
      return 0;
    }
  }

  /// Upload document attachment
  Future<DocumentAttachment> uploadDocument({
    required String caseId,
    required String orgId,
    required String fileName,
    required List<int> fileBytes,
    required String fileType,
    required String uploadedBy,
  }) async {
    try {
      final attachmentId = _uuid.v4();
      final storagePath = 'cases/$caseId/documents/$attachmentId';

      final ref = _storage.ref().child(storagePath);
      final uploadTask = ref.putData(Uint8List.fromList(fileBytes));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      final attachment = DocumentAttachment(
        id: attachmentId,
        fileName: fileName,
        fileUrl: downloadUrl,
        fileType: fileType,
        fileSize: fileBytes.length,
        uploadedAt: DateTime.now(),
        uploadedBy: uploadedBy,
      );

      print('✅ Document uploaded: $attachmentId');
      return attachment;
    } catch (e) {
      print('❌ Error uploading document: $e');
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
      print('✅ Message deleted: $messageId');
    } catch (e) {
      print('❌ Error deleting message: $e');
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
      print('❌ Error getting messages by type: $e');
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
      final allMessages = await getCaseMessages(orgId, caseId);
      return allMessages
          .where(
            (message) =>
                message.content.toLowerCase().contains(query.toLowerCase()) ||
                message.senderName.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    } catch (e) {
      print('❌ Error searching messages: $e');
      rethrow;
    }
  }

  /// Get message statistics for a case
  Future<Map<String, int>> getMessageStatistics(
    String orgId,
    String caseId,
  ) async {
    try {
      final allMessages = await getCaseMessages(orgId, caseId);

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
      print('❌ Error getting message statistics: $e');
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
