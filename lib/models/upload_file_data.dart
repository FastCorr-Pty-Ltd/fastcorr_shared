import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum DocStatus { pending, returned, docOut }

class UploadFileData {
  final String fileName;
  final String? fileUrl, barcodeUrl;
  final String caseFileId, litNumber;
  final int? pages;
  final double? size;
  final String? fileId;
  final DocStatus? docStatus;
  final Timestamp? takenAt, returnedAt;

  const UploadFileData({
    required this.fileName,
    required this.caseFileId,
    required this.litNumber,
    this.pages,
    this.fileUrl,
    this.barcodeUrl,
    this.size,
    this.docStatus,
    this.fileId,
    this.takenAt,
    this.returnedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'fileUrl': fileUrl,
      'barcodeUrl': barcodeUrl,
      'caseFileId': caseFileId,
      'litNumber': litNumber,
      'pages': pages,
      'size': size,
      'fileId': fileId,
      'docStatus': docStatus?.name,
      'takenAt': takenAt?.toDate().toIso8601String(),
      'returnedAt': returnedAt?.toDate().toIso8601String(),
    };
  }

  factory UploadFileData.fromJson(Map<String, dynamic> json) {
    return UploadFileData(
      fileName: json['fileName'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      barcodeUrl: json['barcodeUrl'] ?? '',
      caseFileId: json['caseFileId'] ?? '',
      litNumber: json['litNumber'] ?? '',
      pages: json['pages'],
      size: json['size'],
      fileId: json['fileId'],
      docStatus: json['docStatus'] != null
          ? DocStatus.values.byName(json['docStatus'])
          : null,
      takenAt: json['takenAt'] != null
          ? processedTimestamp(json['takenAt'])
          : null,
      returnedAt: json['returnedAt'] != null
          ? processedTimestamp(json['returnedAt'])
          : null,
    );
  }

  factory UploadFileData.fromSnapshot(DocumentSnapshot snap) {
    return UploadFileData(
      fileName: snap['fileName']?.toString() ?? '',
      fileUrl: snap['fileUrl']?.toString() ?? '',
      barcodeUrl: snap['barcodeUrl']?.toString() ?? '',
      caseFileId: snap['caseFileId']?.toString() ?? '',
      litNumber: snap['litNumber']?.toString() ?? '',
      pages: snap['pages']?.toInt(),
      size: snap['size']?.toDouble(),
      fileId: snap['fileId']?.toString() ?? '',
      docStatus: snap['docStatus'] != null
          ? DocStatus.values.byName(snap['docStatus']?.toString() ?? '')
          : null,
      takenAt: snap['takenAt'] != null
          ? processedTimestamp(snap['takenAt'])
          : null,
      returnedAt: snap['returnedAt'] != null
          ? processedTimestamp(snap['returnedAt'])
          : null,
    );
  }
  UploadFileData copyWith({
    String? fileName,
    String? fileUrl,
    String? barcodeUrl,
    String? caseFileId,
    String? litNumber,
    int? pages,
    double? size,
    String? fileId,
    DocStatus? docStatus,
    List<String>? recipients,
    Timestamp? takenAt,
    Timestamp? returnedAt,
  }) {
    return UploadFileData(
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      barcodeUrl: barcodeUrl ?? this.barcodeUrl,
      caseFileId: caseFileId ?? this.caseFileId,
      litNumber: litNumber ?? this.litNumber,
      pages: pages ?? this.pages,
      size: size ?? this.size,
      fileId: fileId ?? this.fileId,
      docStatus: docStatus ?? this.docStatus,
      takenAt: takenAt ?? this.takenAt,
      returnedAt: returnedAt ?? this.returnedAt,
    );
  }
}
