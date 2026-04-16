import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Outcome of ranking an office for jurisdiction-based case routing.
class OfficeRoutingResult {
  final String officeId;
  final String officeName;
  final double qualityScore;
  final double workloadScore;
  final int openCaseCount;
  final int unassignedCaseCount;
  final int overdueTaskCount;
  final int openComplaintCount;

  const OfficeRoutingResult({
    required this.officeId,
    required this.officeName,
    required this.qualityScore,
    required this.workloadScore,
    required this.openCaseCount,
    required this.unassignedCaseCount,
    required this.overdueTaskCount,
    required this.openComplaintCount,
  });
}

/// Picks an [officeId] for a new case when several offices share the same
/// [courtId] (jurisdiction). High-performing offices are preferred; overloaded
/// offices are skipped in favour of the next best candidate.
///
/// **Quality** (higher is better): penalises open support tickets and overdue /
/// escalated tasks. **Workload** (higher is busier): open org cases, unassigned
/// cases, and delay signals. Tunable weights are fields on this class.
class OfficeRoutingService {
  OfficeRoutingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Weight applied to each open / non-resolved support ticket (complaints).
  double complaintPenaltyWeight = 8.0;

  /// Weight for tasks in `overdue` or `escalated` status.
  double delaySignalWeight = 3.0;

  /// Weight for active org cases at the office.
  double openCaseWeight = 1.2;

  /// Extra weight for unassigned cases (routing risk).
  double unassignedCaseWeight = 2.5;

  /// When comparing workloads, allow the best-quality office only if its
  /// workload is at or below `medianWorkload * workloadCeilingFactor`.
  double workloadCeilingFactor = 1.35;

  CollectionReference get _offices => _firestore.collection('offices');
  CollectionReference get _cases => _firestore.collection('cases');
  CollectionReference get _tasks => _firestore.collection('litigation_requests');
  CollectionReference get _tickets => _firestore.collection('support_tickets');

  /// Returns the best office id, or `null` if none qualify.
  Future<String?> selectOptimalOfficeId({
    required String courtId,
    required String orgId,
  }) async {
    final pick = await selectOptimalOffice(courtId: courtId, orgId: orgId);
    return pick?.officeId;
  }

  /// Load-balanced pick when possible; if ranking fails entirely, returns any
  /// active office for [courtId] so case creation can still proceed.
  Future<String?> resolveOfficeIdForNewCase({
    required String courtId,
    required String orgId,
  }) async {
    final optimal =
        await selectOptimalOfficeId(courtId: courtId, orgId: orgId);
    if (optimal != null && optimal.isNotEmpty) return optimal;
    try {
      final snap = await _offices
          .where('courtId', isEqualTo: courtId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.id;
    } catch (e, s) {
      log('[OfficeRouting] fallback office: $e\n$s');
      return null;
    }
  }

  Future<OfficeRoutingResult?> selectOptimalOffice({
    required String courtId,
    required String orgId,
  }) async {
    final ranked = await rankOfficesForCourt(courtId: courtId, orgId: orgId);
    if (ranked.isEmpty) return null;
    if (ranked.length == 1) return ranked.first;

    final workloads = ranked.map((e) => e.workloadScore).toList()..sort();
    final mid = workloads.length ~/ 2;
    final medianWorkload = workloads.length.isOdd
        ? workloads[mid]
        : (workloads[mid - 1] + workloads[mid]) / 2.0;
    final ceiling = medianWorkload * workloadCeilingFactor;

    for (final candidate in ranked) {
      if (candidate.workloadScore <= ceiling) {
        return candidate;
      }
    }

    // All above ceiling — pick least loaded to protect SLAs.
    ranked.sort((a, b) => a.workloadScore.compareTo(b.workloadScore));
    return ranked.first;
  }

  /// All active offices for [courtId], sorted by **quality** (best first).
  Future<List<OfficeRoutingResult>> rankOfficesForCourt({
    required String courtId,
    required String orgId,
  }) async {
    if (courtId.isEmpty || orgId.isEmpty) return [];

    try {
      final snap = await _offices
          .where('courtId', isEqualTo: courtId)
          .where('isActive', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) {
        log('[OfficeRouting] No active offices for courtId=$courtId');
        return [];
      }

      final results = <OfficeRoutingResult>[];
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final officeId = doc.id;
        final officeName = data['officeName'] as String? ?? officeId;

        final openCases =
            await _countOrgCasesForOffice(orgId: orgId, officeId: officeId);
        final unassigned = await _countUnassignedCases(
            orgId: orgId, officeId: officeId);
        final delaySignals = await _countDelaySignals(officeId: officeId);
        final complaints = await _countOpenComplaints(officeId: officeId);

        final workload = openCases * openCaseWeight +
            unassigned * unassignedCaseWeight +
            delaySignals * delaySignalWeight;

        final quality = 100.0 -
            complaints * complaintPenaltyWeight -
            delaySignals * (delaySignalWeight * 0.8);

        final clampedQuality = quality.clamp(0.0, 100.0);

        results.add(OfficeRoutingResult(
          officeId: officeId,
          officeName: officeName,
          qualityScore: clampedQuality,
          workloadScore: workload,
          openCaseCount: openCases,
          unassignedCaseCount: unassigned,
          overdueTaskCount: delaySignals,
          openComplaintCount: complaints,
        ));
      }

      results.sort((a, b) => b.qualityScore.compareTo(a.qualityScore));
      return results;
    } catch (e, s) {
      log('[OfficeRouting] Error ranking offices: $e\n$s');
      return [];
    }
  }

  Future<int> _countOrgCasesForOffice({
    required String orgId,
    required String officeId,
  }) async {
    final snap = await _cases
        .where('orgId', isEqualTo: orgId)
        .where('officeId', isEqualTo: officeId)
        .where('status', whereIn: ['active', 'pending', 'onHold']).get();
    return snap.docs.length;
  }

  Future<int> _countUnassignedCases({
    required String orgId,
    required String officeId,
  }) async {
    final snap = await _cases
        .where('orgId', isEqualTo: orgId)
        .where('officeId', isEqualTo: officeId)
        .where('assigneeId', isNull: true)
        .get();
    return snap.docs.length;
  }

  /// Tasks explicitly marked overdue / escalated (fast path).
  Future<int> _countDelaySignals({required String officeId}) async {
    try {
      final overdue = await _tasks
          .where('officeId', isEqualTo: officeId)
          .where('status', isEqualTo: 'overdue')
          .get();
      final escalated = await _tasks
          .where('officeId', isEqualTo: officeId)
          .where('status', isEqualTo: 'escalated')
          .get();
      return overdue.docs.length + escalated.docs.length;
    } catch (e) {
      log('[OfficeRouting] count delay signals: $e');
      return 0;
    }
  }

  /// Support tickets tied to the office that are not resolved/closed.
  Future<int> _countOpenComplaints({required String officeId}) async {
    try {
      final snap = await _tickets
          .where('officeId', isEqualTo: officeId)
          .where('status', whereIn: [
            'open',
            'assigned',
            'inProgress',
            'escalated',
          ]).get();
      return snap.docs.length;
    } catch (e) {
      log('[OfficeRouting] complaint count: $e');
      return 0;
    }
  }
}
