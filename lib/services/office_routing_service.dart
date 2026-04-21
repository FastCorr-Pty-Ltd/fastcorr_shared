import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Resolves which [officeId] a new case should use for a given filing court.
///
/// **Model:** one office per jurisdiction. Each court document stores the linked
/// office id (`fastCorrOffice` / [CourtModel.officeId]). There is no multi-office
/// scoring or load-balancing pick at case creation.
class OfficeRoutingService {
  OfficeRoutingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference get _offices => _firestore.collection('offices');

  /// Returns the validated office id for a new case.
  ///
  /// [linkedOfficeId] comes from the selected court's `fastCorrOffice` field.
  /// The office must exist, be active, and (when the office record has a
  /// non-empty `courtId`) it must match [courtId].
  ///
  Future<String?> resolveOfficeIdForNewCase({
    required String courtId,
    required String linkedOfficeId,
  }) async {
    final trimmed = linkedOfficeId.trim();
    if (courtId.isEmpty || trimmed.isEmpty) {
      log('[OfficeRouting] Missing courtId or linked office');
      return null;
    }

    try {
      final doc = await _offices.doc(trimmed).get();
      if (!doc.exists) {
        log('[OfficeRouting] Office not found: $trimmed');
        return null;
      }
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      if (data['isActive'] != true) {
        log('[OfficeRouting] Office inactive: $trimmed');
        return null;
      }
      final officeCourtId = data['courtId'] as String?;
      if (officeCourtId != null &&
          officeCourtId.isNotEmpty &&
          officeCourtId != courtId) {
        log(
          '[OfficeRouting] Office $trimmed courtId=$officeCourtId does not match court $courtId',
        );
        return null;
      }
      return trimmed;
    } catch (e, s) {
      log('[OfficeRouting] resolveOfficeIdForNewCase: $e\n$s');
      return null;
    }
  }
}
