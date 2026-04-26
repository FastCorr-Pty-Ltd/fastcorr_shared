import 'package:fastcorr_shared/models/models.dart';
import 'package:fastcorr_shared/services/tracked_map_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Generic map widget bound to a [TrackedMapState].
///
/// Renders the driver, pickup, dropoffs and route polyline. Designed to be
/// composed into per-app responsive layouts (mobile / tablet / desktop)
/// without forcing a particular page chrome.
///
/// Marker icons use sensible defaults (`hueRed` for driver, `hueBlue` for
/// pickup, status-coloured for dropoffs) but every visual choice can be
/// overridden via the constructor for apps that ship custom assets.
class TrackingMap extends StatelessWidget {
  const TrackingMap({
    super.key,
    required this.state,
    this.onMapCreated,
    this.mapType = MapType.normal,
    this.driverIcon,
    this.pickupIcon,
    this.dropoffIconFor,
    this.onDriverTap,
    this.onDropoffTap,
    this.onPickupTap,
    this.polylineColor,
    this.polylineWidth = 4,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = true,
    this.trafficEnabled = true,
    this.fallbackCenter = const LatLng(-33.8688, 18.4221),
    this.fallbackZoom = 12,
    this.emptyPlaceholder,
  });

  /// Combined order + driver + route state produced by [TrackedMapService].
  final TrackedMapState state;

  /// Forwarded to [GoogleMap.onMapCreated]. Hosts typically capture the
  /// controller in their viewmodel so they can call `animateCamera` later.
  final void Function(GoogleMapController)? onMapCreated;

  final MapType mapType;

  /// Override the driver marker icon (e.g. a custom car bitmap).
  final BitmapDescriptor? driverIcon;

  /// Override the pickup marker icon.
  final BitmapDescriptor? pickupIcon;

  /// Override the per-dropoff marker icon. Receives the dropoff so callers
  /// can colour by status, sequence, etc.
  final BitmapDescriptor Function(TrackedDropoff dropoff)? dropoffIconFor;

  final VoidCallback? onDriverTap;
  final ValueChanged<TrackedDropoff>? onDropoffTap;
  final VoidCallback? onPickupTap;

  final Color? polylineColor;
  final double polylineWidth;

  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool trafficEnabled;

  /// Camera target / zoom used when no order data has loaded yet (avoids
  /// showing a black canvas before the first emission).
  final LatLng fallbackCenter;
  final double fallbackZoom;

  /// Rendered when [state] is in the `initial` phase or has no order yet.
  final Widget? emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    if (!state.hasOrder) {
      return emptyPlaceholder ??
          const Center(child: CircularProgressIndicator());
    }

    final order = state.order!;
    final theme = Theme.of(context);

    return GoogleMap(
      mapType: mapType,
      initialCameraPosition: _initialCameraPosition(order, state),
      onMapCreated: onMapCreated,
      markers: _buildMarkers(order),
      polylines: _buildPolylines(theme),
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      buildingsEnabled: true,
      trafficEnabled: trafficEnabled,
    );
  }

  CameraPosition _initialCameraPosition(
    TrackedOrder order,
    TrackedMapState state,
  ) {
    final pickup = order.pickup;
    if (pickup != null) {
      return CameraPosition(
        target: LatLng(pickup.latitude, pickup.longitude),
        zoom: 14,
      );
    }
    final driverLoc = state.driverLocation;
    if (driverLoc != null) {
      return CameraPosition(target: driverLoc, zoom: 14);
    }
    if (order.dropoffs.isNotEmpty) {
      final first = order.dropoffs.first.location;
      return CameraPosition(
        target: LatLng(first.latitude, first.longitude),
        zoom: 14,
      );
    }
    return CameraPosition(target: fallbackCenter, zoom: fallbackZoom);
  }

  Set<Marker> _buildMarkers(TrackedOrder order) {
    final out = <Marker>{};

    final pickup = order.pickup;
    if (pickup != null) {
      out.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pickup.latitude, pickup.longitude),
        icon: pickupIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: pickup.label ?? 'Pickup',
          snippet: pickup.address,
        ),
        onTap: onPickupTap,
      ));
    }

    for (final d in order.dropoffs) {
      out.add(Marker(
        markerId: MarkerId('dropoff_${d.sequence}'),
        position: LatLng(d.location.latitude, d.location.longitude),
        icon: dropoffIconFor?.call(d) ??
            BitmapDescriptor.defaultMarkerWithHue(_dropoffHue(d.status)),
        infoWindow: InfoWindow(
          title: d.contactName ?? 'Dropoff ${d.sequence}',
          snippet: d.location.address,
        ),
        onTap: onDropoffTap == null ? null : () => onDropoffTap!(d),
      ));
    }

    final driverLoc = state.driverLocation;
    if (driverLoc != null) {
      out.add(Marker(
        markerId: const MarkerId('driver'),
        position: driverLoc,
        icon: driverIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: state.driver?.name ?? 'Driver',
          snippet: state.driver?.vehicleInfo,
        ),
        onTap: onDriverTap,
      ));
    }

    return out;
  }

  Set<Polyline> _buildPolylines(ThemeData theme) {
    if (!state.hasRoute) return const <Polyline>{};
    return {
      Polyline(
        polylineId: const PolylineId('tracked_route'),
        points: state.polyline,
        color: polylineColor ?? theme.colorScheme.primary,
        width: polylineWidth.toInt(),
        geodesic: true,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  static double _dropoffHue(AddressStatus status) {
    switch (status) {
      case AddressStatus.delivered:
        return BitmapDescriptor.hueGreen;
      case AddressStatus.arrived:
        return BitmapDescriptor.hueViolet;
      case AddressStatus.canceled:
        return BitmapDescriptor.hueRed;
      case AddressStatus.pending:
        return BitmapDescriptor.hueOrange;
    }
  }
}
