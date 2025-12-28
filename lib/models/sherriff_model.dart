import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

class SheriffModel {
  String? sheriffId;
  String? name;
  String? contact;
  String? phone;
  String? address;
  String? email;
  List<String>? serviceAreas;

  SheriffModel({
    this.sheriffId,
    this.name,
    this.contact,
    this.phone,
    this.address,
    this.email,
    this.serviceAreas,
  });

  Map<String, dynamic> toJson() {
    return {
      'sheriffId': sheriffId,
      'name': name,
      'contact': contact,
      'phone': phone,
      'address': address,
      'email': email,
      'serviceAreas': serviceAreas,
    };
  }

  // Factory constructor to create a Sheriff object from a Map (JSON)
  factory SheriffModel.fromJson(Map<String, dynamic> json) {
    return SheriffModel(
      sheriffId: json['sheriffId'],
      name: cleanString(json['name']),
      contact: cleanString(json['contact']),
      phone: cleanString(json['phone']),
      address: cleanString(json['address']),
      email: cleanString(json['email']),
      serviceAreas: safeListFromJson(json['serviceAreas']),
    );
  }

  factory SheriffModel.fromSnapshot(DocumentSnapshot snap) {
    return SheriffModel(
      sheriffId: snap.id,
      name: cleanString(snap['name']),
      contact: cleanString(snap['contact']),
      phone: cleanString(snap['phone']),
      address: cleanString(snap['address']),
      email: cleanString(snap['email']),
      serviceAreas: safeListFromSnapshot(snap['serviceAreas']),
    );
  }

  SheriffModel copyWith({
    String? sheriffId,
    String? name,
    String? contact,
    String? phone,
    String? address,
    String? email,
    List<String>? serviceAreas,
  }) {
    return SheriffModel(
      sheriffId: sheriffId ?? this.sheriffId,
      name: name ?? this.name,
      contact: contact ?? this.contact,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      serviceAreas: serviceAreas ?? this.serviceAreas,
    );
  }
}
