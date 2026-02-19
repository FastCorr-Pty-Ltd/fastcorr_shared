import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum AlertType {
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

extension AlertTypeX on AlertType {
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
      case AlertType.caseCreated:
      case AlertType.caseDocumentUploaded:
        return true;

      // Trial (All)
      case AlertType.trialCreated:
      case AlertType.trialReminder24h:
      case AlertType.trialReminder1h:
      case AlertType.trialUpdated:
      case AlertType.trialCancelled:
        return true;

      // Payment (All)
      case AlertType.paymentSuccessful:
      case AlertType.paymentFailed:
      case AlertType.paymentRefund:
      case AlertType.creditAdded:
      case AlertType.creditLow:
        return true;

      // System (All)
      case AlertType.accountVerification:
      case AlertType.inviteAccepted:
      case AlertType.policyUpdate:
      case AlertType.maintenanceScheduled:
        return true;

      // Everything else (Litigation, Delivery, Chat) defaults to false
      default:
        return false;
    }
  }

  bool get isCritical =>
      this == AlertType.requestExpired ||
      this == AlertType.requestFailed ||
      this == AlertType.deliveryFailed ||
      this == AlertType.paymentFailed ||
      this == AlertType.trialReminder1h ||
      this == AlertType.creditLow;
}

class NotificationModel {
  final String id;
  final String taskId;
  final String userId;
  final AlertType type;
  final String title;
  final String body;
  final String officeId;
  final Timestamp sentAt;
  final bool acknowledged;
  final bool read;
  final String? recipientEmail;
  final bool sendEmail;
  final Map<String, dynamic>? data;

  NotificationModel({
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

  static NotificationModel fromJson(Map<String, Object?> json) {
    return NotificationModel(
      id: json['id'] as String,
      taskId: json['taskId'] as String? ?? '',
      userId: json['userId'] as String,
      type: AlertType.values.byName(json['type'] as String),
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

  factory NotificationModel.fromSnapshot(DocumentSnapshot snap) {
    return NotificationModel(
      id: snap.id,
      taskId: snap['taskId'] as String? ?? '',
      userId: snap['userId'] as String,
      type: AlertType.values.byName(snap['type'] as String),
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

  NotificationModel copyWith({
    String? id,
    String? taskId,
    String? userId,
    AlertType? type,
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
    return NotificationModel(
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
  // NOTIFICATION TYPE HELPERS
  // =============================================================================

  /// Litigation Request notifications
  bool get isRequestSubmitted => type == 'request_submitted';
  bool get isRequestAccepted => type == 'request_accepted';
  bool get isRequestArrived => type == 'request_arrived';
  bool get isRequestPickedUp => type == 'request_picked_up';
  bool get isRequestCompleted => type == 'request_completed';
  bool get isRequestFailed => type == 'request_failed';
  bool get isRequestExpired => type == 'request_expired';

  /// Delivery Order notifications
  bool get isDeliveryAccepted => type == 'delivery_accepted';
  bool get isDeliveryArrivedAtPickup => type == 'delivery_arrived_at_pickup';
  bool get isDeliveryPickedUp => type == 'delivery_picked_up';
  bool get isDeliveryInTransit => type == 'delivery_in_transit';
  bool get isDeliveryArrivedAtDestination =>
      type == 'delivery_arrived_at_destination';
  bool get isDeliveryCompleted => type == 'delivery_completed';
  bool get isDeliveryFailed => type == 'delivery_failed';

  /// Case Management notifications
  bool get isCaseCreated => type == 'case_created';
  bool get isCaseUpdated => type == 'case_updated';
  bool get isCasePhaseChanged => type == 'case_phase_changed';
  bool get isCaseDocumentUploaded => type == 'case_document_uploaded';
  bool get isCaseCommentAdded => type == 'case_comment_added';

  /// Trial notifications
  bool get isTrialCreated => type == 'trial_created';
  bool get isTrialReminder24h => type == 'trial_reminder_24h';
  bool get isTrialReminder1h => type == 'trial_reminder_1h';
  bool get isTrialUpdated => type == 'trial_updated';
  bool get isTrialCancelled => type == 'trial_cancelled';

  /// Chat notifications
  bool get isChatMessage => type == 'chat_message';
  bool get isChatDocumentShared => type == 'chat_document_shared';
  bool get isChatMention => type == 'chat_mention';

  /// Payment notifications
  bool get isPaymentSuccessful => type == 'payment_successful';
  bool get isPaymentFailed => type == 'payment_failed';
  bool get isPaymentRefund => type == 'payment_refund';
  bool get isCreditAdded => type == 'credit_added';
  bool get isCreditLow => type == 'credit_low';

  /// System notifications
  bool get isAccountVerification => type == 'account_verification';
  bool get isInviteAccepted => type == 'invite_accepted';
  bool get isPolicyUpdate => type == 'policy_update';
  bool get isMaintenanceScheduled => type == 'maintenance_scheduled';

  /// Critical notifications (require immediate attention)
  bool get isCritical =>
      isRequestExpired ||
      isRequestFailed ||
      isDeliveryFailed ||
      isPaymentFailed ||
      isTrialReminder1h ||
      isCreditLow;

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
    // Request notifications
    if (isRequestSubmitted) return '📝';
    if (isRequestAccepted) return '✅';
    if (isRequestArrived) return '📍';
    if (isRequestPickedUp) return '📦';
    if (isRequestCompleted) return '🎉';
    if (isRequestFailed) return '❌';
    if (isRequestExpired) return '⏰';

    // Delivery notifications
    if (isDeliveryAccepted) return '✅';
    if (isDeliveryArrivedAtPickup) return '📍';
    if (isDeliveryPickedUp) return '📦';
    if (isDeliveryInTransit) return '🚗';
    if (isDeliveryArrivedAtDestination) return '📍';
    if (isDeliveryCompleted) return '🎉';
    if (isDeliveryFailed) return '❌';

    // Case notifications
    if (isCaseCreated) return '📁';
    if (isCaseUpdated) return '🔄';
    if (isCasePhaseChanged) return '⚖️';
    if (isCaseDocumentUploaded) return '📄';
    if (isCaseCommentAdded) return '💬';

    // Trial notifications
    if (isTrialCreated) return '📅';
    if (isTrialReminder24h || isTrialReminder1h) return '⏰';
    if (isTrialUpdated) return '🔄';
    if (isTrialCancelled) return '🚫';

    // Chat notifications
    if (isChatMessage) return '💬';
    if (isChatDocumentShared) return '📎';
    if (isChatMention) return '👤';

    // Payment notifications
    if (isPaymentSuccessful) return '💳';
    if (isPaymentFailed) return '❌';
    if (isPaymentRefund) return '💰';
    if (isCreditAdded) return '💰';
    if (isCreditLow) return '⚠️';

    // System notifications
    if (isAccountVerification) return '✔️';
    if (isInviteAccepted) return '👥';
    if (isPolicyUpdate) return '📋';
    if (isMaintenanceScheduled) return '🔧';

    return '📢';
  }

  /// Get notification color based on type
  String get color {
    // Request notifications
    if (isRequestSubmitted) return '#2ED573'; // Green
    if (isRequestAccepted) return '#2ED573'; // Green
    if (isRequestArrived) return '#FFA502'; // Orange
    if (isRequestPickedUp) return '#FFA502'; // Orange
    if (isRequestCompleted) return '#3742FA'; // Blue
    if (isRequestFailed) return '#FF6B6B'; // Red
    if (isRequestExpired) return '#FF6B6B'; // Red

    // Delivery notifications
    if (isDeliveryAccepted) return '#2ED573'; // Green
    if (isDeliveryArrivedAtPickup) return '#FFA502'; // Orange
    if (isDeliveryPickedUp) return '#FFA502'; // Orange
    if (isDeliveryInTransit) return '#FFA502'; // Orange
    if (isDeliveryArrivedAtDestination) return '#FFA502'; // Orange
    if (isDeliveryCompleted) return '#3742FA'; // Blue
    if (isDeliveryFailed) return '#FF6B6B'; // Red

    // Case notifications
    if (isCaseCreated) return '#2ED573'; // Green
    if (isCaseUpdated) return '#3742FA'; // Blue
    if (isCasePhaseChanged) return '#FFA502'; // Orange
    if (isCaseDocumentUploaded) return '#3742FA'; // Blue
    if (isCaseCommentAdded) return '#9C88FF'; // Purple

    // Trial notifications
    if (isTrialCreated) return '#2ED573'; // Green
    if (isTrialReminder24h) return '#FFA502'; // Orange
    if (isTrialReminder1h) return '#FF6B6B'; // Red
    if (isTrialUpdated) return '#3742FA'; // Blue
    if (isTrialCancelled) return '#FF6B6B'; // Red

    // Chat notifications
    if (isChatMessage || isChatDocumentShared || isChatMention) {
      return '#9C88FF'; // Purple
    }

    // Payment notifications
    if (isPaymentSuccessful || isCreditAdded) return '#2ED573'; // Green
    if (isPaymentFailed) return '#FF6B6B'; // Red
    if (isPaymentRefund) return '#3742FA'; // Blue
    if (isCreditLow) return '#FFA502'; // Orange

    // System notifications
    return '#3742FA'; // Blue
  }
}
