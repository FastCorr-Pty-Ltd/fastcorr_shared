import 'dart:async';
import 'dart:developer';

import 'package:fastcorr_shared/models/chat_msg_model.dart';
import 'package:fastcorr_shared/models/tracked_order.dart';
import 'package:fastcorr_shared/services/tracked_map_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared base for the user / admin map-tracking viewmodels.
///
/// Owns everything that's identical across apps:
///   * lifecycle of the [TrackedMapService] subscription,
///   * camera helpers (fit-to-all, center on driver / pickup / dropoff),
///   * UI toggles (driver info panel, location list, chat, map type),
///   * `callDriver` (url_launcher) and `goBack` (router),
///   * the shape of `sendChatMessage` (build the [ChatMsgModel],
///     hand off to the per-app ChatService).
///
/// Per-app subclasses only have to plug in three small hooks:
///   1. [chatMessagesFor] — return the live message stream from the
///      app's own ChatService.
///   2. [resolveSender] — return the current user's display name + role
///      (client for user app, support for admin app).
///   3. [deliverMessage] — call the app's ChatService to persist the
///      outgoing message.
///
/// We deliberately don't reach into a per-app `locator` from shared code:
/// the apps inject [TrackedMapService] and [RouterService] via the
/// constructor. That keeps this file dependency-free at compile time.
abstract class TrackedMapViewModelBase extends BaseViewModel {
  TrackedMapViewModelBase({
    required TrackedMapService trackingService,
    required RouterService routerService,
  })  : _trackingServ = trackingService,
        _routerServ = routerService;

  final TrackedMapService _trackingServ;
  final RouterService _routerServ;

  String? _orderId;
  TrackedMapState _state = TrackedMapState.initial();
  GoogleMapController? _mapController;
  StreamSubscription<TrackedMapState>? _subscription;

  // UI panel state — owned here so all responsive layouts (mobile, tablet,
  // desktop) render the same overlays regardless of breakpoint.
  bool _showDriverInfo = true;
  bool _showLocationList = true;
  bool _showChat = false;
  MapType _mapType = MapType.normal;
  bool _initialFitDone = false;

  // ---- State surface ----

  String? get orderId => _orderId;

  /// Latest combined state from [TrackedMapService].
  TrackedMapState get state => _state;

  TrackedOrder? get order => _state.order;
  TrackedDriver? get driver => _state.driver;
  LatLng? get driverLocation => _state.driverLocation;

  bool get hasOrder => _state.hasOrder;
  bool get hasDriver => _state.hasDriver;
  bool get hasDriverLocation => _state.hasDriverLocation;

  /// Driver is "online" if we received a ping in the last minute.
  bool get isDriverOnline {
    final updated = _state.driverLocationUpdatedAt;
    if (updated == null) return false;
    return DateTime.now().difference(updated).inSeconds < 60;
  }

  bool get showDriverInfo => _showDriverInfo;
  bool get showLocationList => _showLocationList;
  bool get showChat => _showChat;
  MapType get mapType => _mapType;

  /// Live chat stream — defers to the per-app ChatService via
  /// [chatMessagesFor]. Returns an empty stream until [initTracking]
  /// has set an [orderId].
  Stream<List<ChatMsgModel>> get chatStream =>
      _orderId == null ? const Stream.empty() : chatMessagesFor(_orderId!);

  // ---- Lifecycle ----

  Future<void> initTracking(String orderId, [String? orgId]) async {
    _orderId = orderId;
    setBusy(true);
    try {
      await _subscription?.cancel();
      _subscription = _trackingServ.trackOrder(orderId).listen(
        _onState,
        onError: (e, s) {
          log('Map tracking stream error: $e');
          setError(e);
        },
      );
    } catch (e) {
      log('Error initialising tracking: $e');
      setError(e);
    } finally {
      setBusy(false);
    }
  }

  void _onState(TrackedMapState next) {
    _state = next;

    // Auto-fit the camera to all points exactly once, after the first
    // emission that has bounds — avoids the camera jumping on every
    // driver ping while still framing the trip on entry.
    if (!_initialFitDone &&
        _state.bounds != null &&
        _mapController != null) {
      _initialFitDone = true;
      _animateToBounds(_state.bounds!);
    }

    notifyListeners();
  }

  // ---- Camera ----

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    if (!_initialFitDone && _state.bounds != null) {
      _initialFitDone = true;
      _animateToBounds(_state.bounds!);
    }
  }

  void fitToAll() {
    final bounds = _state.bounds;
    if (bounds != null && _mapController != null) {
      _animateToBounds(bounds);
    }
  }

  void centerOnDriver() {
    final loc = _state.driverLocation;
    if (loc != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 16));
    }
  }

  void centerOnPickup() {
    final p = _state.order?.pickup;
    if (p != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(p.latitude, p.longitude), 16),
      );
    }
  }

  void centerOnDropoff(TrackedDropoff dropoff) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(dropoff.location.latitude, dropoff.location.longitude),
        16,
      ),
    );
  }

  void _animateToBounds(LatLngBounds bounds) {
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ---- UI toggles ----

  void toggleDriverInfo() {
    _showDriverInfo = !_showDriverInfo;
    notifyListeners();
  }

  void toggleLocationList() {
    _showLocationList = !_showLocationList;
    if (_showLocationList) _showChat = false;
    notifyListeners();
  }

  void toggleChat() {
    _showChat = !_showChat;
    if (_showChat) _showLocationList = false;
    notifyListeners();
  }

  void changeMapType(MapType type) {
    _mapType = type;
    notifyListeners();
  }

  // ---- Driver actions ----

  Future<void> callDriver() async {
    final phone = _state.driver?.phone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ---- Chat ----

  /// Per-app: return the live chat stream from the app's ChatService.
  @protected
  Stream<List<ChatMsgModel>> chatMessagesFor(String orderId);

  /// Per-app: resolve the current user as a (name, role) pair. Return
  /// null if no user is signed in / can be loaded.
  @protected
  Future<({String name, SenderRole role})?> resolveSender();

  /// Per-app: persist the outgoing message via the app's ChatService.
  @protected
  Future<void> deliverMessage(String orderId, ChatMsgModel msg);

  Future<void> sendChatMessage(String text) async {
    if (_orderId == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      final ident = await resolveSender();
      if (ident == null) {
        log('sendChatMessage: no sender identity');
        return;
      }
      await deliverMessage(
        _orderId!,
        ChatMsgModel(
          id: '',
          senderName: ident.name,
          senderRole: ident.role,
          content: trimmed,
          type: MessageType.text,
          createdAt: DateTime.now(),
        ),
      );
    } catch (e) {
      log('Error sending chat message: $e');
      rethrow;
    }
  }

  // ---- Navigation ----

  void goBack() => _routerServ.back();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
