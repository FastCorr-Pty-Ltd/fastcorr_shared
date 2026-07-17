import 'package:cloud_firestore/cloud_firestore.dart';

/// RevenueCat webhook log for audit trail
class RevenueCatWebhookLog {
  final String webhookId;
  final String eventType;
  final Timestamp receivedAt;
  final Map<String, dynamic> payload;
  final bool processed;
  final String? errorMessage;
  final Timestamp? processedAt;

  RevenueCatWebhookLog({
    required this.webhookId,
    required this.eventType,
    required this.receivedAt,
    required this.payload,
    this.processed = false,
    this.errorMessage,
    this.processedAt,
  });

  /// Create from Firestore document
  factory RevenueCatWebhookLog.fromMap(Map<String, dynamic> map) {
    return RevenueCatWebhookLog(
      webhookId: map['webhookId'] ?? '',
      eventType: map['eventType'] ?? '',
      receivedAt: map['receivedAt'] ?? Timestamp.now(),
      payload: Map<String, dynamic>.from(map['payload'] ?? {}),
      processed: map['processed'] ?? false,
      errorMessage: map['errorMessage'],
      processedAt: map['processedAt'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'webhookId': webhookId,
      'eventType': eventType,
      'receivedAt': receivedAt,
      'payload': payload,
      'processed': processed,
      'errorMessage': errorMessage,
      'processedAt': processedAt,
    };
  }

  /// Mark as processed
  RevenueCatWebhookLog markProcessed({String? error}) {
    return RevenueCatWebhookLog(
      webhookId: webhookId,
      eventType: eventType,
      receivedAt: receivedAt,
      payload: payload,
      processed: error == null,
      errorMessage: error,
      processedAt: Timestamp.now(),
    );
  }
}
