import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/config/maps_keys.dart';
import 'package:fastcorr_shared/models/models.dart';
import 'package:fastcorr_shared/services/tracked_order_repository.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Combined view-state for an order being tracked on a map.
///
/// Built by [TrackedMapService.trackOrder] from three asynchronous sources:
///
/// 1. The unified [TrackedOrder] stream (litigation or delivery).
/// 2. The driver's `drivers/{id}` document (location + profile).
/// 3. The Google Routes API (polyline computation).
///
/// View / viewmodel layers should depend only on this type — they never
/// need to know whether the order originates from `litigation_requests` or
/// `delivery_orders`, or how the polyline was calculated.
class TrackedMapState {
  /// Lifecycle phase. `initial` is emitted exactly once before any data has
  /// arrived (lets callers render skeletons without inspecting nullable
  /// fields). `loaded` after the first successful order emission.
  /// `error` carries [error] when the order stream fails terminally.
  final TrackedMapPhase phase;

  /// The order projection. `null` only while [phase] is `initial`.
  final TrackedOrder? order;

  /// The assigned driver, enriched with name/phone/vehicle when the
  /// `drivers/{id}` document is reachable. `null` if no driver is assigned
  /// or the document hasn't been read yet.
  final TrackedDriver? driver;

  /// Driver's most recent reported coordinates, or `null` if unavailable.
  final LatLng? driverLocation;

  /// `lastLocationUpdate` from the driver document. Used by callers to
  /// show "updated N seconds ago" hints.
  final DateTime? driverLocationUpdatedAt;

  /// Encoded route polyline as decoded `LatLng` points. Empty until the
  /// first route calculation completes (or when no route can be computed,
  /// e.g. before pickup has coordinates and there's no driver location).
  final List<LatLng> polyline;

  /// Bounds covering all known points (driver, pickup, dropoffs, route).
  /// `null` when no coordinates are available yet.
  final LatLngBounds? bounds;

  /// Populated only when [phase] is `error`.
  final Object? error;

  const TrackedMapState({
    required this.phase,
    this.order,
    this.driver,
    this.driverLocation,
    this.driverLocationUpdatedAt,
    this.polyline = const [],
    this.bounds,
    this.error,
  });

  factory TrackedMapState.initial() =>
      const TrackedMapState(phase: TrackedMapPhase.initial);

  bool get hasOrder => order != null;
  bool get hasDriver => driver != null;
  bool get hasDriverLocation => driverLocation != null;
  bool get hasRoute => polyline.isNotEmpty;

  TrackedMapState copyWith({
    TrackedMapPhase? phase,
    TrackedOrder? order,
    TrackedDriver? driver,
    LatLng? driverLocation,
    DateTime? driverLocationUpdatedAt,
    List<LatLng>? polyline,
    LatLngBounds? bounds,
    Object? error,
    bool clearDriver = false,
    bool clearDriverLocation = false,
    bool clearBounds = false,
    bool clearError = false,
  }) {
    return TrackedMapState(
      phase: phase ?? this.phase,
      order: order ?? this.order,
      driver: clearDriver ? null : (driver ?? this.driver),
      driverLocation:
          clearDriverLocation ? null : (driverLocation ?? this.driverLocation),
      driverLocationUpdatedAt: clearDriverLocation
          ? null
          : (driverLocationUpdatedAt ?? this.driverLocationUpdatedAt),
      polyline: polyline ?? this.polyline,
      bounds: clearBounds ? null : (bounds ?? this.bounds),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

enum TrackedMapPhase { initial, loaded, error }

/// Concrete map-tracking service. Composes a [TrackedOrderRepository] with
/// a driver-location stream and a Routes-API client into a single
/// [TrackedMapState] stream.
///
/// Stateless at the service level — every call to [trackOrder] creates an
/// independent session that owns its own subscriptions and is torn down on
/// stream cancellation.
class TrackedMapService {
  TrackedMapService({
    FirebaseFirestore? firestore,
    TrackedOrderRepository? repository,
    String? googleMapsApiKey,
    double driverMoveThresholdMeters = 50.0,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _repository =
            repository ?? TrackedOrderRepository(firestore: firestore),
        _apiKey = googleMapsApiKey ?? googleMapsHttpApiKey,
        _moveThresholdMeters = driverMoveThresholdMeters;

  final FirebaseFirestore _firestore;
  final TrackedOrderRepository _repository;
  final String _apiKey;

  /// Distance (in metres) the driver must move before the route polyline
  /// is recomputed. Tuned to balance UI snappiness against Routes API
  /// quota: at 50 m a typical urban trip recomputes ~20-40 times rather
  /// than once per GPS sample (~2-3 / s).
  final double _moveThresholdMeters;

  static const String _driversCollection = 'drivers';

  // ---- Public API -------------------------------------------------------

  /// Live, combined map-tracking state. Each emission reflects the current
  /// merge of order + driver + computed route.
  ///
  /// Cancelling the returned subscription tears down all underlying
  /// listeners and stops Routes API calls.
  Stream<TrackedMapState> trackOrder(String orderId) {
    late final StreamController<TrackedMapState> controller;
    late final _TrackingSession session;

    controller = StreamController<TrackedMapState>(
      onListen: () => session.start(),
      onCancel: () => session.dispose(),
    );

    session = _TrackingSession(
      orderId: orderId,
      firestore: _firestore,
      repository: _repository,
      apiKey: _apiKey,
      moveThresholdMeters: _moveThresholdMeters,
      sink: controller,
    );

    return controller.stream;
  }

  /// One-shot route calculation between [origin] and [destinations]. The
  /// last destination is treated as the final point; intermediate ones
  /// become waypoints. Falls back to a straight-line route on API error.
  Future<List<LatLng>> calculateRoute({
    required LatLng origin,
    required List<LatLng> destinations,
    TravelMode mode = TravelMode.driving,
    bool optimizeWaypoints = true,
  }) {
    return _RouteCalculator(apiKey: _apiKey).compute(
      origin: origin,
      destinations: destinations,
      mode: mode,
      optimizeWaypoints: optimizeWaypoints,
    );
  }

  /// Distance (in metres) between two points using the haversine formula.
  /// Exposed for callers that want to render distance hints without
  /// hitting the network.
  static double distanceMeters(LatLng a, LatLng b) =>
      _Geo.haversineMeters(a, b);
}

// =============================================================================
// Internal: per-stream session
// =============================================================================

/// Owns the lifetime of a single `trackOrder` subscription.
///
/// Composes:
///
/// * `_orderSub` — subscription to the unified [TrackedOrder] stream.
/// * `_driverSub` — subscription to the assigned driver's `drivers/{id}` doc;
///   re-created when the order's `driverId` changes.
///
/// Polyline recomputation is debounced by a "route fingerprint" (set of
/// lat/lng waypoints rounded to 5 decimals) plus a movement threshold on
/// the driver location, so that high-frequency driver pings don't trigger
/// a Routes API call on every emission.
class _TrackingSession {
  _TrackingSession({
    required this.orderId,
    required this.firestore,
    required this.repository,
    required this.apiKey,
    required this.moveThresholdMeters,
    required this.sink,
  }) : _routeCalculator = _RouteCalculator(apiKey: apiKey);

  final String orderId;
  final FirebaseFirestore firestore;
  final TrackedOrderRepository repository;
  final String apiKey;
  final double moveThresholdMeters;
  final StreamController<TrackedMapState> sink;
  final _RouteCalculator _routeCalculator;

  StreamSubscription<TrackedOrder>? _orderSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _driverSub;

  TrackedMapState _state = TrackedMapState.initial();

  String? _trackedDriverId;
  LatLng? _polylineSeenDriverLoc;
  String? _polylineSeenFingerprint;

  bool _disposed = false;

  void start() {
    sink.add(_state);
    _orderSub = repository.streamOrder(orderId).listen(
      _onOrder,
      onError: _onOrderError,
    );
  }

  Future<void> dispose() async {
    _disposed = true;
    await _orderSub?.cancel();
    await _driverSub?.cancel();
    _orderSub = null;
    _driverSub = null;
  }

  // ---- Order ----

  void _onOrder(TrackedOrder order) {
    if (_disposed) return;

    final newDriverId = order.driver?.id;
    if (newDriverId != _trackedDriverId) {
      _swapDriverSubscription(newDriverId);
    }

    _emit(_state.copyWith(
      phase: TrackedMapPhase.loaded,
      order: order,
      // Re-merge driver projection (id only) from the order if we don't
      // yet have an enriched one from the driver doc.
      driver: _state.driver ?? order.driver,
      bounds: _computeBounds(order, _state.driverLocation),
    ));

    _maybeRecomputeRoute();
  }

  void _onOrderError(Object error, StackTrace stack) {
    _emit(_state.copyWith(phase: TrackedMapPhase.error, error: error));
  }

  // ---- Driver ----

  void _swapDriverSubscription(String? newDriverId) {
    _driverSub?.cancel();
    _driverSub = null;
    _trackedDriverId = newDriverId;

    if (newDriverId == null || newDriverId.isEmpty) {
      _emit(_state.copyWith(
        clearDriver: true,
        clearDriverLocation: true,
      ));
      return;
    }

    _driverSub = firestore
        .collection(TrackedMapService._driversCollection)
        .doc(newDriverId)
        .snapshots()
        .listen(_onDriver, onError: (_) {/* ignore — keep last known */});
  }

  void _onDriver(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (_disposed) return;
    final data = snap.data();
    if (!snap.exists || data == null) return;

    final loc = data['currentLocation'];
    LatLng? location;
    if (loc is GeoPoint) {
      location = LatLng(loc.latitude, loc.longitude);
    }
    final lastUpdate = data['lastLocationUpdate'];
    final updatedAt = lastUpdate is Timestamp ? lastUpdate.toDate() : null;
    final enriched = _enrichDriver(snap.id, data);

    _emit(_state.copyWith(
      driver: enriched,
      driverLocation: location,
      driverLocationUpdatedAt: updatedAt,
      bounds: _computeBounds(_state.order, location),
    ));

    _maybeRecomputeRoute();
  }

  TrackedDriver _enrichDriver(String id, Map<String, dynamic> data) {
    final model = data['vehicleModel'] as String?;
    final plate = data['vehiclePlate'] as String?;
    String? vehicleInfo;
    if ((model != null && model.isNotEmpty) &&
        (plate != null && plate.isNotEmpty)) {
      vehicleInfo = '$model • $plate';
    } else if (model != null && model.isNotEmpty) {
      vehicleInfo = model;
    } else if (plate != null && plate.isNotEmpty) {
      vehicleInfo = plate;
    }
    return TrackedDriver(
      id: id,
      name: (data['name'] as String?)?.trim().isEmpty == true
          ? null
          : data['name'] as String?,
      phone: (data['phone'] as String?)?.trim().isEmpty == true
          ? null
          : data['phone'] as String?,
      vehicleInfo: vehicleInfo,
      photoUrl: (data['profilePic'] as String?)?.trim().isEmpty == true
          ? null
          : data['profilePic'] as String?,
    );
  }

  // ---- Route ----

  /// Decide whether the polyline needs to be recomputed and, if so, kick
  /// off an async fetch. Guarded by:
  ///
  /// 1. A waypoint fingerprint (skip when the set of stops is identical).
  /// 2. A driver-movement threshold (skip when the driver hasn't moved
  ///    further than [moveThresholdMeters]).
  void _maybeRecomputeRoute() {
    final order = _state.order;
    if (order == null) return;

    final waypoints = _routeWaypoints(order, _state.driverLocation);
    if (waypoints.length < 2) {
      if (_state.polyline.isNotEmpty) {
        _emit(_state.copyWith(polyline: const []));
      }
      return;
    }

    final fingerprint = _fingerprint(waypoints);
    final driverLoc = _state.driverLocation;
    final movedFar = _polylineSeenDriverLoc == null ||
        driverLoc == null ||
        _Geo.haversineMeters(_polylineSeenDriverLoc!, driverLoc) >=
            moveThresholdMeters;

    if (fingerprint == _polylineSeenFingerprint && !movedFar) return;

    _polylineSeenFingerprint = fingerprint;
    _polylineSeenDriverLoc = driverLoc;

    final origin = waypoints.first;
    final destinations = waypoints.sublist(1);

    _routeCalculator
        .compute(origin: origin, destinations: destinations)
        .then((points) {
      if (_disposed) return;
      _emit(_state.copyWith(
        polyline: points,
        bounds: _computeBounds(_state.order, _state.driverLocation,
            polyline: points),
      ));
    });
  }

  /// Build the ordered list of route waypoints.
  ///
  /// Origin selection:
  /// * Driver location if known (we want the route to start where the
  ///   driver actually is).
  /// * Otherwise pickup, so the user still sees a planned route before
  ///   the driver has shared a location.
  ///
  /// Stops in order:
  /// * Pickup — included as a waypoint *only if* pickup hasn't happened
  ///   yet AND we have a driver location (otherwise pickup is already
  ///   the origin or the route is meaningless).
  /// * Each unresolved dropoff in sequence.
  List<LatLng> _routeWaypoints(TrackedOrder order, LatLng? driverLoc) {
    final out = <LatLng>[];

    LatLng? originLatLng;
    if (driverLoc != null) {
      originLatLng = driverLoc;
    } else if (order.pickup != null) {
      originLatLng = LatLng(order.pickup!.latitude, order.pickup!.longitude);
    }
    if (originLatLng == null) return const [];
    out.add(originLatLng);

    final pickedUp = order.pickedupAt != null;
    if (!pickedUp && order.pickup != null && driverLoc != null) {
      out.add(LatLng(order.pickup!.latitude, order.pickup!.longitude));
    }

    for (final d in order.dropoffs) {
      if (d.isResolved) continue;
      out.add(LatLng(d.location.latitude, d.location.longitude));
    }
    return out;
  }

  String _fingerprint(List<LatLng> points) {
    final buf = StringBuffer();
    for (final p in points) {
      buf.write(p.latitude.toStringAsFixed(5));
      buf.write(',');
      buf.write(p.longitude.toStringAsFixed(5));
      buf.write(';');
    }
    return buf.toString();
  }

  // ---- Bounds ----

  LatLngBounds? _computeBounds(
    TrackedOrder? order,
    LatLng? driverLoc, {
    List<LatLng>? polyline,
  }) {
    final pts = <LatLng>[];
    if (order != null) {
      final p = order.pickup;
      if (p != null) pts.add(LatLng(p.latitude, p.longitude));
      for (final d in order.dropoffs) {
        pts.add(LatLng(d.location.latitude, d.location.longitude));
      }
    }
    if (driverLoc != null) pts.add(driverLoc);
    if (polyline != null) pts.addAll(polyline);

    if (pts.isEmpty) return null;
    var minLat = pts.first.latitude;
    var maxLat = pts.first.latitude;
    var minLng = pts.first.longitude;
    var maxLng = pts.first.longitude;
    for (final p in pts.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    // Pad slightly so markers aren't pressed against the edge.
    const pad = 0.0015;
    return LatLngBounds(
      southwest: LatLng(minLat - pad, minLng - pad),
      northeast: LatLng(maxLat + pad, maxLng + pad),
    );
  }

  // ---- Sink ----

  void _emit(TrackedMapState next) {
    if (_disposed || sink.isClosed) return;
    _state = next;
    sink.add(next);
  }
}

// =============================================================================
// Internal: route calculation
// =============================================================================

class _RouteCalculator {
  _RouteCalculator({required this.apiKey});

  final String apiKey;

  /// Computes a polyline via the Google Routes API (v2). Returns a
  /// straight-line fallback on API failure rather than empty, so the
  /// caller always has *something* to render.
  ///
  /// Uses `getRouteBetweenCoordinatesV2` (the current Routes API) rather
  /// than the deprecated `getRouteBetweenCoordinates` (legacy Directions
  /// API). Waypoints become `intermediates` in the new API.
  Future<List<LatLng>> compute({
    required LatLng origin,
    required List<LatLng> destinations,
    TravelMode mode = TravelMode.driving,
    bool optimizeWaypoints = true,
  }) async {
    if (destinations.isEmpty) return const [];

    final polylinePoints = PolylinePoints(apiKey: apiKey);
    try {
      final last = destinations.last;
      final intermediates = destinations.length > 1
          ? destinations
              .take(destinations.length - 1)
              .map((p) => PolylineWayPoint(
                    location: '${p.latitude},${p.longitude}',
                  ))
              .toList()
          : const <PolylineWayPoint>[];

      final response = await polylinePoints.getRouteBetweenCoordinatesV2(
        request: RoutesApiRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(last.latitude, last.longitude),
          intermediates: intermediates,
          travelMode: mode,
          optimizeWaypointOrder: optimizeWaypoints,
        ),
      );

      final points = response.primaryRoute?.polylinePoints;
      if (points == null || points.isEmpty) {
        return _fallback(origin, destinations);
      }
      return points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(growable: false);
    } catch (_) {
      return _fallback(origin, destinations);
    }
  }

  List<LatLng> _fallback(LatLng origin, List<LatLng> destinations) {
    return <LatLng>[origin, ...destinations];
  }
}

// =============================================================================
// Internal: geo helpers
// =============================================================================

class _Geo {
  static const double _earthRadiusMeters = 6371000.0;

  static double haversineMeters(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;

    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return _earthRadiusMeters * c;
  }
}
