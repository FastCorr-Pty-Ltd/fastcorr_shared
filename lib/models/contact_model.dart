import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';
import 'package:flutter/material.dart';

enum ContactRole {
  applicant,
  applicantAttorney,
  respondentAttorney,
  firstDefendant,
  secondDefendant,
  thirdDefendant,
  fourthDefendant,
  firstRespondent,
  secondRespondent,
  thirdRespondent,
  fourthRespondent,
  plaintiffAttorney,
  defendantAttorney,
  opposingAttorney,
  sheriff,
  courtClerk,
  other,
}

class ContactModel {
  String? id;
  String name;
  String? phone;
  String? email;
  String? address;
  ContactRole role;
  String? customRole; // For 'other' role
  String? notes;
  Timestamp? createdAt;
  Timestamp? lastUpdated;
  GeoPoint? location;

  ContactModel({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    required this.role,
    this.customRole,
    this.notes,
    this.createdAt,
    this.lastUpdated,
    this.location,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) => ContactModel(
    id: json['id'],
    name: json['name'] ?? '',
    phone: json['phone'],
    email: json['email'],
    address: json['address'],
    role: ContactRole.values.byName(json['role'] ?? 'other'),
    customRole: json['customRole'],
    notes: json['notes'],
    createdAt: json['createdAt'] == null
        ? null
        : processedTimestamp(json['createdAt']),
    lastUpdated: json['lastUpdated'] == null
        ? null
        : processedTimestamp(json['lastUpdated']),
    location: json['location'],
  );

  factory ContactModel.fromSnapshot(DocumentSnapshot snap) => ContactModel(
    id: snap.id,
    name: snap['name'] ?? '',
    phone: snap['phone'],
    email: snap['email'],
    address: snap['address'],
    role: ContactRole.values.byName(snap['role'] ?? 'other'),
    customRole: snap['customRole'],
    notes: snap['notes'],
    createdAt: snap['createdAt'] == null
        ? null
        : processedTimestamp(snap['createdAt']),
    lastUpdated: snap['lastUpdated'] == null
        ? null
        : processedTimestamp(snap['lastUpdated']),
    location: snap['location'],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'role': role.name,
    'customRole': customRole,
    'notes': notes,
    'createdAt': createdAt?.toDate().toIso8601String(),
    'lastUpdated': lastUpdated?.toDate().toIso8601String(),
    'location': location,
  };

  ContactModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    ContactRole? role,
    String? customRole,
    String? notes,
    Timestamp? createdAt,
    Timestamp? lastUpdated,
    GeoPoint? location,
  }) {
    return ContactModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      role: role ?? this.role,
      customRole: customRole ?? this.customRole,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      location: location ?? this.location,
    );
  }

  String get displayRole {
    if (role == ContactRole.other && customRole != null) {
      return customRole!;
    }
    return role.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .trim();
  }

  String get displayName {
    return '$name (${displayRole})';
  }
}

// Helper functions
String getPartyRoleDisplayName(ContactRole role) {
  switch (role) {
    case ContactRole.applicant:
      return 'Applicant';
    case ContactRole.firstDefendant:
      return 'First Defendant';
    case ContactRole.secondDefendant:
      return 'Second Defendant';
    case ContactRole.thirdDefendant:
      return 'Third Defendant';
    case ContactRole.fourthDefendant:
      return 'Fourth Defendant';
    case ContactRole.defendantAttorney:
      return 'Defendant Attorney';
    case ContactRole.firstRespondent:
      return 'First Respondent';
    case ContactRole.secondRespondent:
      return 'Second Respondent';
    case ContactRole.thirdRespondent:
      return 'Third Respondent';
    case ContactRole.fourthRespondent:
      return 'Fourth Respondent';
    case ContactRole.applicantAttorney:
      return 'Applicant Attorney';
    case ContactRole.opposingAttorney:
      return 'Opposing Attorney';
    case ContactRole.sheriff:
      return 'Sheriff';
    case ContactRole.courtClerk:
      return 'Court Clerk';

    case ContactRole.other:
      return 'Other';
    case ContactRole.respondentAttorney:
      return 'Respondent Attorney';

    case ContactRole.plaintiffAttorney:
      return 'Plaintiff Attorney';
  }
}

Color getPartyRoleColor(ContactRole role) {
  switch (role) {
    case ContactRole.applicant:
      return Colors.blue;
    case ContactRole.applicantAttorney:
      return Colors.green;
    case ContactRole.respondentAttorney:
      return Colors.red;
    case ContactRole.firstDefendant:
      return Colors.deepOrange;
    case ContactRole.secondDefendant:
      return Colors.deepOrange;
    case ContactRole.thirdDefendant:
      return Colors.deepOrange;

    case ContactRole.fourthDefendant:
      return Colors.deepOrange;

    case ContactRole.firstRespondent:
      return Colors.yellow;
    case ContactRole.secondRespondent:
      return Colors.yellow;
    case ContactRole.thirdRespondent:
      return Colors.yellow;
    case ContactRole.fourthRespondent:
      return Colors.yellow;
    case ContactRole.plaintiffAttorney:
      return Colors.orange;
    case ContactRole.defendantAttorney:
      return Colors.orange;
    case ContactRole.opposingAttorney:
      return Colors.teal;
    case ContactRole.sheriff:
      return Colors.teal;
    case ContactRole.courtClerk:
      return Colors.teal;
    case ContactRole.other:
      return Colors.teal;
  }
}

IconData getPartyRoleIcon(ContactRole role) {
  switch (role) {
    case ContactRole.applicant:
      return Icons.person;
    case ContactRole.firstDefendant:
      return Icons.person_outline;
    case ContactRole.secondDefendant:
      return Icons.person_outline;
    case ContactRole.thirdDefendant:
      return Icons.person_outline;
    case ContactRole.fourthDefendant:
      return Icons.person_outline;
    case ContactRole.plaintiffAttorney:
      return Icons.gavel;
    case ContactRole.defendantAttorney:
      return Icons.balance;
    case ContactRole.opposingAttorney:
      return Icons.balance;
    case ContactRole.sheriff:
      return Icons.security;
    case ContactRole.courtClerk:
      return Icons.assignment;
    case ContactRole.firstRespondent:
      return Icons.person_outline;
    case ContactRole.secondRespondent:
    case ContactRole.thirdRespondent:
      return Icons.person_outline;
    case ContactRole.fourthRespondent:
      return Icons.person_outline;

    case ContactRole.other:
      return Icons.person_add;
    case ContactRole.applicantAttorney:
      return Icons.gavel;
    case ContactRole.respondentAttorney:
      return Icons.balance;
  }
}
