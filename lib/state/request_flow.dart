import 'package:fastcorr_shared/models/request_model.dart' show OrderType;

/// Which lifecycle a subject follows.
///
/// Both [RequestModel] (litigation, secretary-processed) and [OrderModel]
/// (messenger, driver-direct) share the same [Status] enum after Phase A's
/// enum merge, but they follow *different* transition graphs. The state
/// machine uses this flag to pick the right subset of transitions.
///
/// - [litigation]: `pending → assigned → inProgress → readyForPickup →
///   pickedup → completed`, with secretaries and correspondents doing the
///   processing work.
/// - [messenger]: `pending → accepted → arrivedAtPickup → pickedup →
///   completed`, with drivers self-accepting and no secretary involvement.
enum RequestFlow {
  litigation,
  messenger,
}

extension RequestFlowFromOrderType on OrderType {
  RequestFlow toRequestFlow() {
    switch (this) {
      case OrderType.litigation:
        return RequestFlow.litigation;
      case OrderType.messenger:
        return RequestFlow.messenger;
    }
  }
}
