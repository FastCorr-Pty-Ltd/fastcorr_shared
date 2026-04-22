import 'package:fastcorr_shared/models/request_model.dart' show Status;
import 'package:fastcorr_shared/state/actor_role.dart';
import 'package:fastcorr_shared/state/stateful_request.dart';
import 'package:fastcorr_shared/state/transition.dart';
import 'package:fastcorr_shared/state/transition_result.dart';
import 'package:fastcorr_shared/state/transitions.dart';

/// Pure, stateless query API over [allowedTransitions].
///
/// The state machine is a *validator*, not a mutator: it never touches
/// Firestore. Every caller gets a [TransitionResult] back and is responsible
/// for (a) returning early on failure and (b) writing the mutation when the
/// result is [TransitionAllowed].
///
/// Canonical call shape on the service layer:
///
/// ```dart
/// final decision = RequestStateMachine.validateTransition(
///   subject: RequestModelState(request),
///   to: Status.readyForPickup,
///   actor: ActorRole.secretary,
///   reason: null,
/// );
/// if (decision is! TransitionAllowed) {
///   throw StateError(decision.message);
/// }
/// // ... perform the write, stamping decision.transition.timestampField.
/// ```
class RequestStateMachine {
  RequestStateMachine._();

  /// Which statuses the given [subject] could legally move to if driven by
  /// [actor]. Useful for gating UI (enable/disable buttons, populate
  /// dropdowns).
  ///
  /// Preconditions are NOT evaluated here — they are dynamic and checked at
  /// transition time via [validateTransition]. That means the returned set is
  /// the *upper bound* of what might be allowed; the caller should still
  /// validate before mutating.
  static Set<Status> legalNextStates({
    required StatefulRequest subject,
    required ActorRole actor,
  }) {
    if (terminalStates.contains(subject.currentStatus)) {
      return const <Status>{};
    }
    final out = <Status>{};
    for (final t in allowedTransitions) {
      if (t.from != subject.currentStatus) continue;
      if (!t.flows.contains(subject.flow)) continue;
      if (!t.actors.contains(actor)) continue;
      out.add(t.to);
    }
    return out;
  }

  /// Shallow check: is `from → to` in the table for this flow+actor at all,
  /// ignoring preconditions and reason requirements. Prefer
  /// [validateTransition] for anything that will actually mutate state.
  static bool canTransition({
    required StatefulRequest subject,
    required Status to,
    required ActorRole actor,
  }) {
    if (terminalStates.contains(subject.currentStatus)) return false;
    for (final t in allowedTransitions) {
      if (t.from == subject.currentStatus &&
          t.to == to &&
          t.flows.contains(subject.flow) &&
          t.actors.contains(actor)) {
        return true;
      }
    }
    return false;
  }

  /// Full validation including actor check, terminal-state guard, precondition,
  /// and reason-requirement. Returns a structured [TransitionResult] so the
  /// caller can surface the exact reason for failure to the UI / logs.
  ///
  /// Resolution order (first failure wins):
  ///   1. TerminalState  — from-status is terminal
  ///   2. IllegalTransition — (from, to, flow) not in the table at all
  ///   3. ForbiddenActor — transition exists for flow but not for actor
  ///   4. MissingReason — reason required but not supplied
  ///   5. PreconditionFailed — dynamic guard returned false
  ///   6. TransitionAllowed — carries the matched Transition
  static TransitionResult validateTransition({
    required StatefulRequest subject,
    required Status to,
    required ActorRole actor,
    String? reason,
  }) {
    if (terminalStates.contains(subject.currentStatus)) {
      return TerminalState(subject.currentStatus);
    }

    // Candidates matching (from, to, flow).
    final flowMatches = <Transition>[];
    for (final t in allowedTransitions) {
      if (t.from == subject.currentStatus &&
          t.to == to &&
          t.flows.contains(subject.flow)) {
        flowMatches.add(t);
      }
    }
    if (flowMatches.isEmpty) {
      return IllegalTransition(from: subject.currentStatus, to: to);
    }

    // Among flow-matches, filter by actor.
    Transition? match;
    for (final t in flowMatches) {
      if (t.actors.contains(actor)) {
        match = t;
        break;
      }
    }
    if (match == null) {
      final allowedActors = <ActorRole>{
        for (final t in flowMatches) ...t.actors,
      };
      return ForbiddenActor(
        actor: actor,
        allowedActors: allowedActors,
        from: subject.currentStatus,
        to: to,
      );
    }

    if (match.requiresReason && (reason == null || reason.trim().isEmpty)) {
      return MissingReason(from: subject.currentStatus, to: to);
    }

    final precond = match.precondition;
    if (precond != null && !precond(subject)) {
      return PreconditionFailed(
        description: match.preconditionDescription ??
            'unspecified precondition failed',
        from: subject.currentStatus,
        to: to,
      );
    }

    return TransitionAllowed(match);
  }
}
