import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../models/trial_model.dart';
import 'document_service.dart';

/// Shared service for managing trial records.
///
/// This service is intended to replace the remaining CourtDateModel usage by
/// providing a unified CRUD layer around TrialModel that both the user and
/// admin applications can consume.
class TrialService {
  TrialService({
    FirebaseFirestore? firestore,
    DocumentService? documentService,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _documentService = documentService ?? DocumentService(),
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final DocumentService _documentService;
  final Uuid _uuid;

  CollectionReference<Map<String, dynamic>> get _trialsRef =>
      _firestore.collection('trials');

  /// Get a single trial by its Firestore document ID.
  Future<TrialModel?> getTrialById(String trialId) async {
    if (trialId.isEmpty) return null;
    try {
      final doc = await _trialsRef.doc(trialId).get();
      if (!doc.exists) {
        return null;
      }
      return TrialModel.fromSnapshot(doc);
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error fetching trial by id: $trialId -> $e',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Get all trials associated with a litigation number.
  ///
  /// [litNumber] acts as a unique identifier for a case file.
  Future<List<TrialModel>> getTrialsByLitNumber(
    String litNumber, {
    TrialStatus? status,
    TrialType? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (litNumber.isEmpty) return [];

    try {
      Query<Map<String, dynamic>> query = _trialsRef.where(
        'litNumber',
        isEqualTo: litNumber,
      );

      if (status != null) {
        query = query.where('status', isEqualTo: status.name);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
      }

      if (startDate != null) {
        query = query.where(
          'trialDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'trialDate',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      query = query.orderBy('trialDate');

      final snapshot = await query.get();
      return snapshot.docs.map(TrialModel.fromSnapshot).toList();
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error fetching trials for litNumber $litNumber: $e',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Stream trials for a litigation number to support real-time views.
  Stream<List<TrialModel>> watchTrialsByLitNumber(String litNumber) {
    if (litNumber.isEmpty) {
      return const Stream.empty();
    }

    try {
      return _trialsRef
          .where('litNumber', isEqualTo: litNumber)
          .orderBy('trialDate')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map(TrialModel.fromSnapshot)
                .toList(growable: false),
          );
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error streaming trials for litNumber $litNumber: $e',
        stackTrace: stackTrace,
      );
      return const Stream.empty();
    }
  }

  /// Create a new trial entry.
  ///
  /// Returns the persisted [TrialModel] with the generated document id, or null
  /// when creation fails.
  Future<TrialModel?> createTrial(TrialModel trial) async {
    try {
      final docRef = _trialsRef.doc();
      final trialToSave = trial.copyWith(trialId: docRef.id);
      await docRef.set(trialToSave.toJson());
      return trialToSave;
    } catch (e, stackTrace) {
      log('[TrialService] Error creating trial: $e', stackTrace: stackTrace);
      return null;
    }
  }

  /// Update an existing trial. Returns `true` on success.
  Future<bool> updateTrial(TrialModel trial) async {
    if (trial.trialId.isEmpty) {
      log('[TrialService] Cannot update trial without an id');
      return false;
    }

    try {
      await _trialsRef.doc(trial.trialId).update(trial.toJson());
      return true;
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error updating trial ${trial.trialId}: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Patch selective fields on a trial document.
  ///
  /// Useful when only a subset of fields need to be updated without creating a
  /// new [TrialModel] instance.
  Future<bool> patchTrial(
    String trialId, {
    String? correspondentId,
    String? correspondentName,
    TrialStatus? status,
    TrialType? type,
    Timestamp? trialDate,
    String? trialOutcome,
    int? capitalAmount,
    String? scale,
    String? opposingAttorney,
    String? opposingAttorneyId,
    String? counselBriefId,
  }) async {
    if (trialId.isEmpty) return false;

    final updateData = <String, dynamic>{
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    if (correspondentId != null) {
      updateData['correspondentId'] = correspondentId;
    }

    if (correspondentName != null) {
      updateData['correspondentName'] = correspondentName;
    }

    if (status != null) {
      updateData['status'] = status.name;
    }

    if (type != null) {
      updateData['type'] = type.name;
    }

    if (trialDate != null) {
      updateData['trialDate'] = trialDate;
    }

    if (trialOutcome != null) {
      updateData['trialOutcome'] = trialOutcome;
    }

    if (capitalAmount != null) {
      updateData['capitalAmount'] = capitalAmount;
    }

    if (scale != null) {
      updateData['scale'] = scale;
    }

    if (opposingAttorney != null) {
      updateData['opposingAttorney'] = opposingAttorney;
    }

    if (opposingAttorneyId != null) {
      updateData['opposingAttorneyId'] = opposingAttorneyId;
    }

    if (counselBriefId != null) {
      updateData['counselBriefId'] = counselBriefId;
    }

    if (updateData.length == 1) {
      // Only updatedAt present — nothing to patch
      return true;
    }

    try {
      await _trialsRef.doc(trialId).update(updateData);
      return true;
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error patching trial $trialId: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Remove a trial document. Caller is responsible for any cascading deletions
  /// (e.g. notifications or availability slots).
  Future<bool> deleteTrial(String trialId) async {
    if (trialId.isEmpty) return false;
    try {
      await _trialsRef.doc(trialId).delete();
      return true;
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error deleting trial $trialId: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Upload a counsel brief file and persist its metadata on the trial record.
  ///
  /// Returns [CounselBriefInfo] describing the uploaded asset, or `null` if the
  /// upload failed.
  Future<CounselBriefInfo?> uploadCounselBrief({
    required String trialId,
    required PlatformFile file,
    String? notes,
  }) async {
    if (trialId.isEmpty) return null;

    try {
      final trialRef = _trialsRef.doc(trialId);
      final trialDoc = await trialRef.get();
      if (!trialDoc.exists) {
        log(
          '[TrialService] Trial not found for counsel brief upload: $trialId',
        );
        return null;
      }

      final downloadUrl = await _documentService.uploadFileToStorage(file);
      final briefId = _uuid.v4();
      final uploadedAt = Timestamp.now();

      final updateData = {
        'counselBriefId': briefId,
        'counselBriefName': file.name,
        'counselBriefUrl': downloadUrl,
        'counselBriefUploadedAt': uploadedAt,
        'counselBriefNotes': notes ?? '',
      };

      await trialRef.update(updateData);

      return CounselBriefInfo(
        briefId: briefId,
        fileName: file.name,
        downloadUrl: downloadUrl,
        uploadedAt: uploadedAt,
        notes: notes,
      );
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error uploading counsel brief for $trialId: $e',
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Clear counsel brief metadata from a trial document.
  Future<bool> clearCounselBrief(String trialId) async {
    if (trialId.isEmpty) return false;
    try {
      await _trialsRef.doc(trialId).update({
        'counselBriefId': FieldValue.delete(),
        'counselBriefName': FieldValue.delete(),
        'counselBriefUrl': FieldValue.delete(),
        'counselBriefUploadedAt': FieldValue.delete(),
        'counselBriefNotes': FieldValue.delete(),
      });
      return true;
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error clearing counsel brief for $trialId: $e',
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}

/// Represents uploaded counsel brief metadata.
class CounselBriefInfo {
  const CounselBriefInfo({
    required this.briefId,
    required this.fileName,
    required this.downloadUrl,
    required this.uploadedAt,
    this.notes,
  });

  final String briefId;
  final String fileName;
  final String downloadUrl;
  final Timestamp uploadedAt;
  final String? notes;

  Map<String, dynamic> toMap() {
    return {
      'counselBriefId': briefId,
      'counselBriefName': fileName,
      'counselBriefUrl': downloadUrl,
      'counselBriefUploadedAt': uploadedAt,
      'counselBriefNotes': notes,
    };
  }
}
