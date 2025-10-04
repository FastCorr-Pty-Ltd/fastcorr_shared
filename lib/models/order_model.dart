import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fastcorr_shared/models/models.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum OrderStatus {
  pending,
  inProgress,
  completed,
  readyForPickup,
  pickedup,
  canceled,
  accepted,
  arrivedAtPickup,
  rejected,
  overdue,
  escalated,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.inProgress:
        return 'In Progress';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.readyForPickup:
        return 'Ready for Pickup';
      case OrderStatus.pickedup:
        return 'Picked Up';
      case OrderStatus.canceled:
        return 'Canceled';
      case OrderStatus.accepted:
        return 'Accepted';
      case OrderStatus.arrivedAtPickup:
        return 'Arrived at Pickup';
      case OrderStatus.rejected:
        return 'Rejected';
      case OrderStatus.overdue:
        return 'Overdue';
      case OrderStatus.escalated:
        return 'Escalated';
    }
  }
}

class OrderModel {
  final String orderId, serviceTitle;
  final String orgId, lawyerId;
  final String pickupAddress;
  final GeoPoint? pickupLocation;
  final String senderName, senderPhone, senderEmail;
  final OrderStatus status;
  final List<AddressModel> dropoffList;

  final String? instructions;
  final String? driverId, assigneeId;
  final bool selfService;

  /// Financial information
  final double cost;
  final double driverFare;
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
    status: OrderStatus.values.byName(snap['status']),
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
    cost: snap['cost']?.toDouble() ?? 0,
    driverFare: snap['driverFare']?.toDouble() ?? 0,
    transactionRef: snap['transactionRef'] ?? '',
    receiptId: snap['receiptId'] ?? '',
    selfService: snap['selfService'] ?? false,
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
    status: OrderStatus.values.byName(json['status']),
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
    cost: json['cost']?.toDouble() ?? 0,
    driverFare: json['driverFare']?.toDouble() ?? 0,
    transactionRef: json['transactionRef'] ?? '',
    receiptId: json['receiptId'] ?? '',
    selfService: json['selfService'] ?? false,
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
      'status': status.toString().split('.').last,
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
    double? cost,
    double? driverFare,
    OrderStatus? status,
    String? transactionRef,
    String? receiptId,
    bool? selfService,
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
}
