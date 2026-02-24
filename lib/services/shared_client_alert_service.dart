import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/models.dart';

/// A shared service for handling the creation of notifications.
/// This service is used by both the user and admin apps to write
/// notifications to Firestore and determine email sending logic.
class SharedClientAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Sends a notification to the specified user and correctly sets
  /// the email flags based on the ClientAlertType via the backend.
  Future<void> sendNotification({
    required String userId,
    required ClientAlertType type,
    required String title,
    required String body,
    String? taskId,
    String? officeId,
    String? recipientEmail,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final docRef = _firestore.collection('notifications').doc();

      final sendEmail = recipientEmail != null && type.shouldSendEmail;

      final notification = ClientAlertModel(
        id: docRef.id,
        userId: userId,
        taskId: taskId ?? '',
        type: type,
        title: title,
        body: body,
        officeId: officeId ?? 'default_office',
        sentAt: Timestamp.now(),
        recipientEmail: recipientEmail,
        sendEmail: sendEmail,
        data: extraData,
      );

      await docRef.set(notification.toJson());
      log(
        'SharedClientAlertService: ✅ Notification sent (Email Queued: $sendEmail)',
      );
    } catch (e) {
      log('SharedClientAlertService: ❌ Failed to send notification: $e');
    }
  }
}
