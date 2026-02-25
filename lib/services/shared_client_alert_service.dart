import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/models.dart';

/// A shared service for handling the creation and retrieval of notifications.
/// This service is used by both the user and admin apps to read/write
/// notifications to Firestore.
class SharedClientAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _notificationsRef =>
      _firestore.collection('notifications');

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
      final docRef = _notificationsRef.doc();

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
        read: false,
        acknowledged: false,
      );

      await docRef.set(notification.toJson());
      log(
        'SharedClientAlertService: ✅ Notification sent (Email Queued: $sendEmail)',
      );
    } catch (e) {
      log('SharedClientAlertService: ❌ Failed to send notification: $e');
    }
  }

  /// Get a stream of notifications for a specific user, ordered by most recent first
  Stream<List<ClientAlertModel>> getUserNotificationsStream(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ClientAlertModel.fromSnapshot(doc))
              .toList();
        });
  }

  /// Get a stream of unread notifications for a specific user
  Stream<int> getUnreadCountStream(String userId) {
    return _notificationsRef
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).update({'read': true});
    } catch (e) {
      log('SharedClientAlertService: ❌ Failed to mark as read: $e');
    }
  }

  /// Mark all notifications as read for a specific user
  Future<void> markAllAsRead(String userId) async {
    try {
      final querySnapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
      log(
        'SharedClientAlertService: ✅ Marked ${querySnapshot.docs.length} notifications as read',
      );
    } catch (e) {
      log('SharedClientAlertService: ❌ Failed to mark all as read: $e');
    }
  }

  /// Delete a specific notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).delete();
    } catch (e) {
      log('SharedClientAlertService: ❌ Failed to delete notification: $e');
    }
  }

  /// Delete all notifications for a specific user
  Future<void> clearAllNotifications(String userId) async {
    try {
      final querySnapshot = await _notificationsRef
          .where('userId', isEqualTo: userId)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      log(
        'SharedClientAlertService: ✅ Cleared ${querySnapshot.docs.length} notifications',
      );
    } catch (e) {
      log('SharedClientAlertService: ❌ Failed to clear notifications: $e');
    }
  }
}
