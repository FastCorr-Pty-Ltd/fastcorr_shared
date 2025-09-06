/// Unified case message model for cross-app communication
/// This model is shared between fastcorr_user and fastcorr_admin apps

import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of messages in the case communication system
enum UnifiedMessageType { systemLog, chatMessage, document, systemNotification }

/// Roles of participants in case communication
enum UnifiedParticipantRole {
  lawyer,
  client,
  admin,
  secretary,
  driver,
  courtClerk,
  observer,
}

/// Status of a message
enum MessageStatus { sent, delivered, read }

/// Document attachment for messages
class DocumentAttachment {
  final String id;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSize;
  final DateTime uploadedAt;
  final String uploadedBy;

  const DocumentAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.uploadedAt,
    required this.uploadedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'uploadedBy': uploadedBy,
    };
  }

  factory DocumentAttachment.fromJson(Map<String, dynamic> json) {
    return DocumentAttachment(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileUrl: json['fileUrl'] as String,
      fileType: json['fileType'] as String,
      fileSize: json['fileSize'] as int,
      uploadedAt: (json['uploadedAt'] as Timestamp).toDate(),
      uploadedBy: json['uploadedBy'] as String,
    );
  }

  DocumentAttachment copyWith({
    String? id,
    String? fileName,
    String? fileUrl,
    String? fileType,
    int? fileSize,
    DateTime? uploadedAt,
    String? uploadedBy,
  }) {
    return DocumentAttachment(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
    );
  }
}

/// Unified case message for cross-app communication
class UnifiedCaseMessage {
  final String id;
  final String caseId;
  final String orgId;
  final UnifiedMessageType type;
  final String senderId;
  final String senderName;
  final UnifiedParticipantRole senderRole;
  final String content;
  final List<DocumentAttachment> attachments;
  final DateTime timestamp;
  final MessageStatus status;
  final List<String> readBy;
  final String? replyToMessageId;
  final Map<String, dynamic> metadata;

  const UnifiedCaseMessage({
    required this.id,
    required this.caseId,
    required this.orgId,
    required this.type,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    this.attachments = const [],
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.readBy = const [],
    this.replyToMessageId,
    this.metadata = const {},
  });

  /// Create a chat message
  factory UnifiedCaseMessage.chat({
    required String id,
    required String caseId,
    required String orgId,
    required String senderId,
    required String senderName,
    required UnifiedParticipantRole senderRole,
    required String content,
    List<DocumentAttachment> attachments = const [],
    String? replyToMessageId,
    Map<String, dynamic> metadata = const {},
  }) {
    return UnifiedCaseMessage(
      id: id,
      caseId: caseId,
      orgId: orgId,
      type: UnifiedMessageType.chatMessage,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
      attachments: attachments,
      timestamp: DateTime.now(),
      replyToMessageId: replyToMessageId,
      metadata: metadata,
    );
  }

  /// Create a system log message
  factory UnifiedCaseMessage.systemLog({
    required String id,
    required String caseId,
    required String orgId,
    required String content,
    Map<String, dynamic> metadata = const {},
  }) {
    return UnifiedCaseMessage(
      id: id,
      caseId: caseId,
      orgId: orgId,
      type: UnifiedMessageType.systemLog,
      senderId: 'system',
      senderName: 'System',
      senderRole: UnifiedParticipantRole.admin,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Create a document message
  factory UnifiedCaseMessage.document({
    required String id,
    required String caseId,
    required String orgId,
    required String senderId,
    required String senderName,
    required UnifiedParticipantRole senderRole,
    required String content,
    required List<DocumentAttachment> attachments,
    Map<String, dynamic> metadata = const {},
  }) {
    return UnifiedCaseMessage(
      id: id,
      caseId: caseId,
      orgId: orgId,
      type: UnifiedMessageType.document,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
      attachments: attachments,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Create a system notification
  factory UnifiedCaseMessage.systemNotification({
    required String id,
    required String caseId,
    required String orgId,
    required String content,
    Map<String, dynamic> metadata = const {},
  }) {
    return UnifiedCaseMessage(
      id: id,
      caseId: caseId,
      orgId: orgId,
      type: UnifiedMessageType.systemNotification,
      senderId: 'system',
      senderName: 'System',
      senderRole: UnifiedParticipantRole.admin,
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caseId': caseId,
      'orgId': orgId,
      'type': type.name,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole.name,
      'content': content,
      'attachments': attachments
          .map((attachment) => attachment.toJson())
          .toList(),
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.name,
      'readBy': readBy,
      'replyToMessageId': replyToMessageId,
      'metadata': metadata,
    };
  }

  factory UnifiedCaseMessage.fromJson(Map<String, dynamic> json) {
    return UnifiedCaseMessage(
      id: json['id'] as String,
      caseId: json['caseId'] as String,
      orgId: json['orgId'] as String,
      type: UnifiedMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => UnifiedMessageType.chatMessage,
      ),
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderRole: UnifiedParticipantRole.values.firstWhere(
        (e) => e.name == json['senderRole'],
        orElse: () => UnifiedParticipantRole.observer,
      ),
      content: json['content'] as String,
      attachments:
          (json['attachments'] as List<dynamic>?)
              ?.map(
                (attachment) => DocumentAttachment.fromJson(
                  attachment as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      readBy: (json['readBy'] as List<dynamic>?)?.cast<String>() ?? [],
      replyToMessageId: json['replyToMessageId'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  UnifiedCaseMessage copyWith({
    String? id,
    String? caseId,
    String? orgId,
    UnifiedMessageType? type,
    String? senderId,
    String? senderName,
    UnifiedParticipantRole? senderRole,
    String? content,
    List<DocumentAttachment>? attachments,
    DateTime? timestamp,
    MessageStatus? status,
    List<String>? readBy,
    String? replyToMessageId,
    Map<String, dynamic>? metadata,
  }) {
    return UnifiedCaseMessage(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      orgId: orgId ?? this.orgId,
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      attachments: attachments ?? this.attachments,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      readBy: readBy ?? this.readBy,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Mark message as read by a user
  UnifiedCaseMessage markAsReadBy(String userId) {
    if (readBy.contains(userId)) return this;

    return copyWith(readBy: [...readBy, userId], status: MessageStatus.read);
  }

  /// Check if message is read by a specific user
  bool isReadBy(String userId) {
    return readBy.contains(userId);
  }

  /// Get display name for message type
  String get typeDisplayName {
    switch (type) {
      case UnifiedMessageType.systemLog:
        return 'System Log';
      case UnifiedMessageType.chatMessage:
        return 'Chat Message';
      case UnifiedMessageType.document:
        return 'Document';
      case UnifiedMessageType.systemNotification:
        return 'System Notification';
    }
  }

  /// Get display name for sender role
  String get senderRoleDisplayName {
    switch (senderRole) {
      case UnifiedParticipantRole.lawyer:
        return 'Attorney';
      case UnifiedParticipantRole.client:
        return 'Client';
      case UnifiedParticipantRole.admin:
        return 'Admin';
      case UnifiedParticipantRole.secretary:
        return 'Secretary';
      case UnifiedParticipantRole.driver:
        return 'Driver';
      case UnifiedParticipantRole.courtClerk:
        return 'Court Clerk';
      case UnifiedParticipantRole.observer:
        return 'Observer';
    }
  }

  /// Check if message has attachments
  bool get hasAttachments => attachments.isNotEmpty;

  /// Get attachment count
  int get attachmentCount => attachments.length;

  /// Get total attachment size
  int get totalAttachmentSize {
    return attachments.fold(0, (sum, attachment) => sum + attachment.fileSize);
  }

  @override
  String toString() {
    return 'UnifiedCaseMessage(id: $id, caseId: $caseId, type: $type, sender: $senderName, content: $content)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnifiedCaseMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
