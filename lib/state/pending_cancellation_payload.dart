import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/order_model.dart';
import 'package:fastcorr_shared/models/request_model.dart';

/// Payload for `pending_cancellations/{orderId}` when a lawyer moves an order
/// to [Status.cancelPending] (mirrors admin [PendingCancellationsService]).
Map<String, dynamic> buildLitigationPendingCancellationPayload({
  required RequestModel request,
  required String previousStatus,
  required int requestCostCents,
  String? cancelReason,
  String? lawyerEmail,
  String? lawyerPhone,
  String? lawyerName,
}) {
  final trimmedCase = request.caseFileId.trim();
  return {
    'requestId': request.orderId,
    'lawyerId': request.lawyerId,
    'officeId': request.officeId,
    'orgId': request.orgId,
    'orderType': request.orderType?.name,
    'previousStatus': previousStatus,
    'requestCost': requestCostCents,
    'caseFileId': trimmedCase.isEmpty ? null : trimmedCase,
    'lawyerEmail': lawyerEmail ?? '',
    'lawyerPhone': lawyerPhone ?? '',
    'lawyerName': lawyerName ?? '',
    'snapshot': {
      'orderId': request.orderId,
      'title': request.title,
      'status': request.status?.name,
      'lawyerId': request.lawyerId,
      'officeId': request.officeId,
      'orgId': request.orgId,
      'assigneeId': request.assigneeId,
      'driverId': request.driverId,
      'caseFileId': trimmedCase.isEmpty ? null : trimmedCase,
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
  required String previousStatus,
  required int requestCostCents,
  String? cancelReason,
  String? lawyerEmail,
  String? lawyerPhone,
  String? lawyerName,
}) {
  return {
    'requestId': order.orderId,
    'lawyerId': order.lawyerId,
    'officeId': officeId,
    'orgId': order.orgId,
    'orderType': OrderType.messenger.name,
    'previousStatus': previousStatus,
    'requestCost': requestCostCents,
    'caseFileId': order.caseFileId,
    'lawyerEmail': lawyerEmail ?? '',
    'lawyerPhone': lawyerPhone ?? '',
    'lawyerName': lawyerName ?? '',
    'snapshot': {
      'orderId': order.orderId,
      'title': order.serviceTitle,
      'status': order.status.name,
      'lawyerId': order.lawyerId,
      'officeId': officeId,
      'orgId': order.orgId,
      'assigneeId': order.assigneeId,
      'driverId': order.driverId,
      'caseFileId': order.caseFileId,
      'orderType': OrderType.messenger.name,
    },
    'cancelReason': cancelReason ?? '',
    'canceledAt': Timestamp.now(),
    'rollbackStatus': 'pending',
  };
}
