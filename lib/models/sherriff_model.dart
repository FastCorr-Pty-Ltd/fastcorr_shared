import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

class SheriffModel {
  final String? sheriffId;
  final String? sheriffName;
  final String? magisterialDistrict;
  final String? address;
  final String? postalAddress;
  final String? officeLine;
  final String? cellNumber;
  final String? emailAddress;
  final String? province;
  final String? postalCode;

  SheriffModel({
    this.sheriffId,
    this.sheriffName,
    this.magisterialDistrict,
    this.address,
    this.postalAddress,
    this.officeLine,
    this.cellNumber,
    this.emailAddress,
    this.province,
    this.postalCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'sheriffId': sheriffId,
      'sheriffName': sheriffName,
      'magisterialDistrict': magisterialDistrict,
      'address': address,
      'postalAddress': postalAddress,
      'officeLine': officeLine,
      'cellNumber': cellNumber,
      'emailAddress': emailAddress,
      'province': province,
      'postalCode': postalCode,
    };
  }

  // Factory constructor to create a Sheriff object from a Map (JSON)
  factory SheriffModel.fromJson(Map<String, dynamic> json) {
    return SheriffModel(
      sheriffId: json['sheriffId'],
      sheriffName: cleanString(json['Sheriff Name']),
      magisterialDistrict: cleanString(json['Magisterial District (HL)']),
      address: cleanString(json['Address']),
      postalAddress: cleanString(json['Postal Address']),
      officeLine: cleanString(json['Office Line 1']),
      cellNumber: cleanString(json['Cell Number']),
      emailAddress: cleanString(json['Email Address']),
      province: cleanString(json['Province']),
      postalCode: cleanString(json['Postal Code']),
    );
  }

  factory SheriffModel.fromSnapshot(DocumentSnapshot snap) {
    return SheriffModel(
      sheriffId: snap.id,
      sheriffName: cleanString(snap['Sheriff Name']),
      magisterialDistrict: cleanString(snap['Magisterial District (HL)']),
      address: cleanString(snap['Address']),
      postalAddress: cleanString(snap['Postal Address']),
      officeLine: cleanString(snap['Office Line 1']),
      cellNumber: cleanString(snap['Cell Number']),
      emailAddress: cleanString(snap['Email Address']),
      province: cleanString(snap['Province']),
      postalCode: cleanString(snap['Postal Code']),
    );
  }

  SheriffModel copyWith({
    String? sheriffId,
    String? sheriffName,
    String? magisterialDistrict,
    String? address,
    String? postalAddress,
    String? officeLine,
    String? cellNumber,
    String? emailAddress,
    String? province,
    String? postalCode,
  }) {
    return SheriffModel(
      sheriffId: sheriffId ?? this.sheriffId,
      sheriffName: sheriffName ?? this.sheriffName,
      magisterialDistrict: magisterialDistrict ?? this.magisterialDistrict,
      address: address ?? this.address,
      postalAddress: postalAddress ?? this.postalAddress,
      officeLine: officeLine ?? this.officeLine,
      cellNumber: cellNumber ?? this.cellNumber,
      emailAddress: emailAddress ?? this.emailAddress,
      province: province ?? this.province,
      postalCode: postalCode ?? this.postalCode,
    );
  }
}
