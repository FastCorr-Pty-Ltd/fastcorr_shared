/// Subscription status for premium users
enum SubscriptionStatus {
  /// User has never subscribed
  none,

  /// User is in trial period
  trial,

  /// User has active subscription
  active,

  /// Subscription has expired
  expired,

  /// Payment failed but in grace period
  gracePeriod,

  /// User cancelled (but may still have access until period end)
  cancelled;

  /// Check if user has premium access
  bool get isPremium {
    return this == SubscriptionStatus.active ||
        this == SubscriptionStatus.trial ||
        this == SubscriptionStatus.gracePeriod;
  }

  /// Check if subscription is active (not expired/cancelled)
  bool get isActive {
    return this == SubscriptionStatus.active ||
        this == SubscriptionStatus.trial;
  }

  /// Display name for UI
  String get displayName {
    switch (this) {
      case SubscriptionStatus.none:
        return 'No Subscription';
      case SubscriptionStatus.trial:
        return 'Trial';
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.gracePeriod:
        return 'Grace Period';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
    }
  }
}
