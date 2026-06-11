import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

/// Lifecycle of a client invoice.
enum InvoiceStatus { draft, issued, paid, overdue }

/// Kind of billable line on a client invoice.
enum InvoiceLineKind {
  /// Professional fee recorded by a lawyer (time, fixed fee, tariff item).
  fee,

  /// Recoverable cost. FastCorr litigation requests land here automatically.
  disbursement,
}

/// One billable line on a [ClientInvoiceModel].
class InvoiceLineModel {
  const InvoiceLineModel({
    required this.lineId,
    required this.kind,
    required this.description,
    required this.amountCents,
    required this.lawyerId,
    required this.createdAt,
    this.requestId,
    this.receiptId,
  });

  final String lineId;
  final InvoiceLineKind kind;
  final String description;
  final int amountCents;

  /// Lawyer who incurred the fee/disbursement.
  final String lawyerId;
  final Timestamp createdAt;

  /// FastCorr litigation order id when this line was auto-added for a request.
  final String? requestId;
  final String? receiptId;

  factory InvoiceLineModel.fromJson(Map<String, dynamic> json) {
    return InvoiceLineModel(
      lineId: json['lineId'] as String? ?? '',
      kind: InvoiceLineKind.values.byName(
        json['kind'] as String? ?? 'disbursement',
      ),
      description: json['description'] as String? ?? '',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      lawyerId: json['lawyerId'] as String? ?? '',
      createdAt: processedTimestamp(json['createdAt']) ?? Timestamp.now(),
      requestId: json['requestId'] as String?,
      receiptId: json['receiptId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lineId': lineId,
      'kind': kind.name,
      'description': description,
      'amountCents': amountCents,
      'lawyerId': lawyerId,
      'createdAt': createdAt,
      'requestId': requestId,
      'receiptId': receiptId,
    };
  }
}

/// Invoice issued by an organisation to one of its billing clients, stored
/// under `organisations/{orgId}/invoices/{invoiceNumber}`.
///
/// Each billed action (e.g. a paid FastCorr litigation request) creates its
/// own invoice. A case file may have many invoices; [CaseModel.invoiceIds]
/// tracks them all.
class ClientInvoiceModel {
  const ClientInvoiceModel({
    required this.invoiceNumber,
    required this.clientNumber,
    required this.clientName,
    required this.caseFileId,
    required this.litNumber,
    required this.caseName,
    required this.orgId,
    required this.createdBy,
    this.account = 'business',
    this.status = InvoiceStatus.draft,
    this.lines = const [],
    this.subtotalCents,
    this.vatCents,
    this.totalCents = 0,
    this.vatRate = 0.15,
    required this.createdAt,
    this.updatedAt,
    this.dueAt,
    this.sourceRequestId,
  });

  /// Unique identifier and Firestore document id, e.g. `INV-LTGN1234567`.
  final String invoiceNumber;

  /// Billing client this invoice belongs to (their unique client number).
  final String clientNumber;
  final String clientName;

  // Case file context.
  final String caseFileId;
  final String litNumber;
  final String caseName;

  final String orgId;

  /// Lawyer who recorded or triggered this billed action.
  final String createdBy;

  /// Litigation order id when this invoice was auto-created for a request.
  final String? sourceRequestId;

  /// `business` or `trust`.
  final String account;
  final InvoiceStatus status;
  final List<InvoiceLineModel> lines;

  /// Sum of [lines] before VAT (ex-VAT).
  final int? subtotalCents;

  /// VAT amount in cents.
  final int? vatCents;

  /// Grand total (subtotal + VAT), denormalised for list views.
  final int totalCents;

  /// VAT rate applied when the invoice was issued (default 15%).
  final double vatRate;

  final Timestamp createdAt;
  final Timestamp? updatedAt;
  final Timestamp? dueAt;

  List<InvoiceLineModel> get disbursements =>
      lines.where((l) => l.kind == InvoiceLineKind.disbursement).toList();

  List<InvoiceLineModel> get fees =>
      lines.where((l) => l.kind == InvoiceLineKind.fee).toList();

  bool get isOutstanding =>
      status == InvoiceStatus.issued || status == InvoiceStatus.overdue;

  /// Line sum; falls back to [subtotalCents] or [totalCents] for legacy docs.
  int get effectiveSubtotalCents {
    if (subtotalCents != null) return subtotalCents!;
    if (lines.isNotEmpty) {
      return lines.fold(0, (sum, l) => sum + l.amountCents);
    }
    return totalCents;
  }

  int get effectiveVatCents => vatCents ?? 0;

  int get effectiveGrandTotalCents =>
      subtotalCents != null && vatCents != null
          ? totalCents
          : effectiveSubtotalCents + effectiveVatCents;

  factory ClientInvoiceModel.fromJson(Map<String, dynamic> json) {
    List<InvoiceLineModel> safeLines(dynamic raw) {
      if (raw == null || raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => InvoiceLineModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return ClientInvoiceModel(
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      clientNumber: json['clientNumber'] as String? ?? '',
      clientName: json['clientName'] as String? ?? '',
      caseFileId: json['caseFileId'] as String? ?? '',
      litNumber: json['litNumber'] as String? ?? '',
      caseName: json['caseName'] as String? ?? '',
      orgId: json['orgId'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      sourceRequestId: json['sourceRequestId'] as String?,
      account: json['account'] as String? ?? 'business',
      status: InvoiceStatus.values.byName(
        json['status'] as String? ?? 'draft',
      ),
      lines: safeLines(json['lines']),
      subtotalCents: (json['subtotalCents'] as num?)?.toInt(),
      vatCents: (json['vatCents'] as num?)?.toInt(),
      totalCents: (json['totalCents'] as num?)?.toInt() ?? 0,
      vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.15,
      createdAt: processedTimestamp(json['createdAt']) ?? Timestamp.now(),
      updatedAt: json['updatedAt'] != null
          ? processedTimestamp(json['updatedAt'])
          : null,
      dueAt: json['dueAt'] != null ? processedTimestamp(json['dueAt']) : null,
    );
  }

  factory ClientInvoiceModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    // The document id is the invoice number.
    return ClientInvoiceModel.fromJson({
      ...data,
      'invoiceNumber': snap.id,
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'invoiceNumber': invoiceNumber,
      'clientNumber': clientNumber,
      'clientName': clientName,
      'caseFileId': caseFileId,
      'litNumber': litNumber,
      'caseName': caseName,
      'orgId': orgId,
      'createdBy': createdBy,
      'sourceRequestId': sourceRequestId,
      'account': account,
      'status': status.name,
      'lines': lines.map((l) => l.toJson()).toList(),
      'subtotalCents': subtotalCents,
      'vatCents': vatCents,
      'totalCents': totalCents,
      'vatRate': vatRate,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'dueAt': dueAt,
    };
  }
}
