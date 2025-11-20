import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';

enum TrialStatus { pending, pendingConfirmation, urgent, proceeding, postponed, settled, resolvedByClient }

enum TrialType { trial, preTrial, motion }

class TrialModel {
  final String trialId;
  final String litNumber;
  final String courtId;
  final String courtName;
  final String officeId;
  final String managerId;
  final String managerName;
  final String orgId;
  final String assigneeId;
  final String? correspondentId;
  final String correspondentName;
  final String lawyerId;
  final TrialStatus status;
  final Timestamp trialDate;
  final String? trialOutcome;
  final int capitalAmount;
  final String opposingAttorney;
  final String opposingAttorneyId;
  final String? counselBriefId;
  final String? scale;
  final TrialType type;

  TrialModel({
    required this.trialId,
    required this.litNumber,
    required this.courtId,
    required this.officeId,
    required this.orgId,
    required this.assigneeId,
    this.correspondentId,
    required this.lawyerId,
    required this.status,
    required this.trialDate,
    this.trialOutcome,
    required this.capitalAmount,
    required this.opposingAttorney,
    required this.opposingAttorneyId,
    this.counselBriefId,
    this.scale,
    required this.type,
    required this.courtName,
    required this.correspondentName,
    required this.managerId,
    required this.managerName,
  });

  factory TrialModel.fromJson(Map<String, dynamic> json) {
    return TrialModel(
      trialId: json['trialId'],
      litNumber: json['litNumber'],
      courtId: json['courtId'],
      officeId: json['officeId'],
      orgId: json['orgId'],
      assigneeId: json['assigneeId'],
      correspondentId: json['correspondentId'],
      lawyerId: json['lawyerId'],
      status: TrialStatus.values.byName(json['status']),
      trialDate: processedTimestamp(json['trialDate'])!,
      trialOutcome: json['trialOutcome'],
      capitalAmount: json['capitalAmount'],
      opposingAttorney: json['opposingAttorney'],
      opposingAttorneyId: json['opposingAttorneyId'],
      counselBriefId: json['counselBriefId'],
      scale: json['scale'],
      type: TrialType.values.byName(json['type']),
      courtName: json['courtName'],
      correspondentName: json['correspondentName'],
      managerId: json['managerId'],
      managerName: json['managerName'],
    );
  }

  factory TrialModel.fromSnapshot(DocumentSnapshot snapshot) {
    return TrialModel(
      trialId: snapshot.id,
      litNumber: snapshot['litNumber'],
      courtId: snapshot['courtId'],
      officeId: snapshot['officeId'],
      orgId: snapshot['orgId'],
      assigneeId: snapshot['assigneeId'],
      correspondentId: snapshot['correspondentId'],
      lawyerId: snapshot['lawyerId'],
      status: TrialStatus.values.byName(snapshot['status']),
      trialDate: processedTimestamp(snapshot['trialDate'])!,
      trialOutcome: snapshot['trialOutcome'],
      capitalAmount: snapshot['capitalAmount'],
      opposingAttorney: snapshot['opposingAttorney'],
      opposingAttorneyId: snapshot['opposingAttorneyId'],
      counselBriefId: snapshot['counselBriefId'],
      scale: snapshot['scale'],
      type: TrialType.values.byName(snapshot['type']),
      courtName: snapshot['courtName'],
      correspondentName: snapshot['correspondentName'],
      managerId: snapshot['managerId'],
      managerName: snapshot['managerName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trialId': trialId,
      'litNumber': litNumber,
      'courtId': courtId,
      'officeId': officeId,
      'orgId': orgId,
      'assigneeId': assigneeId,
      'correspondentId': correspondentId,
      'lawyerId': lawyerId,
      'status': status.name,
      'trialDate': trialDate,
      'trialOutcome': trialOutcome,
      'capitalAmount': capitalAmount,
      'opposingAttorney': opposingAttorney,
      'opposingAttorneyId': opposingAttorneyId,
      'counselBriefId': counselBriefId,
      'scale': scale,
      'type': type.name,
      'courtName': courtName,
      'correspondentName': correspondentName,
      'managerId': managerId,
      'managerName': managerName,
    };
  }

  TrialModel copyWith({
    String? trialId,
    String? litNumber,
    String? courtId,
    String? officeId,
    String? orgId,
    String? assigneeId,
    String? correspondentId,
    String? lawyerId,
    TrialStatus? status,
    Timestamp? trialDate,
    String? trialOutcome,
    int? capitalAmount,
    String? opposingAttorney,
    String? opposingAttorneyId,
    String? counselBriefId,
    String? scale,
    TrialType? type,
    String? courtName,
    String? correspondentName,
    String? managerId,
    String? managerName,
  }) {
    return TrialModel(
      trialId: trialId ?? this.trialId,
      litNumber: litNumber ?? this.litNumber,
      courtId: courtId ?? this.courtId,
      officeId: officeId ?? this.officeId,
      orgId: orgId ?? this.orgId,
      assigneeId: assigneeId ?? this.assigneeId,
      correspondentId: correspondentId ?? this.correspondentId,
      lawyerId: lawyerId ?? this.lawyerId,
      status: status ?? this.status,
      trialDate: trialDate ?? this.trialDate,
      trialOutcome: trialOutcome ?? this.trialOutcome,
      capitalAmount: capitalAmount ?? this.capitalAmount,
      opposingAttorney: opposingAttorney ?? this.opposingAttorney,
      opposingAttorneyId: opposingAttorneyId ?? this.opposingAttorneyId,
      counselBriefId: counselBriefId ?? this.counselBriefId,
      scale: scale ?? this.scale,
      type: type ?? this.type,
      courtName: courtName ?? this.courtName,
      correspondentName: correspondentName ?? this.correspondentName,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
    );
  }
}
