import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/request_model.dart';
import 'package:fastcorr_shared/state/adapters/request_model_state.dart';
import 'package:fastcorr_shared/state/actor_role.dart';
import 'package:fastcorr_shared/state/pending_cancellation_payload.dart';
import 'package:fastcorr_shared/state/request_state_machine.dart';
import 'package:fastcorr_shared/state/request_status_patch.dart';
import 'package:fastcorr_shared/state/transition_result.dart';

typedef LitigationTransitionSideEffect = Future<void> Function(
  Transaction transaction,
);

/// Client-side applier for validated `litigation_requests` transitions.
///
/// Runs the same validation and document shape as admin [RequestTransitionService]
/// inside a Firestore transaction. Does **not** dispatch admin notification
/// emails/FCM — that remains admin-only after the fact via streams or backend.
class LitigationRequestTransitionClient {
  LitigationRequestTransitionClient({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reqRef =>
      _firestore.collection('litigation_requests');

  CollectionReference<Map<String, dynamic>> get _pendingCancelRef =>
      _firestore.collection('pending_cancellations');

  /// Optional [alsoInTransaction] runs after the request doc, activity, and
  /// pending-cancellation writes (e.g. QR doc updates in the driver app).
  Future<TransitionResult> applyTransition({
    required String orderId,
    required Status to,
    required String actorUserId,
    required ActorRole actor,
    String? reason,
    Map<String, dynamic>? mergeFields,
    String? lawyerEmail,
    String? lawyerPhone,
    String? lawyerName,
    LitigationTransitionSideEffect? alsoInTransaction,
  }) async {
    return _firestore.runTransaction((transaction) async {
      final docRef = _reqRef.doc(orderId);
      final snap = await transaction.get(docRef);
      if (!snap.exists) {
        return IllegalTransition(from: Status.pending, to: to);
      }

      final fresh = RequestModel.fromSnapshot(snap);
      final decision = RequestStateMachine.validateTransition(
        subject: RequestModelState(fresh),
        to: to,
        actor: actor,
        reason: reason,
      );

      if (!decision.isAllowed) {
        return decision;
      }

      final allowed = decision as TransitionAllowed;
      final t = allowed.transition;

      final patch = buildRequestStatusPatch(
        transition: t,
        to: to,
        actor: actor,
        reason: reason,
      );
      if (mergeFields != null && mergeFields.isNotEmpty) {
        patch.addAll(mergeFields);
      }

      transaction.update(docRef, patch);

      final activityRef = docRef.collection('activity').doc();
      final now = Timestamp.now();
      transaction.set(activityRef, {
        'type': 'statusChange',
        'message': 'Status updated to ${to.name}',
        'createdBy': actorUserId,
        'createdByRole': 'admin',
        'createdAt': now.toDate().toIso8601String(),
        'data': {
          'from': fresh.status?.name,
          'to': to.name,
          'actor': actor.name,
        },
      });

      if (actor == ActorRole.lawyer && to == Status.cancelPending) {
        final prev = fresh.status ?? Status.pending;
        transaction.set(
          _pendingCancelRef.doc(orderId),
          buildLitigationPendingCancellationPayload(
            request: fresh,
            previousStatus: prev.name,
            requestCostCents: fresh.cost ?? 0,
            cancelReason: reason,
            lawyerEmail: lawyerEmail,
            lawyerPhone: lawyerPhone,
            lawyerName: lawyerName,
          ),
        );
      }

      if (fresh.status == Status.cancelPending && to != Status.cancelPending) {
        transaction.delete(_pendingCancelRef.doc(orderId));
      }

      if (alsoInTransaction != null) {
        await alsoInTransaction(transaction);
      }

      return decision;
    });
  }
}
