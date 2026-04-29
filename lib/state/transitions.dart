import 'package:fastcorr_shared/models/request_model.dart'
    show ActionType, Status;
import 'package:fastcorr_shared/state/actor_role.dart';
import 'package:fastcorr_shared/state/request_flow.dart';
import 'package:fastcorr_shared/state/stateful_request.dart';
import 'package:fastcorr_shared/state/transition.dart';

/// The single source of truth for what's legal in the request lifecycle.
///
/// Reading this table should be enough to understand the entire business rule
/// set for requests and orders. If a transition isn't listed here, the state
/// machine rejects it — no client code, no Cloud Function, and no Firestore
/// rule should bypass this list.
///
/// Ownership conventions (established during Phase-A policy review):
///   - **Secretaries** own litigation progression (assign-self, work,
///     ready-for-pickup). **Correspondents** do NOT — they are a distinct
///     role that does not self-claim or progress litigation work, and
///     therefore do not appear in any row of this table.
///   - **Lawyers** request cancellation up through `inProgress` (and
///     `pending` for both flows) via `cancelPending`, which pauses the
///     request until an office admin **approves** (final `canceled` + credit
///     refund) or **reverses** (restore `statusBeforeCancelPending`). A
///     lawyer may also **reactivate** while `cancelPending` by transitioning
///     back to the stored prior status. `readyForPickup` and later remain
///     admin-only for cancellation.
///   - **Office admins** own escalation handling and recovery within their
///     office scope. Super admins are intentionally NOT granted recovery
///     permissions — if a super admin needs to intervene, they do so by
///     stepping into the office admin role.
///   - **System** (Cloud Functions) is the only actor that writes
///     `overdue`. It can also auto-escalate overdue → escalated.
///
/// Organisation:
///   (1) Entry points from `pending`
///   (2) Litigation work progression
///   (3) Litigation rejection (by the worker)
///   (4) Cancellation after work has started
///   (5) Driver pickup / arrival
///   (6) Completion
///   (7) Escalation (manual by office admin, auto by system)
///   (8) Overdue (system only)
///   (9) Recovery from escalated / overdue (office admin)
///
/// Terminal states (no outgoing transitions): `completed`, `canceled`,
/// `rejected`. `cancelPending` is a pause state (awaiting admin).
/// `overdue` and `escalated` are NOT terminal — they have recovery edges.
const List<Transition> allowedTransitions = [
  // =========================================================================
  // (1) ENTRY POINTS FROM `pending`
  // =========================================================================

  // --- Litigation: office admin pushes OR secretary self-claims.
  // Correspondents are deliberately excluded — they do not self-claim or
  // progress litigation work.
  Transition(
    from: Status.pending,
    to: Status.assigned,
    flows: {RequestFlow.litigation},
    actors: {
      ActorRole.officeAdmin,
      ActorRole.superAdmin,
      ActorRole.secretary,
    },
    timestampField: 'assignedAt',
    notifies: {ActorRole.lawyer, ActorRole.secretary},
  ),

  // --- Messenger: driver accepts a pending messenger order.
  Transition(
    from: Status.pending,
    to: Status.accepted,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.driver},
    timestampField: 'acceptedAt',
    notifies: {ActorRole.lawyer},
  ),

  // --- Lawyer requests cancellation review (soft cancel). Office admin
  // finalizes to `canceled` (and credits) or reverses to the prior status.
  Transition(
    from: Status.pending,
    to: Status.cancelPending,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.lawyer},
    timestampField: 'cancelPendingAt',
    notifies: {ActorRole.officeAdmin},
  ),

  // --- Office admin: immediate cancel without `cancelPending` (support).
  Transition(
    from: Status.pending,
    to: Status.canceled,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.superAdmin},
    timestampField: 'canceledAt',
    notifies: {ActorRole.lawyer, ActorRole.officeAdmin},
  ),

  // =========================================================================
  // (2) LITIGATION WORK PROGRESSION
  // =========================================================================

  Transition(
    from: Status.assigned,
    to: Status.inProgress,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.secretary},
    notifies: {ActorRole.lawyer},
  ),

  // --- Skip-ahead path: quick jobs that are done before they ever "start".
  // Current code (TaskService.readyForPickup) allows this today.
  Transition(
    from: Status.assigned,
    to: Status.readyForPickup,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.secretary},
    timestampField: 'readyForPickupAt',
    notifies: {ActorRole.lawyer, ActorRole.deliveryCoordinator},
  ),

  Transition(
    from: Status.inProgress,
    to: Status.readyForPickup,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.secretary},
    timestampField: 'readyForPickupAt',
    notifies: {ActorRole.lawyer, ActorRole.deliveryCoordinator},
  ),

  // =========================================================================
  // (3) LITIGATION REJECTION (by the worker)
  // =========================================================================
  //
  // POLICY: rejection is ONLY allowed from `assigned` — secretaries cannot
  // reject mid-work. If blocked mid-work, they must escalate (a separate
  // path in section 7) so the office admin can reassign.
  Transition(
    from: Status.assigned,
    to: Status.rejected,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.secretary},
    requiresReason: true,
    reasonField: 'rejectionReason',
    notifies: {ActorRole.lawyer, ActorRole.officeAdmin},
  ),

  // =========================================================================
  // (4) CANCELLATION AFTER WORK HAS STARTED
  // =========================================================================

  // --- Lawyer: request cancel review. Admins: force-cancel to `canceled`.
  Transition(
    from: Status.assigned,
    to: Status.cancelPending,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.lawyer},
    timestampField: 'cancelPendingAt',
    requiresReason: true,
    reasonField: 'cancelReason',
    notifies: {ActorRole.officeAdmin},
  ),

  Transition(
    from: Status.assigned,
    to: Status.canceled,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin, ActorRole.superAdmin},
    timestampField: 'canceledAt',
    requiresReason: true,
    reasonField: 'cancelReason',
    notifies: {ActorRole.lawyer, ActorRole.secretary, ActorRole.officeAdmin},
  ),

  Transition(
    from: Status.inProgress,
    to: Status.cancelPending,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.lawyer},
    timestampField: 'cancelPendingAt',
    requiresReason: true,
    reasonField: 'cancelReason',
    notifies: {ActorRole.officeAdmin},
  ),

  Transition(
    from: Status.inProgress,
    to: Status.canceled,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin, ActorRole.superAdmin},
    timestampField: 'canceledAt',
    requiresReason: true,
    reasonField: 'cancelReason',
    notifies: {ActorRole.lawyer, ActorRole.secretary, ActorRole.officeAdmin},
  ),

  // Lawyer is intentionally OMITTED here: once work is done and ready for
  // courier pickup, cancellations are admin-only (refund / billing impact).
  Transition(
    from: Status.readyForPickup,
    to: Status.canceled,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin, ActorRole.superAdmin},
    timestampField: 'canceledAt',
    requiresReason: true,
    reasonField: 'cancelReason',
    notifies: {ActorRole.lawyer, ActorRole.secretary, ActorRole.driver},
  ),

  // --- Messenger: admin cancels while driver already accepted.
  Transition(
    from: Status.accepted,
    to: Status.canceled,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.superAdmin},
    timestampField: 'canceledAt',
    requiresReason: true,
    reasonField: 'cancelReason',
    notifies: {ActorRole.lawyer, ActorRole.driver},
  ),

  // =========================================================================
  // (4b) `cancelPending` — lawyer reactivation or admin final cancel
  // =========================================================================

  Transition(
    from: Status.cancelPending,
    to: Status.pending,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {
      ActorRole.lawyer,
      ActorRole.officeAdmin,
      ActorRole.superAdmin,
    },
    precondition: _restoreToPending,
    preconditionDescription:
        'reactivation only restores the status stored before cancelPending',
    notifies: {ActorRole.officeAdmin},
  ),

  Transition(
    from: Status.cancelPending,
    to: Status.assigned,
    flows: {RequestFlow.litigation},
    actors: {
      ActorRole.lawyer,
      ActorRole.officeAdmin,
      ActorRole.superAdmin,
    },
    precondition: _restoreToAssigned,
    preconditionDescription:
        'reactivation only restores the status stored before cancelPending',
    notifies: {ActorRole.secretary, ActorRole.officeAdmin},
  ),

  Transition(
    from: Status.cancelPending,
    to: Status.inProgress,
    flows: {RequestFlow.litigation},
    actors: {
      ActorRole.lawyer,
      ActorRole.officeAdmin,
      ActorRole.superAdmin,
    },
    precondition: _restoreToInProgress,
    preconditionDescription:
        'reactivation only restores the status stored before cancelPending',
    notifies: {ActorRole.secretary, ActorRole.officeAdmin},
  ),

  Transition(
    from: Status.cancelPending,
    to: Status.canceled,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {
      ActorRole.officeAdmin,
      ActorRole.superAdmin,
      ActorRole.system,
    },
    timestampField: 'canceledAt',
    notifies: {ActorRole.lawyer, ActorRole.secretary, ActorRole.driver},
  ),

  // =========================================================================
  // (5) DRIVER PICKUP / ARRIVAL
  // =========================================================================

  // --- Litigation: single-hop pickup from the office.
  Transition(
    from: Status.readyForPickup,
    to: Status.pickedup,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.driver},
    timestampField: 'pickedupAt',
    precondition: _hasDriver,
    preconditionDescription: 'a driver must be assigned before pickup',
    notifies: {ActorRole.lawyer, ActorRole.secretary},
  ),

  // --- Messenger: two-step arrive-then-pickup.
  Transition(
    from: Status.accepted,
    to: Status.arrivedAtPickup,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.driver},
    timestampField: 'arrivedAtPickupAt',
    precondition: _hasDriver,
    preconditionDescription: 'a driver must be assigned before arrival',
    notifies: {ActorRole.lawyer},
  ),

  Transition(
    from: Status.arrivedAtPickup,
    to: Status.pickedup,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.driver},
    timestampField: 'pickedupAt',
    precondition: _hasDriver,
    preconditionDescription: 'a driver must be assigned to confirm pickup',
    notifies: {ActorRole.lawyer},
  ),

  // =========================================================================
  // (6) COMPLETION
  // =========================================================================

  Transition(
    from: Status.pickedup,
    to: Status.completed,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.driver},
    timestampField: 'completedAt',
    precondition: _hasDriver,
    preconditionDescription: 'a driver must own the pickup to complete it',
    notifies: {
      ActorRole.lawyer,
      ActorRole.secretary,
      ActorRole.officeAdmin,
    },
    policyNote:
        'Multi-stop dropoff completion (all-dropoffs-delivered) is NOT '
        'enforced here because StatefulRequest does not carry dropoff '
        'progress. Service layer still owns that guard.',
  ),

  // --- Court appearance: no driver pickup; secretary (or admin) closes the
  // request once the date is on the office appearance calendar.
  Transition(
    from: Status.assigned,
    to: Status.completed,
    flows: {RequestFlow.litigation},
    actors: {
      ActorRole.secretary,
      ActorRole.officeAdmin,
      ActorRole.superAdmin,
    },
    timestampField: 'completedAt',
    precondition: _isCourtAppearanceRequest,
    preconditionDescription: 'request actionType must be courtAppearance',
    notifies: {ActorRole.lawyer, ActorRole.officeAdmin},
    policyNote:
        'Counsel assignment and hearing outcome live on trials / case Court Dates.',
  ),
  Transition(
    from: Status.inProgress,
    to: Status.completed,
    flows: {RequestFlow.litigation},
    actors: {
      ActorRole.secretary,
      ActorRole.officeAdmin,
      ActorRole.superAdmin,
    },
    timestampField: 'completedAt',
    precondition: _isCourtAppearanceRequest,
    preconditionDescription: 'request actionType must be courtAppearance',
    notifies: {ActorRole.lawyer, ActorRole.officeAdmin},
  ),
  Transition(
    from: Status.readyForPickup,
    to: Status.completed,
    flows: {RequestFlow.litigation},
    actors: {
      ActorRole.secretary,
      ActorRole.officeAdmin,
      ActorRole.superAdmin,
    },
    timestampField: 'completedAt',
    precondition: _isCourtAppearanceRequest,
    preconditionDescription: 'request actionType must be courtAppearance',
    notifies: {ActorRole.lawyer, ActorRole.officeAdmin},
  ),

  // =========================================================================
  // (7) ESCALATION (manual by office admin, auto by system)
  // =========================================================================
  //
  // POLICY: super admins are intentionally NOT in the actor list here. Per
  // the "office admins handle escalations within their office scope" rule,
  // if a super admin needs to escalate they do so while acting as an
  // office admin.
  Transition(
    from: Status.pending,
    to: Status.escalated,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    requiresReason: true,
    reasonField: 'escalationReason',
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer},
  ),
  Transition(
    from: Status.assigned,
    to: Status.escalated,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    requiresReason: true,
    reasonField: 'escalationReason',
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.secretary},
  ),
  Transition(
    from: Status.inProgress,
    to: Status.escalated,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    requiresReason: true,
    reasonField: 'escalationReason',
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.secretary},
  ),
  Transition(
    from: Status.readyForPickup,
    to: Status.escalated,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    requiresReason: true,
    reasonField: 'escalationReason',
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.driver},
  ),
  Transition(
    from: Status.accepted,
    to: Status.escalated,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    requiresReason: true,
    reasonField: 'escalationReason',
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.driver},
  ),
  Transition(
    from: Status.arrivedAtPickup,
    to: Status.escalated,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    requiresReason: true,
    reasonField: 'escalationReason',
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.driver},
  ),
  Transition(
    from: Status.pickedup,
    to: Status.escalated,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    requiresReason: true,
    reasonField: 'escalationReason',
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.driver},
  ),

  // --- Auto-escalation path: `overdue → escalated` so office admins
  // intervene on late requests.
  Transition(
    from: Status.overdue,
    to: Status.escalated,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    requiresReason: true,
    reasonField: 'escalationReason',
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer},
  ),

  // =========================================================================
  // (8) OVERDUE (system only — Cloud Function sets it when dueDate passes)
  // =========================================================================
  //
  // POLICY: overdue is a waypoint, not a terminal state. Timer Cloud Function
  // flips status → overdue when `dueDate < now`; a second step (same or
  // different CF) escalates overdue → escalated so the office admin
  // dashboard surfaces it. Overdue is also recoverable by office admin if
  // the due-date is extended or the late work is salvaged.
  Transition(
    from: Status.pending,
    to: Status.overdue,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.system},
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer},
  ),
  Transition(
    from: Status.assigned,
    to: Status.overdue,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.system},
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.secretary},
  ),
  Transition(
    from: Status.inProgress,
    to: Status.overdue,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.system},
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.secretary},
  ),
  Transition(
    from: Status.readyForPickup,
    to: Status.overdue,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.system},
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer},
  ),
  Transition(
    from: Status.accepted,
    to: Status.overdue,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.system},
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.driver},
  ),
  Transition(
    from: Status.arrivedAtPickup,
    to: Status.overdue,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.system},
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.driver},
  ),
  Transition(
    from: Status.pickedup,
    to: Status.overdue,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.system},
    notifies: {ActorRole.officeAdmin, ActorRole.lawyer, ActorRole.driver},
  ),

  // =========================================================================
  // (9) RECOVERY FROM `escalated` / `overdue` — office-admin owned
  // =========================================================================
  //
  // Recovery edges collapse back onto the pre-flagged status so work can
  // resume. Office admin drives recovery within their office scope.
  //
  // POLICY: we deliberately DO NOT let recovery transitions forward-skip
  // stages (e.g. `escalated → completed`). Office admin must first restore
  // a sane prior status, then the request rejoins the normal flow. When
  // reassigning, the admin writes a new `assigneeId` in the same update
  // that drives `escalated → assigned`.

  // --- Escalated → resume litigation at the right stage.
  Transition(
    from: Status.escalated,
    to: Status.assigned,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin},
    requiresReason: true,
    reasonField: 'recoveryReason',
    notifies: {ActorRole.lawyer, ActorRole.secretary},
  ),
  Transition(
    from: Status.escalated,
    to: Status.inProgress,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin},
    requiresReason: true,
    reasonField: 'recoveryReason',
    notifies: {ActorRole.lawyer, ActorRole.secretary},
  ),
  Transition(
    from: Status.escalated,
    to: Status.readyForPickup,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin},
    requiresReason: true,
    reasonField: 'recoveryReason',
    timestampField: 'readyForPickupAt',
    notifies: {ActorRole.lawyer, ActorRole.deliveryCoordinator},
  ),

  // --- Escalated → resume messenger at the right stage.
  Transition(
    from: Status.escalated,
    to: Status.pending,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.officeAdmin},
    requiresReason: true,
    reasonField: 'recoveryReason',
    notifies: {ActorRole.lawyer},
  ),

  // --- Escalated → terminate (both flows).
  Transition(
    from: Status.escalated,
    to: Status.canceled,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.officeAdmin},
    timestampField: 'canceledAt',
    requiresReason: true,
    reasonField: 'cancelReason',
    notifies: {ActorRole.lawyer, ActorRole.secretary, ActorRole.driver},
  ),

  // --- Overdue → recover (office admin manual; system can only clear to
  // a prior non-terminal status when the due-date is extended).
  Transition(
    from: Status.overdue,
    to: Status.pending,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    notifies: {ActorRole.lawyer},
    policyNote:
        'Used when due-date is extended, reverting an overdue request back '
        'to pending so normal flow resumes.',
  ),
  Transition(
    from: Status.overdue,
    to: Status.assigned,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    notifies: {ActorRole.lawyer, ActorRole.secretary},
  ),
  Transition(
    from: Status.overdue,
    to: Status.inProgress,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    notifies: {ActorRole.lawyer, ActorRole.secretary},
  ),
  Transition(
    from: Status.overdue,
    to: Status.readyForPickup,
    flows: {RequestFlow.litigation},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    notifies: {ActorRole.lawyer, ActorRole.deliveryCoordinator},
  ),
  Transition(
    from: Status.overdue,
    to: Status.accepted,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    notifies: {ActorRole.lawyer, ActorRole.driver},
  ),
  Transition(
    from: Status.overdue,
    to: Status.arrivedAtPickup,
    flows: {RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    notifies: {ActorRole.lawyer, ActorRole.driver},
  ),
  Transition(
    from: Status.overdue,
    to: Status.pickedup,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.officeAdmin, ActorRole.system},
    notifies: {ActorRole.lawyer, ActorRole.driver},
  ),
  Transition(
    from: Status.overdue,
    to: Status.canceled,
    flows: {RequestFlow.litigation, RequestFlow.messenger},
    actors: {ActorRole.officeAdmin},
    timestampField: 'canceledAt',
    requiresReason: true,
    reasonField: 'cancelReason',
    notifies: {ActorRole.lawyer, ActorRole.secretary, ActorRole.driver},
  ),
];

/// Terminal states: no outgoing transitions, ever.
const Set<Status> terminalStates = {
  Status.completed,
  Status.canceled,
  Status.rejected,
};

// ---- Preconditions: restore after soft-cancel --------------------------------

bool _restoreToPending(StatefulRequest s) =>
    s.statusBeforeCancelPending == Status.pending.name;

bool _restoreToAssigned(StatefulRequest s) =>
    s.statusBeforeCancelPending == Status.assigned.name;

bool _restoreToInProgress(StatefulRequest s) =>
    s.statusBeforeCancelPending == Status.inProgress.name;

/// Driver-ownership guard used on all pickup / arrival / delivery rows.
bool _hasDriver(StatefulRequest subject) {
  final id = subject.driverId;
  return id != null && id.isNotEmpty;
}

bool _isCourtAppearanceRequest(StatefulRequest subject) =>
    subject.actionType == ActionType.courtAppearance;
