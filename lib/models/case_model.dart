import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum CaseStatus { active, closed, pending, onHold }

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

  final CaseStatus status;
  final String? judge;

  final String? courtId;
  final String? caseType; // civil, criminal, etc.
  final String? assigneeId;
  final String? correspondentId;
  final String? opposingAttorneyId;
  final String? opposingAttorneyName;

  // Financial tracking
  final int totalCost;
  final int paidAmount;
  final int capitalAmount;
  final String scale;

  // Event tracking
  final List<String> courtDateIds;
  final List<String> requestIds;
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
    this.paidAmount = 0,
    this.courtDateIds = const [],
    this.requestIds = const [],
    this.returnTaskIds = const [],
    this.instructionIds,
    this.followupDocIds,
    this.receiptIds,
    required this.orgId,
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
      paidAmount: safeToInt(json['paidAmount']),
      capitalAmount: safeToInt(json['capitalAmount']),
      scale: json['scale'] ?? '',
      courtDateIds: safeListFromJson(json['courtDateIds']),
      requestIds: safeListFromJson(json['requestIds']),
      receiptIds: safeListFromJson(json['receiptIds']),
      returnTaskIds: safeListFromJson(json['returnTaskIds']),
      instructionIds: safeListFromJson(json['instructionIds']),
      followupDocIds: safeListFromJson(json['followupDocIds']),
      orgId: json['orgId'] ?? '',
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
      paidAmount: safeToInt(snapshot['paidAmount']),
      capitalAmount: safeToInt(snapshot['capitalAmount']),
      scale: snapshot['scale'] ?? '',
      courtDateIds: safeListFromSnapshot(snapshot['courtDateIds']),
      requestIds: safeListFromSnapshot(snapshot['requestIds']),
      receiptIds: safeListFromSnapshot(snapshot['receiptIds']),
      returnTaskIds: safeListFromSnapshot(snapshot['returnTaskIds']),
      instructionIds: safeListFromSnapshot(snapshot['instructionIds']),
      followupDocIds: safeListFromSnapshot(snapshot['followupDocIds']),
      orgId: snapshot['orgId'] ?? '',
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
      'paidAmount': paidAmount,
      'capitalAmount': capitalAmount,
      'scale': scale,
      'returnTaskIds': safeListToJson(returnTaskIds),
      'instructionIds': safeListToJson(instructionIds),
      'followupDocIds': safeListToJson(followupDocIds),
      'courtDateIds': safeListToJson(courtDateIds),
      'requestIds': safeListToJson(requestIds),
      'receiptIds': safeListToJson(receiptIds),
      'orgId': orgId,
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
    int? paidAmount,
    int? capitalAmount,
    String? scale,
    List<String>? eventIds,
    List<String>? courtDateIds,
    List<String>? requestIds,
    List<String>? receiptIds,
    List<String>? returnTaskIds,
    List<String>? instructionIds,
    List<String>? followupDocIds,
    String? orgId,
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
      paidAmount: paidAmount ?? this.paidAmount,
      courtDateIds: courtDateIds ?? this.courtDateIds,
      requestIds: requestIds ?? this.requestIds,
      receiptIds: receiptIds ?? this.receiptIds,
      orgId: orgId ?? this.orgId,
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
  int get outstandingAmount => totalCost - paidAmount;
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
