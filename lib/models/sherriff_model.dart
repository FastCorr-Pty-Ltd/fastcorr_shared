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
      sheriffName: cleanString(json['sheriffName']),
      magisterialDistrict: cleanString(json['magisterialDistrict']),
      address: cleanString(json['address']),
      postalAddress: cleanString(json['postalAddress']),
      officeLine: cleanString(json['officeLine']),
      cellNumber: cleanString(json['cellNumber']),
      emailAddress: cleanString(json['emailAddress']),
      province: cleanString(json['province']),
      postalCode: cleanString(json['postalCode']),
    );
  }

  factory SheriffModel.fromSnapshot(DocumentSnapshot snap) {
    return SheriffModel(
      sheriffId: snap.id,
      sheriffName: cleanString(snap['sheriffName']),
      magisterialDistrict: cleanString(snap['magisterialDistrict']),
      address: cleanString(snap['address']),
      postalAddress: cleanString(snap['postalAddress']),
      officeLine: cleanString(snap['officeLine']),
      cellNumber: cleanString(snap['cellNumber']),
      emailAddress: cleanString(snap['emailAddress']),
      province: cleanString(snap['province']),
      postalCode: cleanString(snap['postalCode']),
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
