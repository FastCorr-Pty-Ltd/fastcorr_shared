/// Tracks how a [RequestModel] was routed to a secretary.
enum RequestRoutingStatus {
  /// Case has no assignee yet; waiting for auto or manual assignment.
  pendingAssignment,

  /// Request has been linked to a secretary (via case assignee).
  assigned,

  /// Routing could not complete (missing case, no secretaries, etc.).
  failed,
}

extension RequestRoutingStatusX on RequestRoutingStatus {
  String get firestoreValue => name;

  static RequestRoutingStatus? parse(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    for (final s in RequestRoutingStatus.values) {
      if (s.name == raw) return s;
    }
    return null;
  }
}

/// Builds initial routing fields when a lawyer creates a new request.
({
  String? assigneeId,
  RequestRoutingStatus routingStatus,
  String routingReason,
  DateTime? routedAt,
  String? routedBy,
}) initialRequestRouting({String? caseAssigneeId}) {
  final fromCase = caseAssigneeId?.trim() ?? '';
  if (fromCase.isNotEmpty) {
    return (
      assigneeId: fromCase,
      routingStatus: RequestRoutingStatus.assigned,
      routingReason: 'case_already_assigned',
      routedAt: DateTime.now(),
      routedBy: 'client',
    );
  }
  return (
    assigneeId: null,
    routingStatus: RequestRoutingStatus.pendingAssignment,
    routingReason: 'awaiting_auto_or_manual_assignment',
    routedAt: null,
    routedBy: null,
  );
}
