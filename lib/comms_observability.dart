import 'dart:convert';
import 'dart:developer' as dev;

import 'package:fastcorr_shared/models/case_message_metadata.dart';
import 'package:fastcorr_shared/models/unified_case_message.dart';

/// Log name: filter in DevTools or forward JSON lines from device logs to your pipeline.
const String kCommsLogName = 'fastcorr.comms';

/// JSON-serializable payload for [kCommsLogName] (Grafana Loki, Cloud Logging, etc.).
void logCommsEvent(String event, Map<String, Object?> fields) {
  final safe = <String, Object?>{'event': event, ..._jsonSafeMap(fields)};
  try {
    dev.log(jsonEncode(safe), name: kCommsLogName);
  } catch (_) {
    dev.log('$event ${safe.toString()}', name: kCommsLogName);
  }
}

Map<String, Object?> _jsonSafeMap(Map<String, Object?> m) {
  return m.map((k, v) => MapEntry(k, _jsonSafe(v)));
}

Object? _jsonSafe(Object? v) {
  if (v == null) return null;
  if (v is num || v is String || v is bool) return v;
  return v.toString();
}

// --- Case communications (Firestore: cases/.../communications) ---

void logCaseCommsMessageWriteOk({
  required String caseId,
  String? orgId,
  required String messageId,
  required UnifiedMessageType type,
  String? component,
}) {
  logCommsEvent('case_comms.message.write_ok', {
    'channel': 'case_comms',
    'caseId': caseId,
    'orgId': orgId,
    'messageId': messageId,
    'messageType': type.name,
    'component': component,
  });
}

void logCaseCommsPostWritePartial({
  required String caseId,
  String? orgId,
  required String messageId,
  required UnifiedMessageType type,
  String? component,
  Object? error,
}) {
  logCommsEvent('case_comms.message.postwrite_partial', {
    'channel': 'case_comms',
    'caseId': caseId,
    'orgId': orgId,
    'messageId': messageId,
    'messageType': type.name,
    'component': component,
    'stage': CaseCommsSendStage.postWrite.name,
    'error': error?.toString(),
  });
}

void logCaseCommsSendFailed({
  required String caseId,
  String? orgId,
  String? messageId,
  required CaseCommsSendStage stage,
  required UnifiedMessageType type,
  String? component,
  required Object error,
}) {
  logCommsEvent('case_comms.send.failed', {
    'channel': 'case_comms',
    'caseId': caseId,
    'orgId': orgId,
    'messageId': messageId,
    'messageType': type.name,
    'stage': stage.name,
    'component': component,
    'error': error.toString(),
  });
}

void logCaseCommsUploadFailed({
  required String caseId,
  String? orgId,
  String? fileName,
  String? component,
  required Object error,
}) {
  logCommsEvent('case_comms.upload.failed', {
    'channel': 'case_comms',
    'caseId': caseId,
    'orgId': orgId,
    'fileName': fileName,
    'component': component,
    'error': error.toString(),
  });
}

// --- Order chat (Firestore: chats/.../messages) ---

void logOrderChatMessageWriteOk({
  required String orderId,
  String? component,
}) {
  logCommsEvent('order_chat.message.write_ok', {
    'channel': 'order_chat',
    'orderId': orderId,
    'component': component,
  });
}

void logOrderChatMessageWriteFailed({
  required String orderId,
  String? component,
  required Object error,
}) {
  logCommsEvent('order_chat.message.write_failed', {
    'channel': 'order_chat',
    'orderId': orderId,
    'component': component,
    'error': error.toString(),
  });
}
