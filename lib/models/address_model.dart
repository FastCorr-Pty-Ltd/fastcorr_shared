import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/models.dart';

import '../utils/utils.dart';

enum AddressStatus { pending, arrived, delivered, canceled }

class AddressModel {
  String? id;
  String contactId;
  AddressStatus? status;
  Timestamp? lastStatusUpdate, arrivedAt, deliveredAt, canceledAt;
  UploadFileData? instructionFile;
  GeoPoint? location;
  String? podSignatureUrl, podPhotoUrl;

  AddressModel({
    this.id,
    this.status,
    this.lastStatusUpdate,
    this.arrivedAt,
    this.deliveredAt,
    this.canceledAt,
    required this.contactId,
    this.instructionFile,
    this.location,
    this.podSignatureUrl,
    this.podPhotoUrl,
  });

  factory AddressModel.fromSnapshot(DocumentSnapshot snap) => AddressModel(
    id: snap['id'],
    contactId: snap['contactId'] ?? '',
    status: snap['status'] == null
        ? null
        : AddressStatus.values.byName(snap['status']),
    lastStatusUpdate: snap['lastStatusUpdate'] == null
        ? null
        : processedTimestamp(snap['lastStatusUpdate']),
    arrivedAt: snap['arrivedAt'] == null
        ? null
        : processedTimestamp(snap['arrivedAt']),
    deliveredAt: snap['deliveredAt'] == null
        ? null
        : processedTimestamp(snap['deliveredAt']),
    canceledAt: snap['canceledAt'] == null
        ? null
        : processedTimestamp(snap['canceledAt']),
    instructionFile: snap['instructionFile'] == null
        ? null
        : UploadFileData.fromSnapshot(snap['instructionFile']),
    location: snap['location'] == null
        ? null
        : processedGeoPoint(snap['location']),
    podSignatureUrl: snap['podSignatureUrl'] ?? '',
    podPhotoUrl: snap['podPhotoUrl'] ?? '',
  );

  factory AddressModel.fromJson(Map<String, dynamic> json) => AddressModel(
    id: json['id'],
    contactId: json['contactId'] ?? '',
    status: json['status'] == null
        ? null
        : AddressStatus.values.byName(json['status']),
    lastStatusUpdate: json['lastStatusUpdate'] == null
        ? null
        : processedTimestamp(json['lastStatusUpdate']),
    arrivedAt: json['arrivedAt'] == null
        ? null
        : processedTimestamp(json['arrivedAt']),
    deliveredAt: json['deliveredAt'] == null
        ? null
        : processedTimestamp(json['deliveredAt']),
    canceledAt: json['canceledAt'] == null
        ? null
        : processedTimestamp(json['canceledAt']),
    instructionFile: json['instructionFile'] == null
        ? null
        : UploadFileData.fromJson(json['instructionFile']),
    location: json['location'] == null
        ? null
        : processedGeoPoint(json['location']),
    podSignatureUrl: json['podSignatureUrl'] ?? '',
    podPhotoUrl: json['podPhotoUrl'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'contactId': contactId,
    'status': status?.name,
    'lastStatusUpdate': lastStatusUpdate,
    'arrivedAt': arrivedAt,
    'deliveredAt': deliveredAt,
    'canceledAt': canceledAt,
    'instructionFile': instructionFile?.toJson(),
    'location': location,
    'podSignatureUrl': podSignatureUrl,
    'podPhotoUrl': podPhotoUrl,
  };

  AddressModel copyWith({
    String? id,
    String? contactId,
    AddressStatus? status,
    Timestamp? lastStatusUpdate,
    Timestamp? arrivedAt,
    Timestamp? deliveredAt,
    Timestamp? canceledAt,
    UploadFileData? instructionFile,
    GeoPoint? location,
    String? podSignatureUrl,
    String? podPhotoUrl,
  }) {
    return AddressModel(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      status: status ?? this.status,
      lastStatusUpdate: lastStatusUpdate ?? this.lastStatusUpdate,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      canceledAt: canceledAt ?? this.canceledAt,
      instructionFile: instructionFile ?? this.instructionFile,
      location: location ?? this.location,
      podSignatureUrl: podSignatureUrl ?? this.podSignatureUrl,
      podPhotoUrl: podPhotoUrl ?? this.podPhotoUrl,
    );
  }
}
