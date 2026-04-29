import 'package:fastcorr_shared/models/request_model.dart';
import 'package:fastcorr_shared/state/request_flow.dart';
import 'package:fastcorr_shared/state/stateful_request.dart';

/// Adapter that exposes a [RequestModel] (litigation flow) to the state
/// machine via the [StatefulRequest] contract.
///
/// Adapters keep the state machine oblivious to model-class shapes, and
/// keep the model classes oblivious to state-machine concerns. Neither
/// side imports the other.
class RequestModelState implements StatefulRequest {
  final RequestModel _request;
  const RequestModelState(this._request);

  /// `RequestModel.status` is nullable on the model (legacy docs predate the
  /// field). Null is treated as `Status.pending` — the natural entry state —
  /// so the machine can still gate newly-created or malformed docs.
  @override
  Status get currentStatus => _request.status ?? Status.pending;

  /// A [RequestModel] is the litigation flow by definition (secretary-
  /// processed), but if the model itself ever carries a different
  /// [OrderType] we defer to that so the machine still does the right
  /// thing for mixed-data migrations. Null defaults to litigation.
  @override
  RequestFlow get flow =>
      (_request.orderType ?? OrderType.litigation).toRequestFlow();

  @override
  String? get assigneeId => _request.assigneeId;

  @override
  String? get driverId => _request.driverId;

  @override
  String get subjectId => _request.orderId;

  @override
  String? get statusBeforeCancelPending => _request.statusBeforeCancelPending;

  @override
  ActionType? get actionType => _request.actionType;
}
