import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/order_model.dart';
import 'package:fastcorr_shared/models/request_model.dart';

/// Payload for `pending_cancellations/{orderId}` when a lawyer cancels
/// litigation work (mirrors admin [PendingCancellationsService.buildPendingDoc]).
Map<String, dynamic> buildLitigationPendingCancellationPayload({
  required RequestModel request,
  String? cancelReason,
}) {
  return {
    'requestId': request.orderId,
    'lawyerId': request.lawyerId,
    'officeId': request.officeId,
    'orgId': request.orgId,
    'orderType': request.orderType?.name,
    'snapshot': {
      'orderId': request.orderId,
      'title': request.title,
      'status': request.status?.name,
      'lawyerId': request.lawyerId,
      'officeId': request.officeId,
      'orgId': request.orgId,
      'assigneeId': request.assigneeId,
      'driverId': request.driverId,
      'caseFileId': request.caseFileId,
      'orderType': request.orderType?.name,
    },
    'cancelReason': cancelReason ?? '',
    'canceledAt': Timestamp.now(),
    'rollbackStatus': 'pending',
  };
}

/// Payload for lawyer-cancel on a messenger [OrderModel].
Map<String, dynamic> buildMessengerPendingCancellationPayload({
  required OrderModel order,
  required String officeId,
  String? cancelReason,
}) {
  return {
    'requestId': order.orderId,
    'lawyerId': order.lawyerId,
    'officeId': officeId,
    'orgId': order.orgId,
    'orderType': OrderType.messenger.name,
    'snapshot': {
      'orderId': order.orderId,
      'title': order.serviceTitle,
      'status': order.status.name,
      'lawyerId': order.lawyerId,
      'officeId': officeId,
      'orgId': order.orgId,
      'assigneeId': order.assigneeId,
      'driverId': order.driverId,
      'caseFileId': null,
      'orderType': OrderType.messenger.name,
    },
    'cancelReason': cancelReason ?? '',
    'canceledAt': Timestamp.now(),
    'rollbackStatus': 'pending',
  };
}
