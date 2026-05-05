import 'package:cloud_firestore/cloud_firestore.dart';

import 'unified_case_message.dart' show MessageStatus;

enum MessageType { text, image, file }

enum SenderRole { admin, support, client, driver, assignee, system }

class ChatMsgModel {
  final String id;
  final String senderName;
  final SenderRole senderRole;
  final String content;
  final MessageType type;
  final DateTime createdAt;
  final bool isRead;
  /// Firebase Auth uid (or staff userId) for the sender; null for legacy/system.
  final String? senderId;
  /// Delivery pipeline status for order chat (optional for legacy messages).
  final MessageStatus status;
  final String? fileName;
  final int? fileSize;
  final String? fileUrl;
  final List<int>? fileBytes;

  ChatMsgModel({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.senderId,
    this.status = MessageStatus.sent,
    this.fileName,
    this.fileSize,
    this.fileUrl,
    this.fileBytes,
  });

  factory ChatMsgModel.fromSnapshot(DocumentSnapshot snap) {
    final raw = snap.data();
    final data = raw is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    data['id'] = (data['id'] as String?)?.isNotEmpty == true ? data['id'] : snap.id;
    return ChatMsgModel.fromJson(data);
  }

  static DateTime _parseCreatedAt(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  static SenderRole _parseSenderRole(dynamic v) {
    if (v is! String || v.isEmpty) return SenderRole.system;
    try {
      return SenderRole.values.byName(v);
    } catch (_) {
      return SenderRole.system;
    }
  }

  static MessageType _parseMessageType(dynamic v) {
    if (v is! String || v.isEmpty) return MessageType.text;
    try {
      return MessageType.values.byName(v);
    } catch (_) {
      return MessageType.text;
    }
  }

  static MessageStatus _parseStatus(dynamic v) {
    if (v is! String || v.isEmpty) return MessageStatus.sent;
    try {
      return MessageStatus.values.byName(v);
    } catch (_) {
      return MessageStatus.sent;
    }
  }

  factory ChatMsgModel.fromJson(Map<String, dynamic> json) {
    var status = _parseStatus(json['status']);
    if (json['status'] == null && json['isRead'] == true) {
      status = MessageStatus.read;
    }
    return ChatMsgModel(
      id: json['id'] ?? '',
      senderName: json['senderName'] ?? '',
      senderRole: _parseSenderRole(json['senderRole']),
      content: json['content'] ?? '',
      type: _parseMessageType(json['type']),
      createdAt: _parseCreatedAt(json['createdAt']),
      isRead: json['isRead'] ?? false,
      senderId: json['senderId'] as String?,
      status: status,
      fileName: json['fileName'],
      fileSize: json['fileSize'],
      fileUrl: json['fileUrl'],
      fileBytes: json['fileBytes'] != null
          ? List<int>.from(json['fileBytes'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderName': senderName,
      'senderRole': senderRole.name,
      'content': content,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'status': status.name,
      if (senderId != null && senderId!.isNotEmpty) 'senderId': senderId,
      'fileName': fileName,
      'fileSize': fileSize,
      'fileUrl': fileUrl,
      'fileBytes': fileBytes,
    };
  }

  ChatMsgModel copyWith({
    String? id,
    String? senderName,
    SenderRole? senderRole,
    String? content,
    MessageType? type,
    DateTime? createdAt,
    bool? isRead,
    String? senderId,
    MessageStatus? status,
    String? fileName,
    int? fileSize,
    String? fileUrl,
    List<int>? fileBytes,
  }) {
    return ChatMsgModel(
      id: id ?? this.id,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      senderId: senderId ?? this.senderId,
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileUrl: fileUrl ?? this.fileUrl,
      fileBytes: fileBytes ?? this.fileBytes,
    );
  }
}
