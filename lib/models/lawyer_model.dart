import 'package:cloud_firestore/cloud_firestore.dart';
import 'subscription_status.dart';

/// Lawyer/User model with subscription fields
///
/// This file shows ALL the fields that need to be added to your existing LawyerModel.
/// Copy the subscription fields section into your existing LawyerModel class.
class LawyerModel {
  // ============================================
  // EXISTING FIELDS (keep as-is)
  // ============================================
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String orgId;
  final String role; // 'admin' | 'lawyer'
  final bool mustChangePassword;
  final Timestamp createdAt;
  final GeoPoint? location;
  final String? officeId;

  // ============================================
  // NEW SUBSCRIPTION FIELDS (add these)
  // ============================================

  /// RevenueCat customer ID
  final String? revenueCatUserId;

  /// Current subscription status
  final SubscriptionStatus subscriptionStatus;

  /// Subscription tier (e.g., 'premium')
  final String? subscriptionTier;

  /// When subscription started
  final Timestamp? subscriptionStartDate;

  /// When subscription expires
  final Timestamp? subscriptionEndDate;

  /// Whether user has premium access
  final bool isPremium;

  /// Platform where subscription was purchased ('ios', 'android', 'web')
  final String? subscriptionPlatform;

  /// Whether user has used their free trial
  final bool hasUsedTrial;

  /// When trial started
  final Timestamp? trialStartDate;

  /// When trial ends
  final Timestamp? trialEndDate;

  /// Last time subscription status was synced from RevenueCat
  final Timestamp? lastSubscriptionSync;

  LawyerModel({
    // Existing fields
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.orgId,
    required this.role,
    this.mustChangePassword = false,
    required this.createdAt,
    this.location,
    this.officeId,

    // New subscription fields with defaults
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

  /// Create from Firestore document
  factory LawyerModel.fromMap(Map<String, dynamic> map) {
    return LawyerModel(
      // Existing fields
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      orgId: map['orgId'] ?? '',
      role: map['role'] ?? 'lawyer',
      mustChangePassword: map['mustChangePassword'] ?? false,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      location: map['location'],
      officeId: map['officeId'],

      // New subscription fields
      revenueCatUserId: map['revenueCatUserId'],
      subscriptionStatus: _parseSubscriptionStatus(map['subscriptionStatus']),
      subscriptionTier: map['subscriptionTier'],
      subscriptionStartDate: map['subscriptionStartDate'],
      subscriptionEndDate: map['subscriptionEndDate'],
      isPremium: map['isPremium'] ?? false,
      subscriptionPlatform: map['subscriptionPlatform'],
      hasUsedTrial: map['hasUsedTrial'] ?? false,
      trialStartDate: map['trialStartDate'],
      trialEndDate: map['trialEndDate'],
      lastSubscriptionSync: map['lastSubscriptionSync'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      // Existing fields
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'orgId': orgId,
      'role': role,
      'mustChangePassword': mustChangePassword,
      'createdAt': createdAt,
      'location': location,
      'officeId': officeId,

      // New subscription fields
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

  /// Create a copy with updated fields
  LawyerModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? phone,
    String? orgId,
    String? role,
    bool? mustChangePassword,
    Timestamp? createdAt,
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
  }) {
    return LawyerModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      orgId: orgId ?? this.orgId,
      role: role ?? this.role,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      createdAt: createdAt ?? this.createdAt,
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

  // Computed properties

  /// Days until subscription expires
  int get daysUntilExpiry {
    if (subscriptionEndDate == null) return 0;
    final now = DateTime.now();
    final end = subscriptionEndDate!.toDate();
    return end.difference(now).inDays;
  }

  /// Is subscription expiring soon (< 7 days)
  bool get isExpiringSoon => daysUntilExpiry > 0 && daysUntilExpiry <= 7;

  /// Is user in trial period
  bool get isInTrial => subscriptionStatus == SubscriptionStatus.trial;

  /// Display text for subscription status
  String get subscriptionStatusDisplay {
    if (isInTrial) {
      return 'Trial ($daysUntilExpiry days left)';
    }
    return subscriptionStatus.displayName;
  }
}
