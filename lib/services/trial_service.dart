import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/trial_model.dart';
import '../models/upload_file_data.dart';
import 'document_service.dart';

/// Shared service for managing trial records.
///
/// Provides a unified CRUD layer around `TrialModel` that both the user and
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

  @protected
  FirebaseFirestore get firestore => _firestore;

  @protected
  CollectionReference<Map<String, dynamic>> get trialsRef => _trialsRef;

  @protected
  DocumentService get documentService => _documentService;

  @protected
  Uuid get uuid => _uuid;

  /// Parses trial documents, logging and skipping any that fail to deserialize.
  List<TrialModel> _trialModelsFromDocs(
    Iterable<DocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final out = <TrialModel>[];
    for (final doc in docs) {
      if (!doc.exists) continue;
      final model = TrialModel.tryParseSnapshot(doc);
      if (model != null) {
        out.add(model);
      }
    }
    return out;
  }

  /// Get a single trial by its Firestore document ID.
  Future<TrialModel?> getTrialById(String trialId) async {
    if (trialId.isEmpty) return null;
    try {
      final doc = await _trialsRef.doc(trialId).get();
      if (!doc.exists) {
        return null;
      }
      return TrialModel.tryParseSnapshot(doc);
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
      return _trialModelsFromDocs(snapshot.docs);
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
            (snapshot) =>
                _trialModelsFromDocs(snapshot.docs),
          );
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error streaming trials for litNumber $litNumber: $e',
        stackTrace: stackTrace,
      );
      return const Stream.empty();
    }
  }

  /// Get all trials assigned to a specific lawyer.
  Future<List<TrialModel>> getTrialsByLawyerId({
    required String lawyerId,
    String? orgId,
  }) async {
    if (lawyerId.isEmpty) return [];

    try {
      Query<Map<String, dynamic>> query = trialsRef.where(
        'lawyerId',
        isEqualTo: lawyerId,
      );

      if (orgId != null && orgId.isNotEmpty) {
        query = query.where('orgId', isEqualTo: orgId);
      }

      final snapshot = await query.get();
      return _trialModelsFromDocs(snapshot.docs);
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error getting trials for lawyer $lawyerId: $e',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Filter trials for a lawyer by type and organisation.
  Future<List<TrialModel>> getTrialsByType({
    required String lawyerId,
    required String orgId,
    required TrialType type,
    bool descending = true,
  }) async {
    if (lawyerId.isEmpty || orgId.isEmpty) return [];

    try {
      final snapshot = await trialsRef
          .where('lawyerId', isEqualTo: lawyerId)
          .where('orgId', isEqualTo: orgId)
          .where('type', isEqualTo: type.name)
          .orderBy('trialDate', descending: descending)
          .get();

      return _trialModelsFromDocs(snapshot.docs);
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error getting ${type.name} trials for lawyer $lawyerId / org $orgId: $e',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Create a new trial entry.
  ///
  /// Returns the persisted [TrialModel] with the generated document id, or null
  /// when creation fails.
  Future<TrialModel?> createTrial(TrialModel trial) async {
    try {
      final docRef = _trialsRef.doc();
      final now = Timestamp.now();
      final trialToSave = trial.copyWith(trialId: docRef.id, updatedAt: now);
      await docRef.set(trialToSave.toJson());
      return trialToSave;
    } catch (e, stackTrace) {
      log('[TrialService] Error creating trial: $e', stackTrace: stackTrace);
      return null;
    }
  }

  /// Validate trial date is reasonable (not too far in past or future)
  ///
  /// Returns null if valid, error message if invalid
  String? validateTrialDate(DateTime trialDate) {
    final now = DateTime.now();
    final minDate = now.subtract(
      const Duration(days: 365),
    ); // Allow past dates up to 1 year
    final maxDate = now.add(
      const Duration(days: 365 * 3),
    ); // Allow future dates up to 3 years

    if (trialDate.isBefore(minDate)) {
      return 'Trial date cannot be more than 1 year in the past';
    }

    if (trialDate.isAfter(maxDate)) {
      return 'Trial date cannot be more than 3 years in the future';
    }

    return null; // Valid
  }

  /// Validate required fields for trial creation
  ///
  /// Returns null if valid, error message if invalid
  String? validateTrialData(TrialModel trial) {
    if (trial.litNumber.isEmpty) {
      return 'Litigation number is required';
    }

    if (trial.courtId.isEmpty) {
      return 'Court ID is required';
    }

    if (trial.lawyerId.isEmpty) {
      return 'Lawyer ID is required';
    }

    if (trial.orgId.isEmpty) {
      return 'Organization ID is required';
    }

    // Validate trial date
    final trialDate = trial.trialDate.toDate();
    final dateValidation = validateTrialDate(trialDate);
    if (dateValidation != null) {
      return dateValidation;
    }

    return null; // Valid
  }

  /// Create or update trial atomically with duplicate prevention and status update.
  ///
  /// This method uses a Firestore transaction to ensure:
  /// - No duplicate pendingConfirmation trials for the same case/type
  /// - Atomic status update from pendingConfirmation to pending
  /// - Atomic counsel brief linking (supports multiple briefs)
  /// - Optimistic locking to prevent race conditions
  /// - Validation of trial data before creation
  ///
  /// [existingTrial] - The trial to update (if null, creates new trial)
  /// [newTrial] - The new trial data (only used if existingTrial is null)
  /// [needsStatusUpdate] - Whether to update status from pendingConfirmation to pending
  /// [counselBriefs] - List of counsel brief files to link (supports multiple)
  ///
  /// Returns the trial model if successful, null otherwise.
  Future<TrialModel?> createOrUpdateTrialAtomically({
    required String litNumber,
    required TrialType type,
    TrialModel? existingTrial,
    TrialModel? newTrial,
    required bool needsStatusUpdate,
    List<UploadFileData>? counselBriefs,
  }) async {
    try {
      return await _firestore.runTransaction((transaction) async {
        DocumentReference trialRef;
        TrialModel trialToProcess;

        if (existingTrial != null && existingTrial.trialId.isNotEmpty) {
          // Updating existing trial - read it within transaction
          trialRef = _trialsRef.doc(existingTrial.trialId);
          final trialDoc = await transaction.get(trialRef);

          if (!trialDoc.exists) {
            log(
              '[TrialService] Existing trial ${existingTrial.trialId} not found in transaction',
            );
            throw Exception('Trial not found');
          }

          final parsed = TrialModel.tryParseSnapshot(trialDoc);
          if (parsed == null) {
            throw Exception(
              'Trial document ${trialDoc.id} could not be parsed (see console)',
            );
          }
          trialToProcess = parsed;

          // Enhanced optimistic locking: verify the trial hasn't been modified
          if (trialToProcess.status != existingTrial.status) {
            log(
              '[TrialService] Trial status changed from ${existingTrial.status} to ${trialToProcess.status}',
            );
            throw Exception(
              'Trial status has changed. Please refresh and try again.',
            );
          }

          // Check updatedAt timestamp for additional version checking
          if (existingTrial.updatedAt != null &&
              trialToProcess.updatedAt != null) {
            if (trialToProcess.updatedAt!.millisecondsSinceEpoch !=
                existingTrial.updatedAt!.millisecondsSinceEpoch) {
              log(
                '[TrialService] Trial was modified (updatedAt mismatch). Expected: ${existingTrial.updatedAt}, Got: ${trialToProcess.updatedAt}',
              );
              throw Exception(
                'Trial was modified by another process. Please refresh and try again.',
              );
            }
          }
        } else {
          // Creating new trial - check for duplicate pendingConfirmation trials
          // Note: Firestore transactions can't query, only read specific documents
          // So we check before transaction, then verify within transaction if duplicates found
          final duplicateTrials = await getTrialsByLitNumber(
            litNumber,
            status: TrialStatus.pendingConfirmation,
            type: type,
          );

          if (duplicateTrials.isNotEmpty) {
            // Verify within transaction that the duplicate still exists
            // This ensures we catch race conditions where another transaction
            // creates a duplicate between our check and the transaction
            final duplicateRef = _trialsRef.doc(duplicateTrials.first.trialId);
            final duplicateDoc = await transaction.get(duplicateRef);

            if (duplicateDoc.exists) {
              log(
                '[TrialService] Duplicate pendingConfirmation trial found for $litNumber, type: $type',
              );
              throw Exception(
                'A trial is already pending confirmation for this case. Please confirm the existing trial instead.',
              );
            }
          }

          // Validate new trial data
          if (newTrial == null) {
            throw Exception('New trial data is required for creation');
          }

          // Validate trial data before creation
          final validationError = validateTrialData(newTrial);
          if (validationError != null) {
            log('[TrialService] Validation failed: $validationError');
            throw Exception(validationError);
          }

          // Create new trial document
          trialRef = _trialsRef.doc();
          trialToProcess = newTrial;
        }

        // Prepare update data with timestamp for version tracking
        final now = Timestamp.now();
        final updateData = <String, dynamic>{'updatedAt': now};

        // Update status if needed
        if (needsStatusUpdate) {
          if (trialToProcess.status != TrialStatus.pendingConfirmation) {
            throw Exception(
              'Cannot update status: trial is not in pendingConfirmation status',
            );
          }
          updateData['status'] = TrialStatus.pending.name;
          log(
            '[TrialService] Updating trial status from pendingConfirmation to pending',
          );
        }

        // Add counsel briefs if provided (supports multiple)
        if (counselBriefs != null && counselBriefs.isNotEmpty) {
          // Convert UploadFileData list to JSON
          updateData['counselBriefs'] = counselBriefs
              .map((brief) => brief.toJson())
              .toList();
          log(
            '[TrialService] Linking ${counselBriefs.length} counsel brief(s) to trial',
          );
        }

        // Perform the update/create atomically
        if (existingTrial != null && existingTrial.trialId.isNotEmpty) {
          // Update existing trial
          if (updateData.length > 1) {
            // More than just updatedAt
            transaction.update(trialRef, updateData);
          }
          log(
            '[TrialService] Updating existing trial ${trialRef.id} atomically',
          );

          // Return updated trial model with new timestamp
          return trialToProcess.copyWith(
            status: needsStatusUpdate
                ? TrialStatus.pending
                : trialToProcess.status,
            counselBriefs: counselBriefs ?? trialToProcess.counselBriefs,
            updatedAt: now,
          );
        } else {
          // Create new trial
          final trialToSave = trialToProcess.copyWith(trialId: trialRef.id);
          final finalTrial = needsStatusUpdate
              ? trialToSave.copyWith(status: TrialStatus.pending)
              : trialToSave;

          // Merge counsel briefs into the trial JSON
          final trialJson = finalTrial.toJson();
          if (counselBriefs != null && counselBriefs.isNotEmpty) {
            trialJson['counselBriefs'] = counselBriefs
                .map((brief) => brief.toJson())
                .toList();
          }
          trialJson['updatedAt'] = now;

          transaction.set(trialRef, trialJson);
          log('[TrialService] Creating new trial ${trialRef.id} atomically');

          return finalTrial.copyWith(
            counselBriefs: counselBriefs ?? finalTrial.counselBriefs,
            updatedAt: now,
          );
        }
      });
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error in atomic trial operation: $e',
        stackTrace: stackTrace,
      );
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
  }) async {
    if (trialId.isEmpty) return false;

    final updateData = <String, dynamic>{'updatedAt': Timestamp.now()};

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

  /// Find and report orphaned trials (trials in inconsistent states)
  ///
  /// Orphaned trials include:
  /// - pendingConfirmation trials older than 30 days (likely abandoned)
  /// - Trials with invalid or missing case references
  /// - Trials with dates in the past that are still pending
  ///
  /// Returns a list of trial IDs that may need cleanup
  Future<List<String>> findOrphanedTrials({
    Duration maxPendingConfirmationAge = const Duration(days: 30),
    bool includeStalePending = true,
  }) async {
    try {
      final orphanedTrialIds = <String>[];
      final now = DateTime.now();
      final cutoffDate = now.subtract(maxPendingConfirmationAge);

      // Find pendingConfirmation trials older than cutoff
      final stalePendingConfirmation = await _trialsRef
          .where('status', isEqualTo: TrialStatus.pendingConfirmation.name)
          .where('trialDate', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      for (final doc in stalePendingConfirmation.docs) {
        orphanedTrialIds.add(doc.id);
        log('[TrialService] Found stale pendingConfirmation trial: ${doc.id}');
      }

      // Find pending trials with dates in the past (more than 7 days old)
      if (includeStalePending) {
        final pastDate = now.subtract(const Duration(days: 7));
        final stalePending = await _trialsRef
            .where('status', isEqualTo: TrialStatus.pending.name)
            .where('trialDate', isLessThan: Timestamp.fromDate(pastDate))
            .get();

        for (final doc in stalePending.docs) {
          final trial = TrialModel.tryParseSnapshot(doc);
          if (trial == null) continue;
          // Only flag if trial date is significantly in the past
          if (trial.trialDate.toDate().isBefore(pastDate)) {
            orphanedTrialIds.add(doc.id);
            log(
              '[TrialService] Found stale pending trial with past date: ${doc.id}',
            );
          }
        }
      }

      log('[TrialService] Found ${orphanedTrialIds.length} orphaned trials');
      return orphanedTrialIds;
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error finding orphaned trials: $e',
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Clean up orphaned trials by updating their status or marking for review
  ///
  /// This is a safe operation that marks trials for review rather than deleting them
  Future<int> cleanupOrphanedTrials({
    Duration maxPendingConfirmationAge = const Duration(days: 30),
    bool autoResolve = false,
  }) async {
    try {
      final orphanedIds = await findOrphanedTrials(
        maxPendingConfirmationAge: maxPendingConfirmationAge,
      );

      if (orphanedIds.isEmpty) {
        log('[TrialService] No orphaned trials found');
        return 0;
      }

      int cleanedCount = 0;
      final batch = _firestore.batch();
      final batchLimit = 500; // Firestore batch limit
      int batchCount = 0;

      for (final trialId in orphanedIds) {
        try {
          final trialDoc = await _trialsRef.doc(trialId).get();
          if (!trialDoc.exists) continue;

          final trial = TrialModel.tryParseSnapshot(trialDoc);
          if (trial == null) continue;

          // Only auto-resolve if explicitly requested and trial is very old
          if (autoResolve && trial.status == TrialStatus.pendingConfirmation) {
            final trialAge = DateTime.now().difference(
              trial.trialDate.toDate(),
            );
            if (trialAge.inDays > 60) {
              // Mark as resolved by client if very old
              final trialRef = _trialsRef.doc(trialId);
              batch.update(trialRef, {
                'status': TrialStatus.resolvedByClient.name,
                'updatedAt': Timestamp.now(),
                'cleanupNote': 'Auto-resolved during orphaned trial cleanup',
              });
              batchCount++;
              cleanedCount++;
            }
          } else {
            // Mark for manual review
            final trialRef = _trialsRef.doc(trialId);
            batch.update(trialRef, {
              'updatedAt': Timestamp.now(),
              'needsReview': true,
              'reviewReason': 'Orphaned trial detected during cleanup',
            });
            batchCount++;
            cleanedCount++;
          }

          // Commit batch if we hit the limit
          if (batchCount >= batchLimit) {
            await batch.commit();
            batchCount = 0;
            log('[TrialService] Committed batch of orphaned trial updates');
          }
        } catch (e) {
          log('[TrialService] Error processing orphaned trial $trialId: $e');
        }
      }

      // Commit remaining updates
      if (batchCount > 0) {
        await batch.commit();
      }

      log('[TrialService] Cleaned up $cleanedCount orphaned trials');
      return cleanedCount;
    } catch (e, stackTrace) {
      log(
        '[TrialService] Error cleaning up orphaned trials: $e',
        stackTrace: stackTrace,
      );
      return 0;
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

      // Get trial to extract litNumber
      final trial = TrialModel.tryParseSnapshot(trialDoc);
      if (trial == null) {
        log(
          '[TrialService] Could not parse trial for counsel brief upload: $trialId',
        );
        return null;
      }

      // Get existing counsel briefs or create new list
      final trialDocData = trialDoc.data();
      final existingBriefs = trialDocData?['counselBriefs'] as List? ?? [];

      // Create new brief entry as JSON map (UploadFileData requires caseFileId which may not be available)
      final newBriefJson = {
        'fileId': briefId,
        'fileName': file.name,
        'fileUrl': downloadUrl,
        'litNumber': trial.litNumber,
        'caseFileId': '', // caseFileId may not be available at trial level
        'size': file.size?.toDouble(),
        'takenAt': uploadedAt.toDate().toIso8601String(),
      };

      // Add new brief to list
      final updatedBriefs = <Map<String, dynamic>>[
        ...existingBriefs.map((e) => e as Map<String, dynamic>),
        newBriefJson,
      ];

      await trialRef.update({
        'counselBriefs': updatedBriefs,
        'updatedAt': Timestamp.now(),
      });

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
        'counselBriefs': FieldValue.delete(),
        'updatedAt': Timestamp.now(),
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
