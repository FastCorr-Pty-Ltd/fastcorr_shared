/// User-visible names for the three **separate** communication surfaces.
/// Do not reuse one label for another pipeline (case thread vs order chat vs support).
class CommunicationChannelLabels {
  CommunicationChannelLabels._();

  /// Header / nav: [cases]/{caseId}/[communications] (matters, counsel, staff).
  static const String caseCommunications = 'Case communications';

  /// Fullscreen hubs aggregating per-case threads (still case comms, not order chat).
  static const String caseCommunicationsHubTitle = 'Case communications hub';

  /// In-tab filter for human chat lines (avoids the ambiguous word “Chat” alone).
  static const String caseCommsFilterMessages = 'Messages';

  /// [chats]/{orderId} — delivery / driver / assignee logistics.
  static const String orderChat = 'Order chat';

  /// Support tickets / help desk (not case thread, not order chat).
  static const String support = 'Support';

  /// Staff / org internal threads ([InternalCommsWidget], not case comms or order chat).
  static const String internalCommunications = 'Chats';

  /// One-line context for order chat panels.
  static const String orderChatScopeHint =
      'For this delivery and driver only. Case-wide discussion uses Case communications.';

  /// Shown in case comms headers so users do not conflate with order or support.
  static const String caseCommsNotOrderOrSupport =
      'Matter thread for this case — not order chat or support.';

  /// Nav from the order-scoped [chats] thread to the matter thread (when linked).
  static const String openCaseCommunicationsCta = 'Open case communications';

  /// Request / matter integration entry points.
  static const String goToCaseCommunicationsCta = 'Go to case communications';
}
