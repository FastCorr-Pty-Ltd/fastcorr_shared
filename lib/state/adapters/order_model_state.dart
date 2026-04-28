import 'package:fastcorr_shared/models/order_model.dart';
import 'package:fastcorr_shared/models/request_model.dart' show Status;
import 'package:fastcorr_shared/state/request_flow.dart';
import 'package:fastcorr_shared/state/stateful_request.dart';

/// Adapter that exposes an [OrderModel] (messenger flow) to the state
/// machine via the [StatefulRequest] contract.
///
/// `OrderModel` is always a messenger order — it has no `orderType` field
/// because there is no other kind of OrderModel.
class OrderModelState implements StatefulRequest {
  final OrderModel _order;
  const OrderModelState(this._order);

  @override
  Status get currentStatus => _order.status;

  @override
  RequestFlow get flow => RequestFlow.messenger;

  @override
  String? get assigneeId => _order.assigneeId;

  @override
  String? get driverId => _order.driverId;

  @override
  String get subjectId => _order.orderId;

  @override
  String? get statusBeforeCancelPending => _order.statusBeforeCancelPending;
}
