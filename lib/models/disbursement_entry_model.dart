import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/fee_entry_model.dart';
import 'package:fastcorr_shared/utils/utils.dart';

/// Manually captured recoverable cost (court fee, sheriff, etc.) linked to a
/// case file. Stored under `organisations/{orgId}/disbursement_entries`.
///
/// FastCorr litigation disbursements are auto-invoiced per request; this
/// model covers everything else the firm bills on to the client.
class DisbursementEntryModel {
  const DisbursementEntryModel({
    required this.entryId,
    required this.orgId,
    required this.caseFileId,
    required this.litNumber,
    required this.caseName,
    this.clientNumber,
    required this.recordedById,
    required this.recordedByName,
    required this.description,
    required this.amountCents,
    required this.expenseDate,
    this.vendorReference,
    this.status = FeeEntryStatus.wip,
    this.invoicedInvoiceNumber,
    required this.createdAt,
  });

  final String entryId;
  final String orgId;
  final String caseFileId;
  final String litNumber;
  final String caseName;
  final String? clientNumber;

  final String recordedById;
  final String recordedByName;

  final String description;
  final int amountCents;

  /// When the expense was incurred.
  final Timestamp expenseDate;

  /// Optional receipt / reference from the vendor.
  final String? vendorReference;

  final FeeEntryStatus status;
  final String? invoicedInvoiceNumber;
  final Timestamp createdAt;

  factory DisbursementEntryModel.fromJson(Map<String, dynamic> json) {
    return DisbursementEntryModel(
      entryId: json['entryId'] as String? ?? '',
      orgId: json['orgId'] as String? ?? '',
      caseFileId: json['caseFileId'] as String? ?? '',
      litNumber: json['litNumber'] as String? ?? '',
      caseName: json['caseName'] as String? ?? '',
      clientNumber: json['clientNumber'] as String?,
      recordedById: json['recordedById'] as String? ?? '',
      recordedByName: json['recordedByName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      expenseDate:
          processedTimestamp(json['expenseDate']) ?? Timestamp.now(),
      vendorReference: json['vendorReference'] as String?,
      status: FeeEntryStatus.values.byName(
        json['status'] as String? ?? 'wip',
      ),
      invoicedInvoiceNumber: json['invoicedInvoiceNumber'] as String?,
      createdAt: processedTimestamp(json['createdAt']) ?? Timestamp.now(),
    );
  }

  factory DisbursementEntryModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    return DisbursementEntryModel.fromJson({
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
      'recordedById': recordedById,
      'recordedByName': recordedByName,
      'description': description,
      'amountCents': amountCents,
      'expenseDate': expenseDate,
      'vendorReference': vendorReference,
      'status': status.name,
      'invoicedInvoiceNumber': invoicedInvoiceNumber,
      'createdAt': createdAt,
    };
  }
}
