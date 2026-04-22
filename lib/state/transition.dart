import 'package:fastcorr_shared/models/request_model.dart' show Status;
import 'package:fastcorr_shared/state/actor_role.dart';
import 'package:fastcorr_shared/state/request_flow.dart';
import 'package:fastcorr_shared/state/stateful_request.dart';

/// A single allowed edge in the request state graph.
///
/// One [Transition] answers five questions about a move from [from] to [to]:
///  - In which [flows] is this edge legal?
///  - Which [actors] are allowed to drive it?
///  - What server-side [timestampField] must be stamped when it fires?
///    (null = no timestamp; only `updatedAt` will be touched)
///  - Is a free-text reason required ([requiresReason]) and if so under which
///    Firestore field name ([reasonField])?
///  - Any dynamic guard that can't be expressed statically goes in
///    [precondition].
///
/// Keep one transition per (from, to, flow, actor-group). Splitting a row into
/// two is cheaper than smuggling logic into `precondition`.
class Transition {
  final Status from;
  final Status to;
  final Set<RequestFlow> flows;
  final Set<ActorRole> actors;

  /// Firestore field to set to `FieldValue.serverTimestamp()` when the
  /// transition fires. Null means no status-specific timestamp beyond the
  /// baseline `updatedAt`.
  final String? timestampField;

  /// When true, the caller must supply a non-empty reason or the transition
  /// fails with [TransitionResult.missingReason]. The service layer is
  /// expected to write that reason into [reasonField].
  final bool requiresReason;
  final String? reasonField;

  /// Optional dynamic guard (e.g. "driver must be assigned"). Returning false
  /// yields [TransitionResult.preconditionFailed] with this row's
  /// [preconditionDescription] as the error.
  final bool Function(StatefulRequest subject)? precondition;
  final String? preconditionDescription;

  /// Roles that should receive a notification when this transition fires.
  ///
  /// The machine does NOT send anything — it only DECLARES intent. The
  /// service layer, after a successful transition, is expected to:
  ///   (1) resolve these roles to actual user IDs for the specific request
  ///       (e.g. `lawyer` → `request.lawyerId`, `officeAdmin` →
  ///       all admins in `request.officeId`),
  ///   (2) exclude the actor who drove the transition from the recipient
  ///       list (you don't need a notification about your own action), and
  ///   (3) dispatch via the existing notification service.
  ///
  /// Empty set = no notifications declared for this edge. Keeping this
  /// declarative means product / UX changes to "who gets pinged when X
  /// happens" are a one-line edit in the transition table, not a hunt
  /// across services.
  final Set<ActorRole> notifies;

  /// Free-text note explaining *why* this row exists, used to flag ambiguous
  /// policy decisions for review. Surfaces in documentation only; not
  /// consumed at runtime.
  final String? policyNote;

  const Transition({
    required this.from,
    required this.to,
    required this.flows,
    required this.actors,
    this.timestampField,
    this.requiresReason = false,
    this.reasonField,
    this.precondition,
    this.preconditionDescription,
    this.notifies = const {},
    this.policyNote,
  }) : assert(
         !requiresReason || reasonField != null,
         'Transitions that require a reason must declare a reasonField.',
       );
}
