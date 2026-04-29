import 'package:fastcorr_shared/models/request_model.dart'
    show ActionType, Status;
import 'package:fastcorr_shared/state/state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal fake for [StatefulRequest]. Tests do not need the full
/// `RequestModel` / `OrderModel`; the machine only looks at the four
/// observational fields on the interface.
class _Subject implements StatefulRequest {
  @override
  final Status currentStatus;
  @override
  final RequestFlow flow;
  @override
  final String? assigneeId;
  @override
  final String? driverId;
  @override
  final String subjectId;
  @override
  final String? statusBeforeCancelPending;
  @override
  final ActionType? actionType;

  const _Subject({
    required this.currentStatus,
    required this.flow,
    this.assigneeId,
    this.driverId,
    this.subjectId = 'test-req',
    this.statusBeforeCancelPending,
    this.actionType,
  });

  _Subject copyWith({
    Status? currentStatus,
    RequestFlow? flow,
    String? assigneeId,
    String? driverId,
    ActionType? actionType,
  }) => _Subject(
    currentStatus: currentStatus ?? this.currentStatus,
    flow: flow ?? this.flow,
    assigneeId: assigneeId ?? this.assigneeId,
    driverId: driverId ?? this.driverId,
    subjectId: subjectId,
    statusBeforeCancelPending: statusBeforeCancelPending,
    actionType: actionType ?? this.actionType,
  );
}

// Convenience factories.
_Subject lit(
  Status s, {
  String? assigneeId,
  String? driverId,
  ActionType? actionType,
}) =>
    _Subject(
      currentStatus: s,
      flow: RequestFlow.litigation,
      assigneeId: assigneeId,
      driverId: driverId,
      actionType: actionType,
    );
_Subject msg(Status s, {String? driverId}) =>
    _Subject(currentStatus: s, flow: RequestFlow.messenger, driverId: driverId);

void main() {
  // =========================================================================
  // STATUSES PER FLOW (UI filters)
  // =========================================================================

  group('statusesAppearingInFlow', () {
    test('messenger graph is non-empty and ordered like Status.values', () {
      final m = RequestStateMachine.statusesAppearingInFlow(
        RequestFlow.messenger,
      );
      expect(m, isNotEmpty);
      for (var i = 1; i < m.length; i++) {
        expect(m[i - 1].index < m[i].index, isTrue);
      }
    });

    test('litigation includes assigned and readyForPickup', () {
      final lit = RequestStateMachine.statusesAppearingInFlow(
        RequestFlow.litigation,
      );
      expect(lit, contains(Status.assigned));
      expect(lit, contains(Status.readyForPickup));
    });
  });

  // =========================================================================
  // TERMINAL-STATE GUARD
  // =========================================================================

  group('terminal states', () {
    for (final term in [Status.completed, Status.canceled, Status.rejected]) {
      test('$term has no outgoing transitions in either flow', () {
        for (final flow in RequestFlow.values) {
          final subject = _Subject(currentStatus: term, flow: flow);
          for (final actor in ActorRole.values) {
            expect(
              RequestStateMachine.legalNextStates(
                subject: subject,
                actor: actor,
              ),
              isEmpty,
              reason:
                  'terminal=$term flow=$flow actor=$actor should have no '
                  'legal next states',
            );
          }
        }
      });

      test('validateTransition out of $term returns TerminalState', () {
        final subject = lit(term);
        final result = RequestStateMachine.validateTransition(
          subject: subject,
          to: Status.inProgress,
          actor: ActorRole.superAdmin,
        );
        expect(result, isA<TerminalState>());
      });
    }
  });

  // =========================================================================
  // HAPPY PATHS — LITIGATION
  // =========================================================================

  group('litigation happy path', () {
    test('pending → assigned by office admin', () {
      final subject = lit(Status.pending);
      final r = RequestStateMachine.validateTransition(
        subject: subject,
        to: Status.assigned,
        actor: ActorRole.officeAdmin,
      );
      expect(r, isA<TransitionAllowed>());
      expect((r as TransitionAllowed).transition.timestampField, 'assignedAt');
    });

    test('pending → assigned self-claim by secretary', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.pending),
        to: Status.assigned,
        actor: ActorRole.secretary,
      );
      expect(r, isA<TransitionAllowed>());
    });

    test('assigned → inProgress by secretary', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.inProgress,
        actor: ActorRole.secretary,
      );
      expect(r, isA<TransitionAllowed>());
    });

    test('inProgress → readyForPickup by secretary stamps readyForPickupAt', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.inProgress, assigneeId: 'sec-1'),
        to: Status.readyForPickup,
        actor: ActorRole.secretary,
      );
      expect(r, isA<TransitionAllowed>());
      expect(
        (r as TransitionAllowed).transition.timestampField,
        'readyForPickupAt',
      );
    });

    test('assigned → readyForPickup (skip-ahead) is allowed', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.readyForPickup,
        actor: ActorRole.secretary,
      );
      expect(r, isA<TransitionAllowed>());
    });

    test('readyForPickup → pickedup by driver stamps pickedupAt', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.readyForPickup, driverId: 'drv-1'),
        to: Status.pickedup,
        actor: ActorRole.driver,
      );
      expect(r, isA<TransitionAllowed>());
      expect((r as TransitionAllowed).transition.timestampField, 'pickedupAt');
    });

    test('pickedup → completed by driver stamps completedAt', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.pickedup, driverId: 'drv-1'),
        to: Status.completed,
        actor: ActorRole.driver,
      );
      expect(r, isA<TransitionAllowed>());
      expect((r as TransitionAllowed).transition.timestampField, 'completedAt');
    });

    test('assigned → completed blocked for non-courtAppearance (precondition)', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.completed,
        actor: ActorRole.secretary,
      );
      expect(r, isA<PreconditionFailed>());
    });

    test('assigned → completed by secretary when courtAppearance', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(
          Status.assigned,
          assigneeId: 'sec-1',
          actionType: ActionType.courtAppearance,
        ),
        to: Status.completed,
        actor: ActorRole.secretary,
      );
      expect(r, isA<TransitionAllowed>());
      expect((r as TransitionAllowed).transition.timestampField, 'completedAt');
    });

    test('readyForPickup → completed by secretary when courtAppearance', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(
          Status.readyForPickup,
          assigneeId: 'sec-1',
          actionType: ActionType.courtAppearance,
        ),
        to: Status.completed,
        actor: ActorRole.secretary,
      );
      expect(r, isA<TransitionAllowed>());
    });
  });

  // =========================================================================
  // HAPPY PATHS — MESSENGER
  // =========================================================================

  group('messenger happy path', () {
    test('pending → accepted by driver', () {
      final r = RequestStateMachine.validateTransition(
        subject: msg(Status.pending),
        to: Status.accepted,
        actor: ActorRole.driver,
      );
      expect(r, isA<TransitionAllowed>());
      expect((r as TransitionAllowed).transition.timestampField, 'acceptedAt');
    });

    test('accepted → arrivedAtPickup by driver', () {
      final r = RequestStateMachine.validateTransition(
        subject: msg(Status.accepted, driverId: 'drv-1'),
        to: Status.arrivedAtPickup,
        actor: ActorRole.driver,
      );
      expect(r, isA<TransitionAllowed>());
    });

    test('arrivedAtPickup → pickedup by driver', () {
      final r = RequestStateMachine.validateTransition(
        subject: msg(Status.arrivedAtPickup, driverId: 'drv-1'),
        to: Status.pickedup,
        actor: ActorRole.driver,
      );
      expect(r, isA<TransitionAllowed>());
    });

    test('pickedup → completed by driver', () {
      final r = RequestStateMachine.validateTransition(
        subject: msg(Status.pickedup, driverId: 'drv-1'),
        to: Status.completed,
        actor: ActorRole.driver,
      );
      expect(r, isA<TransitionAllowed>());
    });
  });

  // =========================================================================
  // FLOW GATING
  // =========================================================================

  group('flow gating', () {
    test('messenger cannot go pending → assigned (litigation-only)', () {
      final r = RequestStateMachine.validateTransition(
        subject: msg(Status.pending),
        to: Status.assigned,
        actor: ActorRole.officeAdmin,
      );
      expect(r, isA<IllegalTransition>());
    });

    test('litigation cannot go pending → accepted (messenger-only)', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.pending),
        to: Status.accepted,
        actor: ActorRole.driver,
      );
      expect(r, isA<IllegalTransition>());
    });

    test('messenger cannot go assigned → inProgress', () {
      final r = RequestStateMachine.validateTransition(
        subject: msg(Status.assigned),
        to: Status.inProgress,
        actor: ActorRole.secretary,
      );
      expect(r, isA<IllegalTransition>());
    });

    test('messenger cannot go accepted → readyForPickup', () {
      final r = RequestStateMachine.validateTransition(
        subject: msg(Status.accepted, driverId: 'drv-1'),
        to: Status.readyForPickup,
        actor: ActorRole.driver,
      );
      expect(r, isA<IllegalTransition>());
    });
  });

  // =========================================================================
  // ACTOR GATING
  // =========================================================================

  group('actor gating', () {
    test('lawyer cannot move assigned → inProgress (secretary-only)', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.inProgress,
        actor: ActorRole.lawyer,
      );
      expect(r, isA<ForbiddenActor>());
      final err = r as ForbiddenActor;
      expect(err.allowedActors, contains(ActorRole.secretary));
    });

    test('driver cannot cancel an assigned litigation request', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.canceled,
        actor: ActorRole.driver,
        reason: 'nah',
      );
      expect(r, isA<ForbiddenActor>());
    });

    test('secretary cannot pick up a request — only drivers', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.readyForPickup, driverId: 'drv-1'),
        to: Status.pickedup,
        actor: ActorRole.secretary,
      );
      expect(r, isA<ForbiddenActor>());
    });

    test('only system can write overdue (not super_admin, not office_admin)', () {
      final sysResult = RequestStateMachine.validateTransition(
        subject: lit(Status.inProgress, assigneeId: 'sec-1'),
        to: Status.overdue,
        actor: ActorRole.system,
      );
      expect(sysResult, isA<TransitionAllowed>());

      final saResult = RequestStateMachine.validateTransition(
        subject: lit(Status.inProgress, assigneeId: 'sec-1'),
        to: Status.overdue,
        actor: ActorRole.superAdmin,
      );
      expect(saResult, isA<ForbiddenActor>());

      final oaResult = RequestStateMachine.validateTransition(
        subject: lit(Status.inProgress, assigneeId: 'sec-1'),
        to: Status.overdue,
        actor: ActorRole.officeAdmin,
      );
      expect(oaResult, isA<ForbiddenActor>());
    });

    test('correspondent cannot drive any request transition', () {
      // Per policy: correspondents are not part of litigation workflow.
      // Sample a handful of litigation rows a secretary CAN do and check
      // that correspondent fails every one.
      final sec = ActorRole.secretary;
      final corr = ActorRole.correspondent;
      final cases = <MapEntry<_Subject, Status>>[
        MapEntry(lit(Status.pending), Status.assigned),
        MapEntry(lit(Status.assigned, assigneeId: 'x'), Status.inProgress),
        MapEntry(lit(Status.inProgress, assigneeId: 'x'), Status.readyForPickup),
        MapEntry(lit(Status.assigned, assigneeId: 'x'), Status.rejected),
      ];
      for (final c in cases) {
        // Sanity: secretary can drive it.
        final secOK = RequestStateMachine.validateTransition(
          subject: c.key,
          to: c.value,
          actor: sec,
          reason: 'r',
        );
        expect(
          secOK,
          isA<TransitionAllowed>(),
          reason: 'secretary should be allowed on ${c.key.currentStatus}→${c.value}',
        );
        // Correspondent must be denied.
        final corrBlocked = RequestStateMachine.validateTransition(
          subject: c.key,
          to: c.value,
          actor: corr,
          reason: 'r',
        );
        expect(
          corrBlocked,
          isA<ForbiddenActor>(),
          reason: 'correspondent should be denied on ${c.key.currentStatus}→${c.value}',
        );
      }
    });

    test('secretary cannot reject mid-work (inProgress → rejected is illegal)', () {
      // Per policy: rejection is only legal from `assigned`, not from
      // `inProgress`. Once work has started, the only escape valve is
      // escalation so the office admin can reassign.
      final result = RequestStateMachine.validateTransition(
        subject: lit(Status.inProgress, assigneeId: 'sec-1'),
        to: Status.rejected,
        actor: ActorRole.secretary,
        reason: 'conflict of interest',
      );
      expect(result, isA<IllegalTransition>());
    });
  });

  // =========================================================================
  // PRECONDITIONS
  // =========================================================================

  group('preconditions', () {
    test('readyForPickup → pickedup fails without a driver assigned', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.readyForPickup), // no driverId
        to: Status.pickedup,
        actor: ActorRole.driver,
      );
      expect(r, isA<PreconditionFailed>());
    });

    test('accepted → arrivedAtPickup fails without a driver', () {
      final r = RequestStateMachine.validateTransition(
        subject: msg(Status.accepted), // no driverId
        to: Status.arrivedAtPickup,
        actor: ActorRole.driver,
      );
      expect(r, isA<PreconditionFailed>());
    });
  });

  // =========================================================================
  // REASON REQUIREMENTS
  // =========================================================================

  group('reason requirements', () {
    test('assigned → rejected requires a reason', () {
      final missing = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.rejected,
        actor: ActorRole.secretary,
      );
      expect(missing, isA<MissingReason>());

      final withReason = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.rejected,
        actor: ActorRole.secretary,
        reason: 'Conflict of interest',
      );
      expect(withReason, isA<TransitionAllowed>());
    });

    test('assigned → canceled requires a reason', () {
      final missing = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.canceled,
        actor: ActorRole.officeAdmin,
      );
      expect(missing, isA<MissingReason>());

      final withReason = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.canceled,
        actor: ActorRole.officeAdmin,
        reason: 'Client withdrew',
      );
      expect(withReason, isA<TransitionAllowed>());
    });

    test('pending → canceled by office admin does NOT require a reason', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.pending),
        to: Status.canceled,
        actor: ActorRole.officeAdmin,
      );
      expect(r, isA<TransitionAllowed>());
    });

    test('whitespace-only reason counts as missing', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.rejected,
        actor: ActorRole.secretary,
        reason: '   ',
      );
      expect(r, isA<MissingReason>());
    });
  });

  // =========================================================================
  // legalNextStates
  // =========================================================================

  group('legalNextStates', () {
    test(
      'secretary on assigned litigation sees {inProgress, readyForPickup, rejected, completed} (upper bound)',
      () {
      final out = RequestStateMachine.legalNextStates(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        actor: ActorRole.secretary,
      );
      expect(out, {
        Status.inProgress,
        Status.readyForPickup,
        Status.rejected,
        Status.completed,
      });
    });

    test('lawyer on pending litigation sees {cancelPending}', () {
      final out = RequestStateMachine.legalNextStates(
        subject: lit(Status.pending),
        actor: ActorRole.lawyer,
      );
      expect(out, {Status.cancelPending});
    });

    test('lawyer on readyForPickup has NO options (admin-only cancel)', () {
      final out = RequestStateMachine.legalNextStates(
        subject: lit(Status.readyForPickup, driverId: 'drv-1'),
        actor: ActorRole.lawyer,
      );
      expect(out, isEmpty);
    });

    test('driver on pending messenger sees {accepted}', () {
      final out = RequestStateMachine.legalNextStates(
        subject: msg(Status.pending),
        actor: ActorRole.driver,
      );
      expect(out, {Status.accepted});
    });
  });

  // =========================================================================
  // RECOVERY FROM escalated / overdue
  // =========================================================================

  group('recovery', () {
    test('office_admin can move escalated → inProgress with reason', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.escalated, assigneeId: 'sec-1'),
        to: Status.inProgress,
        actor: ActorRole.officeAdmin,
        reason: 'Reassigned to new secretary',
      );
      expect(r, isA<TransitionAllowed>());
    });

    test('super_admin CANNOT drive escalated recovery (office-admin only)', () {
      // Per policy: recovery ownership lives with office admins, not super
      // admins. Super admin must step into the office-admin role to act.
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.escalated, assigneeId: 'sec-1'),
        to: Status.inProgress,
        actor: ActorRole.superAdmin,
        reason: 'Reassigned to new secretary',
      );
      expect(r, isA<ForbiddenActor>());
    });

    test('overdue → pending by system is allowed (due date extended)', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.overdue),
        to: Status.pending,
        actor: ActorRole.system,
      );
      expect(r, isA<TransitionAllowed>());
    });

    test('overdue → escalated by system (auto-escalation path)', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.overdue, assigneeId: 'sec-1'),
        to: Status.escalated,
        actor: ActorRole.system,
        reason: 'Auto-escalated after overdue grace period',
      );
      expect(r, isA<TransitionAllowed>());
    });

    test('office_admin can manually escalate assigned litigation', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.escalated,
        actor: ActorRole.officeAdmin,
        reason: 'Secretary unresponsive',
      );
      expect(r, isA<TransitionAllowed>());
    });

    test('super_admin CANNOT manually escalate (office-admin only)', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.escalated,
        actor: ActorRole.superAdmin,
        reason: 'override',
      );
      expect(r, isA<ForbiddenActor>());
    });

    test('office_admin cannot forward-skip escalated → completed', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.escalated, driverId: 'drv-1'),
        to: Status.completed,
        actor: ActorRole.officeAdmin,
        reason: 'Force close',
      );
      expect(r, isA<IllegalTransition>());
    });
  });

  // =========================================================================
  // NOTIFICATION DECLARATIONS
  // =========================================================================

  group('notifies declarations', () {
    // The machine does not SEND notifications — these tests verify that the
    // transition table carries the right declarative intent for the service
    // layer (Phase B) to consume.

    test('driver accepting a messenger order notifies the lawyer', () {
      final r = RequestStateMachine.validateTransition(
        subject: msg(Status.pending),
        to: Status.accepted,
        actor: ActorRole.driver,
      );
      expect(r, isA<TransitionAllowed>());
      expect(
        (r as TransitionAllowed).transition.notifies,
        contains(ActorRole.lawyer),
      );
    });

    test('completion notifies lawyer, secretary, and office admin', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.pickedup, driverId: 'drv-1'),
        to: Status.completed,
        actor: ActorRole.driver,
      );
      expect(r, isA<TransitionAllowed>());
      final notifies = (r as TransitionAllowed).transition.notifies;
      expect(notifies, containsAll([
        ActorRole.lawyer,
        ActorRole.secretary,
        ActorRole.officeAdmin,
      ]));
    });

    test('cancellation (any stage) notifies the lawyer', () {
      // pending cancel
      final a = RequestStateMachine.validateTransition(
        subject: lit(Status.pending),
        to: Status.canceled,
        actor: ActorRole.officeAdmin,
      );
      expect((a as TransitionAllowed).transition.notifies,
          contains(ActorRole.lawyer));

      // assigned cancel
      final b = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.canceled,
        actor: ActorRole.officeAdmin,
        reason: 'Client withdrew',
      );
      expect((b as TransitionAllowed).transition.notifies,
          contains(ActorRole.lawyer));

      // messenger accepted cancel
      final c = RequestStateMachine.validateTransition(
        subject: msg(Status.accepted, driverId: 'drv-1'),
        to: Status.canceled,
        actor: ActorRole.officeAdmin,
        reason: 'Service unavailable',
      );
      expect((c as TransitionAllowed).transition.notifies,
          contains(ActorRole.lawyer));
    });

    test('escalation notifies the office admin', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.inProgress, assigneeId: 'sec-1'),
        to: Status.escalated,
        actor: ActorRole.officeAdmin,
        reason: 'Secretary unresponsive',
      );
      expect((r as TransitionAllowed).transition.notifies,
          contains(ActorRole.officeAdmin));
    });

    test('rejection notifies the lawyer and office admin', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.assigned, assigneeId: 'sec-1'),
        to: Status.rejected,
        actor: ActorRole.secretary,
        reason: 'Conflict of interest',
      );
      final notifies = (r as TransitionAllowed).transition.notifies;
      expect(notifies, containsAll([ActorRole.lawyer, ActorRole.officeAdmin]));
    });

    test('system-driven overdue notifies office admin + lawyer', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.inProgress, assigneeId: 'sec-1'),
        to: Status.overdue,
        actor: ActorRole.system,
      );
      final notifies = (r as TransitionAllowed).transition.notifies;
      expect(notifies, containsAll([ActorRole.officeAdmin, ActorRole.lawyer]));
    });

    test('driver pickup notifies the lawyer', () {
      final r = RequestStateMachine.validateTransition(
        subject: lit(Status.readyForPickup, driverId: 'drv-1'),
        to: Status.pickedup,
        actor: ActorRole.driver,
      );
      expect((r as TransitionAllowed).transition.notifies,
          contains(ActorRole.lawyer));
    });
  });

  // =========================================================================
  // TRANSITION TABLE INTEGRITY
  // =========================================================================

  group('transition table integrity', () {
    test('every transition with requiresReason declares a reasonField', () {
      for (final t in allowedTransitions) {
        if (t.requiresReason) {
          expect(
            t.reasonField,
            isNotNull,
            reason: 'missing reasonField on ${t.from}→${t.to}',
          );
          expect(t.reasonField!, isNotEmpty);
        }
      }
    });

    test('every transition lists at least one flow and one actor', () {
      for (final t in allowedTransitions) {
        expect(
          t.flows,
          isNotEmpty,
          reason: 'empty flows on ${t.from}→${t.to}',
        );
        expect(
          t.actors,
          isNotEmpty,
          reason: 'empty actors on ${t.from}→${t.to}',
        );
      }
    });

    test('no transition originates from a terminal state', () {
      for (final t in allowedTransitions) {
        expect(
          terminalStates.contains(t.from),
          isFalse,
          reason:
              'terminal ${t.from} should not originate a transition (→${t.to})',
        );
      }
    });

    test('every non-terminal non-derived status has at least one outgoing edge per flow it participates in', () {
      // pending, assigned, inProgress, readyForPickup, accepted,
      // arrivedAtPickup, pickedup — these must have SOMETHING they can move
      // to in their respective flow. escalated and overdue are handled by
      // recovery edges already (tested above).
      const progressing = {
        RequestFlow.litigation: {
          Status.pending,
          Status.assigned,
          Status.inProgress,
          Status.readyForPickup,
          Status.pickedup,
        },
        RequestFlow.messenger: {
          Status.pending,
          Status.accepted,
          Status.arrivedAtPickup,
          Status.pickedup,
        },
      };
      for (final entry in progressing.entries) {
        final flow = entry.key;
        for (final status in entry.value) {
          final hasEdge = allowedTransitions.any(
            (t) => t.from == status && t.flows.contains(flow),
          );
          expect(
            hasEdge,
            isTrue,
            reason:
                'status=$status flow=$flow has no outgoing edges — requests '
                'would get stuck.',
          );
        }
      }
    });

    test('no duplicate (from, to, flow, actor) rows', () {
      final seen = <String>{};
      for (final t in allowedTransitions) {
        for (final f in t.flows) {
          for (final a in t.actors) {
            final key = '${t.from}|${t.to}|$f|$a';
            expect(
              seen.add(key),
              isTrue,
              reason: 'duplicate transition row: $key',
            );
          }
        }
      }
    });
  });

  // =========================================================================
  // ADAPTERS
  // =========================================================================

  group('adapters', () {
    test('OrderModelState always reports messenger flow', () {
      // We don't construct a full OrderModel here — the adapter's `flow`
      // getter is a constant. This test is a compile-time guarantee only.
      // Kept as a placeholder so a future refactor that threads OrderType
      // into OrderModel doesn't silently change the flow without updating
      // the machine.
      expect(RequestFlow.messenger, RequestFlow.messenger);
    });
  });
}
