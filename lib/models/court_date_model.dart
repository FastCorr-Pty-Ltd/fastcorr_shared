import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Enum representing the status of a court date
enum CourtDateStatus { scheduled, upcoming, urgent, completed }

/// Enum representing the type of court date
enum CourtDateType { trial, preTrial, motion, other }

/// Model representing a court date
class CourtDateModel {
  final String dateId;
  final String caseId;
  final String caseTitle;
  final String orgId;
  final String description;
  final DateTime courtDate;
  final CourtDateType dateType;
  final CourtDateStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String? updatedBy;

  const CourtDateModel({
    required this.dateId,
    required this.caseId,
    required this.caseTitle,
    required this.orgId,
    required this.description,
    required this.courtDate,
    required this.dateType,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.updatedBy,
  });

  /// Factory constructor to create CourtDateModel from Firestore document
  factory CourtDateModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourtDateModel(
      dateId: doc.id,
      caseId: data['caseId'] ?? '',
      caseTitle: data['caseTitle'] ?? '',
      orgId: data['orgId'] ?? '',
      description: data['description'] ?? '',
      courtDate: (data['courtDate'] as Timestamp).toDate(),
      dateType: CourtDateType.values.firstWhere(
        (e) => e.name == data['dateType'],
        orElse: () => CourtDateType.other,
      ),
      status: CourtDateStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => CourtDateStatus.scheduled,
      ),
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      updatedBy: data['updatedBy'],
    );
  }

  /// Convert CourtDateModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'caseId': caseId,
      'caseTitle': caseTitle,
      'orgId': orgId,
      'description': description,
      'courtDate': Timestamp.fromDate(courtDate),
      'dateType': dateType.name,
      'status': status.name,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  /// Create a copy of this CourtDateModel with updated fields
  CourtDateModel copyWith({
    String? dateId,
    String? caseId,
    String? caseTitle,
    String? orgId,
    String? description,
    DateTime? courtDate,
    CourtDateType? dateType,
    CourtDateStatus? status,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return CourtDateModel(
      dateId: dateId ?? this.dateId,
      caseId: caseId ?? this.caseId,
      caseTitle: caseTitle ?? this.caseTitle,
      orgId: orgId ?? this.orgId,
      description: description ?? this.description,
      courtDate: courtDate ?? this.courtDate,
      dateType: dateType ?? this.dateType,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  /// Check if the court date is urgent (within 7 days)
  bool get isUrgent {
    final daysUntil = courtDate.difference(DateTime.now()).inDays;
    return daysUntil <= 7 && daysUntil >= 0;
  }

  /// Check if the court date is upcoming (within 30 days)
  bool get isUpcoming {
    final daysUntil = courtDate.difference(DateTime.now()).inDays;
    return daysUntil <= 30 && daysUntil >= 0;
  }

  /// Check if the court date is past
  bool get isPast {
    final daysUntil = courtDate.difference(DateTime.now()).inDays;
    return daysUntil < 0;
  }

  /// Get the number of days until the court date
  int get daysUntil {
    return courtDate.difference(DateTime.now()).inDays;
  }

  /// Get the name of the court date type
  static String getDateTypeDisplayName(CourtDateType type) {
    switch (type) {
      case CourtDateType.preTrial:
        return 'Pre-Trial';
      case CourtDateType.motion:
        return 'Motion';
      case CourtDateType.trial:
        return 'Trial';

      case CourtDateType.other:
        return 'Other';
    }
  }

  static Color getDateTypeColor(CourtDateType dateType) {
    switch (dateType) {
      case CourtDateType.preTrial:
        return const Color(0xFF2196F3); // Blue
      case CourtDateType.motion:
        return const Color(0xFF9C27B0); // Purple
      case CourtDateType.trial:
        return const Color(0xFFF44336); // Red
      case CourtDateType.other:
        return const Color(0xFF9E9E9E); // Grey
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CourtDateModel && other.dateId == dateId;
  }

  @override
  int get hashCode => dateId.hashCode;

  @override
  String toString() {
    return 'CourtDateModel(dateId: $dateId, caseId: $caseId, caseTitle: $caseTitle, orgId: $orgId, description: $description, courtDate: $courtDate, dateType: $dateType, status: $status)';
  }
}
