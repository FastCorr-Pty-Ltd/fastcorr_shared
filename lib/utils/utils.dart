import 'package:cloud_firestore/cloud_firestore.dart';

// Helper function to handle 'N/A' or empty strings as null
String? cleanString(dynamic value) {
  if (value == null) return null;
  final String str = value.toString().trim();
  if (str.isEmpty || str.toUpperCase() == 'N/A' || str.toUpperCase() == 'TBC') {
    return null;
  }
  return str;
}

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

  /// Handle Firestore Web timestamps (JavaScript objects)
  /// These come as objects with seconds and nanoseconds properties
  try {
    // Try to extract seconds and nanoseconds for web compatibility
    final timestamp = rawValue as dynamic;
    if (timestamp.seconds != null) {
      final seconds = timestamp.seconds as int;
      final nanoseconds = (timestamp.nanoseconds ?? 0) as int;
      return Timestamp(seconds, nanoseconds);
    }
  } catch (e) {
    // If extraction fails, fall through to error
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

// Helper function to safely parse lists from JSON
List<String> safeListFromJson(dynamic jsonList) {
  if (jsonList == null) return [];
  if (jsonList is! List) return [];

  return jsonList
      .where((item) => item != null)
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
}

// Helper function to safely parse lists from snapshot
List<String> safeListFromSnapshot(dynamic snapshotList) {
  if (snapshotList == null) return [];
  if (snapshotList is! List) return [];

  return snapshotList
      .where((item) => item != null)
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList();
}

// Helper function to safely convert lists to JSON arrays
List<String> safeListToJson(List<String>? list) {
  if (list == null) return [];
  return list
      .where((item) => item.isNotEmpty)
      .map((item) => item.toString())
      .toList();
}
