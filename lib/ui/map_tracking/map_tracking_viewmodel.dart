import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:stacked/stacked.dart';

import '../../services/map_tracking_service.dart';

/// Generic map tracking ViewModel that works with both user and admin apps
/// Uses generic Map<String, dynamic> for data to avoid model dependencies
class MapTrackingViewModel extends BaseViewModel {
  final MapTrackingService _trackingService;

  MapTrackingViewModel(this._trackingService);

  // State variables
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _driver;
  LatLng? _driverPosition;
  Map<String, dynamic>? _office;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _routeVisible = true;
  String? _etaText;
  Completer<GoogleMapController> mapController = Completer();

  // Subscriptions
  StreamSubscription? _mapStateSubscription;
  StreamSubscription? _driverLocationSubscription;
  StreamSubscription? _officeSubscription;

  // Getters
  Map<String, dynamic>? get order => _order;
  Map<String, dynamic>? get driver => _driver;
  LatLng? get driverPosition => _driverPosition;
  Map<String, dynamic>? get office => _office;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  Set<Polyline> get visiblePolylines => _routeVisible ? _polylines : {};
  String? get etaText => _etaText;

  /// Initialize the map tracking for a specific order
  void initModel({required String orderId, required String orgId}) async {
    setBusy(true);
    notifyListeners();

    log('Initializing map tracking for order: $orderId');

    final orderStream = _trackingService.getOrderStream(
      orgId: orgId,
      orderId: orderId,
    );

    // Cancel any previous subscription before creating a new one
    _mapStateSubscription?.cancel();
    _officeSubscription?.cancel();

    _mapStateSubscription = orderStream.listen(
      (orderData) {
        log(
          'Order received: $orderId, driverId: ${orderData['driverId']}, officeId: ${orderData['officeId']}',
        );

        _order = orderData;

        // Fetch office data for pickup point
        _fetchOfficeData(orderData['officeId']);

        // Handle case where no driver is assigned yet
        if (orderData['driverId'] == null ||
            orderData['driverId'].toString().isEmpty) {
          log('No driver assigned to order yet - showing order details only');
          _driverPosition = null;
          _updateMapStateForUnassignedOrder(orgId);
        } else {
          log(
            'Driver assigned: ${orderData['driverId']} - starting location tracking',
          );
          _startDriverTracking(orderData);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          setBusy(false);
          notifyListeners();
        });
      },
      onError: (e, s) {
        log('Error in order stream: $e \n stack: $s');
        setBusy(false);
        notifyListeners();
      },
    );
  }

  void _fetchOfficeData(String officeId) {
    log('Fetching office data for officeId: $officeId');

    _officeSubscription?.cancel();
    _officeSubscription = _trackingService
        .getOfficeStream(officeId)
        .listen(
          (officeData) {
            _office = officeData;
            log(
              'Office data loaded: ${officeData?['officeName']} at ${officeData?['fullAddress']}',
            );

            // Update map state with office data
            if (_order != null) {
              if (_order!['driverId'] == null ||
                  _order!['driverId'].toString().isEmpty) {
                _updateMapStateForUnassignedOrder(_order!['orgId']);
              } else {
                _updateMapState(_order!['orgId']);
              }
            }

            notifyListeners();
          },
          onError: (e) {
            log('Error fetching office data: $e');
          },
        );
  }

  void _startDriverTracking(Map<String, dynamic> orderData) {
    // Cancel any existing driver tracking
    _driverLocationSubscription?.cancel();

    _driverLocationSubscription = _trackingService
        .getDriverLocationStream(orderData['driverId'])
        .listen(
          (driverPosition) {
            _driverPosition = driverPosition;
            log('Driver position updated: $driverPosition');
            _updateMapState(orderData['orgId']);
            notifyListeners();
          },
          onError: (e) {
            log('Error tracking driver location: $e');
            // Fallback to simulated location for testing
            log('Falling back to simulated driver location');
            _startSimulatedDriverTracking(orderData['orgId']);
          },
        );
  }

  void _startSimulatedDriverTracking(String orgId) {
    _driverLocationSubscription?.cancel();

    _driverLocationSubscription = _trackingService
        .getSimulatedDriverLocationStream()
        .listen(
          (driverPosition) {
            _driverPosition = driverPosition;
            log('Simulated driver position: $driverPosition');
            _updateMapState(orgId);
            notifyListeners();
          },
          onError: (e) {
            log('Error in simulated driver tracking: $e');
          },
        );
  }

  void _updateMapStateForUnassignedOrder(String orgId) async {
    log('=== UPDATING MAP STATE FOR UNASSIGNED ORDER ===');

    final newMarkers = <Marker>{};

    // Add office marker as pickup point
    if (_office != null && _office!['location'] != null) {
      final location = _office!['location'] as Map<String, dynamic>;
      newMarkers.add(
        Marker(
          markerId: const MarkerId('office_pickup'),
          position: LatLng(
            location['latitude'] as double,
            location['longitude'] as double,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Pickup: ${_office!['officeName']}',
            snippet: _office!['fullAddress'],
          ),
        ),
      );
      log('Added office pickup marker: ${_office!['officeName']}');
    }

    // Add markers for all dropoff locations
    if (_order!['dropoffList'] != null) {
      final dropoffList = _order!['dropoffList'] as List<dynamic>;
      for (var i = 0; i < dropoffList.length; i++) {
        final address = dropoffList[i] as Map<String, dynamic>;
        final contact = await _trackingService.getContact(
          contactId: address['contactId'],
          orgId: orgId,
        );
        if (contact != null && contact['location'] != null) {
          final location = contact['location'] as Map<String, dynamic>;
          newMarkers.add(
            Marker(
              markerId: MarkerId('dropoff_${i}_${contact['name']}'),
              position: LatLng(
                location['latitude'] as double,
                location['longitude'] as double,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              infoWindow: InfoWindow(
                title: 'Dropoff ${i + 1}: ${contact['name']}',
                snippet: contact['address'],
              ),
            ),
          );
          log('Added dropoff marker ${i + 1}: ${contact['name']}');
        }
      }
    }

    _markers = newMarkers;
    _polylines.clear(); // No route without driver

    // Calculate ETA based on order creation time
    _calculateETAForUnassignedOrder();

    // Fit map bounds to show all locations
    _fitMapBounds();

    log('=== MAP STATE UPDATE COMPLETE FOR UNASSIGNED ORDER ===');
  }

  void _updateMapState(String orgId) async {
    log('=== UPDATING MAP STATE ===');

    final newMarkers = <Marker>{};

    // 1. Add driver marker
    if (_driverPosition != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Driver Location',
            snippet:
                '${_driver?['name'] ?? 'Driver'} - ${_driver?['vehiclePlate'] ?? 'N/A'}',
          ),
        ),
      );
      log('Added driver marker at: $_driverPosition');
    }

    // 2. Add office marker as pickup point
    if (_office != null && _office!['location'] != null) {
      final location = _office!['location'] as Map<String, dynamic>;
      newMarkers.add(
        Marker(
          markerId: const MarkerId('office_pickup'),
          position: LatLng(
            location['latitude'] as double,
            location['longitude'] as double,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Pickup: ${_office!['officeName']}',
            snippet: _office!['fullAddress'],
          ),
        ),
      );
      log('Added office pickup marker: ${_office!['officeName']}');
    }

    // 3. Add markers for all dropoff locations
    if (_order!['dropoffList'] != null) {
      final dropoffList = _order!['dropoffList'] as List<dynamic>;
      for (var i = 0; i < dropoffList.length; i++) {
        final address = dropoffList[i] as Map<String, dynamic>;
        final contact = await _trackingService.getContact(
          contactId: address['contactId'],
          orgId: orgId,
        );
        if (contact != null && contact['location'] != null) {
          final location = contact['location'] as Map<String, dynamic>;
          newMarkers.add(
            Marker(
              markerId: MarkerId('dropoff_${i}_${contact['name']}'),
              position: LatLng(
                location['latitude'] as double,
                location['longitude'] as double,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              infoWindow: InfoWindow(
                title: 'Dropoff ${i + 1}: ${contact['name']}',
                snippet: contact['address'],
              ),
            ),
          );
          log('Added dropoff marker ${i + 1}: ${contact['name']}');
        }
      }
    }

    _markers = newMarkers;

    // 4. Calculate route from driver to all dropoff points
    _calculateRoute(orgId);

    // 5. Calculate ETA
    _calculateETA(orgId);

    // 6. Fit map bounds to show entire route
    _fitMapBounds();

    log('=== MAP STATE UPDATE COMPLETE ===');
  }

  void _fitMapBounds() {
    if (_markers.isEmpty) {
      log('No markers to fit bounds to');
      return;
    }

    try {
      final controller = mapController.future;
      controller.then((mapController) {
        if (_markers.length == 1) {
          // Single marker - center on it with appropriate zoom
          mapController.animateCamera(
            CameraUpdate.newLatLngZoom(_markers.first.position, 15.0),
          );
        } else {
          // Multiple markers - fit bounds to show all
          final bounds = _calculateBounds();
          mapController.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 50.0), // 50px padding
          );
        }
      });
    } catch (e) {
      log('Error fitting map bounds: $e');
    }
  }

  LatLngBounds _calculateBounds() {
    if (_markers.isEmpty) {
      // Return default bounds if no markers
      return LatLngBounds(
        southwest: const LatLng(-33.8737, 18.6340),
        northeast: const LatLng(-33.8745, 18.6882),
      );
    }

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in _markers) {
      minLat = math.min(minLat, marker.position.latitude);
      maxLat = math.max(maxLat, marker.position.latitude);
      minLng = math.min(minLng, marker.position.longitude);
      maxLng = math.max(maxLng, marker.position.longitude);
    }

    // Add some padding to the bounds
    const padding = 0.01; // About 1km
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  Future<void> _calculateRoute(String orgId) async {
    if (_order!['dropoffList'] == null) {
      log('No dropoff addresses available for route calculation');
      return;
    }

    final dropoffList = _order!['dropoffList'] as List<dynamic>;
    if (dropoffList.isEmpty) {
      log('No dropoff addresses available for route calculation');
      return;
    }

    if (_driverPosition == null) {
      log('Driver position is null, cannot calculate route');
      return;
    }

    try {
      final allPolylines = <Polyline>{};

      // Calculate route from driver to each dropoff point
      for (var i = 0; i < dropoffList.length; i++) {
        final dropoff = dropoffList[i] as Map<String, dynamic>;
        final contact = await _trackingService.getContact(
          contactId: dropoff['contactId'],
          orgId: orgId,
        );
        if (contact != null && contact['location'] != null) {
          final location = contact['location'] as Map<String, dynamic>;
          final destination = LatLng(
            location['latitude'] as double,
            location['longitude'] as double,
          );

          log(
            'Calculating route ${i + 1} from driver at $_driverPosition to destination at $destination',
          );

          final polylines = await _trackingService.polylineRoute(
            origin: _driverPosition!,
            dest: destination,
          );

          if (polylines.isNotEmpty) {
            // Update polyline with better styling and unique ID
            final updatedPolylines = polylines.map((polyline) {
              return Polyline(
                polylineId: PolylineId('route_${i + 1}'),
                points: polyline.points,
                color: _getRouteColor(i),
                width: 6,
                geodesic: true,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              );
            }).toSet();

            allPolylines.addAll(updatedPolylines);
            log(
              'Route ${i + 1} calculated successfully with ${polylines.length} polylines',
            );
          } else {
            log('No polylines returned for route ${i + 1}, creating fallback');
            // Create a simple straight line if no route is available
            allPolylines.add(
              Polyline(
                polylineId: PolylineId('fallback_route_${i + 1}'),
                points: [_driverPosition!, destination],
                color: Colors.red.withValues(alpha: 0.6),
                width: 4,
                geodesic: true,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            );
          }
        }
      }

      _polylines = allPolylines;
      log('Total routes calculated: ${_polylines.length}');

      notifyListeners();
    } catch (e) {
      log('Error calculating routes: $e');

      // Create fallback straight line routes
      final fallbackPolylines = <Polyline>{};
      for (var i = 0; i < dropoffList.length; i++) {
        final dropoff = dropoffList[i] as Map<String, dynamic>;
        final contact = await _trackingService.getContact(
          contactId: dropoff['contactId'],
          orgId: orgId,
        );
        if (contact != null && contact['location'] != null) {
          final location = contact['location'] as Map<String, dynamic>;
          final destination = LatLng(
            location['latitude'] as double,
            location['longitude'] as double,
          );

          fallbackPolylines.add(
            Polyline(
              polylineId: PolylineId('error_fallback_route_${i + 1}'),
              points: [_driverPosition!, destination],
              color: Colors.orange.withValues(alpha: 0.6),
              width: 4,
              geodesic: true,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          );
        }
      }

      _polylines = fallbackPolylines;
      notifyListeners();
    }
  }

  // Get different colors for different routes
  Color _getRouteColor(int routeIndex) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
    ];

    return colors[routeIndex % colors.length].withValues(alpha: 0.8);
  }

  void _calculateETA(String orgId) async {
    if (_order!['dropoffList'] == null) {
      _etaText = 'No destination set';
      return;
    }

    final dropoffList = _order!['dropoffList'] as List<dynamic>;
    if (dropoffList.isEmpty) {
      _etaText = 'No destination set';
      return;
    }

    if (_driverPosition == null) {
      _etaText = 'Driver location unavailable';
      return;
    }

    try {
      // Calculate total distance to all dropoff points
      double totalDistance = 0;
      int validDropoffs = 0;

      for (final dropoff in dropoffList) {
        final address = dropoff as Map<String, dynamic>;
        final contact = await _trackingService.getContact(
          contactId: address['contactId'],
          orgId: orgId,
        );
        if (contact != null && contact['location'] != null) {
          final location = contact['location'] as Map<String, dynamic>;
          final distance = _calculateDistance(
            _driverPosition!,
            LatLng(
              location['latitude'] as double,
              location['longitude'] as double,
            ),
          );
          totalDistance += distance;
          validDropoffs++;
        }
      }

      if (validDropoffs == 0) {
        _etaText = 'No valid destinations';
        return;
      }

      // Calculate average distance and estimated time
      final averageDistance = totalDistance / validDropoffs;
      final estimatedMinutes = (averageDistance / 1000 * 2)
          .round(); // Rough estimate: 2 min per km

      if (validDropoffs == 1) {
        _etaText = '$estimatedMinutes minutes';
      } else {
        _etaText = '$estimatedMinutes minutes (avg)';
      }

      log(
        'ETA calculated: $estimatedMinutes minutes for $validDropoffs dropoff(s), avg distance: ${(averageDistance / 1000).toStringAsFixed(1)}km',
      );
    } catch (e) {
      log('Error calculating ETA: $e');
      _etaText = 'Calculating...';
    }
  }

  void _calculateETAForUnassignedOrder() {
    if (_order!['dropoffList'] == null) {
      _etaText = 'No destination set';
      return;
    }

    final dropoffList = _order!['dropoffList'] as List<dynamic>;
    if (dropoffList.isEmpty) {
      _etaText = 'No destination set';
      return;
    }

    // For unassigned orders, show estimated time based on order creation
    final createdAt = _order!['createdAt'] as dynamic;
    final timeSinceCreation = DateTime.now().difference(createdAt.toDate());
    final hoursSinceCreation = timeSinceCreation.inHours;

    if (hoursSinceCreation < 1) {
      _etaText = 'Awaiting driver assignment';
    } else if (hoursSinceCreation < 24) {
      _etaText = 'Pending assignment (${hoursSinceCreation}h ago)';
    } else {
      final daysSinceCreation = timeSinceCreation.inDays;
      _etaText = 'Pending assignment (${daysSinceCreation}d ago)';
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // meters
    final lat1 = start.latitude * (math.pi / 180);
    final lat2 = end.latitude * (math.pi / 180);
    final deltaLat = (end.latitude - start.latitude) * (math.pi / 180);
    final deltaLng = (end.longitude - start.longitude) * (math.pi / 180);

    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  // Public methods for enhanced functionality
  void refreshTracking() {
    if (_order != null) {
      initModel(orderId: _order!['orderId'], orgId: _order!['orgId']);
    }
  }

  void toggleRouteVisibility() {
    _routeVisible = !_routeVisible;
    log('Route visibility toggled: $_routeVisible');
    notifyListeners();
  }

  void refreshRoute() async {
    log('Manually refreshing route');
    if (_order != null) {
      await _calculateRoute(_order!['orgId']);
    }
  }

  void createTestRoute() async {
    log('Creating test route for debugging');

    // Use office and order data if available, otherwise use default coordinates
    List<Polyline> testPolylines = [];

    if (_office != null &&
        _office!['location'] != null &&
        _order != null &&
        _order!['dropoffList'] != null) {
      final location = _office!['location'] as Map<String, dynamic>;
      final officeLocation = LatLng(
        location['latitude'] as double,
        location['longitude'] as double,
      );

      final dropoffList = _order!['dropoffList'] as List<dynamic>;
      // Create routes from office to each dropoff point
      for (var i = 0; i < dropoffList.length; i++) {
        final dropoff = dropoffList[i] as Map<String, dynamic>;
        final contact = await _trackingService.getContact(
          contactId: dropoff['contactId'],
          orgId: _order!['orgId'],
        );
        if (contact != null && contact['location'] != null) {
          final contactLocation = contact['location'] as Map<String, dynamic>;
          final destination = LatLng(
            contactLocation['latitude'] as double,
            contactLocation['longitude'] as double,
          );

          testPolylines.add(
            Polyline(
              polylineId: PolylineId('test_route_${i + 1}'),
              points: [officeLocation, destination],
              color: _getRouteColor(i),
              width: 8,
              geodesic: true,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.round,
            ),
          );
          log(
            'Test route ${i + 1} using office to dropoff ${i + 1}: $destination',
          );
        }
      }
    }

    // Fallback to default coordinates if no office or order data
    if (testPolylines.isEmpty) {
      testPolylines = [
        Polyline(
          polylineId: const PolylineId('test_route_default'),
          points: [
            const LatLng(-33.8737, 18.6340), // Start point
            const LatLng(-33.8745, 18.6882), // End point
          ],
          color: Colors.red,
          width: 8,
          geodesic: true,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      ];
      log('Test route using default coordinates');
    }

    _polylines = testPolylines.toSet();
    log('Test routes created with ${_polylines.length} polylines');
    notifyListeners();
  }

  void centerOnDriver() async {
    if (_driverPosition != null) {
      final controller = await mapController.future;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_driverPosition!, 15.0),
      );
    }
  }

  void centerOnOffice() async {
    if (_office != null && _office!['location'] != null) {
      final location = _office!['location'] as Map<String, dynamic>;
      final controller = await mapController.future;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(
            location['latitude'] as double,
            location['longitude'] as double,
          ),
          15.0,
        ),
      );
    }
  }

  void centerOnAllLocations() async {
    if (_markers.isNotEmpty) {
      final controller = await mapController.future;
      final bounds = _calculateBounds();
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50.0));
    }
  }

  void zoomIn() async {
    final controller = await mapController.future;
    controller.animateCamera(CameraUpdate.zoomIn());
  }

  void zoomOut() async {
    final controller = await mapController.future;
    controller.animateCamera(CameraUpdate.zoomOut());
  }

  void callDriver() {
    // TODO: Implement driver calling functionality
    log('Calling driver...');
  }

  @override
  void dispose() {
    _mapStateSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _officeSubscription?.cancel();
    super.dispose();
  }
}

