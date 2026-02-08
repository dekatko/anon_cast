import 'dart:convert';

import 'package:hive/hive.dart';

part 'conversation_key.g.dart';

/// Historical key entry for decrypting messages encrypted with an older key version.
class HistoricalKey {
  const HistoricalKey({
    required this.key,
    required this.version,
    required this.validFrom,
    required this.validUntil,
  });

  final String key;
  final int version;
  final DateTime validFrom;
  final DateTime validUntil;

  Map<String, dynamic> toJson() => {
        'key': key,
        'version': version,
        'validFrom': validFrom.millisecondsSinceEpoch,
        'validUntil': validUntil.millisecondsSinceEpoch,
      };

  factory HistoricalKey.fromJson(Map<dynamic, dynamic> map) {
    final vFrom = map['validFrom'];
    final vUntil = map['validUntil'];
    return HistoricalKey(
      key: map['key'] as String? ?? '',
      version: map['version'] as int? ?? 0,
      validFrom: vFrom != null
          ? DateTime.fromMillisecondsSinceEpoch(vFrom is int ? vFrom : (vFrom as num).toInt())
          : DateTime.now(),
      validUntil: vUntil != null
          ? DateTime.fromMillisecondsSinceEpoch(vUntil is int ? vUntil : (vUntil as num).toInt())
          : DateTime.now(),
    );
  }

  static List<HistoricalKey> listFromJson(List<dynamic>? list) {
    if (list == null || list.isEmpty) return [];
    return list
        .map((e) => e is Map ? HistoricalKey.fromJson(Map<dynamic, dynamic>.from(e as Map)) : null)
        .whereType<HistoricalKey>()
        .toList();
  }

  static List<Map<String, dynamic>> listToJson(List<HistoricalKey> keys) =>
      keys.map((k) => k.toJson()).toList();
}

/// Per-conversation encryption key for zero-knowledge E2E.
///
/// Stored **only in Hive** on device; never sent to Firestore.
/// [key] is the current AES key (base64). [version] increments on rotation.
/// [oldKeys] holds previous keys for decrypting older messages (stored as JSON in Hive).
@HiveType(typeId: 7)
class ConversationKey {
  ConversationKey({
    required this.id,
    required this.key,
    required this.createdAt,
    DateTime? lastRotated,
    this.version = 1,
    List<HistoricalKey>? oldKeys,
  })  : lastRotated = lastRotated ?? createdAt,
        oldKeysJson = (oldKeys != null && oldKeys.isNotEmpty)
            ? jsonEncode(HistoricalKey.listToJson(oldKeys))
            : '[]';

  /// For Hive adapter: read with stored oldKeysJson (backward compat: default '[]').
  ConversationKey._withOldKeysJson({
    required this.id,
    required this.key,
    required this.createdAt,
    required this.lastRotated,
    required this.version,
    required this.oldKeysJson,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String key;
  @HiveField(2)
  final DateTime createdAt;
  @HiveField(3)
  final DateTime lastRotated;
  @HiveField(4)
  final int version;
  @HiveField(5)
  final String oldKeysJson;

  /// Previous keys for decrypting messages with older [keyVersion]. Parsed from [oldKeysJson].
  List<HistoricalKey> get oldKeys {
    if (oldKeysJson.isEmpty || oldKeysJson == '[]') return [];
    try {
      final list = jsonDecode(oldKeysJson) as List<dynamic>?;
      return HistoricalKey.listFromJson(list);
    } catch (_) {
      return [];
    }
  }

  /// Alias for [key] (current key).
  String get currentKey => key;

  /// From local/Hive map.
  factory ConversationKey.fromMap(Map<dynamic, dynamic> map) {
    final created = map['createdAt'];
    final rotated = map['lastRotated'];
    DateTime createdAt = DateTime.now();
    if (created != null) {
      if (created is int) createdAt = DateTime.fromMillisecondsSinceEpoch(created);
      if (created is num) createdAt = DateTime.fromMillisecondsSinceEpoch(created.toInt());
    }
    DateTime lastRotated = createdAt;
    if (rotated != null) {
      if (rotated is int) lastRotated = DateTime.fromMillisecondsSinceEpoch(rotated);
      if (rotated is num) lastRotated = DateTime.fromMillisecondsSinceEpoch(rotated.toInt());
    }
    final oldKeysRaw = map['oldKeys'];
    final oldKeys = oldKeysRaw is List ? HistoricalKey.listFromJson(oldKeysRaw) : <HistoricalKey>[];
    return ConversationKey(
      id: map['id'] as String? ?? '',
      key: map['key'] as String? ?? '',
      createdAt: createdAt,
      lastRotated: lastRotated,
      version: map['version'] as int? ?? 1,
      oldKeys: oldKeys.isNotEmpty ? oldKeys : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'key': key,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'lastRotated': lastRotated.millisecondsSinceEpoch,
        'version': version,
        'oldKeys': HistoricalKey.listToJson(oldKeys),
      };

  ConversationKey copyWith({
    String? id,
    String? key,
    DateTime? createdAt,
    DateTime? lastRotated,
    int? version,
    List<HistoricalKey>? oldKeys,
  }) {
    return ConversationKey(
      id: id ?? this.id,
      key: key ?? this.key,
      createdAt: createdAt ?? this.createdAt,
      lastRotated: lastRotated ?? this.lastRotated,
      version: version ?? this.version,
      oldKeys: oldKeys ?? this.oldKeys,
    );
  }
}
