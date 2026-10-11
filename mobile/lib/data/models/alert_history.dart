class AlertHistoryItem {
  final String id;
  final String? backendAlertId;
  final String geofenceId;
  final String eventType;
  final double? distanceMeters;
  final DateTime occurredAtUtc;
  final DateTime? dismissedAtUtc;
  final String? action; // dismiss, snooze

  AlertHistoryItem({
    required this.id,
    this.backendAlertId,
    required this.geofenceId,
    required this.eventType,
    this.distanceMeters,
    required this.occurredAtUtc,
    this.dismissedAtUtc,
    this.action,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'backend_alert_id': backendAlertId,
      'geofence_id': geofenceId,
      'event_type': eventType,
      'distance_meters': distanceMeters,
      'occurred_at_utc': occurredAtUtc.toIso8601String(),
      'dismissed_at_utc': dismissedAtUtc?.toIso8601String(),
      'action': action,
    };
  }

  factory AlertHistoryItem.fromMap(Map<String, dynamic> map) {
    return AlertHistoryItem(
      id: map['id'],
      backendAlertId: map['backend_alert_id'],
      geofenceId: map['geofence_id'],
      eventType: map['event_type'],
      distanceMeters: map['distance_meters'] != null
          ? (map['distance_meters'] as num).toDouble()
          : null,
      occurredAtUtc: DateTime.parse(map['occurred_at_utc']),
      dismissedAtUtc: map['dismissed_at_utc'] != null
          ? DateTime.tryParse(map['dismissed_at_utc'])
          : null,
      action: map['action'],
    );
  }
}

