import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum QrAction { pending, pickedUp, delivered, returned }

class QrModel {
  final String fileId;
  final String fileName;
  final QrAction? action;
  final String orderId, litNumber, serviceName;
  final Timestamp uploadedAt;
  final Timestamp? pickedUpAt;
  final Timestamp? deliveredAt;
  final String? driverId, driverName;

  QrModel({
    required this.fileId,
    required this.fileName,
    required this.orderId,
    required this.litNumber,
    required this.serviceName,
    required this.uploadedAt,
    this.action,
    this.pickedUpAt,
    this.deliveredAt,
    this.driverId,
    this.driverName,
  });

  Map<String, dynamic> toJson() {
    return {
      'fileId': fileId,
      'fileName': fileName,
      'orderId': orderId,
      'litNumber': litNumber,
      'serviceName': serviceName,
      'uploadedAt': uploadedAt,
      'pickedUpAt': pickedUpAt,
      'deliveredAt': deliveredAt,
      'driverId': driverId,
      'driverName': driverName,
      'action': action?.name,
    };
  }

  factory QrModel.fromJson(Map<String, dynamic> json) {
    return QrModel(
      fileId: json['fileId'],
      fileName: json['fileName'],
      orderId: json['orderId'],
      litNumber: json['litNumber'],
      serviceName: json['serviceName'],
      uploadedAt: processedTimestamp(json['uploadedAt'])!,
      pickedUpAt: processedTimestamp(json['pickedUpAt']),
      deliveredAt: processedTimestamp(json['deliveredAt']),
      driverId: json['driverId'],
      driverName: json['driverName'],
      action: json['action'] != null
          ? QrAction.values.byName(json['action'])
          : null,
    );
  }

  factory QrModel.fromSnapshot(DocumentSnapshot snap) {
    return QrModel(
      fileId: snap['fileId'],
      fileName: snap['fileName'],
      orderId: snap['orderId'],
      litNumber: snap['litNumber'],
      serviceName: snap['serviceName'],
      uploadedAt: processedTimestamp(snap['uploadedAt'])!,
      pickedUpAt: processedTimestamp(snap['pickedUpAt']),
      deliveredAt: processedTimestamp(snap['deliveredAt']),
      driverId: snap['driverId'],
      driverName: snap['driverName'],
      action: snap['action'] != null
          ? QrAction.values.byName(snap['action'])
          : null,
    );
  }
}
