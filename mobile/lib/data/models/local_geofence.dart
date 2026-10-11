class LocalGeofence {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final String linkedSavedLinkId;
  final bool enabled;
  final String triggerMode;
  final int cooldownSeconds;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  LocalGeofence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 200,
    required this.linkedSavedLinkId,
    this.enabled = true,
    this.triggerMode = 'crossing',
    this.cooldownSeconds = 900,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      'linked_saved_link_id': linkedSavedLinkId,
      'enabled': enabled ? 1 : 0,
      'trigger_mode': triggerMode,
      'cooldown_seconds': cooldownSeconds,
      'created_at_utc': createdAtUtc.toIso8601String(),
      'updated_at_utc': updatedAtUtc.toIso8601String(),
    };
  }

  factory LocalGeofence.fromMap(Map<String, dynamic> map) {
    return LocalGeofence(
      id: map['id'],
      name: map['name'],
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radiusMeters: map['radius_meters'] as int,
      linkedSavedLinkId: map['linked_saved_link_id'],
      enabled: map['enabled'] == 1,
      triggerMode: map['trigger_mode'] ?? 'crossing',
      cooldownSeconds: map['cooldown_seconds'] as int,
      createdAtUtc: DateTime.parse(map['created_at_utc']),
      updatedAtUtc: DateTime.parse(map['updated_at_utc']),
    );
  }

  LocalGeofence copyWith({
    String? name,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? enabled,
    String? triggerMode,
    int? cooldownSeconds,
    DateTime? updatedAtUtc,
  }) {
    return LocalGeofence(
      id: id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      linkedSavedLinkId: linkedSavedLinkId,
      enabled: enabled ?? this.enabled,
      triggerMode: triggerMode ?? this.triggerMode,
      cooldownSeconds: cooldownSeconds ?? this.cooldownSeconds,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }
}
