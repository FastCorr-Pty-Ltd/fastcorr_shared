import 'package:fastcorr_shared/models/request_model.dart' show Status;
import 'package:fastcorr_shared/state/actor_role.dart';
import 'package:fastcorr_shared/state/transition.dart';

/// Outcome of `RequestStateMachine.validateTransition`.
///
/// Call sites should ALWAYS check `isAllowed` or pattern-match on the
/// sealed subtypes before mutating Firestore. Treating any validation
/// failure as "assume the UI is buggy" is the correct default.
sealed class TransitionResult {
  const TransitionResult();

  bool get isAllowed => this is TransitionAllowed;

  /// Human-readable explanation for UI/log surfacing. Callers should prefer
  /// this over hand-rolling messages per failure type.
  String get message;
}

class TransitionAllowed extends TransitionResult {
  final Transition transition;
  const TransitionAllowed(this.transition);
  @override
  String get message => 'OK';
}

class IllegalTransition extends TransitionResult {
  final Status from;
  final Status to;
  const IllegalTransition({required this.from, required this.to});
  @override
  String get message =>
      'Illegal status change: ${from.name} → ${to.name} is not in the allowed transition table.';
}

class ForbiddenActor extends TransitionResult {
  final ActorRole actor;
  final Set<ActorRole> allowedActors;
  final Status from;
  final Status to;
  const ForbiddenActor({
    required this.actor,
    required this.allowedActors,
    required this.from,
    required this.to,
  });
  @override
  String get message {
    final allowed = allowedActors.map((a) => a.name).join(', ');
    return 'Role "${actor.name}" is not allowed to move ${from.name} → ${to.name}. Allowed: [$allowed].';
  }
}

class MissingReason extends TransitionResult {
  final Status from;
  final Status to;
  const MissingReason({required this.from, required this.to});
  @override
  String get message =>
      'A reason is required for ${from.name} → ${to.name} but none was provided.';
}

class PreconditionFailed extends TransitionResult {
  final String description;
  final Status from;
  final Status to;
  const PreconditionFailed({
    required this.description,
    required this.from,
    required this.to,
  });
  @override
  String get message =>
      'Precondition failed for ${from.name} → ${to.name}: $description';
}

class TerminalState extends TransitionResult {
  final Status status;
  const TerminalState(this.status);
  @override
  String get message =>
      'Status ${status.name} is terminal — no outgoing transitions are allowed.';
}
