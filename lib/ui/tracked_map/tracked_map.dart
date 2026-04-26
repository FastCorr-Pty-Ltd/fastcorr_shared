/// Shared widgets that compose into a tracking screen.
///
/// All widgets bind to types from `fastcorr_shared` only ([TrackedOrder],
/// [TrackedDropoff], [TrackedDriver], [TrackedMapState], [ChatMsgModel])
/// — no per-app imports — so user, admin and (future) driver apps can
/// drop them into their own responsive layouts without coupling.
library;

export 'tracking_map.dart';
export 'driver_info_panel.dart';
export 'location_status_list.dart';
export 'delivery_info_panel.dart';
export 'chat_panel.dart';
export 'tracked_map_viewmodel_base.dart';
