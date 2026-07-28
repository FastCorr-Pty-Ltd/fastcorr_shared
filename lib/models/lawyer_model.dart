import 'package:cloud_firestore/cloud_firestore.dart';

import 'subscription_status.dart';

/// Lawyer / firm-user profile stored in `users/{uid}`.
///
/// Serialization matches other fastcorr_shared models:
/// - [fromJson] / [toJson] — map-based
/// - [fromSnapshot] — Firestore document
///
/// [toMap] / [fromMap] are aliases kept for transitional call sites.
class LawyerModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String orgId;
  final String role;
  final bool? mustChangePassword;
  final Timestamp createdAt;
  final GeoPoint? location;

  /// Branch office document id under `offices/{officeId}` when assigned.
  final String? officeId;

  // —— Subscription / RevenueCat ——
  final String? revenueCatUserId;
  final SubscriptionStatus subscriptionStatus;
  final String? subscriptionTier;
  final Timestamp? subscriptionStartDate;
  final Timestamp? subscriptionEndDate;
  final bool isPremium;
  final String? subscriptionPlatform;
  final bool hasUsedTrial;
  final Timestamp? trialStartDate;
  final Timestamp? trialEndDate;
  final Timestamp? lastSubscriptionSync;

  LawyerModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.orgId,
    required this.role,
    required this.phone,
    required this.createdAt,
    this.mustChangePassword,
    this.location,
    this.officeId,
    this.revenueCatUserId,
    this.subscriptionStatus = SubscriptionStatus.none,
    this.subscriptionTier,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.isPremium = false,
    this.subscriptionPlatform,
    this.hasUsedTrial = false,
    this.trialStartDate,
    this.trialEndDate,
    this.lastSubscriptionSync,
  });

  factory LawyerModel.fromJson(Map<String, dynamic> json) {
    return LawyerModel(
      uid: (json['uid'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      orgId: (json['orgId'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'lawyer',
      createdAt: _asTimestamp(json['createdAt']) ?? Timestamp.now(),
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      location: _asGeoPoint(json['location']),
      officeId: json['officeId'] as String?,
      revenueCatUserId: json['revenueCatUserId'] as String?,
      subscriptionStatus: _parseSubscriptionStatus(json['subscriptionStatus']),
      subscriptionTier: json['subscriptionTier'] as String?,
      subscriptionStartDate: _asTimestamp(json['subscriptionStartDate']),
      subscriptionEndDate: _asTimestamp(json['subscriptionEndDate']),
      isPremium: json['isPremium'] as bool? ?? false,
      subscriptionPlatform: json['subscriptionPlatform'] as String?,
      hasUsedTrial: json['hasUsedTrial'] as bool? ?? false,
      trialStartDate: _asTimestamp(json['trialStartDate']),
      trialEndDate: _asTimestamp(json['trialEndDate']),
      lastSubscriptionSync: _asTimestamp(json['lastSubscriptionSync']),
    );
  }

  /// Alias for [fromJson] (transitional).
  factory LawyerModel.fromMap(Map<String, dynamic> map) =>
      LawyerModel.fromJson(map);

  factory LawyerModel.fromSnapshot(DocumentSnapshot snap) {
    final raw = snap.data();
    final m = raw is Map<String, dynamic>
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    m['uid'] = snap.id;
    return LawyerModel.fromJson(m);
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'orgId': orgId,
      'role': role,
      'createdAt': createdAt,
      'mustChangePassword': mustChangePassword,
      'location': location,
      if (officeId != null && officeId!.isNotEmpty) 'officeId': officeId,
      'revenueCatUserId': revenueCatUserId,
      'subscriptionStatus': subscriptionStatus.name,
      'subscriptionTier': subscriptionTier,
      'subscriptionStartDate': subscriptionStartDate,
      'subscriptionEndDate': subscriptionEndDate,
      'isPremium': isPremium,
      'subscriptionPlatform': subscriptionPlatform,
      'hasUsedTrial': hasUsedTrial,
      'trialStartDate': trialStartDate,
      'trialEndDate': trialEndDate,
      'lastSubscriptionSync': lastSubscriptionSync,
    };
  }

  /// Alias for [toJson] (transitional).
  Map<String, dynamic> toMap() => toJson();

  LawyerModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? orgId,
    String? phone,
    String? role,
    Timestamp? createdAt,
    bool? mustChangePassword,
    GeoPoint? location,
    String? officeId,
    String? revenueCatUserId,
    SubscriptionStatus? subscriptionStatus,
    String? subscriptionTier,
    Timestamp? subscriptionStartDate,
    Timestamp? subscriptionEndDate,
    bool? isPremium,
    String? subscriptionPlatform,
    bool? hasUsedTrial,
    Timestamp? trialStartDate,
    Timestamp? trialEndDate,
    Timestamp? lastSubscriptionSync,
  }) =>
      LawyerModel(
        uid: uid ?? this.uid,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        orgId: orgId ?? this.orgId,
        role: role ?? this.role,
        createdAt: createdAt ?? this.createdAt,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
        location: location ?? this.location,
        officeId: officeId ?? this.officeId,
        revenueCatUserId: revenueCatUserId ?? this.revenueCatUserId,
        subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
        subscriptionTier: subscriptionTier ?? this.subscriptionTier,
        subscriptionStartDate:
            subscriptionStartDate ?? this.subscriptionStartDate,
        subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
        isPremium: isPremium ?? this.isPremium,
        subscriptionPlatform: subscriptionPlatform ?? this.subscriptionPlatform,
        hasUsedTrial: hasUsedTrial ?? this.hasUsedTrial,
        trialStartDate: trialStartDate ?? this.trialStartDate,
        trialEndDate: trialEndDate ?? this.trialEndDate,
        lastSubscriptionSync: lastSubscriptionSync ?? this.lastSubscriptionSync,
      );

  int get daysUntilExpiry {
    if (subscriptionEndDate == null) return 0;
    return subscriptionEndDate!.toDate().difference(DateTime.now()).inDays;
  }

  bool get isExpiringSoon => daysUntilExpiry > 0 && daysUntilExpiry <= 7;

  bool get isInTrial => subscriptionStatus == SubscriptionStatus.trial;

  String get subscriptionStatusDisplay {
    if (isInTrial) {
      return 'Trial ($daysUntilExpiry days left)';
    }
    return subscriptionStatus.displayName;
  }

  static SubscriptionStatus _parseSubscriptionStatus(dynamic value) {
    if (value == null) return SubscriptionStatus.none;
    if (value is SubscriptionStatus) return value;
    try {
      return SubscriptionStatus.values.firstWhere(
        (e) => e.name == value.toString(),
        orElse: () => SubscriptionStatus.none,
      );
    } catch (_) {
      return SubscriptionStatus.none;
    }
  }

  static Timestamp? _asTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    if (value is int) {
      return Timestamp.fromMillisecondsSinceEpoch(value);
    }
    if (value is Map) {
      final seconds = value['seconds'] ?? value['_seconds'];
      final nanos = value['nanoseconds'] ?? value['_nanoseconds'] ?? 0;
      if (seconds is int) {
        return Timestamp(seconds, nanos is int ? nanos : 0);
      }
    }
    return null;
  }

  static GeoPoint? _asGeoPoint(dynamic value) {
    if (value == null) return null;
    if (value is GeoPoint) return value;
    if (value is Map) {
      final lat = value['latitude'] ?? value['lat'];
      final lng = value['longitude'] ?? value['lng'] ?? value['lon'];
      if (lat is num && lng is num) {
        return GeoPoint(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }
}
