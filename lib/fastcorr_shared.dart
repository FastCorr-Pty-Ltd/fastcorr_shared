/// FastCorr Shared Package
///
/// This package contains shared models, services, and UI components for FastCorr applications.
/// It enables unified communication between fastcorr_user and fastcorr_admin apps.

library fastcorr_shared;

// Export models
export 'models/unified_case_message.dart';

// Export services
export 'services/unified_case_communication_service.dart';
export 'services/unified_status_sync_service.dart';
export 'services/unified_case_state_sync_service.dart';

// Export UI components
export 'ui/communication/shared_communication_viewmodel.dart';
export 'ui/communication/shared_communication_widget.dart';
export 'ui/communication/widgets/message_list_panel.dart';
export 'ui/communication/widgets/message_detail_panel.dart';
export 'ui/communication/widgets/compose_dialog.dart';
