import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

/// Billing client of a law firm (organisation), stored under
/// `organisations/{orgId}/clients/{clientNumber}`.
enum OrgClientType { individual, company }

class OrgClientModel {
  /// Org-unique client number, e.g. `CNT001`. This IS the unique identifier
  /// for the client everywhere: UI, models, and the Firestore document id.
  final String clientNumber;
  final int clientNumberSeq;
  final String name;
  final OrgClientType clientType;
  final String? email;
  final String? phone;
  final String? address;
  /// Primary contact when [clientType] is [OrgClientType.company].
  final String? contactPerson;
  final String? vatNumber;
  final String? notes;
  /// Total invoiced to client (cents). Updated by accounting module.
  final int totalBilledCents;
  /// Total received from client (cents).
  final int totalPaidCents;
  final List<String> caseFileIds;
  final bool isActive;
  final String createdBy;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  OrgClientModel({
    required this.clientNumber,
    required this.clientNumberSeq,
    required this.name,
    this.clientType = OrgClientType.individual,
    this.email,
    this.phone,
    this.address,
    this.contactPerson,
    this.vatNumber,
    this.notes,
    this.totalBilledCents = 0,
    this.totalPaidCents = 0,
    this.caseFileIds = const [],
    this.isActive = true,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  int get balanceCents => totalBilledCents - totalPaidCents;
  int get caseCount => caseFileIds.length;

  /// Whether [value] looks like an org client number (`CNT001`, …).
  static bool isClientNumberFormat(String value) {
    return RegExp(r'^CNT\d+$').hasMatch(value.trim());
  }

  factory OrgClientModel.fromJson(Map<String, dynamic> json) {
    List<String> safeIds(dynamic raw) {
      if (raw == null || raw is! List) return [];
      return raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }

    int safeInt(dynamic v, {int fallback = 0}) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    return OrgClientModel(
      clientNumber: json['clientNumber'] as String? ?? '',
      clientNumberSeq: safeInt(json['clientNumberSeq'], fallback: 0),
      name: json['name'] as String? ?? '',
      clientType: OrgClientType.values.byName(
        json['clientType'] as String? ?? 'individual',
      ),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      contactPerson: json['contactPerson'] as String?,
      vatNumber: json['vatNumber'] as String?,
      notes: json['notes'] as String?,
      totalBilledCents: safeInt(json['totalBilledCents']),
      totalPaidCents: safeInt(json['totalPaidCents']),
      caseFileIds: safeIds(json['caseFileIds']),
      isActive: json['isActive'] as bool? ?? true,
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: processedTimestamp(json['createdAt'])!,
      updatedAt: json['updatedAt'] != null
          ? processedTimestamp(json['updatedAt'])
          : null,
    );
  }

  factory OrgClientModel.fromSnapshot(DocumentSnapshot snap) {
    final data = snap.data() as Map<String, dynamic>? ?? {};
    final stored = (data['clientNumber'] as String?)?.trim() ?? '';

    // Prefer the CNT number stored on the document. Legacy clients were created
    // with a UUID document id but still have clientNumber: CNT001 in the body.
    final clientNumber = isClientNumberFormat(stored)
        ? stored
        : isClientNumberFormat(snap.id)
            ? snap.id
            : stored.isNotEmpty
                ? stored
                : snap.id;

    return OrgClientModel.fromJson({
      ...data,
      'clientNumber': clientNumber,
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'clientNumber': clientNumber,
      'clientNumberSeq': clientNumberSeq,
      'name': name,
      'clientType': clientType.name,
      'email': email,
      'phone': phone,
      'address': address,
      'contactPerson': contactPerson,
      'vatNumber': vatNumber,
      'notes': notes,
      'totalBilledCents': totalBilledCents,
      'totalPaidCents': totalPaidCents,
      'caseFileIds': caseFileIds,
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  OrgClientModel copyWith({
    String? clientNumber,
    int? clientNumberSeq,
    String? name,
    OrgClientType? clientType,
    String? email,
    String? phone,
    String? address,
    String? contactPerson,
    String? vatNumber,
    String? notes,
    int? totalBilledCents,
    int? totalPaidCents,
    List<String>? caseFileIds,
    bool? isActive,
    String? createdBy,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return OrgClientModel(
      clientNumber: clientNumber ?? this.clientNumber,
      clientNumberSeq: clientNumberSeq ?? this.clientNumberSeq,
      name: name ?? this.name,
      clientType: clientType ?? this.clientType,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      contactPerson: contactPerson ?? this.contactPerson,
      vatNumber: vatNumber ?? this.vatNumber,
      notes: notes ?? this.notes,
      totalBilledCents: totalBilledCents ?? this.totalBilledCents,
      totalPaidCents: totalPaidCents ?? this.totalPaidCents,
      caseFileIds: caseFileIds ?? this.caseFileIds,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
