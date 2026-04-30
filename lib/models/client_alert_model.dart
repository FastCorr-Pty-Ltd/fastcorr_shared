import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum ClientAlertType {
  // Litigation Request
  requestSubmitted,
  requestAccepted,
  requestArrived,
  requestPickedUp,
  requestCompleted,
  requestFailed,
  requestExpired,

  // Delivery Order
  deliveryAccepted,
  deliveryArrivedAtPickup,
  deliveryPickedUp,
  deliveryInTransit,
  deliveryArrivedAtDestination,
  deliveryCompleted,
  deliveryFailed,

  // Case Management
  caseCreated,
  caseUpdated,
  casePhaseChanged,
  caseDocumentUploaded,
  caseCommentAdded,

  // Trial
  trialCreated,
  trialReminder24h,
  trialReminder1h,
  trialUpdated,
  trialCancelled,

  // Chat
  chatMessage,
  chatDocumentShared,
  chatMention,

  // Payment
  paymentSuccessful,
  paymentFailed,
  paymentRefund,
  creditAdded,
  creditLow,

  // System
  accountVerification,
  inviteAccepted,
  policyUpdate,
  maintenanceScheduled,
}

extension AlertTypeX on ClientAlertType {
  /// Categorizes as 'Litigation' if the enum starts with 'request'
  bool get isLitigation => name.startsWith('request');

  /// Categorizes as 'Delivery' if the enum starts with 'delivery'
  bool get isDelivery => name.startsWith('delivery');

  /// Categorizes as 'Trial' if the enum starts with 'trial'
  bool get isTrial => name.startsWith('trial');

  /// Categorizes as 'Payment' if the enum starts with 'payment' or 'credit'
  bool get isPayment => name.startsWith('payment') || name.startsWith('credit');

  /// Logic to determine if this notification type requires an email
  bool get shouldSendEmail {
    switch (this) {
      // Case Management (Specific ones)
      case ClientAlertType.caseCreated:
      case ClientAlertType.caseDocumentUploaded:
        return true;

      // Trial — scheduled reminders use in-app / Cloud Function only for now.
      case ClientAlertType.trialReminder24h:
      case ClientAlertType.trialReminder1h:
        return false;

      // Other trial alerts (create/update/cancel) may still use email when wired.
      case ClientAlertType.trialCreated:
      case ClientAlertType.trialUpdated:
      case ClientAlertType.trialCancelled:
        return true;

      // Payment (All)
      case ClientAlertType.paymentSuccessful:
      case ClientAlertType.paymentFailed:
      case ClientAlertType.paymentRefund:
      case ClientAlertType.creditAdded:
      case ClientAlertType.creditLow:
        return true;

      // System (All)
      case ClientAlertType.accountVerification:
      case ClientAlertType.inviteAccepted:
      case ClientAlertType.policyUpdate:
      case ClientAlertType.maintenanceScheduled:
        return true;

      // Everything else (Litigation, Delivery, Chat) defaults to false
      default:
        return false;
    }
  }

  bool get isCritical =>
      this == ClientAlertType.requestExpired ||
      this == ClientAlertType.requestFailed ||
      this == ClientAlertType.deliveryFailed ||
      this == ClientAlertType.paymentFailed ||
      this == ClientAlertType.trialReminder1h ||
      this == ClientAlertType.creditLow;
}

class ClientAlertModel {
  final String id;
  final String taskId;
  final String userId;
  final ClientAlertType type;
  final String title;
  final String body;
  final String officeId;
  final Timestamp sentAt;
  final bool acknowledged;
  final bool read;
  final String? recipientEmail;
  final bool sendEmail;
  final Map<String, dynamic>? data;

  ClientAlertModel({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.officeId,
    required this.sentAt,
    this.acknowledged = false,
    this.read = false,
    this.recipientEmail,
    this.sendEmail = false,
    this.data,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'userId': userId,
    'type': type.name, // Stores as "taskAssigned"
    'title': title,
    'body': body,
    'officeId': officeId,
    'sentAt': sentAt,
    'acknowledged': acknowledged,
    'read': read,
    'recipientEmail': recipientEmail,
    'sendEmail': sendEmail,
    'data': data,
  };

  static ClientAlertModel fromJson(Map<String, Object?> json) {
    return ClientAlertModel(
      id: json['id'] as String,
      taskId: json['taskId'] as String? ?? '',
      userId: json['userId'] as String,
      type: ClientAlertType.values.byName(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      officeId: json['officeId'] as String? ?? '',
      sentAt: processedTimestamp(json['sentAt'])!,
      acknowledged: json['acknowledged'] as bool? ?? false,
      read: json['read'] as bool? ?? false,
      recipientEmail: json['recipientEmail'] as String? ?? '',
      sendEmail: json['sendEmail'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  factory ClientAlertModel.fromSnapshot(DocumentSnapshot snap) {
    return ClientAlertModel(
      id: snap.id,
      taskId: snap['taskId'] as String? ?? '',
      userId: snap['userId'] as String,
      type: ClientAlertType.values.byName(snap['type'] as String),
      title: snap['title'] as String,
      body: snap['body'] as String,
      officeId: snap['officeId'] as String? ?? '',
      // Handle null timestamp from FieldValue.serverTimestamp() during document creation
      sentAt:
          processedTimestamp(snap['sentAt']) ??
          Timestamp.fromDate(DateTime.now()),
      acknowledged: snap['acknowledged'] as bool? ?? false,
      read: snap['read'] as bool? ?? false,
      recipientEmail: snap['recipientEmail'] as String? ?? '',
      sendEmail: snap['sendEmail'] as bool? ?? false,
      data: snap['data'] as Map<String, dynamic>?,
    );
  }

  ClientAlertModel copyWith({
    String? id,
    String? taskId,
    String? userId,
    ClientAlertType? type,
    String? title,
    String? body,
    String? officeId,
    Timestamp? sentAt,
    bool? acknowledged,
    bool? read,
    String? recipientEmail,
    bool? sendEmail,
    Map<String, dynamic>? data,
  }) {
    return ClientAlertModel(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      officeId: officeId ?? this.officeId,
      sentAt: sentAt ?? this.sentAt,
      acknowledged: acknowledged ?? this.acknowledged,
      read: read ?? this.read,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      sendEmail: sendEmail ?? this.sendEmail,
      data: data ?? this.data,
    );
  }

  // =============================================================================
  // NOTIFICATION PRESENTATION HELPERS
  // =============================================================================

  /// Get formatted time since sent
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(sentAt.toDate());

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Get notification icon based on type
  String get icon {
    switch (type) {
      case ClientAlertType.requestSubmitted:
        return '📝';
      case ClientAlertType.requestAccepted:
      case ClientAlertType.deliveryAccepted:
        return '✅';
      case ClientAlertType.requestArrived:
      case ClientAlertType.deliveryArrivedAtPickup:
      case ClientAlertType.deliveryArrivedAtDestination:
        return '📍';
      case ClientAlertType.requestPickedUp:
      case ClientAlertType.deliveryPickedUp:
        return '📦';
      case ClientAlertType.requestCompleted:
      case ClientAlertType.deliveryCompleted:
        return '🎉';
      case ClientAlertType.requestFailed:
      case ClientAlertType.deliveryFailed:
      case ClientAlertType.paymentFailed:
        return '❌';
      case ClientAlertType.requestExpired:
      case ClientAlertType.trialReminder24h:
      case ClientAlertType.trialReminder1h:
        return '⏰';
      case ClientAlertType.deliveryInTransit:
        return '🚗';
      case ClientAlertType.caseCreated:
        return '📁';
      case ClientAlertType.caseUpdated:
      case ClientAlertType.trialUpdated:
        return '🔄';
      case ClientAlertType.casePhaseChanged:
        return '⚖️';
      case ClientAlertType.caseDocumentUploaded:
        return '📄';
      case ClientAlertType.caseCommentAdded:
      case ClientAlertType.chatMessage:
        return '💬';
      case ClientAlertType.trialCreated:
        return '📅';
      case ClientAlertType.trialCancelled:
        return '🚫';
      case ClientAlertType.chatDocumentShared:
        return '📎';
      case ClientAlertType.chatMention:
        return '👤';
      case ClientAlertType.paymentSuccessful:
        return '💳';
      case ClientAlertType.paymentRefund:
      case ClientAlertType.creditAdded:
        return '💰';
      case ClientAlertType.creditLow:
        return '⚠️';
      case ClientAlertType.accountVerification:
        return '✔️';
      case ClientAlertType.inviteAccepted:
        return '👥';
      case ClientAlertType.policyUpdate:
        return '📋';
      case ClientAlertType.maintenanceScheduled:
        return '🔧';
    }
  }

  /// Get notification color based on type
  String get color {
    switch (type) {
      // Green
      case ClientAlertType.requestSubmitted:
      case ClientAlertType.requestAccepted:
      case ClientAlertType.deliveryAccepted:
      case ClientAlertType.caseCreated:
      case ClientAlertType.trialCreated:
      case ClientAlertType.paymentSuccessful:
      case ClientAlertType.creditAdded:
        return '#2ED573';

      // Orange
      case ClientAlertType.requestArrived:
      case ClientAlertType.requestPickedUp:
      case ClientAlertType.deliveryArrivedAtPickup:
      case ClientAlertType.deliveryPickedUp:
      case ClientAlertType.deliveryInTransit:
      case ClientAlertType.deliveryArrivedAtDestination:
      case ClientAlertType.casePhaseChanged:
      case ClientAlertType.trialReminder24h:
      case ClientAlertType.creditLow:
        return '#FFA502';

      // Blue
      case ClientAlertType.requestCompleted:
      case ClientAlertType.deliveryCompleted:
      case ClientAlertType.caseUpdated:
      case ClientAlertType.caseDocumentUploaded:
      case ClientAlertType.trialUpdated:
      case ClientAlertType.paymentRefund:
        return '#3742FA';

      // Red
      case ClientAlertType.requestFailed:
      case ClientAlertType.requestExpired:
      case ClientAlertType.deliveryFailed:
      case ClientAlertType.trialReminder1h:
      case ClientAlertType.trialCancelled:
      case ClientAlertType.paymentFailed:
        return '#FF6B6B';

      // Purple
      case ClientAlertType.caseCommentAdded:
      case ClientAlertType.chatMessage:
      case ClientAlertType.chatDocumentShared:
      case ClientAlertType.chatMention:
        return '#9C88FF';

      // System
      case ClientAlertType.accountVerification:
      case ClientAlertType.inviteAccepted:
      case ClientAlertType.policyUpdate:
      case ClientAlertType.maintenanceScheduled:
        return '#3742FA';
    }
  }
}
