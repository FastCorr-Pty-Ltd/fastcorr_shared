import 'package:fastcorr_shared/models/order_model.dart' show OrderStatus;
import 'package:fastcorr_shared/models/request_model.dart' show Status;

/// Maps litigation [Status] values onto the driver [OrderStatus] typedef.
///
/// [OrderStatus] is a typedef of [Status]; this exists so secretary-side
/// **`assigned`** is surfaced consistently as **`accepted`** for driver UX and
/// services that historically assumed messenger semantics.
OrderStatus orderStatusFromTaskStatus(Status status) {
  switch (status) {
    case Status.assigned:
      return OrderStatus.accepted;
    default:
      return status;
  }
}
