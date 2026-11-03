import 'dart:convert';

/// Lightweight driver model for local / future remote sync.
class DriverProfile {
  final String id; // uid
  final String displayName;
  final bool online;
  final String? activeOrderId;
  final DateTime? lastPingAt;
  final double? lastLat;
  final double? lastLng;

  const DriverProfile({
    required this.id,
    required this.displayName,
    required this.online,
    this.activeOrderId,
    this.lastPingAt,
    this.lastLat,
    this.lastLng,
  });

  DriverProfile copyWith({
    String? displayName,
    bool? online,
    String? activeOrderId,
    DateTime? lastPingAt,
    double? lastLat,
    double? lastLng,
  }) => DriverProfile(
    id: id,
    displayName: displayName ?? this.displayName,
    online: online ?? this.online,
    activeOrderId: activeOrderId ?? this.activeOrderId,
    lastPingAt: lastPingAt ?? this.lastPingAt,
    lastLat: lastLat ?? this.lastLat,
    lastLng: lastLng ?? this.lastLng,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'online': online,
    if (activeOrderId != null) 'activeOrderId': activeOrderId,
    if (lastPingAt != null) 'lastPingAt': lastPingAt!.toIso8601String(),
    if (lastLat != null) 'lastLat': lastLat,
    if (lastLng != null) 'lastLng': lastLng,
  };

  static DriverProfile fromJson(Map<String, dynamic> j) => DriverProfile(
    id: j['id'] as String,
    displayName: j['displayName'] as String? ?? 'Driver',
    online: (j['online'] as bool?) ?? false,
    activeOrderId: j['activeOrderId'] as String?,
    lastPingAt: j['lastPingAt'] != null
        ? DateTime.tryParse(j['lastPingAt'] as String)
        : null,
    lastLat: (j['lastLat'] as num?)?.toDouble(),
    lastLng: (j['lastLng'] as num?)?.toDouble(),
  );

  static String encodeList(List<DriverProfile> list) =>
      json.encode(list.map((e) => e.toJson()).toList());
  static List<DriverProfile> decodeList(String raw) {
    if (raw.isEmpty) return [];
    final list = json.decode(raw) as List;
    return list
        .map((e) => DriverProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
