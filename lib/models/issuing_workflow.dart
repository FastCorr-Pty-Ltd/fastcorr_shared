/// Multi-step court issuing. Only requests created with [RequestModel.issuingWorkflow]
/// enter this lifecycle. Older orders do not carry the flag and keep the
/// single-trip completion path.
enum IssuingStage {
  /// Secretary is preparing, or the court drop-off trip is out.
  courtDropoff,

  /// Court drop-off is done. Waiting for the lawyer to start the follow-up.
  awaitingFollowUp,

  /// Lawyer asked for collection. The follow-up trip is being arranged or is out.
  courtCollection,

  /// Follow-up trip is done. Waiting for the office returned-task log.
  awaitingReturn,

  /// Office logged the documents back. Sheriff trip is not started.
  documentsReturned,

  /// Lawyer asked us to deliver to the sheriff. That trip is being arranged or is out.
  sheriffServe,

  /// Parent order is closed.
  closed,
}

/// One physical driver job linked to an issuing parent.
enum IssuingTripKind {
  courtDropoff,
  followUp,
  sheriffServe,
}

/// Follow-up handling fee, charged only for sheriff-required issuing services.
const int kIssuingFollowUpFeeCents = 5000;

/// Sheriff-delivery handling fee, charged on top of driver fare.
const int kIssuingSheriffHandlingFeeCents = 5000;

class IssuingServiceMatch {
  final bool isIssuing;
  final bool requiresSheriff;

  const IssuingServiceMatch({
    required this.isIssuing,
    required this.requiresSheriff,
  });
}

const IssuingServiceMatch _notIssuing = IssuingServiceMatch(
  isIssuing: false,
  requiresSheriff: false,
);

/// Titles that use the issuing lifecycle. Matched exactly so other services
/// stay on their current flow. Covers the local messenger issuing services and
/// the litigation-phase issuing services.
IssuingServiceMatch matchIssuingService(String? serviceName) {
  final name = (serviceName ?? '').trim().toLowerCase();
  if (name.isEmpty) return _notIssuing;

  const sheriffRequired = <String>{
    'issue deliver to sheriff & return my copy',
    'issue at court, serve & return my copy',
    'issue at court, serve, file & return my copy',
    'issue, set down, serve & return my copy',
    'issue summons',
    'issue an application',
  };
  const issuingOnly = <String>{
    'issue at court & upload digital copy',
    'issue, set down & return my copy',
    'upliftt court order & issue writ',
  };

  if (sheriffRequired.contains(name)) {
    return const IssuingServiceMatch(isIssuing: true, requiresSheriff: true);
  }
  if (issuingOnly.contains(name)) {
    return const IssuingServiceMatch(isIssuing: true, requiresSheriff: false);
  }
  return _notIssuing;
}

IssuingStage? parseIssuingStage(dynamic value) {
  if (value is IssuingStage) return value;
  if (value is! String || value.isEmpty) return null;
  for (final stage in IssuingStage.values) {
    if (stage.name == value) return stage;
  }
  return null;
}

IssuingTripKind? parseIssuingTripKind(dynamic value) {
  if (value is IssuingTripKind) return value;
  if (value is! String || value.isEmpty) return null;
  for (final kind in IssuingTripKind.values) {
    if (kind.name == value) return kind;
  }
  return null;
}
