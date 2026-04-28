import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/models.dart';
import 'package:flutter/material.dart';

enum Priority { urgent, standard }

enum ActionType {
  serve,
  serveAndFile,
  issue,
  issueAndServe,
  courtAppearance,
  other,
}

enum Status {
  pending,
  inProgress,
  completed,
  readyForPickup,
  pickedup,
  assigned,
  canceled,
  accepted,
  arrivedAtPickup,
  rejected,
  overdue,
  escalated,

  /// Lawyer requested cancellation; awaits office approval before final cancel/refund.
  cancelPending,
}

/// Human-readable label for each [Status].
///
/// Consolidated here from the old `OrderStatusExtension` in `order_model.dart`.
/// With `OrderStatus` now being an alias of `Status`, this extension is the
/// single source of truth for displaying any request/order status.
extension StatusDisplayExtension on Status {
  String get displayName {
    switch (this) {
      case Status.pending:
        return 'Pending';
      case Status.inProgress:
        return 'In Progress';
      case Status.completed:
        return 'Completed';
      case Status.readyForPickup:
        return 'Ready for Pickup';
      case Status.pickedup:
        return 'Picked Up';
      case Status.assigned:
        return 'Assigned';
      case Status.canceled:
        return 'Canceled';
      case Status.accepted:
        return 'Accepted';
      case Status.arrivedAtPickup:
        return 'Arrived at Pickup';
      case Status.rejected:
        return 'Rejected';
      case Status.overdue:
        return 'Overdue';
      case Status.escalated:
        return 'Escalated';
      case Status.cancelPending:
        return 'Cancellation pending review';
    }
  }
}

enum OrderType { litigation, messenger }

enum TaskPriority { low, medium, high, urgent }

enum TaskType { filing, scanning, serving, delivery, pickup, other }

enum ProgressStatus { awaitingPayment, processing, deliveryEnroute, completed }

// =============================================================================
// TIMER-RELATED ENUMS
// =============================================================================

enum TaskTimerStatus {
  pending, // Timer not started
  active, // Timer running
  expired, // Timer expired
  escalated, // Escalated to super admin
  completed, // Task completed before expiry
}

enum TaskTimerType {
  acceptance, // 15 min for incoming tasks (assigned)
  pickup, // 30 min for assigned tasks (ready for pickup)
  assignment,
}

enum NotificationType {
  initial, // First notification when timer expires
  escalation, // Escalation notification to super admin
}

class RequestModel {
  /// Core identification fields
  final String orderId;
  final String title;
  final String lawyerId;

  final DateTime createdAt;
  final DateTime dueDate;
  final Priority priority;

  /// Related entity IDs (fetch details on demand)
  final String caseFileId;
  final String courtId;
  final String officeId;
  final String? assigneeId;
  final String orgId;
  final String? driverId;
  final String serviceId;
  final int phase;

  /// Task details
  final String? notes;
  final String? podFileUrl;
  final String? cancelReason;
  final List<UploadFileData>? instructions;
  final List<UploadFileData>? followupDocs;
  final List<AddressModel>? dropoffList;
  final Status? status;
  final TaskType? type;
  final OrderType? orderType;
  final ActionType actionType;

  /// Financial information (stored as cents/minor value)
  final String? transactionRef;
  final int? cost;
  final int? driverFare;
  final bool? selfService;
  final String? receiptId;
  final int? totalTimeSpent; // Total time spent in seconds

  /// Status tracking timestamps
  final DateTime? readyForPickupAt;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final DateTime? canceledAt;
  final DateTime? dispatchedAt;
  final DateTime? pickedupAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAtPickupAt;

  /// Set while [status] is [Status.cancelPending] (for reactivation / admin).
  final String? statusBeforeCancelPending;
  final DateTime? cancelPendingAt;

  /// Timer-related fields
  final DateTime? timerExpiryTime; // Calculated expiry time
  final DateTime? escalationTime; // When to escalate to super admin
  final TaskTimerStatus? timerStatus; // Current timer status
  final TaskTimerType? timerType; // Type of timer (acceptance/pickup)
  final String? lastAssignedTo; // Track reassignments for timer reset
  final DateTime? lastAssignedAt; // When last reassigned
  final List<TimerExtension>? timerExtensions; // Track manual extensions

  RequestModel({
    required this.orderId,
    required this.title,
    required this.lawyerId,
    required this.createdAt,
    required this.dueDate,
    required this.priority,
    required this.caseFileId,
    required this.courtId,
    required this.officeId,
    required this.orgId,
    required this.serviceId,
    required this.actionType,
    required this.phase,
    this.driverId,
    this.assigneeId,
    this.notes,
    this.podFileUrl,
    this.cancelReason,
    this.instructions,
    this.followupDocs,
    this.dropoffList,
    this.status = Status.pending,
    this.type,
    this.orderType,
    this.transactionRef,
    this.cost,
    this.driverFare,
    this.selfService,
    this.readyForPickupAt,
    this.assignedAt,
    this.completedAt,
    this.canceledAt,
    this.dispatchedAt,
    this.pickedupAt,
    this.acceptedAt,
    this.arrivedAtPickupAt,
    this.statusBeforeCancelPending,
    this.cancelPendingAt,
    this.timerExpiryTime,
    this.escalationTime,
    this.timerStatus,
    this.timerType,
    this.lastAssignedTo,
    this.lastAssignedAt,
    this.timerExtensions,
    this.receiptId,
    this.totalTimeSpent,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      // Core fields
      orderId: json['orderId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      lawyerId: json['lawyerId']?.toString() ?? '',
      createdAt: _parseDateTime(json['createdAt']),
      dueDate: _parseDateTime(json['dueDate']),
      priority: _parsePriority(json['priority']),

      // Related entity IDs
      caseFileId: json['caseFileId']?.toString() ?? '',
      courtId: json['courtId']?.toString() ?? '',
      officeId: json['officeId']?.toString() ?? '',
      assigneeId: json['assigneeId']?.toString() ?? '',
      orgId: json['orgId']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? '',
      serviceId: json['serviceId']?.toString() ?? '',

      // Task details
      notes: json['notes']?.toString(),
      podFileUrl: json['podFileUrl']?.toString(),
      cancelReason: json['cancelReason']?.toString(),
      instructions: _parseInstructions(json['instructions']),
      followupDocs: _parseFollowupDocs(json['followupDocs']),
      dropoffList: _parseDropoffList(json['dropoffList']),
      status: _parseTaskStatus(json['status']),
      type: _parseTaskType(json['type']),
      orderType: _parseOrderType(json['orderType']),
      // `phase` is non-nullable but historical docs may be missing it or
      // have a non-int type. Coerce safely instead of crashing deserialization.
      phase: _parsePhase(json['phase']),
      // Financial information
      transactionRef: json['transactionRef']?.toString(),
      cost: json['cost']?.toInt(),
      driverFare: json['driverFare']?.toInt(),
      selfService: json['selfService'] as bool? ?? false,

      // Status tracking timestamps
      readyForPickupAt: _parseDateTime(json['readyForPickupAt']),
      assignedAt: _parseDateTime(json['assignedAt']),
      completedAt: _parseDateTime(json['completedAt']),
      canceledAt: _parseDateTime(json['canceledAt']),
      dispatchedAt: _parseDateTime(json['dispatchedAt']),
      pickedupAt: _parseDateTime(json['pickedupAt']),
      acceptedAt: _parseDateTime(json['acceptedAt']),
      arrivedAtPickupAt: _parseDateTime(json['arrivedAtPickupAt']),
      statusBeforeCancelPending: json['statusBeforeCancelPending']?.toString(),
      cancelPendingAt: _parseDateTime(json['cancelPendingAt']),

      // Timer-related fields
      timerExpiryTime: _parseDateTime(json['timerExpiryTime']),
      escalationTime: _parseDateTime(json['escalationTime']),
      timerStatus: _parseTaskTimerStatus(json['timerStatus']),
      timerType: _parseTaskTimerType(json['timerType']),
      actionType: _parseActionType(json['actionType']),
      lastAssignedTo: json['lastAssignedTo']?.toString(),
      lastAssignedAt: _parseDateTime(json['lastAssignedAt']),
      timerExtensions: _parseTimerExtensions(json['timerExtensions']),

      receiptId: json['receiptId']?.toString() ?? '',
      totalTimeSpent: json['totalTimeSpent']?.toInt(),
    );
  }

  factory RequestModel.fromSnapshot(DocumentSnapshot snap) {
    return RequestModel(
      // Core fields
      orderId: snap.id,
      title: snap['title']?.toString() ?? '',
      lawyerId: snap['lawyerId']?.toString() ?? '',
      createdAt: _parseTimestamp(snap['createdAt']) ?? DateTime.now(),
      dueDate: _parseTimestamp(snap['dueDate']) ?? DateTime.now(),
      priority: _parsePriority(snap['priority']),

      // Related entity IDs
      caseFileId: snap['caseFileId']?.toString() ?? '',
      courtId: snap['courtId']?.toString() ?? '',
      officeId: snap['officeId']?.toString() ?? '',
      assigneeId: snap['assigneeId']?.toString() ?? '',
      orgId: snap['orgId']?.toString() ?? '',
      driverId: snap['driverId']?.toString() ?? '',
      serviceId: snap['serviceId']?.toString() ?? '',
      // Safely extract `phase`: snap['missing'] throws a StateError on
      // Firestore docs that pre-date this field. Use `.data()` + null-coalesce.
      phase: _parsePhase(
        (snap.data() as Map<String, dynamic>?)?['phase'],
      ),
      // Task details
      notes: snap['notes']?.toString(),
      podFileUrl: snap['podFileUrl']?.toString(),
      cancelReason: snap['cancelReason']?.toString(),
      instructions: _parseInstructionsFromSnapshot(snap['instructions']),
      followupDocs: _parseFollowupDocsFromSnapshot(snap['followupDocs']),
      dropoffList: _parseDropoffListFromSnapshot(snap['dropoffList']),
      status: _parseTaskStatus(snap['status']),
      type: _parseTaskType(snap['type']),
      orderType: _parseOrderType(snap['orderType']),
      actionType: _parseActionType(snap['actionType']),
      // Financial information
      transactionRef: snap['transactionRef']?.toString(),
      cost: snap['cost']?.toInt(),
      driverFare: snap['driverFare']?.toInt(),
      selfService: snap['selfService'] as bool? ?? false,

      // Status tracking timestamps
      readyForPickupAt: _parseTimestamp(snap['readyForPickupAt']),
      assignedAt: _parseTimestamp(snap['assignedAt']),
      completedAt: _parseTimestamp(snap['completedAt']),
      canceledAt: _parseTimestamp(snap['canceledAt']),
      dispatchedAt: _parseTimestamp(snap['dispatchedAt']),
      pickedupAt: _parseTimestamp(snap['pickedupAt']),
      acceptedAt: _parseTimestamp(snap['acceptedAt']),
      arrivedAtPickupAt: _parseTimestamp(snap['arrivedAtPickupAt']),
      statusBeforeCancelPending: snap['statusBeforeCancelPending']?.toString(),
      cancelPendingAt: _parseTimestamp(snap['cancelPendingAt']),

      // Timer-related fields
      timerExpiryTime: _parseTimestamp(snap['timerExpiryTime']),
      escalationTime: _parseTimestamp(snap['escalationTime']),
      timerStatus: _parseTaskTimerStatus(snap['timerStatus']),
      timerType: _parseTaskTimerType(snap['timerType']),
      lastAssignedTo: snap['lastAssignedTo'] ?? '',
      lastAssignedAt: _parseTimestamp(snap['lastAssignedAt']),
      timerExtensions: _parseTimerExtensionsFromSnapshot(
        snap['timerExtensions'],
      ),
      receiptId: snap['receiptId'] ?? '',
      totalTimeSpent: snap['totalTimeSpent']?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // Core fields
      'orderId': orderId,
      'title': title,
      'lawyerId': lawyerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority.name,

      // Related entity IDs
      'caseFileId': caseFileId,
      'courtId': courtId,
      'officeId': officeId,
      'assigneeId': assigneeId,
      'orgId': orgId,
      'driverId': driverId,
      'serviceId': serviceId,
      'receiptId': receiptId,

      // Task details
      'notes': notes,
      'podFileUrl': podFileUrl,
      'cancelReason': cancelReason,
      'instructions': instructions?.map((e) => e.toJson()).toList(),
      'followupDocs': followupDocs?.map((e) => e.toJson()).toList(),
      'dropoffList': dropoffList?.map((e) => e.toJson()).toList(),
      'status': status?.name,
      'type': type?.name,
      'orderType': orderType?.name,
      'phase': phase,
      // Financial information
      'transactionRef': transactionRef,
      'cost': cost,
      'driverFare': driverFare,
      'selfService': selfService,

      // Status tracking timestamps
      'readyForPickupAt': readyForPickupAt != null
          ? Timestamp.fromDate(readyForPickupAt!)
          : null,
      'assignedAt': assignedAt != null ? Timestamp.fromDate(assignedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'canceledAt': canceledAt != null ? Timestamp.fromDate(canceledAt!) : null,
      'dispatchedAt': dispatchedAt != null
          ? Timestamp.fromDate(dispatchedAt!)
          : null,
      'pickedupAt': pickedupAt != null ? Timestamp.fromDate(pickedupAt!) : null,
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'arrivedAtPickupAt': arrivedAtPickupAt != null
          ? Timestamp.fromDate(arrivedAtPickupAt!)
          : null,
      if (statusBeforeCancelPending != null)
        'statusBeforeCancelPending': statusBeforeCancelPending,
      if (cancelPendingAt != null)
        'cancelPendingAt': Timestamp.fromDate(cancelPendingAt!),

      // Timer-related fields
      'timerExpiryTime': timerExpiryTime != null
          ? Timestamp.fromDate(timerExpiryTime!)
          : null,
      'escalationTime': escalationTime != null
          ? Timestamp.fromDate(escalationTime!)
          : null,
      'timerStatus': timerStatus?.name,
      'timerType': timerType?.name,
      'actionType': actionType.name,
      'lastAssignedTo': lastAssignedTo,
      'lastAssignedAt': lastAssignedAt != null
          ? Timestamp.fromDate(lastAssignedAt!)
          : null,
      'timerExtensions': timerExtensions?.map((e) => e.toJson()).toList(),
      'totalTimeSpent': totalTimeSpent,
    };
  }

  RequestModel copyWith({
    String? orderId,
    String? title,
    String? lawyerId,
    DateTime? createdAt,
    DateTime? dueDate,
    Priority? priority,
    String? caseFileId,
    String? courtId,
    String? officeId,
    String? assigneeId,
    String? orgId,
    String? driverId,
    String? serviceId,
    String? notes,
    String? podFileUrl,
    String? cancelReason,
    List<UploadFileData>? instructions,
    List<UploadFileData>? followupDocs,
    List<AddressModel>? dropoffList,
    Status? status,
    TaskType? type,
    OrderType? orderType,
    String? transactionRef,
    int? cost,
    int? driverFare,
    bool? selfService,
    DateTime? readyForPickupAt,
    DateTime? assignedAt,
    DateTime? completedAt,
    DateTime? canceledAt,
    DateTime? dispatchedAt,
    DateTime? pickedupAt,
    DateTime? acceptedAt,
    DateTime? arrivedAtPickupAt,
    String? statusBeforeCancelPending,
    DateTime? cancelPendingAt,
    DateTime? timerExpiryTime,
    DateTime? escalationTime,
    TaskTimerStatus? timerStatus,
    TaskTimerType? timerType,
    ActionType? actionType,
    String? lastAssignedTo,
    DateTime? lastAssignedAt,
    List<TimerExtension>? timerExtensions,
    String? receiptId,
    int? phase,
    int? totalTimeSpent,
  }) {
    return RequestModel(
      orderId: orderId ?? this.orderId,
      title: title ?? this.title,
      lawyerId: lawyerId ?? this.lawyerId,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      caseFileId: caseFileId ?? this.caseFileId,
      courtId: courtId ?? this.courtId,
      officeId: officeId ?? this.officeId,
      assigneeId: assigneeId ?? this.assigneeId,
      orgId: orgId ?? this.orgId,
      driverId: driverId ?? this.driverId,
      serviceId: serviceId ?? this.serviceId,
      notes: notes ?? this.notes,
      podFileUrl: podFileUrl ?? this.podFileUrl,
      cancelReason: cancelReason ?? this.cancelReason,
      instructions: instructions ?? this.instructions,
      followupDocs: followupDocs ?? this.followupDocs,
      dropoffList: dropoffList ?? this.dropoffList,
      status: status ?? this.status,
      type: type ?? this.type,
      orderType: orderType ?? this.orderType,
      transactionRef: transactionRef ?? this.transactionRef,
      cost: cost ?? this.cost,
      driverFare: driverFare ?? this.driverFare,
      selfService: selfService ?? this.selfService,
      readyForPickupAt: readyForPickupAt ?? this.readyForPickupAt,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
      canceledAt: canceledAt ?? this.canceledAt,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      pickedupAt: pickedupAt ?? this.pickedupAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      arrivedAtPickupAt: arrivedAtPickupAt ?? this.arrivedAtPickupAt,
      statusBeforeCancelPending:
          statusBeforeCancelPending ?? this.statusBeforeCancelPending,
      cancelPendingAt: cancelPendingAt ?? this.cancelPendingAt,
      timerExpiryTime: timerExpiryTime ?? this.timerExpiryTime,
      escalationTime: escalationTime ?? this.escalationTime,
      timerStatus: timerStatus ?? this.timerStatus,
      timerType: timerType ?? this.timerType,
      actionType: actionType ?? this.actionType,
      lastAssignedTo: lastAssignedTo ?? this.lastAssignedTo,
      lastAssignedAt: lastAssignedAt ?? this.lastAssignedAt,
      timerExtensions: timerExtensions ?? this.timerExtensions,
      receiptId: receiptId ?? this.receiptId,
      phase: phase ?? this.phase,
      totalTimeSpent: totalTimeSpent ?? this.totalTimeSpent,
    );
  }

  // =============================================================================
  // COMPUTED PROPERTIES
  // =============================================================================

  /// Check if task is overdue
  bool get isOverdue {
    final s = status;
    if (s == Status.completed ||
        s == Status.canceled ||
        s == Status.rejected ||
        s == Status.cancelPending) {
      return false;
    }
    return dueDate.isBefore(DateTime.now());
  }

  /// Get days until deadline
  int get daysUntilDeadline {
    final now = DateTime.now();
    return dueDate.difference(now).inDays;
  }

  /// Get task age in days
  int get taskAge {
    final now = DateTime.now();
    return now.difference(createdAt).inDays;
  }

  // =============================================================================
  // TIMER-RELATED COMPUTED PROPERTIES
  // =============================================================================

  /// Check if task timer has expired
  bool get isTimerExpired {
    if (timerExpiryTime == null) return false;
    return DateTime.now().isAfter(timerExpiryTime!);
  }

  /// Check if task needs escalation
  bool get needsEscalation {
    if (escalationTime == null) return false;
    return DateTime.now().isAfter(escalationTime!);
  }

  /// Get remaining time until timer expires
  Duration? get remainingTime {
    if (timerExpiryTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(timerExpiryTime!)) return Duration.zero;
    return timerExpiryTime!.difference(now);
  }

  /// Get remaining time until escalation
  Duration? get remainingEscalationTime {
    if (escalationTime == null) return null;
    final now = DateTime.now();
    if (now.isAfter(escalationTime!)) return Duration.zero;
    return escalationTime!.difference(now);
  }

  /// Check if timer is active
  bool get isTimerActive {
    return timerStatus == TaskTimerStatus.active;
  }

  /// Check if timer is pending
  bool get isTimerPending {
    return timerStatus == TaskTimerStatus.pending;
  }

  /// Check if timer has been escalated
  bool get isTimerEscalated {
    return timerStatus == TaskTimerStatus.escalated;
  }

  /// Get completion time in days (if completed)
  int? get completionTime {
    if (completedAt == null) return null;
    return completedAt!.difference(createdAt).inDays;
  }

  /// Get priority color
  Color get priorityColor {
    switch (priority) {
      case Priority.urgent:
        return Colors.red;
      case Priority.standard:
        return Colors.blue;
    }
  }

  /// Get status color
  Color get statusColor {
    switch (status) {
      case Status.pending:
        return Colors.grey;
      case Status.assigned:
        return Colors.blue;
      case Status.inProgress:
        return Colors.orange;
      case Status.completed:
        return Colors.green;
      case Status.rejected:
        return Colors.red;
      case Status.overdue:
        return Colors.red;
      case Status.escalated:
        return Colors.purple;
      case Status.readyForPickup:
        return Colors.yellow;
      case Status.pickedup:
        return Colors.orange;
      case Status.canceled:
        return Colors.red;
      case Status.cancelPending:
        return Colors.deepOrange;
      case Status.accepted:
        return Colors.blue;
      case Status.arrivedAtPickup:
        return Colors.yellow;
      case null:
        return Colors.grey;
    }
  }

  /// Check if task is assigned
  bool get isAssigned => assigneeId != null && assigneeId!.isNotEmpty;

  /// Check if task is in progress
  bool get isInProgress => status == Status.inProgress;

  /// Check if task is completed
  bool get isCompleted => status == Status.completed;

  /// Check if task is canceled
  bool get isCanceled => status == Status.canceled;

  /// Check if task is ready for pickup
  bool get isReadyForPickup => status == Status.readyForPickup;

  /// Get the most recent status timestamp
  DateTime? get lastStatusUpdate {
    final timestamps = [
      readyForPickupAt,
      assignedAt,
      completedAt,
      canceledAt,
      dispatchedAt,
      pickedupAt,
      acceptedAt,
      arrivedAtPickupAt,
    ].whereType<DateTime>().toList();

    if (timestamps.isEmpty) return null;
    return timestamps.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  // =============================================================================
  // HELPER METHODS
  // =============================================================================

  /// Get formatted due date string
  String get formattedDueDate {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.isNegative) {
      return 'Overdue';
    } else if (difference.inDays == 0) {
      return 'Due today';
    } else if (difference.inDays == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in ${difference.inDays} days';
    }
  }

  /// Get task status display name
  String get statusDisplayName {
    switch (status) {
      case Status.pending:
        return 'Pending';
      case Status.assigned:
        return 'Assigned';
      case Status.inProgress:
        return 'In Progress';
      case Status.completed:
        return 'Completed';
      case Status.rejected:
        return 'Rejected';
      case Status.overdue:
        return 'Overdue';
      case Status.escalated:
        return 'Escalated';
      case Status.readyForPickup:
        return 'Ready for Pickup';
      case Status.pickedup:
        return 'Picked Up';
      case Status.canceled:
        return 'Canceled';
      case Status.cancelPending:
        return 'Cancellation pending review';
      case Status.accepted:
        return 'Accepted';
      case Status.arrivedAtPickup:
        return 'Arrived at Pickup';
      case null:
        return 'Unknown';
    }
  }

  // =============================================================================
  // PRIVATE HELPER METHODS
  // =============================================================================

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) {
      throw ArgumentError('DateTime value cannot be null');
    }

    if (value is String) {
      return DateTime.parse(value);
    } else if (value is DateTime) {
      return value;
    } else {
      throw ArgumentError('Invalid DateTime value: $value');
    }
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

  // Convert any dynamic value to a safe non-null int for `phase`.
  // Returns 0 when the value is missing or can't be parsed.
  static int _parsePhase(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Generic enum lookup by name that never throws. If the stored string
  // doesn't match a known enum value (e.g. a stale/renamed status) we return
  // null instead of crashing the whole stream via `ArgumentError` from
  // `Enum.values.byName`.
  static T? _enumByName<T extends Enum>(Iterable<T> values, String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  static Priority _parsePriority(dynamic value) {
    if (value == null) return Priority.standard;
    if (value is Priority) return value;
    if (value is String) {
      return _enumByName(Priority.values, value) ?? Priority.standard;
    }
    return Priority.standard;
  }

  static Status? _parseTaskStatus(dynamic value) {
    if (value == null) return null;
    if (value is Status) return value;
    if (value is String) return _enumByName(Status.values, value);
    return null;
  }

  static TaskType? _parseTaskType(dynamic value) {
    if (value == null) return null;
    if (value is TaskType) return value;
    if (value is String) return _enumByName(TaskType.values, value);
    return null;
  }

  static OrderType? _parseOrderType(dynamic value) {
    if (value == null) return null;
    if (value is OrderType) return value;
    if (value is String) return _enumByName(OrderType.values, value);
    return null;
  }

  static List<UploadFileData>? _parseInstructions(dynamic value) {
    if (value == null) return null;

    if (value is List) {
      return value
          .map((e) => UploadFileData.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      return null;
    }
  }

  static List<UploadFileData>? _parseInstructionsFromSnapshot(dynamic value) {
    if (value == null) return null;

    if (value is List) {
      return value
          .map((e) => UploadFileData.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      return null;
    }
  }

  static List<UploadFileData>? _parseFollowupDocs(dynamic value) {
    if (value == null) return null;

    if (value is List) {
      return value
          .map((e) => UploadFileData.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      return null;
    }
  }

  static List<UploadFileData>? _parseFollowupDocsFromSnapshot(dynamic value) {
    if (value == null) return null;

    if (value is List) {
      return value
          .map((e) => UploadFileData.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      return null;
    }
  }

  static List<AddressModel>? _parseDropoffList(dynamic value) {
    if (value == null) return null;

    if (value is List) {
      return value
          .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      return null;
    }
  }

  static List<AddressModel>? _parseDropoffListFromSnapshot(dynamic value) {
    if (value == null) return null;

    if (value is List) {
      return value
          .map((e) => AddressModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      return null;
    }
  }

  // Timer-related parse methods
  static TaskTimerStatus? _parseTaskTimerStatus(dynamic value) {
    if (value == null) return null;
    if (value is TaskTimerStatus) return value;
    if (value is String) return _enumByName(TaskTimerStatus.values, value);
    return null;
  }

  static ActionType _parseActionType(dynamic value) {
    if (value == null) return ActionType.serve;
    if (value is ActionType) return value;
    if (value is String) {
      return _enumByName(ActionType.values, value) ?? ActionType.serve;
    }
    return ActionType.serve;
  }

  static TaskTimerType? _parseTaskTimerType(dynamic value) {
    if (value == null) return null;
    if (value is TaskTimerType) return value;
    if (value is String) return _enumByName(TaskTimerType.values, value);
    return null;
  }

  static List<TimerExtension>? _parseTimerExtensions(dynamic value) {
    if (value == null) return null;

    if (value is List) {
      return value
          .map((e) => TimerExtension.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      return null;
    }
  }

  static List<TimerExtension>? _parseTimerExtensionsFromSnapshot(
    dynamic value,
  ) {
    if (value == null) return null;

    if (value is List) {
      return value
          .map((e) => TimerExtension.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      return null;
    }
  }
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

String stringProgressStatus(ProgressStatus progressStatus) {
  switch (progressStatus) {
    case ProgressStatus.awaitingPayment:
      return 'Awaiting Payment';
    case ProgressStatus.processing:
      return 'Processing';
    case ProgressStatus.deliveryEnroute:
      return 'Delivery Enroute';
    case ProgressStatus.completed:
      return 'Completed';
  }
}

ProgressStatus progressStatusFromString(String value) {
  switch (value) {
    case 'Awaiting Payment':
      return ProgressStatus.awaitingPayment;
    case 'Processing':
      return ProgressStatus.processing;
    case 'Delivery Enroute':
      return ProgressStatus.deliveryEnroute;
    case 'Completed':
      return ProgressStatus.completed;
    default:
      throw ArgumentError('Invalid ProgressStatus value: $value');
  }
}
