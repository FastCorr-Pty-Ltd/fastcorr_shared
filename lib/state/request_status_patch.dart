import 'package:cloud_firestore/cloud_firestore.dart'
    show FieldValue, Timestamp;
import 'package:fastcorr_shared/models/request_model.dart' show Status;
import 'package:fastcorr_shared/state/actor_role.dart';
import 'package:fastcorr_shared/state/transition.dart';

/// Fields applied to `litigation_requests` (and the shared core of messenger
/// patches) after a [TransitionAllowed] from [RequestStateMachine].
///
/// Kept in `fastcorr_shared` so admin, user, and driver apps stamp identical
/// shapes when applying validated transitions.
Map<String, dynamic> buildRequestStatusPatch({
  required Transition transition,
  required Status to,
  required ActorRole actor,
  String? reason,
}) {
  final now = Timestamp.now();
  final map = <String, dynamic>{
    'status': to.name,
    'updatedAt': now,
  };

  final tf = transition.timestampField;
  if (tf != null && tf.isNotEmpty) {
    map[tf] = now;
  }

  if (transition.requiresReason &&
      transition.reasonField != null &&
      reason != null &&
      reason.isNotEmpty) {
    map[transition.reasonField!] = reason;
  }

  if (to == Status.cancelPending) {
    map['statusBeforeCancelPending'] = transition.from.name;
  }

  if (transition.from == Status.cancelPending) {
    if (to != Status.cancelPending) {
      map['statusBeforeCancelPending'] = FieldValue.delete();
      map['cancelPendingAt'] = FieldValue.delete();
    }
  }

  if (to == Status.canceled) {
    map['canceledBy'] = actor.name;
  }

  return map;
}

/// [buildRequestStatusPatch] plus `lastUpdated` for `delivery_orders`.
Map<String, dynamic> buildDeliveryOrderStatusPatch({
  required Transition transition,
  required Status to,
  required ActorRole actor,
  String? reason,
}) {
  final p = buildRequestStatusPatch(
    transition: transition,
    to: to,
    actor: actor,
    reason: reason,
  );
  p['lastUpdated'] = p['updatedAt'];
  return p;
}
