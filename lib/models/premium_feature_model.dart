/// Premium features that require a subscription
enum PremiumFeature {
  /// Billing & Invoicing features
  billing('Billing & Invoicing'),
  
  /// Advanced analytics and reports
  advancedAnalytics('Advanced Analytics'),
  
  /// Unlimited case storage
  unlimitedCases('Unlimited Cases'),
  
  /// Unlimited document storage
  unlimitedStorage('Unlimited Document Storage'),
  
  /// Bulk data export
  bulkExport('Bulk Export'),
  
  /// API access (future feature)
  apiAccess('API Access');
  
  const PremiumFeature(this.displayName);
  
  final String displayName;
  
  /// Get feature description
  String get description {
    switch (this) {
      case PremiumFeature.billing:
        return 'Create and manage client invoices, track fees and disbursements';
      case PremiumFeature.advancedAnalytics:
        return 'Access detailed analytics, performance metrics, and custom reports';
      case PremiumFeature.unlimitedCases:
        return 'Create unlimited cases with no storage restrictions';
      case PremiumFeature.unlimitedStorage:
        return 'Upload unlimited documents with no size limits';
      case PremiumFeature.bulkExport:
        return 'Export data in bulk to CSV, Excel, and other formats';
      case PremiumFeature.apiAccess:
        return 'Access FastCorr API for integrations and automation';
    }
  }
  
  /// Get list of benefits for this feature
  List<String> get benefits {
    switch (this) {
      case PremiumFeature.billing:
        return [
          'Create professional client invoices',
          'Track fees and disbursements',
          'Generate PDF invoices automatically',
          'Financial reporting dashboards',
          'Payment tracking and reconciliation',
        ];
      case PremiumFeature.advancedAnalytics:
        return [
          'Detailed case performance metrics',
          'Revenue and profitability reports',
          'Custom report builder',
          'Data visualization tools',
          'Export analytics data',
        ];
      case PremiumFeature.unlimitedCases:
        return [
          'No limit on active cases',
          'Full historical access',
          'No archival requirements',
          'Unlimited case templates',
        ];
      case PremiumFeature.unlimitedStorage:
        return [
          'Unlimited file uploads',
          'No storage cap per seat',
          'All file types supported',
          'High-resolution document storage',
        ];
      case PremiumFeature.bulkExport:
        return [
          'Export cases to CSV/Excel',
          'Bulk data operations',
          'Archive management',
          'Scheduled exports',
        ];
      case PremiumFeature.apiAccess:
        return [
          'REST API access',
          'Webhook integrations',
          'Third-party connections',
          'Custom integrations',
        ];
    }
  }
  
  /// Icon name for UI (using Material Icons)
  String get iconName {
    switch (this) {
      case PremiumFeature.billing:
        return 'receipt_long';
      case PremiumFeature.advancedAnalytics:
        return 'analytics';
      case PremiumFeature.unlimitedCases:
        return 'folder_open';
      case PremiumFeature.unlimitedStorage:
        return 'cloud_upload';
      case PremiumFeature.bulkExport:
        return 'file_download';
      case PremiumFeature.apiAccess:
        return 'api';
    }
  }
}
