import 'package:cloud_firestore/cloud_firestore.dart';

/// Subscription lifecycle event for audit trail
class SubscriptionEvent {
  final String eventId;
  final String eventType;
  final Timestamp eventDate;
  final String? revenueCatEventId;
  final Map<String, dynamic>? metadata;

  SubscriptionEvent({
    required this.eventId,
    required this.eventType,
    required this.eventDate,
    this.revenueCatEventId,
    this.metadata,
  });

  /// Create from Firestore document
  factory SubscriptionEvent.fromMap(Map<String, dynamic> map) {
    return SubscriptionEvent(
      eventId: map['eventId'] ?? '',
      eventType: map['eventType'] ?? '',
      eventDate: map['eventDate'] ?? Timestamp.now(),
      revenueCatEventId: map['revenueCatEventId'],
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventType': eventType,
      'eventDate': eventDate,
      'revenueCatEventId': revenueCatEventId,
      'metadata': metadata,
    };
  }

  /// Event type constants
  static const String trialStarted = 'trial_started';
  static const String subscribed = 'subscribed';
  static const String renewed = 'renewed';
  static const String expired = 'expired';
  static const String cancelled = 'cancelled';
  static const String upgraded = 'upgraded';
  static const String downgraded = 'downgraded';
  static const String billingIssue = 'billing_issue';
  static const String restored = 'restored';
}
