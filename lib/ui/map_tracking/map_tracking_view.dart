import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:iconly/iconly.dart';
import 'package:stacked/stacked.dart';

import 'map_tracking_viewmodel.dart';

/// Generic map tracking view that works with both user and admin apps
/// Uses generic styling that can be customized by each app
class MapTrackingView extends ViewModelWidget<MapTrackingViewModel> {
  const MapTrackingView({
    super.key,
    required this.orderId,
    required this.orgId,
    this.title = 'Live Tracking',
    this.primaryColor = Colors.blue,
    this.onPrimaryColor = Colors.white,
    this.onSurfaceColor = Colors.black,
    this.surfaceColor = Colors.white,
    this.showDriverControls = true,
    this.showInfoPanel = true,
  });

  final String orderId;
  final String orgId;
  final String title;
  final Color primaryColor;
  final Color onPrimaryColor;
  final Color onSurfaceColor;
  final Color surfaceColor;
  final bool showDriverControls;
  final bool showInfoPanel;

  @override
  Widget build(BuildContext context, MapTrackingViewModel viewModel) {
    return ViewModelBuilder<MapTrackingViewModel>.reactive(
      viewModelBuilder: () => viewModel,
      onViewModelReady: (viewModel) =>
          viewModel.initModel(orderId: orderId, orgId: orgId),
      builder: (context, viewModel, child) => Scaffold(
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: onPrimaryColor,
          title: Row(
            children: [
              Icon(IconlyBroken.location, color: onPrimaryColor),
              const SizedBox(width: 12),
              Text(
                '$title - Order #$orderId',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  color: onPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: onPrimaryColor),
              onPressed: () => viewModel.refreshTracking(),
            ),
            IconButton(
              icon: Icon(IconlyBroken.close_square, color: onPrimaryColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: Stack(
          children: [
            // Google Map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _calculateOptimalMapCenter(viewModel),
                zoom: _calculateOptimalZoom(viewModel),
              ),
              onMapCreated: (controller) {
                viewModel.mapController.complete(controller);
              },
              markers: viewModel.markers,
              polylines: viewModel.visiblePolylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

            // Floating Info Panel
            if (showInfoPanel)
              Positioned(
                top: 20,
                left: MediaQuery.of(context).size.width * 0.1,
                right: MediaQuery.of(context).size.width * 0.1,
                child: _buildInfoPanel(context, viewModel),
              ),

            // Driver Controls
            if (showDriverControls)
              Positioned(
                bottom: 20,
                left: 20,
                child: _buildDriverControls(context, viewModel),
              ),

            // Loading Overlay
            if (viewModel.isBusy)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context, MapTrackingViewModel viewModel) {
    return Card(
      elevation: 8,
      color: surfaceColor.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(IconlyBroken.location, color: primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewModel.driver != null
                            ? 'Live Tracking'
                            : 'Order Details',
                        style: Theme.of(context).textTheme.titleMedium!
                            .copyWith(
                              color: onSurfaceColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Order #$orderId',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: onSurfaceColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildETAInfo(context, viewModel)),
                _buildStatusIndicator(context, viewModel),
              ],
            ),

            const SizedBox(height: 16),

            // Driver Info or Assignment Status
            if (viewModel.order?['driverId']?.toString().isNotEmpty ==
                true) ...[
              _buildDriverInfo(context, viewModel),
              const SizedBox(height: 12),
            ] else ...[
              _buildAssignmentStatus(context, viewModel),
              const SizedBox(height: 12),
            ],

            // Office Info
            if (viewModel.office != null) ...[
              _buildOfficeInfo(context, viewModel),
              const SizedBox(height: 12),
            ],

            // Dropoff Info
            if (viewModel.order?['dropoffList'] != null) ...[
              _buildDropoffInfo(context, viewModel),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(
    BuildContext context,
    MapTrackingViewModel viewModel,
  ) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (viewModel.order?['completedAt'] != null) {
      statusColor = Colors.green;
      statusText = 'Completed';
      statusIcon = IconlyBroken.tick_square;
    } else if (viewModel.order?['pickedupAt'] != null) {
      statusColor = primaryColor;
      statusText = 'In Transit';
      statusIcon = IconlyBroken.location;
    } else if (viewModel.order?['acceptedAt'] != null) {
      statusColor = Colors.orange;
      statusText = 'Accepted';
      statusIcon = IconlyBroken.tick_square;
    } else {
      statusColor = onSurfaceColor.withValues(alpha: 0.3);
      statusText = 'Pending';
      statusIcon = IconlyBroken.time_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 12),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfo(
    BuildContext context,
    MapTrackingViewModel viewModel,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            child: Icon(IconlyBroken.profile, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.driver?['name'] ?? 'Driver',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: onSurfaceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Vehicle: ${viewModel.driver?['vehiclePlate'] ?? 'N/A'}',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: onSurfaceColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => viewModel.callDriver(),
            icon: Icon(IconlyBroken.call, color: primaryColor, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildETAInfo(BuildContext context, MapTrackingViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(IconlyBroken.time_circle, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated Arrival',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: onSurfaceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  viewModel.etaText ?? 'Calculating...',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentStatus(
    BuildContext context,
    MapTrackingViewModel viewModel,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.withValues(alpha: 0.1),
            child: Icon(Icons.pending, color: Colors.orange, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Awaiting Driver Assignment',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: onSurfaceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Your order is pending and will be assigned to a driver soon',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: onSurfaceColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeInfo(
    BuildContext context,
    MapTrackingViewModel viewModel,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onSurfaceColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(IconlyBroken.location, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Office Location',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: onSurfaceColor.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${viewModel.office?['address'] ?? 'N/A'}, ${viewModel.office?['city'] ?? 'N/A'}',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: onSurfaceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropoffInfo(
    BuildContext context,
    MapTrackingViewModel viewModel,
  ) {
    final dropoffList = viewModel.order?['dropoffList'] as List<dynamic>?;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onSurfaceColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(IconlyBroken.location, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dropoff Points',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: onSurfaceColor.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  '${dropoffList?.length ?? 0} dropoffs',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: onSurfaceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverControls(
    BuildContext context,
    MapTrackingViewModel viewModel,
  ) {
    return Column(
      children: [
        // Center on Office Button
        if (viewModel.office != null) ...[
          FloatingActionButton(
            heroTag: 'centerOffice',
            onPressed: () => viewModel.centerOnOffice(),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            child: const Icon(Icons.business),
          ),
          const SizedBox(height: 12),
        ],

        // Center on Driver Button
        if (viewModel.driverPosition != null) ...[
          FloatingActionButton(
            heroTag: 'centerDriver',
            onPressed: () => viewModel.centerOnDriver(),
            backgroundColor: primaryColor,
            foregroundColor: onPrimaryColor,
            child: const Icon(IconlyBroken.location),
          ),
          const SizedBox(height: 12),
        ],

        // Center on All Locations Button
        if (viewModel.markers.length > 1) ...[
          FloatingActionButton(
            heroTag: 'centerAll',
            onPressed: () => viewModel.centerOnAllLocations(),
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            child: const Icon(Icons.center_focus_strong),
          ),
          const SizedBox(height: 12),
        ],

        // Refresh Route Button
        FloatingActionButton(
          heroTag: 'refreshRoute',
          onPressed: () => viewModel.refreshRoute(),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          child: const Icon(Icons.refresh),
        ),
        const SizedBox(height: 12),

        // Test Route Button (for debugging)
        FloatingActionButton(
          heroTag: 'testRoute',
          onPressed: () => viewModel.createTestRoute(),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          child: const Icon(Icons.bug_report),
        ),
        const SizedBox(height: 12),

        // Toggle Route Button
        FloatingActionButton(
          heroTag: 'toggleRoute',
          onPressed: () => viewModel.toggleRouteVisibility(),
          backgroundColor: viewModel.polylines.isNotEmpty
              ? Colors.green
              : Colors.grey,
          foregroundColor: Colors.white,
          child: Icon(
            viewModel.polylines.isNotEmpty ? Icons.route : Icons.route_outlined,
          ),
        ),
        const SizedBox(height: 12),

        // Zoom Controls
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              IconButton(
                onPressed: () => viewModel.zoomIn(),
                icon: Icon(IconlyBroken.plus, color: primaryColor),
              ),
              IconButton(
                onPressed: () => viewModel.zoomOut(),
                icon: Icon(Icons.remove, color: primaryColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  LatLng _calculateOptimalMapCenter(MapTrackingViewModel viewModel) {
    // Priority 1: Office location (pickup point)
    if (viewModel.office?['location'] != null) {
      final location = viewModel.office!['location'] as Map<String, dynamic>;
      return LatLng(
        location['latitude'] as double,
        location['longitude'] as double,
      );
    }

    // Priority 2: Driver position
    if (viewModel.driverPosition != null) {
      return viewModel.driverPosition!;
    }

    // Priority 3: First dropoff location
    if (viewModel.markers.isNotEmpty) {
      // Find the first dropoff marker
      final dropoffMarker = viewModel.markers.firstWhere(
        (marker) => marker.markerId.value.startsWith('dropoff_'),
        orElse: () => viewModel.markers.first,
      );
      return dropoffMarker.position;
    }

    // Priority 4: Default location
    return const LatLng(-33.8737, 18.6340); // Default to Cape Town
  }

  double _calculateOptimalZoom(MapTrackingViewModel viewModel) {
    // If we have office + multiple dropoffs, zoom out to show all
    if (viewModel.office?['location'] != null &&
        viewModel.order?['dropoffList'] != null) {
      final dropoffList = viewModel.order!['dropoffList'] as List<dynamic>;
      if (dropoffList.length > 1) {
        return 11.0; // Zoom out to show multiple locations
      }
    }

    // If we have office + single dropoff, medium zoom
    if (viewModel.office?['location'] != null &&
        viewModel.order?['dropoffList'] != null) {
      final dropoffList = viewModel.order!['dropoffList'] as List<dynamic>;
      if (dropoffList.length == 1) {
        return 13.0; // Good zoom for office to single dropoff
      }
    }

    // If we have multiple markers, zoom out
    if (viewModel.markers.length > 1) {
      return 12.0; // Zoom out to show multiple markers
    } else if (viewModel.markers.length == 1) {
      return 15.0; // Good zoom for single marker
    }

    return 13.5; // Default zoom for no markers
  }
}

