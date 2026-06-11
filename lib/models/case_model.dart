import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum CaseStatus { active, closed, pending, onHold }

/// Billing matter types selectable when creating a case file.
const List<String> kMatterTypes = [
  '30-Day Terms',
  '60-Day Terms',
  'Bad Debt',
  'Business Rescue',
  'Client Suspended',
  'Collection',
  'Contingency',
  'Correspondent',
  'Late Estate',
  'Payment Arrangement',
  'Pro-Bono',
  'Retainers',
  'Secretary Pool',
  'SEESA - 10% Discount',
  'Signed AOD',
];

class CaseModel {
  final String caseFileId;
  final String litNumber;
  final int phase;
  String? caseNumber;
  final String caseName;
  String? description;
  final Timestamp createdAt;
  final Timestamp? lastupdatedAt;

  final String lawyerId;
  final String orgId;
  final String officeId;
  final List<String>? partyIds;

  // Billing & access (accounting module)
  /// Org-unique client number, e.g. `CNT001`. The client number is the
  /// unique identifier for clients (also the Firestore document id under
  /// `organisations/{orgId}/clients`).
  final String? clientNumber;
  /// Billing matter type, one of [kMatterTypes].
  final String? matterType;
  /// Optional maximum fees that may be billed on this matter (cents).
  final int? feeCapCents;
  /// Other lawyers in the organisation granted access to this case file.
  final List<String> accessLawyerIds;

  final CaseStatus status;
  final String? judge;

  final String? courtId;
  final String? caseType; // civil, criminal, etc.
  final String? assigneeId;
  final String? correspondentId;
  final String? opposingAttorneyId;
  final String? opposingAttorneyName;

  // Financial tracking
  /// FastCorr platform spend on this matter (litigation/messenger request
  /// costs debited from org credits), in cents.
  final int totalCost;
  /// Client-billable work captured on this matter (fee entries + manual
  /// disbursements), in cents. Does not include FastCorr spend — that is
  /// tracked separately on [totalCost] and client invoices.
  final int clientBillableCents;
  final int paidAmount;
  final int capitalAmount;
  final String scale;

  // Event tracking
  final List<String> courtDateIds;
  final List<String> requestIds;
  /// Client invoice numbers issued against this case file (one per billed action).
  final List<String> invoiceIds;
  final List<String> returnTaskIds;
  final List<String>? receiptIds;
  final List<String>? instructionIds;

  final List<String>? followupDocIds;
  CaseModel({
    this.caseNumber,
    required this.caseFileId,
    required this.caseName,
    required this.litNumber,
    required this.capitalAmount,
    required this.scale,
    this.description,
    required this.createdAt,
    this.lastupdatedAt,
    this.status = CaseStatus.active,
    this.judge,
    this.courtId,
    this.caseType,
    this.partyIds = const [],
    this.totalCost = 0,
    this.clientBillableCents = 0,
    this.paidAmount = 0,
    this.courtDateIds = const [],
    this.requestIds = const [],
    this.invoiceIds = const [],
    this.returnTaskIds = const [],
    this.instructionIds,
    this.followupDocIds,
    this.receiptIds,
    required this.orgId,
    this.clientNumber,
    this.matterType,
    this.feeCapCents,
    this.accessLawyerIds = const [],
    this.assigneeId,
    required this.officeId,
    this.correspondentId,
    required this.lawyerId,
    this.phase = 1, // Default to phase 1 for new cases
    this.opposingAttorneyId,
    this.opposingAttorneyName,
  });

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse lists from JSON
    List<String> safeListFromJson(dynamic jsonList) {
      if (jsonList == null) return [];
      if (jsonList is! List) return [];

      return jsonList
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    // Helper function to safely convert to int, handling Infinity and NaN
    int safeToInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;

      // Handle numeric types
      if (value is int) return value;
      if (value is double) {
        // Check for Infinity or NaN
        if (value.isInfinite || value.isNaN) {
          return defaultValue;
        }
        return value.toInt();
      }

      // Try parsing string
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
        final parsedDouble = double.tryParse(value);
        if (parsedDouble != null &&
            !parsedDouble.isInfinite &&
            !parsedDouble.isNaN) {
          return parsedDouble.toInt();
        }
      }

      return defaultValue;
    }

    return CaseModel(
      caseFileId: json['caseFileId'] ?? '',
      caseNumber: json['caseNumber'] ?? '',
      caseName: json['caseName'] ?? '',
      description: json['description'] ?? '',
      createdAt: processedTimestamp(json['createdAt'])!,
      lastupdatedAt: json['lastupdatedAt'] != null
          ? processedTimestamp(json['lastupdatedAt'])
          : null,
      status: CaseStatus.values.byName(json['status'] ?? 'active'),
      litNumber: json['litNumber'] ?? '',
      judge: json['judge'] ?? '',
      courtId: json['courtId'] ?? '',
      caseType: json['caseType'] ?? '',
      partyIds: safeListFromJson(json['partyIds']),
      totalCost: safeToInt(json['totalCost']),
      clientBillableCents: safeToInt(json['clientBillableCents']),
      paidAmount: safeToInt(json['paidAmount']),
      capitalAmount: safeToInt(json['capitalAmount']),
      scale: json['scale'] ?? '',
      courtDateIds: safeListFromJson(json['courtDateIds']),
      requestIds: safeListFromJson(json['requestIds']),
      invoiceIds: safeListFromJson(json['invoiceIds']),
      receiptIds: safeListFromJson(json['receiptIds']),
      returnTaskIds: safeListFromJson(json['returnTaskIds']),
      instructionIds: safeListFromJson(json['instructionIds']),
      followupDocIds: safeListFromJson(json['followupDocIds']),
      orgId: json['orgId'] ?? '',
      clientNumber: json['clientNumber'] as String?,
      matterType: json['matterType'] as String?,
      feeCapCents:
          json['feeCapCents'] == null ? null : safeToInt(json['feeCapCents']),
      accessLawyerIds: safeListFromJson(json['accessLawyerIds']),
      assigneeId: json['assigneeId'] ?? '',
      officeId: json['officeId'] ?? '',
      correspondentId: json['correspondentId'] ?? '',
      lawyerId: json['lawyerId'] ?? '',
      phase: safeToInt(json['phase'], defaultValue: 1),
      opposingAttorneyId: json['opposingAttorneyId'] ?? '',
      opposingAttorneyName: json['opposingAttorneyName'] ?? '',
    );
  }

  factory CaseModel.fromSnapshot(DocumentSnapshot snapshot) {
    // Helper function to safely parse lists from snapshot
    List<String> safeListFromSnapshot(dynamic snapshotList) {
      if (snapshotList == null) return [];
      if (snapshotList is! List) return [];

      return snapshotList
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    // Helper function to safely convert to int, handling Infinity and NaN
    int safeToInt(dynamic value, {int defaultValue = 0}) {
      if (value == null) return defaultValue;

      // Handle numeric types
      if (value is int) return value;
      if (value is double) {
        // Check for Infinity or NaN
        if (value.isInfinite || value.isNaN) {
          return defaultValue;
        }
        return value.toInt();
      }

      // Try parsing string
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
        final parsedDouble = double.tryParse(value);
        if (parsedDouble != null &&
            !parsedDouble.isInfinite &&
            !parsedDouble.isNaN) {
          return parsedDouble.toInt();
        }
      }

      return defaultValue;
    }

    // New billing fields may be absent on older documents; the snapshot []
    // operator throws on missing fields, so go through the raw data map.
    final data = snapshot.data() as Map<String, dynamic>? ?? {};

    return CaseModel(
      caseFileId: snapshot.id,
      caseNumber: snapshot['caseNumber'] ?? '',
      caseName: snapshot['caseName'] ?? '',
      description: snapshot['description'] ?? '',
      createdAt: processedTimestamp(snapshot['createdAt'])!,
      lastupdatedAt: snapshot['lastupdatedAt'] != null
          ? processedTimestamp(snapshot['lastupdatedAt'])
          : null,
      status: CaseStatus.values.byName(snapshot['status'] ?? 'active'),
      litNumber: snapshot['litNumber'] ?? '',
      judge: snapshot['judge'] ?? '',
      courtId: snapshot['courtId'] ?? '',
      caseType: snapshot['caseType'] ?? '',
      partyIds: safeListFromSnapshot(snapshot['partyIds']),
      totalCost: safeToInt(snapshot['totalCost']),
      clientBillableCents: safeToInt(data['clientBillableCents']),
      paidAmount: safeToInt(snapshot['paidAmount']),
      capitalAmount: safeToInt(snapshot['capitalAmount']),
      scale: snapshot['scale'] ?? '',
      courtDateIds: safeListFromSnapshot(snapshot['courtDateIds']),
      requestIds: safeListFromSnapshot(snapshot['requestIds']),
      invoiceIds: safeListFromSnapshot(data['invoiceIds']),
      receiptIds: safeListFromSnapshot(snapshot['receiptIds']),
      returnTaskIds: safeListFromSnapshot(snapshot['returnTaskIds']),
      instructionIds: safeListFromSnapshot(snapshot['instructionIds']),
      followupDocIds: safeListFromSnapshot(snapshot['followupDocIds']),
      orgId: snapshot['orgId'] ?? '',
      clientNumber: data['clientNumber'] as String?,
      matterType: data['matterType'] as String?,
      feeCapCents:
          data['feeCapCents'] == null ? null : safeToInt(data['feeCapCents']),
      accessLawyerIds: safeListFromSnapshot(data['accessLawyerIds']),
      assigneeId: snapshot['assigneeId'] ?? '',
      officeId: snapshot['officeId'] ?? '',
      correspondentId: snapshot['correspondentId'] ?? '',
      lawyerId: snapshot['lawyerId'] ?? '',
      phase: safeToInt(snapshot['phase'], defaultValue: 1),
      opposingAttorneyId: snapshot['opposingAttorneyId'] ?? '',
      opposingAttorneyName: snapshot['opposingAttorneyName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    // Helper function to safely convert lists to JSON arrays
    List<String> safeListToJson(List<String>? list) {
      if (list == null) return [];
      return list
          .where((item) => item.isNotEmpty)
          .map((item) => item.toString())
          .toList();
    }

    return {
      'caseFileId': caseFileId,
      'caseNumber': caseNumber ?? '',
      'caseName': caseName,
      'description': description ?? '',
      'createdAt': createdAt,
      'lastupdatedAt': lastupdatedAt,
      'status': status.name,
      'litNumber': litNumber,
      'judge': judge ?? '',
      'courtId': courtId ?? '',
      'caseType': caseType ?? '',
      'partyIds': safeListToJson(partyIds),
      'totalCost': totalCost,
      'clientBillableCents': clientBillableCents,
      'paidAmount': paidAmount,
      'capitalAmount': capitalAmount,
      'scale': scale,
      'returnTaskIds': safeListToJson(returnTaskIds),
      'instructionIds': safeListToJson(instructionIds),
      'followupDocIds': safeListToJson(followupDocIds),
      'courtDateIds': safeListToJson(courtDateIds),
      'requestIds': safeListToJson(requestIds),
      'invoiceIds': safeListToJson(invoiceIds),
      'receiptIds': safeListToJson(receiptIds),
      'orgId': orgId,
      'clientNumber': clientNumber,
      'matterType': matterType,
      'feeCapCents': feeCapCents,
      'accessLawyerIds': safeListToJson(accessLawyerIds),
      'assigneeId': assigneeId,
      'officeId': officeId,
      'correspondentId': correspondentId,
      'lawyerId': lawyerId,
      'phase': phase,
      'opposingAttorneyId': opposingAttorneyId,
      'opposingAttorneyName': opposingAttorneyName,
    };
  }

  CaseModel copyWith({
    String? caseFileId,
    String? caseNumber,
    String? caseName,
    String? description,
    Timestamp? createdAt,
    Timestamp? lastupdatedAt,
    CaseStatus? status,
    String? litNumber,
    String? courtName,
    String? courtId,
    String? caseType,
    List<String>? partyIds,
    int? totalCost,
    int? clientBillableCents,
    int? paidAmount,
    int? capitalAmount,
    String? scale,
    List<String>? eventIds,
    List<String>? courtDateIds,
    List<String>? requestIds,
    List<String>? invoiceIds,
    List<String>? receiptIds,
    List<String>? returnTaskIds,
    List<String>? instructionIds,
    List<String>? followupDocIds,
    String? orgId,
    String? clientNumber,
    String? matterType,
    int? feeCapCents,
    List<String>? accessLawyerIds,
    String? assigneeId,
    String? officeId,
    String? judge,
    String? correspondentId,
    String? lawyerId,
    int? phase,
    String? opposingAttorneyId,
    String? opposingAttorneyName,
  }) {
    return CaseModel(
      caseFileId: caseFileId ?? this.caseFileId,
      caseNumber: caseNumber ?? this.caseNumber,
      caseName: caseName ?? this.caseName,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      lastupdatedAt: lastupdatedAt ?? this.lastupdatedAt,
      status: status ?? this.status,
      litNumber: litNumber ?? this.litNumber,
      capitalAmount: capitalAmount ?? this.capitalAmount,
      scale: scale ?? this.scale,
      returnTaskIds: returnTaskIds ?? this.returnTaskIds,
      instructionIds: instructionIds ?? this.instructionIds,
      followupDocIds: followupDocIds ?? this.followupDocIds,
      judge: judge ?? this.judge,
      courtId: courtId ?? this.courtId,
      caseType: caseType ?? this.caseType,
      partyIds: partyIds ?? this.partyIds,
      totalCost: totalCost ?? this.totalCost,
      clientBillableCents: clientBillableCents ?? this.clientBillableCents,
      paidAmount: paidAmount ?? this.paidAmount,
      courtDateIds: courtDateIds ?? this.courtDateIds,
      requestIds: requestIds ?? this.requestIds,
      invoiceIds: invoiceIds ?? this.invoiceIds,
      receiptIds: receiptIds ?? this.receiptIds,
      orgId: orgId ?? this.orgId,
      clientNumber: clientNumber ?? this.clientNumber,
      matterType: matterType ?? this.matterType,
      feeCapCents: feeCapCents ?? this.feeCapCents,
      accessLawyerIds: accessLawyerIds ?? this.accessLawyerIds,
      assigneeId: assigneeId ?? this.assigneeId,
      officeId: officeId ?? this.officeId,
      correspondentId: correspondentId ?? this.correspondentId,
      lawyerId: lawyerId ?? this.lawyerId,
      phase: phase ?? this.phase,
      opposingAttorneyId: opposingAttorneyId ?? this.opposingAttorneyId,
      opposingAttorneyName: opposingAttorneyName ?? this.opposingAttorneyName,
    );
  }

  // Helper getters
  /// Alias for [totalCost] — spend on FastCorr platform services.
  int get platformSpendCents => totalCost;

  /// Outstanding FastCorr platform spend not yet marked paid on the case.
  int get platformOutstandingCents => totalCost - paidAmount;

  /// @deprecated Use [platformOutstandingCents]. Kept for legacy callers.
  int get outstandingAmount => platformOutstandingCents;
  bool get isActive => status == CaseStatus.active;
  bool get isClosed => status == CaseStatus.closed;

  /// Check if the case phase should be updated based on incoming request phase
  /// Returns true if the request phase is higher than current case phase
  bool shouldUpdatePhase(int requestPhase) => requestPhase > phase;

  /// Get phase description for display purposes
  String get phaseDescription {
    switch (phase) {
      case 1:
        return 'Initial Filing';
      case 2:
        return 'Discovery';
      case 3:
        return 'Trial Preparation';
      case 4:
        return 'Trial';
      case 5:
        return 'Post-Trial';
      default:
        return 'Phase $phase';
    }
  }
}
