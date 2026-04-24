import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fastcorr_shared/models/models.dart';
import 'package:fastcorr_shared/utils/utils.dart';

/// `OrderStatus` has been consolidated into [Status] (defined in
/// `request_model.dart`). The two enums had identical semantics for every
/// shared value; maintaining two copies led to drift and prevented a shared
/// state machine.
///
/// This typedef preserves backwards compatibility for all existing references
/// like `OrderStatus.pending`, `List<OrderStatus>`, and `OrderStatus.values`.
/// Call sites can migrate to `Status` at their convenience.
///
/// Note: `Status.values` now includes `Status.assigned`, which is reachable
/// only through the litigation flow. Messenger/delivery orders should never
/// land on `assigned` — the request state machine enforces this. Dropdowns
/// that iterate `.values` may want to filter it out per-flow.
typedef OrderStatus = Status;

/// Display-name extension for [OrderStatus] is provided via
/// [StatusDisplayExtension] in `request_model.dart` (now that `OrderStatus`
/// is a type alias for `Status`).

class OrderModel {
  final String orderId, serviceTitle;
  final String orgId, lawyerId;
  final String pickupAddress;
  final GeoPoint? pickupLocation;
  final String senderName, senderPhone, senderEmail;
  final Status status;
  final List<AddressModel> dropoffList;

  final String? instructions;
  final String? driverId, assigneeId;
  final bool selfService;

  /// Optional link to the matter for navigation (case comms live under this case).
  final String? caseFileId;

  /// Financial information (stored as cents/minor value)
  final int cost;
  final int driverFare;
  final String? transactionRef;
  final String? receiptId;

  /// Status tracking timestamps
  final DateTime? readyForPickupAt;
  final DateTime? completedAt;
  final DateTime? canceledAt;
  final DateTime? pickedupAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAtPickupAt;

  OrderModel({
    required this.orderId,
    required this.serviceTitle,
    required this.orgId,
    required this.lawyerId,
    required this.pickupAddress,
    required this.senderName,
    required this.senderPhone,
    required this.senderEmail,
    required this.status,
    required this.dropoffList,
    this.pickupLocation,
    this.instructions,
    this.driverId,
    this.assigneeId,
    this.readyForPickupAt,
    this.completedAt,
    this.canceledAt,
    this.pickedupAt,
    this.acceptedAt,
    this.arrivedAtPickupAt,
    required this.cost,
    required this.driverFare,
    this.transactionRef,
    this.receiptId,
    required this.selfService,
    this.caseFileId,
  });

  factory OrderModel.fromSnapshot(DocumentSnapshot snap) => OrderModel(
    orderId: snap['orderId'] ?? '',
    serviceTitle: snap['serviceTitle'] ?? '',
    orgId: snap['orgId'] ?? '',
    lawyerId: snap['lawyerId'] ?? '',
    pickupAddress: snap['pickupAddress'] ?? '',
    senderName: snap['senderName'] ?? '',
    senderPhone: snap['senderPhone'] ?? '',
    senderEmail: snap['senderEmail'] ?? '',
    status: _parseStatus(snap['status']),
    dropoffList: (snap['dropoffList']) == null
        ? []
        : (snap['dropoffList'] as List)
              .map((e) => AddressModel.fromJson(e))
              .toList(),
    pickupLocation: processedGeoPoint(snap['pickupLocation']),
    instructions: snap['instructions'] ?? '',
    driverId: snap['driverId'] ?? '',
    assigneeId: snap['assigneeId'] ?? '',
    readyForPickupAt: _parseTimestamp(snap['readyForPickupAt']),
    completedAt: _parseTimestamp(snap['completedAt']),
    canceledAt: _parseTimestamp(snap['canceledAt']),
    pickedupAt: _parseTimestamp(snap['pickedupAt']),
    acceptedAt: _parseTimestamp(snap['acceptedAt']),
    arrivedAtPickupAt: _parseTimestamp(snap['arrivedAtPickupAt']),
    cost: snap['cost']?.toInt() ?? 0,
    driverFare: snap['driverFare']?.toInt() ?? 0,
    transactionRef: snap['transactionRef'] ?? '',
    receiptId: snap['receiptId'] ?? '',
    selfService: snap['selfService'] ?? false,
    caseFileId: _parseOptionalId(snap['caseFileId']),
  );

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
    orderId: json['orderId'] ?? '',
    serviceTitle: json['serviceTitle'] ?? '',
    orgId: json['orgId'] ?? '',
    lawyerId: json['lawyerId'] ?? '',
    pickupAddress: json['pickupAddress'] ?? '',
    senderName: json['senderName'] ?? '',
    senderPhone: json['senderPhone'] ?? '',
    senderEmail: json['senderEmail'] ?? '',
    status: _parseStatus(json['status']),
    dropoffList: (json['dropoffList']) == null
        ? []
        : (json['dropoffList'] as List)
              .map((e) => AddressModel.fromJson(e))
              .toList(),
    pickupLocation: processedGeoPoint(json['pickupLocation']),
    instructions: json['instructions'] ?? '',
    driverId: json['driverId'] ?? '',
    assigneeId: json['assigneeId'] ?? '',
    readyForPickupAt: _parseTimestamp(json['readyForPickupAt']),
    completedAt: _parseTimestamp(json['completedAt']),
    canceledAt: _parseTimestamp(json['canceledAt']),
    pickedupAt: _parseTimestamp(json['pickedupAt']),
    acceptedAt: _parseTimestamp(json['acceptedAt']),
    arrivedAtPickupAt: _parseTimestamp(json['arrivedAtPickupAt']),
    cost: json['cost']?.toInt() ?? 0,
    driverFare: json['driverFare']?.toInt() ?? 0,
    transactionRef: json['transactionRef'] ?? '',
    receiptId: json['receiptId'] ?? '',
    selfService: json['selfService'] ?? false,
    caseFileId: _parseOptionalId(json['caseFileId']),
  );

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'serviceTitle': serviceTitle,
      'orgId': orgId,
      'lawyerId': lawyerId,
      'pickupAddress': pickupAddress,
      'senderName': senderName,
      'senderPhone': senderPhone,
      'senderEmail': senderEmail,
      'status': status.name,
      'dropoffList': dropoffList.map((e) => e.toJson()).toList(),
      'pickupLocation': pickupLocation,
      'instructions': instructions,
      'driverId': driverId,
      'assigneeId': assigneeId,
      'readyForPickupAt': readyForPickupAt != null
          ? Timestamp.fromDate(readyForPickupAt!)
          : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'canceledAt': canceledAt != null ? Timestamp.fromDate(canceledAt!) : null,
      'pickedupAt': pickedupAt != null ? Timestamp.fromDate(pickedupAt!) : null,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'arrivedAtPickupAt': arrivedAtPickupAt != null
          ? Timestamp.fromDate(arrivedAtPickupAt!)
          : null,
      'cost': cost,
      'driverFare': driverFare,
      'transactionRef': transactionRef,
      'receiptId': receiptId,
      'selfService': selfService,
      if (caseFileId != null && caseFileId!.isNotEmpty) 'caseFileId': caseFileId,
    };
  }

  OrderModel copyWith({
    String? orderId,
    String? serviceTitle,
    String? orgId,
    String? lawyerId,
    String? pickupAddress,
    String? senderName,
    String? senderPhone,
    String? senderEmail,
    List<AddressModel>? dropoffList,
    GeoPoint? pickupLocation,
    String? instructions,
    String? driverId,
    String? assigneeId,
    DateTime? readyForPickupAt,
    DateTime? completedAt,
    DateTime? canceledAt,
    DateTime? pickedupAt,
    DateTime? acceptedAt,
    DateTime? arrivedAtPickupAt,
    int? cost,
    int? driverFare,
    Status? status,
    String? transactionRef,
    String? receiptId,
    bool? selfService,
    String? caseFileId,
  }) => OrderModel(
    orderId: orderId ?? this.orderId,
    serviceTitle: serviceTitle ?? this.serviceTitle,
    orgId: orgId ?? this.orgId,
    lawyerId: lawyerId ?? this.lawyerId,
    pickupAddress: pickupAddress ?? this.pickupAddress,
    senderName: senderName ?? this.senderName,
    senderPhone: senderPhone ?? this.senderPhone,
    senderEmail: senderEmail ?? this.senderEmail,
    dropoffList: dropoffList ?? this.dropoffList,
    pickupLocation: pickupLocation ?? this.pickupLocation,
    instructions: instructions ?? this.instructions,
    driverId: driverId ?? this.driverId,
    assigneeId: assigneeId ?? this.assigneeId,
    readyForPickupAt: readyForPickupAt ?? this.readyForPickupAt,
    completedAt: completedAt ?? this.completedAt,
    canceledAt: canceledAt ?? this.canceledAt,
    pickedupAt: pickedupAt ?? this.pickedupAt,
    acceptedAt: acceptedAt ?? this.acceptedAt,
    arrivedAtPickupAt: arrivedAtPickupAt ?? this.arrivedAtPickupAt,
    cost: cost ?? this.cost,
    driverFare: driverFare ?? this.driverFare,
    status: status ?? this.status,
    transactionRef: transactionRef ?? this.transactionRef,
    receiptId: receiptId ?? this.receiptId,
    selfService: selfService ?? this.selfService,
    caseFileId: caseFileId ?? this.caseFileId,
  );

  /// Get the most recent status change timestamp
  DateTime? get lastStatusChangeAt {
    final timestamps = [
      readyForPickupAt,
      acceptedAt,
      arrivedAtPickupAt,
      pickedupAt,
      completedAt,
      canceledAt,
    ].where((timestamp) => timestamp != null).cast<DateTime>().toList();

    if (timestamps.isEmpty) return null;

    // Return the most recent timestamp
    timestamps.sort((a, b) => b.compareTo(a));
    return timestamps.first;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    } else if (value is String) {
      return DateTime.parse(value);
    } else if (value is DateTime) {
      return value;
    } else {
      return null;
    }
  }

  /// Never-throwing status parser. An unknown / missing / corrupt status
  /// falls back to [Status.pending]. The previous implementation used
  /// `Status.values.byName(snap['status'])` which would throw and poison
  /// entire streams on a single bad document.
  static String? _parseOptionalId(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static Status _parseStatus(dynamic value) {
    if (value == null) return Status.pending;
    if (value is Status) return value;
    if (value is String) {
      for (final s in Status.values) {
        if (s.name == value) return s;
      }
    }
    return Status.pending;
  }
}
