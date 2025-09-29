import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/utils/utils.dart';
import 'package:flutter/material.dart';

enum ContactRole {
  plaintiff,
  defendant,
  plaintiffAttorney,
  defendantAttorney,
  sheriff,
  legalSecretary,
  investigator,
  paralegal,
  witness,
  prosecutor,
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
    case ContactRole.plaintiff:
      return 'Plaintiff';
    case ContactRole.defendant:
      return 'Defendant';
    case ContactRole.plaintiffAttorney:
      return 'Plaintiff Attorney';
    case ContactRole.defendantAttorney:
      return 'Defendant Attorney';
    case ContactRole.sheriff:
      return 'Sheriff';
    case ContactRole.legalSecretary:
      return 'Legal Secretary';
    case ContactRole.investigator:
      return 'Investigator';
    case ContactRole.paralegal:
      return 'Paralegal';
    case ContactRole.witness:
      return 'Witness';
    case ContactRole.prosecutor:
      return 'Prosecutor';
    case ContactRole.other:
      return 'Other';
  }
}

Color getPartyRoleColor(ContactRole role) {
  switch (role) {
    case ContactRole.plaintiff:
      return Colors.blue;
    case ContactRole.defendant:
      return Colors.red;
    case ContactRole.plaintiffAttorney:
      return Colors.lightBlue;
    case ContactRole.defendantAttorney:
      return Colors.orange;
    case ContactRole.sheriff:
      return Colors.purple;
    case ContactRole.legalSecretary:
      return Colors.teal;
    case ContactRole.investigator:
      return Colors.indigo;
    case ContactRole.paralegal:
      return Colors.cyan;
    case ContactRole.witness:
      return Colors.amber;
    case ContactRole.prosecutor:
      return Colors.deepPurple;
    case ContactRole.other:
      return Colors.grey;
  }
}

IconData getPartyRoleIcon(ContactRole role) {
  switch (role) {
    case ContactRole.plaintiff:
      return Icons.person;
    case ContactRole.defendant:
      return Icons.person_outline;
    case ContactRole.plaintiffAttorney:
      return Icons.gavel;
    case ContactRole.defendantAttorney:
      return Icons.balance;
    case ContactRole.sheriff:
      return Icons.security;
    case ContactRole.legalSecretary:
      return Icons.assignment;
    case ContactRole.investigator:
      return Icons.search;
    case ContactRole.paralegal:
      return Icons.description;
    case ContactRole.witness:
      return Icons.visibility;
    case ContactRole.prosecutor:
      return Icons.gavel;
    case ContactRole.other:
      return Icons.person_add;
  }
}
