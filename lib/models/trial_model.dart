import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fastcorr_shared/models/upload_file_data.dart';
import 'package:fastcorr_shared/utils/utils.dart';
import 'package:flutter/foundation.dart';

enum TrialStatus {
  pending,
  pendingConfirmation,
  urgent,
  proceeding,
  postponed,
  settled,
  resolvedByClient,
}

enum TrialType { trial, preTrial, motion }

/// Thrown by [TrialModel.fromSnapshot] after [TrialModel.tryParseSnapshot] logs details.
class TrialModelParseException implements Exception {
  TrialModelParseException(this.documentId, this.message);
  final String documentId;
  final String message;

  @override
  String toString() => 'TrialModelParseException($documentId): $message';
}

class TrialModel {
  final String trialId;
  final String litNumber;
  final String courtId;
  final String courtName;
  final String officeId;
  final String managerId;
  final String managerName;
  final String orgId;
  final String assigneeId;
  final String? correspondentId;
  final String correspondentName;
  final String lawyerId;
  final TrialStatus status;
  final Timestamp trialDate;
  final String? trialOutcome;
  final int capitalAmount;
  final String opposingAttorney;
  final String opposingAttorneyId;
  final List<UploadFileData>? counselBriefs;
  final String? scale;
  final TrialType type;
  final Timestamp? updatedAt; // For optimistic locking and version tracking

  TrialModel({
    required this.trialId,
    required this.litNumber,
    required this.courtId,
    required this.officeId,
    required this.orgId,
    required this.assigneeId,
    this.correspondentId,
    required this.lawyerId,
    required this.status,
    required this.trialDate,
    this.trialOutcome,
    required this.capitalAmount,
    required this.opposingAttorney,
    required this.opposingAttorneyId,
    this.counselBriefs,
    this.scale,
    required this.type,
    required this.courtName,
    required this.correspondentName,
    required this.managerId,
    required this.managerName,
    this.updatedAt,
  });

  factory TrialModel.fromJson(Map<String, dynamic> json) {
    final m = Map<String, dynamic>.from(json);
    final id = _trialReadString(m, 'trialId');
    return _trialModelFromMap(
      m,
      trialId: id.isNotEmpty ? id : 'unknown',
    );
  }

  /// Parses a Firestore document without throwing; prints rich diagnostics on failure
  /// (browser console, Flutter console, and `dart:developer` log).
  static TrialModel? tryParseSnapshot(DocumentSnapshot snapshot) {
    final id = snapshot.id;
    Map<String, dynamic>? fieldPreview;

    try {
      if (!snapshot.exists) {
        _reportTrialDocumentParseFailure(
          documentId: id,
          error: StateError('Document does not exist'),
          stackTrace: StackTrace.current,
          fieldPreview: null,
        );
        return null;
      }

      final m = _trialCoerceSnapshotDataToMap(snapshot.data(), documentId: id);
      if (m == null) return null;

      fieldPreview = m;
      return _trialModelFromMap(m, trialId: id);
    } on Object catch (e, st) {
      _reportTrialDocumentParseFailure(
        documentId: id,
        error: e,
        stackTrace: st,
        fieldPreview: fieldPreview ?? _trialSnapshotFieldPreview(snapshot),
      );
      return null;
    }
  }

  /// Strict parse: calls [tryParseSnapshot], then throws [TrialModelParseException]
  /// if parsing failed (diagnostics are already in the console).
  factory TrialModel.fromSnapshot(DocumentSnapshot snapshot) {
    final parsed = TrialModel.tryParseSnapshot(snapshot);
    if (parsed == null) {
      throw TrialModelParseException(
        snapshot.id,
        'Parsing failed — search console for "[TrialModel] PARSE FAILURE"',
      );
    }
    return parsed;
  }

  Map<String, dynamic> toJson() {
    return {
      'trialId': trialId,
      'litNumber': litNumber,
      'courtId': courtId,
      'officeId': officeId,
      'orgId': orgId,
      'assigneeId': assigneeId,
      'correspondentId': correspondentId,
      'lawyerId': lawyerId,
      'status': status.name,
      'trialDate': trialDate,
      'trialOutcome': trialOutcome,
      'capitalAmount': capitalAmount,
      'opposingAttorney': opposingAttorney,
      'opposingAttorneyId': opposingAttorneyId,
      'counselBriefs': counselBriefs?.map((e) => e.toJson()).toList(),
      'scale': scale,
      'type': type.name,
      'courtName': courtName,
      'correspondentName': correspondentName,
      'managerId': managerId,
      'managerName': managerName,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  TrialModel copyWith({
    String? trialId,
    String? litNumber,
    String? courtId,
    String? officeId,
    String? orgId,
    String? assigneeId,
    String? correspondentId,
    String? lawyerId,
    TrialStatus? status,
    Timestamp? trialDate,
    String? trialOutcome,
    int? capitalAmount,
    String? opposingAttorney,
    String? opposingAttorneyId,
    List<UploadFileData>? counselBriefs,
    String? scale,
    TrialType? type,
    String? courtName,
    String? correspondentName,
    String? managerId,
    String? managerName,
    Timestamp? updatedAt,
  }) {
    return TrialModel(
      trialId: trialId ?? this.trialId,
      litNumber: litNumber ?? this.litNumber,
      courtId: courtId ?? this.courtId,
      officeId: officeId ?? this.officeId,
      orgId: orgId ?? this.orgId,
      assigneeId: assigneeId ?? this.assigneeId,
      correspondentId: correspondentId ?? this.correspondentId,
      lawyerId: lawyerId ?? this.lawyerId,
      status: status ?? this.status,
      trialDate: trialDate ?? this.trialDate,
      trialOutcome: trialOutcome ?? this.trialOutcome,
      capitalAmount: capitalAmount ?? this.capitalAmount,
      opposingAttorney: opposingAttorney ?? this.opposingAttorney,
      opposingAttorneyId: opposingAttorneyId ?? this.opposingAttorneyId,
      counselBriefs: counselBriefs ?? this.counselBriefs,
      scale: scale ?? this.scale,
      type: type ?? this.type,
      courtName: courtName ?? this.courtName,
      correspondentName: correspondentName ?? this.correspondentName,
      managerId: managerId ?? this.managerId,
      managerName: managerName ?? this.managerName,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

TrialModel _trialModelFromMap(
  Map<String, dynamic> m, {
  required String trialId,
}) {
  return TrialModel(
    trialId: trialId,
    litNumber: _trialReadString(m, 'litNumber'),
    courtId: _trialReadString(m, 'courtId'),
    courtName: _trialReadString(m, 'courtName'),
    officeId: _trialReadString(m, 'officeId'),
    managerId: _trialReadString(m, 'managerId'),
    managerName: _trialReadString(m, 'managerName'),
    orgId: _trialReadString(m, 'orgId'),
    assigneeId: _trialReadString(m, 'assigneeId'),
    correspondentId: m['correspondentId']?.toString(),
    correspondentName: _trialReadString(m, 'correspondentName'),
    lawyerId: _trialReadString(m, 'lawyerId'),
    status: _trialReadStatus(m),
    trialDate: _trialReadTrialDate(m),
    trialOutcome: m['trialOutcome']?.toString(),
    capitalAmount: _trialReadInt(m, 'capitalAmount'),
    opposingAttorney: _trialReadString(m, 'opposingAttorney'),
    opposingAttorneyId: _trialReadString(m, 'opposingAttorneyId'),
    counselBriefs: _trialReadCounselBriefs(m),
    scale: m['scale']?.toString(),
    type: _trialReadType(m),
    updatedAt: _trialReadTimestampNullable(m, 'updatedAt'),
  );
}

String _trialReadString(
  Map<String, dynamic> m,
  String key, [
  String fallback = '',
]) {
  final v = m[key];
  if (v == null) return fallback;
  return v.toString().trim();
}

int _trialReadInt(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

Timestamp? _trialReadTimestampNullable(Map<String, dynamic> m, String key) {
  final raw = m[key];
  if (raw == null) return null;
  try {
    return processedTimestamp(raw);
  } catch (_) {
    return null;
  }
}

/// Firestore / web clients may omit [trialDate] or send values
/// [processedTimestamp] cannot handle — avoid throwing so the home dashboard loads.
Timestamp _trialReadTrialDate(Map<String, dynamic> m) {
  final t = _trialReadTimestampNullable(m, 'trialDate');
  if (t != null) return t;
  return Timestamp.fromDate(DateTime.now());
}

TrialStatus _trialReadStatus(Map<String, dynamic> m) {
  final v = m['status'];
  if (v == null) return TrialStatus.pending;
  final s = v.toString().trim();
  if (s.isEmpty) return TrialStatus.pending;
  try {
    return TrialStatus.values.byName(s);
  } catch (_) {
    final lower = s.toLowerCase();
    for (final e in TrialStatus.values) {
      if (e.name.toLowerCase() == lower) return e;
    }
    final norm = lower.replaceAll(RegExp(r'[\s_-]'), '');
    for (final e in TrialStatus.values) {
      if (e.name.toLowerCase().replaceAll('_', '') == norm) return e;
    }
    return TrialStatus.pending;
  }
}

TrialType _trialReadType(Map<String, dynamic> m) {
  final v = m['type'];
  if (v == null) return TrialType.trial;
  final s = v.toString().trim();
  if (s.isEmpty) return TrialType.trial;
  try {
    return TrialType.values.byName(s);
  } catch (_) {
    final lower = s.toLowerCase();
    for (final e in TrialType.values) {
      if (e.name.toLowerCase() == lower) return e;
    }
    if (lower == 'pretrial' || lower == 'pre-trial' || lower == 'pre_trial') {
      return TrialType.preTrial;
    }
    return TrialType.trial;
  }
}

List<UploadFileData>? _trialReadCounselBriefs(Map<String, dynamic> m) {
  try {
    final raw = m['counselBriefs'];
    if (raw == null || raw is! List) return null;
    final out = <UploadFileData>[];
    for (final e in raw) {
      if (e is! Map) continue;
      try {
        out.add(
          UploadFileData.fromJson(
            Map<String, dynamic>.from(e),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return out.isEmpty ? null : out;
  } on Object {
    return null;
  }
}

void _reportTrialDocumentParseFailure({
  required String documentId,
  required Object error,
  required StackTrace stackTrace,
  required Map<String, dynamic>? fieldPreview,
}) {
  final buf = StringBuffer()
    ..writeln(
      '════════════════════════════════════════════════════════════',
    )
    ..writeln('[TrialModel] PARSE FAILURE documentId=$documentId')
    ..writeln('error: $error (${error.runtimeType})');

  if (fieldPreview != null) {
    buf.writeln('field count: ${fieldPreview.length}');
    for (final e in fieldPreview.entries) {
      buf.writeln('  • ${e.key}: ${_trialPreviewField(e.value)}');
    }
  } else {
    buf.writeln('(no field map available)');
  }
  buf.writeln('stack:\n$stackTrace');
  buf.writeln(
    '════════════════════════════════════════════════════════════',
  );

  final text = buf.toString();
  // ignore: avoid_print — intentional: visible in browser DevTools where `log` is easy to miss.
  print(text);
  debugPrint(text, wrapWidth: 200);
  developer.log(
    '[TrialModel] PARSE FAILURE id=$documentId — $error',
    name: 'TrialModel',
    error: error,
    stackTrace: stackTrace,
    level: 1000, // severe
  );
}

String _trialPreviewField(Object? v) {
  if (v == null) return 'null';
  if (v is Timestamp) {
    return 'Timestamp(${v.toDate().toIso8601String()})';
  }
  final s = v.toString();
  if (s.length > 200) return '${s.substring(0, 200)}…';
  return '${v.runtimeType}: $s';
}

/// Best-effort field map for error context only (does not log).
Map<String, dynamic>? _trialSnapshotFieldPreview(DocumentSnapshot snapshot) {
  try {
    final raw = snapshot.data();
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
  } on Object {
    return null;
  }
  return null;
}

/// Supports typed queries and transaction reads where [DocumentSnapshot.data] may be
/// `Map<String, dynamic>` or a loose `Map` (e.g. web interop).
Map<String, dynamic>? _trialCoerceSnapshotDataToMap(
  Object? raw, {
  required String documentId,
}) {
  if (raw == null) {
    _reportTrialDocumentParseFailure(
      documentId: documentId,
      error: StateError('snapshot.data() is null'),
      stackTrace: StackTrace.current,
      fieldPreview: null,
    );
    return null;
  }
  try {
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
  } on Object catch (e, st) {
    _reportTrialDocumentParseFailure(
      documentId: documentId,
      error: e,
      stackTrace: st,
      fieldPreview: null,
    );
    return null;
  }

  _reportTrialDocumentParseFailure(
    documentId: documentId,
    error: FormatException(
      'Expected Map snapshot data, got ${raw.runtimeType}',
    ),
    stackTrace: StackTrace.current,
    fieldPreview: null,
  );
  return null;
}
