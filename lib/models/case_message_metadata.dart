import 'package:uuid/uuid.dart';

// -----------------------------------------------------------------------------
// Well-known keys for [UnifiedCaseMessage.metadata] (query / analytics)
// -----------------------------------------------------------------------------

const String kCaseMessageMetaEventType = 'eventType';

/// Optional link to a delivery / request order (when the case is tied to one).
const String kCaseMessageMetaOrderId = 'orderId';

/// Id returned for a filing-return / returned-court task.
const String kCaseMessageMetaReturnedTaskId = 'returnedTaskId';

/// Filing return subtype payload (e.g. document type string); keep JSON-serializable.
const String kCaseMessageMetaFilingReturn = 'filingReturn';

/// Debug / audit: same value used to derive idempotent [UnifiedCaseMessage.id].
const String kCaseMessageMetaIdempotencyKey = 'idempotencyKey';

const String kCaseMessageMetaSource = 'source';

/// [kCaseMessageMetaSource] value — user app case comms tab.
const String kCaseMessageSourceUserCaseDetails = 'user_case_details';

/// [kCaseMessageMetaSource] value — admin case comms tab.
const String kCaseMessageSourceAdminCaseDetails = 'admin_case_details';

// -----------------------------------------------------------------------------
// Event type values
// -----------------------------------------------------------------------------

/// Case comms: secretary completed a filing return / returned task, document on thread.
const String caseEventFilingReturnCompleted = 'filing_return_completed';

/// Case comms tab: document-only send (no body text).
const String caseEventCaseCommsSharedDocuments = 'case_comms_shared_documents';

/// Case comms tab: chat line without treating as special reply.
const String caseEventCaseCommsChat = 'case_comms_chat';

/// Case comms tab: reply to an existing message.
const String caseEventCaseCommsReply = 'case_comms_reply';

// -----------------------------------------------------------------------------
// Event helpers
// -----------------------------------------------------------------------------

/// Metadata for a filing-return task completion message (filter without parsing [content]).
Map<String, dynamic> buildFilingReturnTaskCompletedMetadata({
  required String returnedTaskId,
  String? orderId,
  String? filingReturnType,
  String? idempotencyKey,
}) {
  return {
    kCaseMessageMetaEventType: caseEventFilingReturnCompleted,
    kCaseMessageMetaReturnedTaskId: returnedTaskId,
    if (orderId != null && orderId.isNotEmpty) kCaseMessageMetaOrderId: orderId,
    if (filingReturnType != null && filingReturnType.isNotEmpty)
      kCaseMessageMetaFilingReturn: {
        'type': filingReturnType,
      },
    if (idempotencyKey != null && idempotencyKey.isNotEmpty)
      kCaseMessageMetaIdempotencyKey: idempotencyKey,
  };
}

// -----------------------------------------------------------------------------
// Idempotent Firestore document id (UUID v5) for safe client retries
// -----------------------------------------------------------------------------

const Uuid _uuid = Uuid();

/// Deterministic [UnifiedCaseMessage] id: same [caseId] + [idempotencyKey] -> same id.
String caseMessageDocumentId({
  required String caseId,
  required String idempotencyKey,
}) {
  // Namespace + stable string — RFC 4122 name-based id.
  const namespace = '6ba7b811-9dad-11d1-80b4-00c04fd430c8'; // URL namespace
  final name = 'fastcorr:case-communications:msg:$caseId:$idempotencyKey';
  return _uuid.v5(namespace, name);
}

// -----------------------------------------------------------------------------
// Send pipeline — failure classification
// -----------------------------------------------------------------------------

/// Where the case comms send flow failed (upload, Firestore message write, or post-write).
enum CaseCommsSendStage { upload, messageWrite, postWrite }

class CaseCommsSendException implements Exception {
  CaseCommsSendException(this.stage, this.cause, {this.attachmentIdsCleanedUp = const []});

  final CaseCommsSendStage stage;
  final Object cause;
  final List<String> attachmentIdsCleanedUp;

  @override
  String toString() =>
      'CaseCommsSendException($stage, cause: $cause, cleanedUp: $attachmentIdsCleanedUp)';
}
