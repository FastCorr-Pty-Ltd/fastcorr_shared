/// Unified Status Synchronization Service
/// Handles real-time status synchronization between admin and user apps

import 'package:cloud_firestore/cloud_firestore.dart';

class UnifiedStatusSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _tasksRef =>
      _firestore.collection('litigation_requests');
  CollectionReference get _statusSyncRef =>
      _firestore.collection('status_sync_logs');
  CollectionReference get _notificationsRef =>
      _firestore.collection('cross_app_notifications');

  /// Sync status between admin task and user request
  /// This is the main method for bidirectional status synchronization
  Future<bool> syncTaskRequestStatus({
    required String taskId,
    required String requestId,
    required String newStatus,
    required String updatedBy,
    required String appSource, // 'admin' or 'user'
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print(
        '🔄 [StatusSync] Syncing status: $newStatus for task: $taskId, request: $requestId',
      );

      // Create status sync log
      await _createStatusSyncLog(
        taskId: taskId,
        requestId: requestId,
        newStatus: newStatus,
        updatedBy: updatedBy,
        appSource: appSource,
        reason: reason,
        additionalData: additionalData,
      );

      // Update both task and request status
      final batch = _firestore.batch();

      // Update task in admin app
      final taskDoc = _tasksRef.doc(taskId);
      batch.update(taskDoc, {
        'status': newStatus,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'lastStatusUpdatedBy': updatedBy,
        'lastStatusUpdateSource': appSource,
        if (reason != null) 'lastStatusUpdateReason': reason,
      });

      // Update request in user app (same document, different field mapping)
      final requestDoc = _tasksRef.doc(requestId);
      batch.update(requestDoc, {
        'status': newStatus,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'lastStatusUpdatedBy': updatedBy,
        'lastStatusUpdateSource': appSource,
        if (reason != null) 'lastStatusUpdateReason': reason,
      });

      await batch.commit();

      // Send cross-app notification
      await _sendCrossAppNotification(
        taskId: taskId,
        requestId: requestId,
        status: newStatus,
        updatedBy: updatedBy,
        appSource: appSource,
        reason: reason,
      );

      print('✅ [StatusSync] Status synced successfully: $newStatus');
      return true;
    } catch (e) {
      print('❌ [StatusSync] Error syncing status: $e');
      return false;
    }
  }

  /// Create status sync log for audit trail
  Future<void> _createStatusSyncLog({
    required String taskId,
    required String requestId,
    required String newStatus,
    required String updatedBy,
    required String appSource,
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final syncLog = {
        'taskId': taskId,
        'requestId': requestId,
        'newStatus': newStatus,
        'updatedBy': updatedBy,
        'appSource': appSource,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'additionalData': additionalData ?? {},
      };

      await _statusSyncRef.add(syncLog);
      print('📝 [StatusSync] Sync log created');
    } catch (e) {
      print('❌ [StatusSync] Error creating sync log: $e');
    }
  }

  /// Send cross-app notification
  Future<void> _sendCrossAppNotification({
    required String taskId,
    required String requestId,
    required String status,
    required String updatedBy,
    required String appSource,
    String? reason,
  }) async {
    try {
      final targetApp = appSource == 'admin' ? 'user' : 'admin';

      final notification = {
        'type': 'status_update',
        'taskId': taskId,
        'requestId': requestId,
        'status': status,
        'updatedBy': updatedBy,
        'sourceApp': appSource,
        'targetApp': targetApp,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };

      await _notificationsRef.add(notification);
      print('📢 [StatusSync] Cross-app notification sent to $targetApp');
    } catch (e) {
      print('❌ [StatusSync] Error sending notification: $e');
    }
  }

  /// Get status sync history for a task/request
  Future<List<Map<String, dynamic>>> getStatusSyncHistory(String taskId) async {
    try {
      final snapshot = await _statusSyncRef
          .where('taskId', isEqualTo: taskId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('❌ [StatusSync] Error getting sync history: $e');
      return [];
    }
  }

  /// Get cross-app notifications for a specific app
  Stream<List<Map<String, dynamic>>> getCrossAppNotifications(String appType) {
    return _notificationsRef
        .where('targetApp', isEqualTo: appType)
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>},
              )
              .toList();
        });
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsRef.doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print('✅ [StatusSync] Notification marked as read');
    } catch (e) {
      print('❌ [StatusSync] Error marking notification as read: $e');
    }
  }

  /// Get real-time status updates for a task/request
  Stream<Map<String, dynamic>> getStatusUpdates(String taskId) {
    return _tasksRef.doc(taskId).snapshots().map((snapshot) {
      if (!snapshot.exists) return {};

      final data = snapshot.data() as Map<String, dynamic>;
      return {
        'taskId': taskId,
        'status': data['status'],
        'lastStatusUpdate': data['lastStatusUpdate'],
        'lastStatusUpdatedBy': data['lastStatusUpdatedBy'],
        'lastStatusUpdateSource': data['lastStatusUpdateSource'],
        'lastStatusUpdateReason': data['lastStatusUpdateReason'],
      };
    });
  }

  /// Bulk sync status for multiple tasks/requests
  Future<Map<String, bool>> bulkSyncStatus({
    required List<String> taskIds,
    required String newStatus,
    required String updatedBy,
    required String appSource,
    String? reason,
  }) async {
    final results = <String, bool>{};

    for (final taskId in taskIds) {
      final success = await syncTaskRequestStatus(
        taskId: taskId,
        requestId: taskId, // Assuming taskId and requestId are the same
        newStatus: newStatus,
        updatedBy: updatedBy,
        appSource: appSource,
        reason: reason,
      );
      results[taskId] = success;
    }

    return results;
  }

  /// Get status sync statistics
  Future<Map<String, dynamic>> getStatusSyncStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfWeek = startOfDay.subtract(
        Duration(days: startOfDay.weekday - 1),
      );

      // Get sync logs for today
      final todaySnapshot = await _statusSyncRef
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .get();

      // Get sync logs for this week
      final weekSnapshot = await _statusSyncRef
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
          )
          .get();

      // Get all sync logs
      final allSnapshot = await _statusSyncRef.get();

      // Count by app source
      final adminSyncs = allSnapshot.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['appSource'] == 'admin',
          )
          .length;
      final userSyncs = allSnapshot.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['appSource'] == 'user',
          )
          .length;

      return {
        'totalSyncs': allSnapshot.docs.length,
        'todaySyncs': todaySnapshot.docs.length,
        'weekSyncs': weekSnapshot.docs.length,
        'adminSyncs': adminSyncs,
        'userSyncs': userSyncs,
        'syncRate': allSnapshot.docs.length > 0
            ? (adminSyncs + userSyncs) / allSnapshot.docs.length
            : 0.0,
      };
    } catch (e) {
      print('❌ [StatusSync] Error getting sync stats: $e');
      return {};
    }
  }
}
