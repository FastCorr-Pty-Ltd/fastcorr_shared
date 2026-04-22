/// FastCorr Shared Package
///
/// This package contains shared models, services, and UI components for FastCorr applications.
/// It enables unified communication between fastcorr_user and fastcorr_admin apps.

library fastcorr_shared;

// Export models
export 'models/unified_case_message.dart';
export 'models/upload_file_data.dart';
export 'models/case_model.dart';
export 'models/request_model.dart';
export 'models/contact_model.dart';
export 'models/address_model.dart';
export 'models/court_model.dart';
export 'models/org_model.dart';
export 'models/trial_model.dart';
export 'models/timer_extension.dart';

// Export state machine (Phase A — declaration only; no callers routed yet).
export 'state/state.dart';

// Export services
export 'services/office_routing_service.dart';
export 'services/unified_case_communication_service.dart';
export 'services/unified_status_sync_service.dart';
export 'services/unified_case_state_sync_service.dart';
export 'services/document_service.dart';
export 'services/map_tracking_service.dart';

// Export UI components
export 'ui/communication/shared_communication_viewmodel.dart';
export 'ui/communication/shared_communication_widget.dart';
export 'ui/communication/widgets/message_list_panel.dart';
export 'ui/communication/widgets/message_detail_panel.dart';
export 'ui/communication/widgets/compose_dialog.dart';

// Export document viewer
export 'ui/document/document_view.dart';
export 'ui/document/document_viewmodel.dart';
export 'ui/document/document_view_helper.dart';

// Export court dates functionality
export 'ui/court_dates/court_dates_viewmodel.dart';

// Export map tracking functionality
export 'ui/map_tracking/map_tracking_view.dart';
export 'ui/map_tracking/map_tracking_viewmodel.dart';
