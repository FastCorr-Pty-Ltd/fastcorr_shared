import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum IssueType {
  bugReport,
  featureRequest,
  feedback,
  accountIssue,
  paymentIssue,
  other,
}

enum IssuePriority { low, medium, high, critical }

enum IssueStatus { open, assigned, inProgress, resolved, closed, escalated }

enum HandlerRole { supportAgent, developer, admin, system }

class SupportTicket {
  final String id;
  final String clientName;
  final String clientId;
  final String title;
  final String description;
  final IssueType type;
  final IssuePriority priority;
  final IssueStatus status;
  final HandlerRole? assignedRole;
  final String? assignedStaffName;
  final String? assignedStaffId;
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  SupportTicket({
    required this.id,
    required this.clientName,
    required this.clientId,
    required this.title,
    required this.description,
    required this.type,
    this.priority = IssuePriority.medium,
    this.status = IssueStatus.open,
    this.assignedRole,
    this.assignedStaffName,
    this.assignedStaffId,
    required this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromSnapshot(DocumentSnapshot snap) {
    return SupportTicket(
      id: snap.id,
      createdAt: processedTimestamp(snap['createdAt'])!,
      clientName: snap['clientName'] ?? '',
      clientId: snap['clientId'] ?? '',
      title: snap['title'] ?? '',
      description: snap['description'] ?? '',
      type: IssueType.values.byName(snap['type']),
      priority: IssuePriority.values.byName(snap['priority']),
      status: IssueStatus.values.byName(snap['status']),
      assignedRole: HandlerRole.values.byName(snap['assignedRole']),
      assignedStaffName: snap['assignedStaffName'] ?? '',
      assignedStaffId: snap['assignedStaffId'] ?? '',
      updatedAt: processedTimestamp(snap['updatedAt']),
    );
  }

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] ?? '',
      createdAt: processedTimestamp(json['createdAt'])!,
      clientName: json['clientName'] ?? '',
      clientId: json['clientId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: IssueType.values.byName(json['type']),
      priority: IssuePriority.values.byName(json['priority']),
      status: IssueStatus.values.byName(json['status']),
      assignedRole: HandlerRole.values.byName(json['assignedRole']),
      assignedStaffName: json['assignedStaffName'] ?? '',
      assignedStaffId: json['assignedStaffId'] ?? '',
      updatedAt: processedTimestamp(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt,
      'clientName': clientName,
      'clientId': clientId,
      'title': title,
      'description': description,
      'type': type.name,
      'priority': priority.name,
      'status': status.name,
      'assignedRole': assignedRole?.name,
      'assignedStaffName': assignedStaffName,
      'assignedStaffId': assignedStaffId,
      'updatedAt': updatedAt,
    };
  }

  SupportTicket copyWith({
    String? id,
    String? clientName,
    String? clientId,
    String? title,
    String? description,
    IssueType? type,
    IssuePriority? priority,
    IssueStatus? status,
    HandlerRole? assignedRole,
    String? assignedStaffName,
    String? assignedStaffId,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      clientId: clientId ?? this.clientId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      assignedRole: assignedRole ?? this.assignedRole,
      assignedStaffName: assignedStaffName ?? this.assignedStaffName,
      assignedStaffId: assignedStaffId ?? this.assignedStaffId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
