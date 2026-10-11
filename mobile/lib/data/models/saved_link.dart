class SavedLink {
  final String id;
  final String nickname;
  final String shareUrl;
  final DateTime? tokenExpiryUtc;
  final DateTime addedAtUtc;
  final DateTime updatedAtUtc;
  final bool isFavorite;
  final String lastKnownStatus; // unknown, active, expired, invalid, provider_error
  final DateTime? lastActivatedAtUtc;

  SavedLink({
    required this.id,
    required this.nickname,
    required this.shareUrl,
    this.tokenExpiryUtc,
    required this.addedAtUtc,
    required this.updatedAtUtc,
    this.isFavorite = false,
    this.lastKnownStatus = 'unknown',
    this.lastActivatedAtUtc,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'share_url': shareUrl,
      'token_expiry_utc': tokenExpiryUtc?.toIso8601String(),
      'added_at_utc': addedAtUtc.toIso8601String(),
      'updated_at_utc': updatedAtUtc.toIso8601String(),
      'is_favorite': isFavorite ? 1 : 0,
      'last_known_status': lastKnownStatus,
      'last_activated_at_utc': lastActivatedAtUtc?.toIso8601String(),
    };
  }

  factory SavedLink.fromMap(Map<String, dynamic> map) {
    return SavedLink(
      id: map['id'],
      nickname: map['nickname'],
      shareUrl: map['share_url'],
      tokenExpiryUtc: map['token_expiry_utc'] != null
          ? DateTime.tryParse(map['token_expiry_utc'])
          : null,
      addedAtUtc: DateTime.parse(map['added_at_utc']),
      updatedAtUtc: DateTime.parse(map['updated_at_utc']),
      isFavorite: map['is_favorite'] == 1,
      lastKnownStatus: map['last_known_status'] ?? 'unknown',
      lastActivatedAtUtc: map['last_activated_at_utc'] != null
          ? DateTime.tryParse(map['last_activated_at_utc'])
          : null,
    );
  }

  SavedLink copyWith({
    String? nickname,
    String? shareUrl,
    DateTime? tokenExpiryUtc,
    DateTime? updatedAtUtc,
    bool? isFavorite,
    String? lastKnownStatus,
    DateTime? lastActivatedAtUtc,
  }) {
    return SavedLink(
      id: id,
      nickname: nickname ?? this.nickname,
      shareUrl: shareUrl ?? this.shareUrl,
      tokenExpiryUtc: tokenExpiryUtc ?? this.tokenExpiryUtc,
      addedAtUtc: addedAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      isFavorite: isFavorite ?? this.isFavorite,
      lastKnownStatus: lastKnownStatus ?? this.lastKnownStatus,
      lastActivatedAtUtc: lastActivatedAtUtc ?? this.lastActivatedAtUtc,
    );
  }
}

