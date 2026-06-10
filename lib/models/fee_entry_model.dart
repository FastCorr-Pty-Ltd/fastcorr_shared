import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

/// How a professional fee was captured.
enum FeeEntryKind {
  /// Billed by time: [units] × [rateCents].
  time,

  /// Single fixed / unitary amount.
  fixedFee,
}

/// Lifecycle of a captured fee line (WIP until invoiced).
enum FeeEntryStatus { wip, invoiced }

/// Unbilled professional fee linked to a case file via LitNumber.
/// Stored under `organisations/{orgId}/fee_entries/{entryId}`.
class FeeEntryModel {
  const FeeEntryModel({
    required this.entryId,
    required this.orgId,
    required this.caseFileId,
    required this.litNumber,
    required this.caseName,
    this.clientNumber,
    required this.feeEarnerId,
    required this.feeEarnerName,
    required this.createdBy,
    required this.description,
    required this.kind,
    required this.amountCents,
    this.units,
    this.rateCents,
    required this.activityDate,
    this.status = FeeEntryStatus.wip,
    required this.createdAt,
  });

  final String entryId;
  final String orgId;
  final String caseFileId;
  final String litNumber;
  final String caseName;
  final String? clientNumber;

  /// Lawyer who performed the work (usually the logged-in user).
  final String feeEarnerId;
  final String feeEarnerName;
  final String createdBy;

  final String description;
  final FeeEntryKind kind;
  final int amountCents;

  /// Hours (or units) when [kind] is [FeeEntryKind.time].
  final double? units;

  /// Rate per unit in cents when [kind] is [FeeEntryKind.time].
  final int? rateCents;

  final Timestamp activityDate;
  final FeeEntryStatus status;
  final Timestamp createdAt;

  factory FeeEntryModel.fromJson(Map<String, dynamic> json) {
    return FeeEntryModel(
      entryId: json['entryId'] as String? ?? '',
      orgId: json['orgId'] as String? ?? '',
      caseFileId: json['caseFileId'] as String? ?? '',
      litNumber: json['litNumber'] as String? ?? '',
      caseName: json['caseName'] as String? ?? '',
      clientNumber: json['clientNumber'] as String?,
      feeEarnerId: json['feeEarnerId'] as String? ?? '',
      feeEarnerName: json['feeEarnerName'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      description: json['description'] as String? ?? '',
      kind: FeeEntryKind.values.byName(
        json['kind'] as String? ?? 'fixedFee',
      ),
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      units: json['units'] == null ? null : (json['units'] as num).toDouble(),
      rateCents: json['rateCents'] == null
          ? null
          : (json['rateCents'] as num).toInt(),
      activityDate:
          processedTimestamp(json['activityDate']) ?? Timestamp.now(),
      status: FeeEntryStatus.values.byName(
        json['status'] as String? ?? 'wip',
      ),
      createdAt: processedTimestamp(json['createdAt']) ?? Timestamp.now(),
    );
  }

  factory FeeEntryModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return FeeEntryModel.fromJson({
      ...data,
      'entryId': snap.id,
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'entryId': entryId,
      'orgId': orgId,
      'caseFileId': caseFileId,
      'litNumber': litNumber,
      'caseName': caseName,
      'clientNumber': clientNumber,
      'feeEarnerId': feeEarnerId,
      'feeEarnerName': feeEarnerName,
      'createdBy': createdBy,
      'description': description,
      'kind': kind.name,
      'amountCents': amountCents,
      'units': units,
      'rateCents': rateCents,
      'activityDate': activityDate,
      'status': status.name,
      'createdAt': createdAt,
    };
  }
}
