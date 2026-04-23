import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/order_model.dart';
import 'package:fastcorr_shared/models/request_model.dart';
import 'package:fastcorr_shared/services/messenger_dispatch_mirror.dart';
import 'package:fastcorr_shared/state/adapters/order_model_state.dart';
import 'package:fastcorr_shared/state/actor_role.dart';
import 'package:fastcorr_shared/state/pending_cancellation_payload.dart';
import 'package:fastcorr_shared/state/request_state_machine.dart';
import 'package:fastcorr_shared/state/request_status_patch.dart';
import 'package:fastcorr_shared/state/transition_result.dart';

typedef DeliveryOrderTransitionSideEffect = Future<void> Function(
  Transaction transaction,
);

/// Client-side applier for validated `delivery_orders` (messenger) transitions.
class DeliveryOrderTransitionClient {
  DeliveryOrderTransitionClient({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _deliveryOrdersRef =>
      _firestore.collection('delivery_orders');

  Future<TransitionResult> applyTransition({
    required String orderId,
    required Status to,
    required String actorUserId,
    required ActorRole actor,
    String? reason,
    Map<String, dynamic>? mergeFields,
    DeliveryOrderTransitionSideEffect? alsoInTransaction,
  }) async {
    return _firestore.runTransaction((transaction) async {
      final docRef = _deliveryOrdersRef.doc(orderId);
      final snap = await transaction.get(docRef);
      if (!snap.exists) {
        return IllegalTransition(from: Status.pending, to: to);
      }

      final data = snap.data()!;
      final officeId = data['officeId'] as String? ?? '';
      final fresh = OrderModel.fromSnapshot(snap);
      final decision = RequestStateMachine.validateTransition(
        subject: OrderModelState(fresh),
        to: to,
        actor: actor,
        reason: reason,
      );

      if (!decision.isAllowed) {
        return decision;
      }

      final allowed = decision as TransitionAllowed;
      final t = allowed.transition;

      final smPatch = buildDeliveryOrderStatusPatch(
        transition: t,
        to: to,
        actor: actor,
        reason: reason,
      );
      final orderUpdate = Map<String, dynamic>.from(smPatch);
      if (mergeFields != null && mergeFields.isNotEmpty) {
        orderUpdate.addAll(mergeFields);
      }

      transaction.update(docRef, orderUpdate);

      final activityRef = docRef.collection('activity').doc();
      final now = Timestamp.now();
      transaction.set(activityRef, {
        'type': 'statusChange',
        'message': 'Status updated to ${to.name}',
        'createdBy': actorUserId,
        'createdByRole': 'admin',
        'createdAt': now.toDate().toIso8601String(),
        'data': {
          'from': fresh.status.name,
          'to': to.name,
          'actor': actor.name,
        },
      });

      if (actor == ActorRole.lawyer && to == Status.canceled) {
        transaction.set(
          _firestore.collection('pending_cancellations').doc(orderId),
          buildMessengerPendingCancellationPayload(
            order: fresh,
            officeId: officeId,
            cancelReason: reason,
          ),
        );
      }

      await MessengerDispatchMirror.applyInTransaction(
        transaction: transaction,
        firestore: _firestore,
        orderId: orderId,
        smPatch: smPatch,
        expectedTo: to,
      );

      if (alsoInTransaction != null) {
        await alsoInTransaction(transaction);
      }

      return decision;
    });
  }
}
