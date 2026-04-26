import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/models.dart';

/// Reads either a litigation request (`CLTGN*`) or a delivery order (`ODR*`)
/// and projects it to a unified [TrackedOrder] suitable for map / route
/// rendering.
///
/// This is the *data* layer for Phase 2 of the map-tracking consolidation.
/// It deliberately does **not** know about Google Maps, polylines, markers
/// or driver-location streams — those are responsibilities of the concrete
/// `MapTrackingService` (Phase 3) which composes this repository with a
/// driver-location stream and a routing API.
///
/// Routing rules:
///
/// * IDs prefixed `CLTGN` → `litigation_requests` collection (`RequestModel`).
/// * IDs prefixed `ODR`   → `delivery_orders` collection (`OrderModel`).
///
/// Pickup resolution:
///
/// * Litigation: pickup is the lawyer's office, looked up via
///   `RequestModel.officeId` against the root `offices` collection.
/// * Delivery: pickup is on the order itself
///   (`OrderModel.pickupLocation` / `OrderModel.pickupAddress`).
///
/// Contact resolution:
///
/// Each `AddressModel` in `dropoffList` references a contact id; the contact
/// document lives at `organisations/{orgId}/contacts/{contactId}`. The
/// repository batches these reads and reuses results for the lifetime of a
/// single subscription, so a chatty order document doesn't trigger N
/// contact reads on every emission.
class TrackedOrderRepository {
  TrackedOrderRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Collection paths kept in one place so they're easy to grep / change.
  static const String _litigationCollection = 'litigation_requests';
  static const String _deliveryCollection = 'delivery_orders';
  static const String _orgsCollection = 'organisations';
  static const String _contactsSubcollection = 'contacts';
  static const String _officesCollection = 'offices';

  // ---- Public API -------------------------------------------------------

  /// Detect order type from its id prefix.
  ///
  /// Throws [ArgumentError] if the id doesn't start with a known prefix —
  /// we deliberately fail loudly rather than silently picking a default,
  /// because dispatching to the wrong collection would silently return
  /// `null` forever.
  static TrackedOrderType detectType(String orderId) {
    if (orderId.startsWith('CLTGN')) return TrackedOrderType.litigation;
    if (orderId.startsWith('ODR')) return TrackedOrderType.delivery;
    throw ArgumentError(
      'Unrecognised order id "$orderId". '
      'Expected a "CLTGN*" (litigation) or "ODR*" (delivery) prefix.',
    );
  }

  /// Live stream of [TrackedOrder] for the given id. Auto-dispatches by
  /// prefix and emits a fresh projection each time the underlying source
  /// document changes. Office and contact lookups are cached for the
  /// lifetime of the subscription.
  Stream<TrackedOrder> streamOrder(String orderId) {
    switch (detectType(orderId)) {
      case TrackedOrderType.litigation:
        return _streamLitigation(orderId);
      case TrackedOrderType.delivery:
        return _streamDelivery(orderId);
    }
  }

  /// One-shot read. Returns `null` if the document doesn't exist or the
  /// stream completes before emitting (e.g. immediate cancellation).
  Future<TrackedOrder?> getOrder(String orderId) async {
    try {
      return await streamOrder(orderId).first;
    } on StateError {
      return null;
    }
  }

  /// Adapter: convert an already-fetched [RequestModel] into a
  /// [TrackedOrder]. Useful for callers that already hold a request (e.g.
  /// list-screen viewmodels) and want to avoid a second read.
  ///
  /// Performs the office + contacts lookups inline.
  Future<TrackedOrder> fromRequest(RequestModel req) async {
    final office = await _resolveOffice(req.officeId);
    final contacts = await _resolveContacts(
      req.orgId,
      _contactIds(req.dropoffList),
    );
    return _projectFromRequest(req, office: office, contacts: contacts);
  }

  /// Adapter: convert an already-fetched [OrderModel] into a [TrackedOrder].
  Future<TrackedOrder> fromOrder(OrderModel order) async {
    final contacts = await _resolveContacts(
      order.orgId,
      _contactIds(order.dropoffList),
    );
    return _projectFromOrder(order, contacts: contacts);
  }

  // ---- Streams ----------------------------------------------------------

  Stream<TrackedOrder> _streamLitigation(String orderId) {
    final cache = _LookupCache();
    return _firestore
        .collection(_litigationCollection)
        .doc(orderId)
        .snapshots()
        .where((s) => s.exists)
        .asyncMap((s) async {
      final req = RequestModel.fromSnapshot(s);
      final office = await cache.office(req.officeId, _resolveOffice);
      final contacts = await cache.contacts(
        req.orgId,
        _contactIds(req.dropoffList),
        _resolveContacts,
      );
      return _projectFromRequest(req, office: office, contacts: contacts);
    });
  }

  Stream<TrackedOrder> _streamDelivery(String orderId) {
    final cache = _LookupCache();
    return _firestore
        .collection(_deliveryCollection)
        .doc(orderId)
        .snapshots()
        .where((s) => s.exists)
        .asyncMap((s) async {
      final order = OrderModel.fromSnapshot(s);
      final contacts = await cache.contacts(
        order.orgId,
        _contactIds(order.dropoffList),
        _resolveContacts,
      );
      return _projectFromOrder(order, contacts: contacts);
    });
  }

  // ---- Projection -------------------------------------------------------

  TrackedOrder _projectFromRequest(
    RequestModel req, {
    required _OfficeLite? office,
    required Map<String, ContactModel> contacts,
  }) {
    return TrackedOrder(
      orderId: req.orderId,
      orgId: req.orgId,
      type: TrackedOrderType.litigation,
      status: req.status ?? Status.pending,
      title: req.title.isEmpty ? null : req.title,
      instructions: req.notes,
      driver: _driverIdToTracked(req.driverId),
      pickup: office?.toLocation(),
      dropoffs: _buildDropoffs(req.dropoffList, contacts),
      createdAt: req.createdAt,
      acceptedAt: req.acceptedAt,
      arrivedAtPickupAt: req.arrivedAtPickupAt,
      pickedupAt: req.pickedupAt,
      completedAt: req.completedAt,
      canceledAt: req.canceledAt,
      lastUpdated: DateTime.now(),
    );
  }

  TrackedOrder _projectFromOrder(
    OrderModel order, {
    required Map<String, ContactModel> contacts,
  }) {
    return TrackedOrder(
      orderId: order.orderId,
      orgId: order.orgId,
      type: TrackedOrderType.delivery,
      status: order.status,
      title: order.serviceTitle.isEmpty ? null : order.serviceTitle,
      instructions: order.instructions,
      driver: _driverIdToTracked(order.driverId),
      pickup: _orderPickup(order),
      dropoffs: _buildDropoffs(order.dropoffList, contacts),
      // `OrderModel` doesn't carry a `createdAt` today; leave null.
      acceptedAt: order.acceptedAt,
      arrivedAtPickupAt: order.arrivedAtPickupAt,
      pickedupAt: order.pickedupAt,
      completedAt: order.completedAt,
      canceledAt: order.canceledAt,
      lastUpdated: DateTime.now(),
    );
  }

  TrackedDriver? _driverIdToTracked(String? driverId) {
    if (driverId == null || driverId.isEmpty) return null;
    // Phase 2 only carries the id. Phase 3's MapTrackingService (or each
    // app's existing DriverService) hydrates name/phone/vehicle on demand.
    return TrackedDriver(id: driverId);
  }

  TrackedLocation? _orderPickup(OrderModel order) {
    final loc = order.pickupLocation;
    if (loc == null) return null;
    return TrackedLocation(
      latitude: loc.latitude,
      longitude: loc.longitude,
      address: order.pickupAddress.isEmpty ? null : order.pickupAddress,
      label: 'Pickup',
    );
  }

  List<TrackedDropoff> _buildDropoffs(
    List<AddressModel>? raw,
    Map<String, ContactModel> contacts,
  ) {
    if (raw == null || raw.isEmpty) return const [];
    final out = <TrackedDropoff>[];
    for (var i = 0; i < raw.length; i++) {
      final a = raw[i];
      final loc = a.location;
      if (loc == null) {
        // No coordinates → can't render on a map. Skip rather than emit a
        // half-built dropoff. Future enhancement: fall back to the
        // contact's `location` GeoPoint when the address itself is
        // un-geocoded.
        continue;
      }
      final contact = contacts[a.contactId];
      out.add(TrackedDropoff(
        sequence: i + 1,
        addressId: a.id,
        contactId: a.contactId.isEmpty ? null : a.contactId,
        contactName: contact?.name,
        contactPhone: contact?.phone,
        location: TrackedLocation(
          latitude: loc.latitude,
          longitude: loc.longitude,
          address: contact?.address,
          label: contact?.name,
        ),
        status: a.status ?? AddressStatus.pending,
        arrivedAt: a.arrivedAt?.toDate(),
        deliveredAt: a.deliveredAt?.toDate(),
        canceledAt: a.canceledAt?.toDate(),
        // `AddressModel` defaults these to '' rather than null; normalise.
        podSignatureUrl:
            (a.podSignatureUrl == null || a.podSignatureUrl!.isEmpty)
                ? null
                : a.podSignatureUrl,
        podPhotoUrl: (a.podPhotoUrl == null || a.podPhotoUrl!.isEmpty)
            ? null
            : a.podPhotoUrl,
      ));
    }
    return out;
  }

  // ---- Lookups ----------------------------------------------------------

  List<String> _contactIds(List<AddressModel>? list) {
    if (list == null || list.isEmpty) return const [];
    final ids = <String>{};
    for (final a in list) {
      if (a.contactId.isNotEmpty) ids.add(a.contactId);
    }
    return ids.toList(growable: false);
  }

  /// Reads `offices/{officeId}` directly (bypassing the per-app `OfficeModel`
  /// types, which differ between user and admin packages). Returns `null`
  /// when the doc is missing, the read fails, or the office has no
  /// geographic location.
  Future<_OfficeLite?> _resolveOffice(String officeId) async {
    if (officeId.isEmpty) return null;
    try {
      final doc =
          await _firestore.collection(_officesCollection).doc(officeId).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      final loc = data['location'];
      if (loc is! GeoPoint) return null;
      return _OfficeLite(
        id: doc.id,
        name: (data['officeName'] as String?) ?? '',
        address: (data['address'] as String?) ?? '',
        location: loc,
      );
    } catch (_) {
      // Network / permission error — degrade gracefully so the rest of the
      // tracked order still renders (just without a pickup marker).
      return null;
    }
  }

  /// Resolves the given [contactIds] under `organisations/{orgId}/contacts`.
  /// Uses `whereIn` in chunks of 10 (Firestore's documented limit), with a
  /// per-id fallback if `whereIn` is rejected.
  Future<Map<String, ContactModel>> _resolveContacts(
    String orgId,
    List<String> contactIds,
  ) async {
    if (orgId.isEmpty || contactIds.isEmpty) return const {};
    final contactsRef = _firestore
        .collection(_orgsCollection)
        .doc(orgId)
        .collection(_contactsSubcollection);

    final out = <String, ContactModel>{};
    for (var i = 0; i < contactIds.length; i += 10) {
      final end = (i + 10) < contactIds.length ? (i + 10) : contactIds.length;
      final chunk = contactIds.sublist(i, end);
      try {
        final snap = await contactsRef
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          out[doc.id] = ContactModel.fromSnapshot(doc);
        }
      } catch (_) {
        // Per-id fallback: some Firestore configurations refuse
        // `FieldPath.documentId` with `whereIn`. Failing chunked reads
        // should never block the whole map.
        for (final id in chunk) {
          try {
            final d = await contactsRef.doc(id).get();
            if (d.exists) out[d.id] = ContactModel.fromSnapshot(d);
          } catch (_) {
            // Skip this contact; the dropoff will render without name/phone.
          }
        }
      }
    }
    return out;
  }
}

// ---- Internal helpers ---------------------------------------------------

/// Lightweight projection of an `offices/{id}` document, decoupled from the
/// per-app `OfficeModel` (which differs between user and admin packages).
/// We only carry the three fields the map surface actually consumes.
class _OfficeLite {
  final String id;
  final String name;
  final String address;
  final GeoPoint location;

  const _OfficeLite({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
  });

  TrackedLocation toLocation() => TrackedLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        address: address.isEmpty ? null : address,
        label: name.isEmpty ? null : name,
      );
}

/// Per-stream cache that avoids re-fetching offices/contacts on every order
/// document emission. Bound to a single subscription's lifetime — when the
/// caller cancels, this cache (and its associated stream) are GC'd.
///
/// Refresh policy:
///
/// * Office: re-fetched only when `officeId` actually changes.
/// * Contacts: contacts for the same org accumulate; ids that are already
///   in the map are not re-fetched. A change of `orgId` flushes the cache.
class _LookupCache {
  String? _cachedOfficeId;
  _OfficeLite? _cachedOffice;

  String? _cachedOrgId;
  Map<String, ContactModel> _cachedContacts = const {};

  Future<_OfficeLite?> office(
    String officeId,
    Future<_OfficeLite?> Function(String) fetch,
  ) async {
    if (officeId == _cachedOfficeId) return _cachedOffice;
    _cachedOfficeId = officeId;
    _cachedOffice = await fetch(officeId);
    return _cachedOffice;
  }

  Future<Map<String, ContactModel>> contacts(
    String orgId,
    List<String> ids,
    Future<Map<String, ContactModel>> Function(String, List<String>) fetch,
  ) async {
    if (orgId != _cachedOrgId) {
      _cachedOrgId = orgId;
      _cachedContacts = await fetch(orgId, ids);
      return _cachedContacts;
    }
    final missing =
        ids.where((id) => !_cachedContacts.containsKey(id)).toList();
    if (missing.isEmpty) return _cachedContacts;
    final extra = await fetch(orgId, missing);
    _cachedContacts = {..._cachedContacts, ...extra};
    return _cachedContacts;
  }
}
