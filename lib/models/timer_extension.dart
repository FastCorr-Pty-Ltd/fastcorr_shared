import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for tracking timer extensions
class TimerExtension {
  final String extendedBy; // User ID who extended
  final DateTime extendedAt; // When extended
  final Duration extension; // How much time added
  final String reason; // Reason for extension

  const TimerExtension({
    required this.extendedBy,
    required this.extendedAt,
    required this.extension,
    required this.reason,
  });

  factory TimerExtension.fromJson(Map<String, dynamic> json) {
    return TimerExtension(
      extendedBy: json['extendedBy']?.toString() ?? '',
      extendedAt: _parseDateTime(json['extendedAt']),
      extension: Duration(minutes: json['extensionMinutes'] ?? 0),
      reason: json['reason']?.toString() ?? '',
    );
  }

  factory TimerExtension.fromSnapshot(DocumentSnapshot snap) {
    return TimerExtension(
      extendedBy: snap['extendedBy']?.toString() ?? '',
      extendedAt: _parseDateTime(snap['extendedAt']),
      extension: Duration(minutes: snap['extensionMinutes'] ?? 0),
      reason: snap['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'extendedBy': extendedBy,
      'extendedAt': Timestamp.fromDate(extendedAt),
      'extensionMinutes': extension.inMinutes,
      'reason': reason,
    };
  }

  TimerExtension copyWith({
    String? extendedBy,
    DateTime? extendedAt,
    Duration? extension,
    String? reason,
  }) {
    return TimerExtension(
      extendedBy: extendedBy ?? this.extendedBy,
      extendedAt: extendedAt ?? this.extendedAt,
      extension: extension ?? this.extension,
      reason: reason ?? this.reason,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    } else if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.parse(value);
    }
    return DateTime.now();
  }

  @override
  String toString() {
    return 'TimerExtension(extendedBy: $extendedBy, extendedAt: $extendedAt, extension: $extension, reason: $reason)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimerExtension &&
        other.extendedBy == extendedBy &&
        other.extendedAt == extendedAt &&
        other.extension == extension &&
        other.reason == reason;
  }

  @override
  int get hashCode {
    return extendedBy.hashCode ^
        extendedAt.hashCode ^
        extension.hashCode ^
        reason.hashCode;
  }
}
