import 'package:fastcorr_shared/models/request_model.dart'
    show ActionType, Status;
import 'package:fastcorr_shared/state/request_flow.dart';

/// The minimum contract a request-like object must satisfy for the state
/// machine to reason about it.
///
/// Both `RequestModel` (litigation) and `OrderModel` (messenger) satisfy this
/// via small adapter wrappers rather than implementing the interface directly,
/// to keep `fastcorr_shared/models/*` untouched by state-machine concerns.
///
/// Fields are *observational* only — the machine reads them to decide what's
/// legal; it never mutates a subject. Mutations go through the service layer,
/// which calls [RequestStateMachine.validateTransition] first.
abstract class StatefulRequest {
  /// The request's current status.
  Status get currentStatus;

  /// Which lifecycle graph applies (litigation vs messenger).
  RequestFlow get flow;

  /// The secretary (or correspondent) currently owning the request, if any.
  /// Used by preconditions — e.g. `assigned → inProgress` requires an assignee.
  String? get assigneeId;

  /// The driver currently owning the pickup, if any.
  /// Used by preconditions — e.g. `accepted → arrivedAtPickup` requires a driver.
  String? get driverId;

  /// The opaque document id (for error messages / logging only).
  String get subjectId;

  /// When [currentStatus] is [Status.cancelPending], the status name before the
  /// lawyer requested cancellation (used to validate reactivation edges).
  String? get statusBeforeCancelPending;

  /// Litigation: [ActionType] for request-specific rules (e.g. court appearance
  /// completion without a driver leg). Always null for messenger orders.
  ActionType? get actionType;
}
