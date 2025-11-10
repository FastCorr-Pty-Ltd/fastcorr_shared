import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/models.dart';

class CourtDateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _orgRef => _firestore.collection('organisations');
  CollectionReference get _casesRef => _firestore.collection('cases');

  /// Get court dates collection reference for an organization
  CollectionReference _getCourtDatesRef(String caseId) {
    return _casesRef.doc(caseId).collection('court_dates');
  }

  /// Get all court dates for a specific case
  Future<List<CourtDateModel>> getCourtDatesForCase({
    required String caseId,
  }) async {
    final querySnapshot = await _getCourtDatesRef(
      caseId,
    ).orderBy('courtDate', descending: false).get();

    return querySnapshot.docs
        .map((doc) => CourtDateModel.fromFirestore(doc))
        .toList();
  }

  /// Get all court dates for an organization (with optional date range)
  Future<List<CourtDateModel>> getCourtDatesForOrg({
    required String caseId,
    required String orgId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    Query query = _getCourtDatesRef(caseId);

    if (startDate != null) {
      query = query.where('courtDate', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('courtDate', isLessThanOrEqualTo: endDate);
    }

    query = query.orderBy('courtDate', descending: false);

    if (limit != null) {
      query = query.limit(limit);
    }

    final querySnapshot = await query.where('orgId', isEqualTo: orgId).get();

    return querySnapshot.docs
        .map((doc) => CourtDateModel.fromFirestore(doc))
        .toList();
  }

  /// Get court dates stream for a specific case (real-time updates)
  Stream<List<CourtDateModel>> getCourtDatesStreamForCase({
    required String caseId,
  }) {
    return _getCourtDatesRef(caseId)
        .orderBy('courtDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CourtDateModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get court dates stream for an organization (real-time updates)
  Stream<List<CourtDateModel>> getCourtDatesStreamForOrg({
    required String orgId,
    required String caseId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    Query query = _getCourtDatesRef(caseId);

    if (startDate != null) {
      query = query.where('courtDate', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('courtDate', isLessThanOrEqualTo: endDate);
    }

    return query
        .where('orgId', isEqualTo: orgId)
        .orderBy('courtDate', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CourtDateModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Add a new court date
  Future<CourtDateModel?> addCourtDate({
    required String orgId,
    required String caseId,
    required String caseTitle,
    required String description,
    required DateTime courtDate,
    required CourtDateType dateType,
    String? notes,
    required String createdBy,
  }) async {
    final docRef = _getCourtDatesRef(caseId).doc();
    final trialId = _firestore.collection('trials').doc().id;

    final now = DateTime.now();

    final courtDateModel = CourtDateModel(
      dateId: docRef.id,
      trialId: trialId,
      orgId: orgId,
      caseId: caseId,
      caseTitle: caseTitle,
      description: description,
      courtDate: courtDate,
      dateType: dateType,
      status: CourtDateStatus.scheduled,
      notes: notes,
      createdAt: now,
      updatedAt: now,
      createdBy: createdBy,
    );

    await docRef.set(courtDateModel.toFirestore());
    return courtDateModel;
  }

  /// Update an existing court date
  Future<CourtDateModel?> updateCourtDate({
    required String caseId,
    required String dateId,
    String? description,
    DateTime? courtDate,
    CourtDateType? dateType,
    CourtDateStatus? status,
    String? notes,
    required String updatedBy,
  }) async {
    try {
      final docRef = _getCourtDatesRef(caseId).doc(dateId);
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      };

      if (description != null) updateData['description'] = description;
      if (courtDate != null)
        updateData['courtDate'] = Timestamp.fromDate(courtDate);
      if (dateType != null) updateData['dateType'] = dateType.name;
      if (status != null) updateData['status'] = status.name;
      if (notes != null) updateData['notes'] = notes;

      await docRef.update(updateData);
      return CourtDateModel.fromFirestore(await docRef.get());
    } catch (e) {
      print('Error updating court date: $e');
      return null;
    }
  }

  /// Delete a court date
  Future<bool> deleteCourtDate({
    required String caseId,
    required String dateId,
  }) async {
    try {
      await _getCourtDatesRef(caseId).doc(dateId).delete();
      return true;
    } catch (e) {
      print('Error deleting court date: $e');
      return false;
    }
  }

  /// Check for court date conflicts within an organization
  Future<List<CourtDateModel>> checkCourtDateConflicts({
    required String caseId,
    required DateTime courtDate,
    String? excludeDateId,
  }) async {
    final startOfDay = DateTime(courtDate.year, courtDate.month, courtDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    Query query = _getCourtDatesRef(caseId)
        .where('courtDate', isGreaterThanOrEqualTo: startOfDay)
        .where('courtDate', isLessThan: endOfDay);

    if (excludeDateId != null) {
      query = query.where(FieldPath.documentId, isNotEqualTo: excludeDateId);
    }

    final querySnapshot = await query.get();

    return querySnapshot.docs
        .map((doc) => CourtDateModel.fromFirestore(doc))
        .toList();
  }

  /// Get court dates by type for an organization
  Future<List<CourtDateModel>> getCourtDatesByType({
    required String caseId,
    required CourtDateType dateType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    Query query = _getCourtDatesRef(
      caseId,
    ).where('dateType', isEqualTo: dateType.name);

    if (startDate != null) {
      query = query.where('courtDate', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('courtDate', isLessThanOrEqualTo: endDate);
    }

    query = query.orderBy('courtDate', descending: false);

    final querySnapshot = await query.get();

    return querySnapshot.docs
        .map((doc) => CourtDateModel.fromFirestore(doc))
        .toList();
  }
}
