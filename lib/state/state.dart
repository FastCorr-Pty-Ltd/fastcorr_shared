/// Request / order state machine.
///
/// Entry point: [RequestStateMachine]. See `transitions.dart` for the full
/// transition table (single source of truth for request lifecycle rules).
library;

export 'actor_role.dart';
export 'adapters/order_model_state.dart';
export 'adapters/request_model_state.dart';
export 'pending_cancellation_payload.dart';
export 'request_flow.dart';
export 'request_state_machine.dart';
export 'request_status_patch.dart';
export 'stateful_request.dart';
export 'transition.dart';
export 'transition_result.dart';
export 'transitions.dart';
