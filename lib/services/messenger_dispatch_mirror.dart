import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/request_model.dart' show Status;

/// Copies messenger-relevant fields from a validated `delivery_orders` patch
/// into `dispatch/{orderId}` when that doc exists — same behavior as admin
/// [UnifiedStatusSyncService], but usable from driver / shared clients.
class MessengerDispatchMirror {
  MessengerDispatchMirror._();

  static void ensurePatchStatusMatches(
    Map<String, dynamic> smPatch,
    Status expectedTo,
  ) {
    final patchStatus = smPatch['status'];
    if (patchStatus is! String || patchStatus != expectedTo.name) {
      throw StateError(
        'MessengerDispatchMirror: dispatch mirror expected status '
        '${expectedTo.name} but smPatch has $patchStatus',
      );
    }
  }

  static Future<void> applyInTransaction({
    required Transaction transaction,
    required FirebaseFirestore firestore,
    required String orderId,
    required Map<String, dynamic> smPatch,
    required Status expectedTo,
  }) async {
    ensurePatchStatusMatches(smPatch, expectedTo);

    final ref = firestore.collection('dispatch').doc(orderId);
    final snap = await transaction.get(ref);
    if (!snap.exists) return;

    final m = <String, dynamic>{
      'status': smPatch['status'],
      'lastUpdated': smPatch['lastUpdated'],
      'updatedAt': smPatch['updatedAt'],
    };
    const keys = <String>[
      'assignedAt',
      'readyForPickupAt',
      'acceptedAt',
      'arrivedAtPickupAt',
      'pickedupAt',
      'completedAt',
      'canceledAt',
      'cancelReason',
      'rejectionReason',
      'escalationReason',
      'canceledBy',
    ];
    for (final k in keys) {
      if (smPatch.containsKey(k)) {
        m[k] = smPatch[k]!;
      }
    }
    transaction.update(ref, m);
  }
}
