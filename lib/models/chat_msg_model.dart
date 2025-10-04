import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.fileName,
    this.fileSize,
    this.fileUrl,
    this.fileBytes,
  });

  factory ChatMsgModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>;
    return ChatMsgModel.fromJson(data);
  }

  factory ChatMsgModel.fromJson(Map<String, dynamic> json) {
    return ChatMsgModel(
      id: json['id'] ?? '',
      senderName: json['senderName'] ?? '',
      senderRole: SenderRole.values.byName(json['senderRole']),
      content: json['content'] ?? '',
      type: MessageType.values.byName(json['type']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
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
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileUrl: fileUrl ?? this.fileUrl,
      fileBytes: fileBytes ?? this.fileBytes,
    );
  }
}
