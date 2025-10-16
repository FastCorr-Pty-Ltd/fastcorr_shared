import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum TicketSenderRole { client, supportAgent, developer, admin, system }

class TicketMsg {
  final String senderId;
  final TicketSenderRole senderRole;
  final String message;
  final Timestamp sentAt;
  final List<String> attachments; // optional URLs

  TicketMsg({
    required this.senderId,
    required this.senderRole,
    required this.message,
    required this.sentAt,
    this.attachments = const [],
  });

  factory TicketMsg.fromSnapshot(DocumentSnapshot snap) {
    return TicketMsg(
      senderId: snap['senderId'] ?? '',
      senderRole: TicketSenderRole.values.byName(snap['senderRole']),
      message: snap['message'] ?? '',
      sentAt: processedTimestamp(snap['sentAt'])!,
      attachments: safeListFromSnapshot(snap['attachments']),
    );
  }

  factory TicketMsg.fromJson(Map<String, dynamic> json) {
    return TicketMsg(
      senderId: json['senderId'] ?? '',
      senderRole: TicketSenderRole.values.byName(json['senderRole']),
      message: json['message'] ?? '',
      sentAt: processedTimestamp(json['sentAt'])!,
      attachments: safeListFromJson(json['attachments']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'senderRole': senderRole.name,
      'message': message,
      'sentAt': sentAt,
      'attachments': safeListToJson(attachments),
    };
  }

  TicketMsg copyWith({
    String? senderId,
    TicketSenderRole? senderRole,
    String? message,
    Timestamp? sentAt,
    List<String>? attachments,
  }) {
    return TicketMsg(
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      message: message ?? this.message,
      sentAt: sentAt ?? this.sentAt,
      attachments: attachments ?? this.attachments,
    );
  }
}
