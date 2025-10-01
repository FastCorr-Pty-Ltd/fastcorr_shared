import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

class OrgModel {
  final String regNumber;
  final String name;
  final String address;
  final GeoPoint? location;
  final String? logoUrl;
  final Timestamp createdAt;
  final double? credits;

  OrgModel({
    required this.regNumber,
    required this.name,
    required this.address,
    this.logoUrl,
    this.location,
    this.credits,
    required this.createdAt,
  });

  factory OrgModel.fromJson(Map<String, dynamic> json) {
    return OrgModel(
      regNumber: json['regNumber'] as String,
      name: json['name'] as String,
      address: json['address'],
      logoUrl: json['logoUrl'],
      credits: json['credits']?.toDouble(),
      location: processedGeoPoint(json['location']),
      createdAt: processedTimestamp(json['createdAt'])!,
    );
  }

  factory OrgModel.fromSnapshot(DocumentSnapshot snap) {
    return OrgModel(
      regNumber: snap.id,
      name: snap['regNumber'] as String,
      address: snap['address'],
      location: snap['location'],
      logoUrl: snap['logoUrl'],
      credits: snap['credits']?.toDouble(),
      createdAt: snap['createdAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'regNumber': regNumber,
      'name': name,
      'address': address,
      'logoUrl': logoUrl,
      'credits': credits,
      // Convert the Timestamp to a JSON-friendly ISO 8601 string
      'createdAt': createdAt.toDate().toIso8601String(),
      // Convert the GeoPoint object to a simple Map
      'location': location != null
          ? {'latitude': location!.latitude, 'longitude': location!.longitude}
          : null,
    };
  }

  OrgModel copyWith({
    String? regNumber,
    String? name,
    String? address,
    String? logoUrl,
    GeoPoint? location,
    double? credits,
    Timestamp? createdAt,
  }) {
    return OrgModel(
      regNumber: regNumber ?? this.regNumber,
      name: name ?? this.name,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      credits: credits ?? this.credits,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
