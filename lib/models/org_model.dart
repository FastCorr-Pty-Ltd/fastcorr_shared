import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum PaymentSystem { invoice, credits }

class OrgModel {
  final String regNumber;
  final String name;
  final String adminName;
  final String adminId;
  final PaymentSystem paymentSystem;
  final String address;
  final GeoPoint? location;
  final String? logoUrl;
  final Timestamp createdAt;
  final int? credits;

  OrgModel({
    required this.regNumber,
    required this.name,
    required this.address,
    this.logoUrl,
    this.location,
    this.credits,
    this.paymentSystem = PaymentSystem.credits,
    required this.createdAt,
    required this.adminName,
    required this.adminId,
  });

  factory OrgModel.fromJson(Map<String, dynamic> json) {
    return OrgModel(
      regNumber: json['regNumber'] as String,
      name: json['name'] as String,
      address: json['address'] ?? '',
      logoUrl: json['logoUrl'],
      credits: json['credits']?.toInt(),
      adminName: json['adminName'] as String,
      adminId: json['adminId'] as String,
      location: processedGeoPoint(json['location']),
      createdAt: processedTimestamp(json['createdAt'])!,
      paymentSystem: PaymentSystem.values.byName(
        json['paymentSystem'] ?? 'credits',
      ),
    );
  }

  factory OrgModel.fromSnapshot(DocumentSnapshot snap) {
    return OrgModel(
      regNumber: snap.id,
      name: snap['name'] as String,
      address: snap['address'] ?? '',
      adminName: snap['adminName'] as String,
      adminId: snap['adminId'] as String,
      location: processedGeoPoint(snap['location']),
      logoUrl: snap['logoUrl'],
      credits: snap['credits']?.toInt(),
      createdAt: processedTimestamp(snap['createdAt'])!,
      paymentSystem: PaymentSystem.values.byName(
        snap['paymentSystem'] ?? 'credits',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'regNumber': regNumber,
      'name': name,
      'address': address,
      'logoUrl': logoUrl,
      'credits': credits,
      'createdAt': createdAt,
      'adminName': adminName,
      'adminId': adminId,
      'location': location != null
          ? {'latitude': location!.latitude, 'longitude': location!.longitude}
          : null,
      'paymentSystem': paymentSystem.name,
    };
  }

  OrgModel copyWith({
    String? regNumber,
    String? name,
    String? address,
    String? logoUrl,
    String? adminName,
    String? adminId,
    GeoPoint? location,
    int? credits,
    Timestamp? createdAt,
    PaymentSystem? paymentSystem,
  }) {
    return OrgModel(
      regNumber: regNumber ?? this.regNumber,
      name: name ?? this.name,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      credits: credits ?? this.credits,
      adminName: adminName ?? this.adminName,
      adminId: adminId ?? this.adminId,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      paymentSystem: paymentSystem ?? this.paymentSystem,
    );
  }
}
