import 'package:cloud_firestore/cloud_firestore.dart';

Timestamp? processedTimestamp(dynamic rawValue) {
  if (rawValue == null) {
    return null;
  }

  /// Data is from Firestore, use it directly
  if (rawValue is Timestamp) {
    return rawValue;
  }

  /// Data is from JSON (shared_preferences), parse the string.
  if (rawValue is String) {
    return Timestamp.fromDate(DateTime.parse(rawValue));
  }

  throw ArgumentError('Invalid type for createdAt: ${rawValue.runtimeType}');
}

GeoPoint? processedGeoPoint(dynamic rawValue) {
  if (rawValue == null) {
    return null;
  }

  /// Data is from Firestore, use it directly.
  if (rawValue is GeoPoint) {
    return rawValue;
  }

  /// Data is from JSON (shared_preferences), parse the map.
  if (rawValue is Map) {
    final locationMap = rawValue as Map<String, dynamic>;
    return GeoPoint(locationMap['latitude'], locationMap['longitude']);
  }

  throw ArgumentError('Invalid type for location: ${rawValue.runtimeType}');
}

double toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  return double.tryParse(value.toString()) ?? 0.0;
}
