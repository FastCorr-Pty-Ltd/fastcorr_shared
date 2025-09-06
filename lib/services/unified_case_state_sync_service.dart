/// Unified Case State Synchronization Service
/// Handles real-time case state synchronization between admin and user apps

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/fastcorr_shared.dart' as shared;

class UnifiedCaseStateSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference get _orgRef => _firestore.collection('organisations');
  CollectionReference get _caseStateSyncRef =>
      _firestore.collection('case_state_sync_logs');
  CollectionReference get _notificationsRef =>
      _firestore.collection('cross_app_notifications');

  /// Sync case phase update between apps
  Future<bool> syncCasePhaseUpdate({
    required String caseId,
    required String orgId,
    required int newPhase,
    required String updatedBy,
    required String appSource, // 'admin' or 'user'
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print(
        '🔄 [CaseStateSync] Syncing case phase: $newPhase for case: $caseId',
      );

      // Create case state sync log
      await _createCaseStateSyncLog(
        caseId: caseId,
        orgId: orgId,
        changeType: 'phase_update',
        newValue: newPhase,
        updatedBy: updatedBy,
        appSource: appSource,
        reason: reason,
        additionalData: additionalData,
      );

      // Update case phase in both apps
      final caseRef = _orgRef.doc(orgId).collection('cases').doc(caseId);
      await caseRef.update({
        'phase': newPhase,
        'lastPhaseUpdate': FieldValue.serverTimestamp(),
        'lastPhaseUpdatedBy': updatedBy,
        'lastPhaseUpdateSource': appSource,
        'lastActivityAt': FieldValue.serverTimestamp(),
        'lastupdatedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'lastPhaseUpdateReason': reason,
      });

      // Send cross-app notification
      await _sendCaseStateNotification(
        caseId: caseId,
        orgId: orgId,
        changeType: 'phase_update',
        newValue: newPhase,
        updatedBy: updatedBy,
        appSource: appSource,
        reason: reason,
      );

      print('✅ [CaseStateSync] Case phase synced successfully: $newPhase');
      return true;
    } catch (e) {
      print('❌ [CaseStateSync] Error syncing case phase: $e');
      return false;
    }
  }

  /// Sync case assignment update between apps
  Future<bool> syncCaseAssignmentUpdate({
    required String caseId,
    required String orgId,
    required String? newAssigneeId,
    required String updatedBy,
    required String appSource,
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print(
        '🔄 [CaseStateSync] Syncing case assignment: $newAssigneeId for case: $caseId',
      );

      // Create case state sync log
      await _createCaseStateSyncLog(
        caseId: caseId,
        orgId: orgId,
        changeType: 'assignment_update',
        newValue: newAssigneeId,
        updatedBy: updatedBy,
        appSource: appSource,
        reason: reason,
        additionalData: additionalData,
      );

      // Update case assignment in both apps
      final caseRef = _orgRef.doc(orgId).collection('cases').doc(caseId);
      await caseRef.update({
        'assigneeId': newAssigneeId,
        'lastAssignmentUpdate': FieldValue.serverTimestamp(),
        'lastAssignmentUpdatedBy': updatedBy,
        'lastAssignmentUpdateSource': appSource,
        'lastActivityAt': FieldValue.serverTimestamp(),
        'lastupdatedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'lastAssignmentUpdateReason': reason,
      });

      // Send cross-app notification
      await _sendCaseStateNotification(
        caseId: caseId,
        orgId: orgId,
        changeType: 'assignment_update',
        newValue: newAssigneeId,
        updatedBy: updatedBy,
        appSource: appSource,
        reason: reason,
      );

      print(
        '✅ [CaseStateSync] Case assignment synced successfully: $newAssigneeId',
      );
      return true;
    } catch (e) {
      print('❌ [CaseStateSync] Error syncing case assignment: $e');
      return false;
    }
  }

  /// Sync case status update between apps
  Future<bool> syncCaseStatusUpdate({
    required String caseId,
    required String orgId,
    required String newStatus,
    required String updatedBy,
    required String appSource,
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print(
        '🔄 [CaseStateSync] Syncing case status: $newStatus for case: $caseId',
      );

      // Create case state sync log
      await _createCaseStateSyncLog(
        caseId: caseId,
        orgId: orgId,
        changeType: 'status_update',
        newValue: newStatus,
        updatedBy: updatedBy,
        appSource: appSource,
        reason: reason,
        additionalData: additionalData,
      );

      // Update case status in both apps
      final caseRef = _orgRef.doc(orgId).collection('cases').doc(caseId);
      await caseRef.update({
        'status': newStatus,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
        'lastStatusUpdatedBy': updatedBy,
        'lastStatusUpdateSource': appSource,
        'lastActivityAt': FieldValue.serverTimestamp(),
        'lastupdatedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'lastStatusUpdateReason': reason,
      });

      // Send cross-app notification
      await _sendCaseStateNotification(
        caseId: caseId,
        orgId: orgId,
        changeType: 'status_update',
        newValue: newStatus,
        updatedBy: updatedBy,
        appSource: appSource,
        reason: reason,
      );

      print('✅ [CaseStateSync] Case status synced successfully: $newStatus');
      return true;
    } catch (e) {
      print('❌ [CaseStateSync] Error syncing case status: $e');
      return false;
    }
  }

  /// Create case state sync log for audit trail
  Future<void> _createCaseStateSyncLog({
    required String caseId,
    required String orgId,
    required String changeType,
    required dynamic newValue,
    required String updatedBy,
    required String appSource,
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final syncLog = {
        'caseId': caseId,
        'orgId': orgId,
        'changeType': changeType,
        'newValue': newValue,
        'updatedBy': updatedBy,
        'appSource': appSource,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'additionalData': additionalData ?? {},
      };

      await _caseStateSyncRef.add(syncLog);
      print('📝 [CaseStateSync] State sync log created');
    } catch (e) {
      print('❌ [CaseStateSync] Error creating state sync log: $e');
    }
  }

  /// Send case state notification
  Future<void> _sendCaseStateNotification({
    required String caseId,
    required String orgId,
    required String changeType,
    required dynamic newValue,
    required String updatedBy,
    required String appSource,
    String? reason,
  }) async {
    try {
      final targetApp = appSource == 'admin' ? 'user' : 'admin';

      final notification = {
        'type': 'case_state_update',
        'caseId': caseId,
        'orgId': orgId,
        'changeType': changeType,
        'newValue': newValue,
        'updatedBy': updatedBy,
        'sourceApp': appSource,
        'targetApp': targetApp,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      };

      await _notificationsRef.add(notification);
      print('📢 [CaseStateSync] Case state notification sent to $targetApp');
    } catch (e) {
      print('❌ [CaseStateSync] Error sending case state notification: $e');
    }
  }

  /// Get case state sync history
  Future<List<Map<String, dynamic>>> getCaseStateSyncHistory(
    String caseId,
  ) async {
    try {
      final snapshot = await _caseStateSyncRef
          .where('caseId', isEqualTo: caseId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('❌ [CaseStateSync] Error getting case state sync history: $e');
      return [];
    }
  }

  /// Get real-time case state updates
  Stream<Map<String, dynamic>> getCaseStateUpdates(
    String caseId,
    String orgId,
  ) {
    return _orgRef.doc(orgId).collection('cases').doc(caseId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) return {};

      final data = snapshot.data() as Map<String, dynamic>;
      return {
        'caseId': caseId,
        'orgId': orgId,
        'phase': data['phase'],
        'status': data['status'],
        'assigneeId': data['assigneeId'],
        'lastPhaseUpdate': data['lastPhaseUpdate'],
        'lastPhaseUpdatedBy': data['lastPhaseUpdatedBy'],
        'lastPhaseUpdateSource': data['lastPhaseUpdateSource'],
        'lastAssignmentUpdate': data['lastAssignmentUpdate'],
        'lastAssignmentUpdatedBy': data['lastAssignmentUpdatedBy'],
        'lastAssignmentUpdateSource': data['lastAssignmentUpdateSource'],
        'lastStatusUpdate': data['lastStatusUpdate'],
        'lastStatusUpdatedBy': data['lastStatusUpdatedBy'],
        'lastStatusUpdateSource': data['lastStatusUpdateSource'],
        'lastActivityAt': data['lastActivityAt'],
      };
    });
  }

  /// Get case state sync statistics
  Future<Map<String, dynamic>> getCaseStateSyncStats() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfWeek = startOfDay.subtract(
        Duration(days: startOfDay.weekday - 1),
      );

      // Get sync logs for today
      final todaySnapshot = await _caseStateSyncRef
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
          )
          .get();

      // Get sync logs for this week
      final weekSnapshot = await _caseStateSyncRef
          .where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
          )
          .get();

      // Get all sync logs
      final allSnapshot = await _caseStateSyncRef.get();

      // Count by change type
      final phaseUpdates = allSnapshot.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['changeType'] ==
                'phase_update',
          )
          .length;
      final assignmentUpdates = allSnapshot.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['changeType'] ==
                'assignment_update',
          )
          .length;
      final statusUpdates = allSnapshot.docs
          .where(
            (doc) =>
                (doc.data() as Map<String, dynamic>)['changeType'] ==
                'status_update',
          )
          .length;

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
        'phaseUpdates': phaseUpdates,
        'assignmentUpdates': assignmentUpdates,
        'statusUpdates': statusUpdates,
        'adminSyncs': adminSyncs,
        'userSyncs': userSyncs,
        'syncRate': allSnapshot.docs.length > 0
            ? (adminSyncs + userSyncs) / allSnapshot.docs.length
            : 0.0,
      };
    } catch (e) {
      print('❌ [CaseStateSync] Error getting case state sync stats: $e');
      return {};
    }
  }

  /// Bulk sync case state for multiple cases
  Future<Map<String, bool>> bulkSyncCaseState({
    required List<String> caseIds,
    required String orgId,
    required String changeType,
    required dynamic newValue,
    required String updatedBy,
    required String appSource,
    String? reason,
  }) async {
    final results = <String, bool>{};

    for (final caseId in caseIds) {
      bool success = false;

      switch (changeType) {
        case 'phase_update':
          success = await syncCasePhaseUpdate(
            caseId: caseId,
            orgId: orgId,
            newPhase: newValue as int,
            updatedBy: updatedBy,
            appSource: appSource,
            reason: reason,
          );
          break;
        case 'assignment_update':
          success = await syncCaseAssignmentUpdate(
            caseId: caseId,
            orgId: orgId,
            newAssigneeId: newValue as String?,
            updatedBy: updatedBy,
            appSource: appSource,
            reason: reason,
          );
          break;
        case 'status_update':
          success = await syncCaseStatusUpdate(
            caseId: caseId,
            orgId: orgId,
            newStatus: newValue as String,
            updatedBy: updatedBy,
            appSource: appSource,
            reason: reason,
          );
          break;
      }

      results[caseId] = success;
    }

    return results;
  }
}



