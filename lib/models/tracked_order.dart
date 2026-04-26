import 'package:fastcorr_shared/models/models.dart';

/// Distinguishes which collection / business flow a [TrackedOrder] originates
/// from. The `MapTrackingService` and `TrackedOrderRepository` use this to
/// route reads to the correct Firestore collection (`litigation_requests`
/// vs `delivery_orders`).
enum TrackedOrderType { litigation, delivery }

/// Lightweight geographic point with optional human-readable text.
///
/// Intentionally Flutter-free (no `LatLng` dependency) so that the model
/// layer can be consumed by any caller — including services and tests that
/// don't pull in `google_maps_flutter`. Conversion to `LatLng` happens at
/// the viewmodel/UI boundary.
class TrackedLocation {
  final double latitude;
  final double longitude;

  /// Human-readable street address (e.g. "12 Main St, Sandton").
  final String? address;

  /// Short label for marker rendering (e.g. office name, contact name).
  final String? label;

  const TrackedLocation({
    required this.latitude,
    required this.longitude,
    this.address,
    this.label,
  });

  TrackedLocation copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? label,
  }) {
    return TrackedLocation(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackedLocation &&
          other.latitude == latitude &&
          other.longitude == longitude &&
          other.address == address &&
          other.label == label;

  @override
  int get hashCode => Object.hash(latitude, longitude, address, label);
}

/// Minimal driver projection for the map surface.
///
/// `DriverModel` lives per-app today (different shapes in user/admin), so
/// we project only the fields a tracking view actually renders. Adapters in
/// each app convert their local `DriverModel` into this projection.
class TrackedDriver {
  final String id;
  final String? name;
  final String? phone;
  final String? vehicleInfo;
  final String? photoUrl;

  const TrackedDriver({
    required this.id,
    this.name,
    this.phone,
    this.vehicleInfo,
    this.photoUrl,
  });

  TrackedDriver copyWith({
    String? id,
    String? name,
    String? phone,
    String? vehicleInfo,
    String? photoUrl,
  }) {
    return TrackedDriver(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vehicleInfo: vehicleInfo ?? this.vehicleInfo,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

/// A single dropoff stop on a trip, normalised across litigation and
/// delivery flows.
///
/// Source mapping:
/// * `RequestModel.dropoffList[i]` → one `TrackedDropoff` (litigation).
/// * `OrderModel.dropoffList[i]`   → one `TrackedDropoff` (delivery).
///
/// The repository resolves [contactId] against the org's `contacts`
/// collection so the viewmodel doesn't need a second round-trip.
class TrackedDropoff {
  /// 1-based stop order in the trip.
  final int sequence;

  /// Source `AddressModel.id` if present (used for status updates).
  final String? addressId;

  /// Source `ContactModel.id`. Populated when the address references a
  /// contact in `orgs/{orgId}/contacts`.
  final String? contactId;

  /// Resolved contact display name (from `ContactModel.name`).
  final String? contactName;

  /// Resolved contact phone (from `ContactModel.phone`).
  final String? contactPhone;

  /// Pickup/dropoff coordinates and label.
  final TrackedLocation location;

  /// Per-stop status — pending / arrived / delivered / canceled.
  /// Sourced directly from `AddressModel.status`.
  final AddressStatus status;

  final DateTime? arrivedAt;
  final DateTime? deliveredAt;
  final DateTime? canceledAt;

  /// Proof-of-delivery references (signature image, photo).
  final String? podSignatureUrl;
  final String? podPhotoUrl;

  /// Optional free-form note attached to this stop.
  final String? notes;

  const TrackedDropoff({
    required this.sequence,
    required this.location,
    required this.status,
    this.addressId,
    this.contactId,
    this.contactName,
    this.contactPhone,
    this.arrivedAt,
    this.deliveredAt,
    this.canceledAt,
    this.podSignatureUrl,
    this.podPhotoUrl,
    this.notes,
  });

  /// True when the stop has reached a terminal state (delivered or canceled).
  bool get isResolved =>
      status == AddressStatus.delivered || status == AddressStatus.canceled;

  TrackedDropoff copyWith({
    int? sequence,
    String? addressId,
    String? contactId,
    String? contactName,
    String? contactPhone,
    TrackedLocation? location,
    AddressStatus? status,
    DateTime? arrivedAt,
    DateTime? deliveredAt,
    DateTime? canceledAt,
    String? podSignatureUrl,
    String? podPhotoUrl,
    String? notes,
  }) {
    return TrackedDropoff(
      sequence: sequence ?? this.sequence,
      addressId: addressId ?? this.addressId,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      location: location ?? this.location,
      status: status ?? this.status,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      canceledAt: canceledAt ?? this.canceledAt,
      podSignatureUrl: podSignatureUrl ?? this.podSignatureUrl,
      podPhotoUrl: podPhotoUrl ?? this.podPhotoUrl,
      notes: notes ?? this.notes,
    );
  }
}

/// Unified projection of a trackable order shaped for map/route rendering.
///
/// Built from either:
/// * [RequestModel] (litigation) — pickup is the lawyer's office, resolved
///   via `officeId` by the repository.
/// * [OrderModel] (delivery) — pickup is sourced from `pickupLocation` /
///   `pickupAddress` directly on the order.
///
/// The viewmodel and view layer should depend on this type only — never on
/// `RequestModel`/`OrderModel` directly — so adding a new order source in
/// the future is a single-file change in the repository.
class TrackedOrder {
  /// Public order identifier (e.g. `CLTGN-123` or `ODR-456`).
  /// IDs encode the source: prefix `CLTGN` → litigation, `ODR` → delivery.
  final String orderId;

  /// Owning organisation. Required for resolving contacts and offices.
  final String orgId;

  /// Source flow / collection.
  final TrackedOrderType type;

  /// Unified order status.
  final Status status;

  /// Optional title (e.g. service name for delivery, request title for
  /// litigation). Used for the AppBar / header.
  final String? title;

  /// Optional free-form instructions provided by the requester.
  final String? instructions;

  /// Currently assigned driver, if any.
  final TrackedDriver? driver;

  /// Pickup coordinates. Nullable because pickup may not be resolvable yet
  /// (e.g. office record missing/incomplete on a litigation request).
  final TrackedLocation? pickup;

  /// Ordered list of dropoffs. Empty until the order has at least one stop.
  final List<TrackedDropoff> dropoffs;

  /// Status-tracking timestamps. Each is non-null only once the order has
  /// reached the corresponding state.
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAtPickupAt;
  final DateTime? pickedupAt;
  final DateTime? completedAt;
  final DateTime? canceledAt;

  /// Wall-clock time this projection was assembled. Useful for "last
  /// updated N seconds ago" UI.
  final DateTime lastUpdated;

  TrackedOrder({
    required this.orderId,
    required this.orgId,
    required this.type,
    required this.status,
    required this.dropoffs,
    required this.lastUpdated,
    this.title,
    this.instructions,
    this.driver,
    this.pickup,
    this.createdAt,
    this.acceptedAt,
    this.arrivedAtPickupAt,
    this.pickedupAt,
    this.completedAt,
    this.canceledAt,
  });

  /// True when no further status change is expected.
  bool get isTerminal =>
      status == Status.completed ||
      status == Status.canceled ||
      status == Status.rejected;

  /// Count of dropoffs in the `delivered` state.
  int get completedDropoffs =>
      dropoffs.where((d) => d.status == AddressStatus.delivered).length;

  int get totalDropoffs => dropoffs.length;

  /// True when every dropoff has been delivered (and there's at least one).
  bool get allDelivered =>
      totalDropoffs > 0 && completedDropoffs == totalDropoffs;

  /// 0.0–1.0 fraction of stops delivered.
  double get progress =>
      totalDropoffs == 0 ? 0.0 : completedDropoffs / totalDropoffs;

  /// First dropoff that hasn't reached a terminal state, in sequence order.
  /// Useful to highlight the "current" stop on the map.
  TrackedDropoff? get nextDropoff {
    for (final d in dropoffs) {
      if (!d.isResolved) return d;
    }
    return null;
  }

  TrackedOrder copyWith({
    String? orderId,
    String? orgId,
    TrackedOrderType? type,
    Status? status,
    String? title,
    String? instructions,
    TrackedDriver? driver,
    TrackedLocation? pickup,
    List<TrackedDropoff>? dropoffs,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? arrivedAtPickupAt,
    DateTime? pickedupAt,
    DateTime? completedAt,
    DateTime? canceledAt,
    DateTime? lastUpdated,
  }) {
    return TrackedOrder(
      orderId: orderId ?? this.orderId,
      orgId: orgId ?? this.orgId,
      type: type ?? this.type,
      status: status ?? this.status,
      title: title ?? this.title,
      instructions: instructions ?? this.instructions,
      driver: driver ?? this.driver,
      pickup: pickup ?? this.pickup,
      dropoffs: dropoffs ?? this.dropoffs,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      arrivedAtPickupAt: arrivedAtPickupAt ?? this.arrivedAtPickupAt,
      pickedupAt: pickedupAt ?? this.pickedupAt,
      completedAt: completedAt ?? this.completedAt,
      canceledAt: canceledAt ?? this.canceledAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
