import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stacked/stacked.dart';

const String _trackingReqId = 'trackingReqId';

/// Abstract base class for map tracking functionality
/// This allows both user and admin apps to implement their own model-specific tracking
abstract class MapTrackingService with ListenableServiceMixin {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference get _driverRef => _firestore.collection('drivers');

  Future<String?> get trackingReqId async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_trackingReqId);
  }

  Future<void> setTrackingReqId(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_trackingReqId, orderId);
    notifyListeners();
  }

  /// Abstract methods that must be implemented by each app
  /// These handle the specific model types for each app

  /// Get office data by officeId - returns a generic Map for flexibility
  Future<Map<String, dynamic>?> getOfficeById(String officeId);

  /// Stream office data by officeId - returns a generic Map for flexibility
  Stream<Map<String, dynamic>?> getOfficeStream(String officeId);

  /// Get order/request data by orderId - returns a generic Map for flexibility
  Stream<Map<String, dynamic>> getOrderStream({
    required String orgId,
    required String orderId,
  });

  /// Get driver data by driverId - returns a generic Map for flexibility
  Future<Map<String, dynamic>> getDriver(String driverId);

  /// Get contact data by contactId - returns a generic Map for flexibility
  Future<Map<String, dynamic>?> getContact({
    required String contactId,
    required String orgId,
  });

  /// Get live orders stream - returns a list of generic Maps
  Stream<List<Map<String, dynamic>>> getLiveOrdersStream();

  /// Get activity stream for an order - returns a list of generic Maps
  Stream<List<Map<String, dynamic>>> allActivityStream(String orderId);

  /// Get driver location stream - returns LatLng coordinates
  Stream<LatLng> getDriverLocationStream(String? driverId) {
    // Handle case where driver is not assigned yet
    if (driverId == null || driverId.isEmpty) {
      log('No driver assigned to order yet');
      return Stream.empty();
    }

    log('Getting real-time location for driver: $driverId');

    return _driverRef
        .doc(driverId)
        .snapshots()
        .where((snapshot) => snapshot.exists)
        .map((snapshot) {
          final driverData = snapshot.data() as Map<String, dynamic>?;

          if (driverData == null || driverData['currentLocation'] == null) {
            log('Driver $driverId has no current location data');
            throw Exception('Driver location not available');
          }

          final location =
              driverData['currentLocation'] as Map<String, dynamic>;
          final latitude = location['latitude'] as double;
          final longitude = location['longitude'] as double;

          log('Driver $driverId location: $latitude, $longitude');
          return LatLng(latitude, longitude);
        })
        .handleError((error) {
          log('Error getting driver location: $error');
          throw error;
        });
  }

  /// Fallback method for testing when no real driver data is available
  Stream<LatLng> getSimulatedDriverLocationStream() {
    log('Using simulated driver location for testing');

    // 1. Define Start and End Points (can be made configurable)
    const LatLng tygerValley = LatLng(-33.8737, 18.6340);
    const LatLng capeGate = LatLng(-33.8745, 18.6882);

    const int numberOfSteps = 20; // How many updates to simulate

    // 2. Calculate the "journey" for both latitude and longitude
    final double totalLatDistance = capeGate.latitude - tygerValley.latitude;
    final double totalLngDistance = capeGate.longitude - tygerValley.longitude;

    // 3. Calculate the size of each small step
    final double latStep = totalLatDistance / numberOfSteps;
    final double lngStep = totalLngDistance / numberOfSteps;

    return Stream.periodic(const Duration(seconds: 2), (step) {
      // 4. For each step, calculate the new position
      final double newLat = tygerValley.latitude + (latStep * step);
      final double newLng = tygerValley.longitude + (lngStep * step);

      return LatLng(newLat, newLng);
    }).take(numberOfSteps + 1);
  }

  /// Calculate polyline route between two points
  Future<List<Polyline>> polylineRoute({
    required LatLng origin,
    required LatLng dest,
  }) async {
    // Use an interpolated geodesic fallback route until external routing is wired.
    // This avoids jagged two-point rendering and gives stable UX.
    final points = _buildInterpolatedPoints(origin, dest);
    log('Creating interpolated route with ${points.length} points from $origin to $dest');

    return [
      Polyline(
        polylineId: const PolylineId('interpolated_route'),
        points: points,
        color: Colors.blue,
        width: 3,
        geodesic: true,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    ];
  }

  List<LatLng> _buildInterpolatedPoints(LatLng origin, LatLng dest) {
    const segments = 24;
    final points = <LatLng>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final lat = origin.latitude + ((dest.latitude - origin.latitude) * t);
      final lng = origin.longitude + ((dest.longitude - origin.longitude) * t);
      points.add(LatLng(lat, lng));
    }
    return points;
  }
}

