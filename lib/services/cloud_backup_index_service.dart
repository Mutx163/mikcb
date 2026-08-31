import 'dart:convert';

enum CloudBackupSource { auto, manual }

class CloudBackupEntry {
  final String id;
  final String fileName;
  final DateTime exportedAt;
  final String contentSha256;
  final String deviceId;
  final String deviceLabel;
  final String? appVersion;
  final bool isCurrent;
  final CloudBackupSource source;
  final int? profileCount;
  final int? courseCount;

  const CloudBackupEntry({
    required this.id,
    required this.fileName,
    required this.exportedAt,
    required this.contentSha256,
    required this.deviceId,
    required this.deviceLabel,
    this.appVersion,
    this.isCurrent = false,
    this.source = CloudBackupSource.auto,
    this.profileCount,
    this.courseCount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fileName': fileName,
    'exportedAt': exportedAt.toIso8601String(),
    'contentSha256': contentSha256,
    'deviceId': deviceId,
    'deviceLabel': deviceLabel,
    if (appVersion != null) 'appVersion': appVersion,
    'isCurrent': isCurrent,
    'source': source.name,
    if (profileCount != null) 'profileCount': profileCount,
    if (courseCount != null) 'courseCount': courseCount,
  };

  factory CloudBackupEntry.fromJson(Map<String, dynamic> json) {
    return CloudBackupEntry(
      id: json['id'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      exportedAt:
          DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      contentSha256: json['contentSha256'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      deviceLabel: json['deviceLabel'] as String? ?? '',
      appVersion: json['appVersion'] as String?,
      isCurrent: json['isCurrent'] as bool? ?? false,
      source: CloudBackupSource.values.firstWhere(
        (item) => item.name == json['source'],
        orElse: () => CloudBackupSource.auto,
      ),
      profileCount: (json['profileCount'] as num?)?.toInt(),
      courseCount: (json['courseCount'] as num?)?.toInt(),
    );
  }

  CloudBackupEntry copyWith({
    String? id,
    String? fileName,
    DateTime? exportedAt,
    String? contentSha256,
    String? deviceId,
    String? deviceLabel,
    String? appVersion,
    bool? isCurrent,
    CloudBackupSource? source,
    int? profileCount,
    int? courseCount,
  }) {
    return CloudBackupEntry(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      exportedAt: exportedAt ?? this.exportedAt,
      contentSha256: contentSha256 ?? this.contentSha256,
      deviceId: deviceId ?? this.deviceId,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      appVersion: appVersion ?? this.appVersion,
      isCurrent: isCurrent ?? this.isCurrent,
      source: source ?? this.source,
      profileCount: profileCount ?? this.profileCount,
      courseCount: courseCount ?? this.courseCount,
    );
  }
}

class CloudBackupIndex {
  static const int schemaVersion = 1;

  final List<CloudBackupEntry> entries;

  const CloudBackupIndex({this.entries = const []});

  Map<String, dynamic> toJson() => {
    'version': schemaVersion,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory CloudBackupIndex.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    if (rawEntries is! List) {
      return const CloudBackupIndex();
    }
    return CloudBackupIndex(
      entries: rawEntries
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => CloudBackupEntry.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }
}

class CloudBackupPruneResult {
  final CloudBackupIndex index;
  final List<CloudBackupEntry> removedEntries;

  const CloudBackupPruneResult({
    required this.index,
    this.removedEntries = const [],
  });
}

class CloudBackupIndexService {
  const CloudBackupIndexService();

  static String buildBackupId({
    required DateTime exportedAt,
    required String contentSha256,
  }) {
    final local = exportedAt.toLocal();
    final timestamp =
        '${local.year.toString().padLeft(4, '0')}'
        '${local.month.toString().padLeft(2, '0')}'
        '${local.day.toString().padLeft(2, '0')}-'
        '${local.hour.toString().padLeft(2, '0')}'
        '${local.minute.toString().padLeft(2, '0')}'
        '${local.second.toString().padLeft(2, '0')}';
    final hashSuffix = contentSha256.length >= 8
        ? contentSha256.substring(0, 8)
        : contentSha256;
    return '$timestamp-$hashSuffix';
  }

  static String buildBackupFileName(String id) => '$id.mikcb';

  String encodeIndex(CloudBackupIndex index) {
    return const JsonEncoder.withIndent('  ').convert(index.toJson());
  }

  CloudBackupIndex decodeIndex(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map) {
      return const CloudBackupIndex();
    }
    return CloudBackupIndex.fromJson(Map<String, dynamic>.from(decoded));
  }

  bool indexContainsHash(CloudBackupIndex index, String contentSha256) {
    return index.entries.any(
      (entry) => entry.contentSha256 == contentSha256,
    );
  }

  CloudBackupIndex addEntry({
    required CloudBackupIndex index,
    required CloudBackupEntry entry,
    required String currentContentSha256,
    bool allowDuplicateHash = false,
  }) {
    if (!allowDuplicateHash &&
        indexContainsHash(index, entry.contentSha256)) {
      return markCurrent(index: index, currentContentSha256: currentContentSha256);
    }

    final normalizedEntry = entry.copyWith(
      isCurrent: entry.contentSha256 == currentContentSha256,
    );
    final nextEntries = [
      normalizedEntry,
      ...index.entries.where((item) => item.id != normalizedEntry.id),
    ];
    return markCurrent(
      index: CloudBackupIndex(entries: nextEntries),
      currentContentSha256: currentContentSha256,
    );
  }

  CloudBackupIndex markCurrent({
    required CloudBackupIndex index,
    required String currentContentSha256,
  }) {
    return CloudBackupIndex(
      entries: index.entries
          .map(
            (entry) => entry.copyWith(
              isCurrent: entry.contentSha256 == currentContentSha256,
            ),
          )
          .toList(),
    );
  }

  CloudBackupIndex removeEntry({
    required CloudBackupIndex index,
    required String entryId,
  }) {
    return CloudBackupIndex(
      entries: index.entries.where((entry) => entry.id != entryId).toList(),
    );
  }

  CloudBackupPruneResult prune({
    required CloudBackupIndex index,
    required int maxBackupCount,
    required int maxBackupAgeDays,
    required bool manualBackupProtected,
    required DateTime now,
  }) {
    if (index.entries.isEmpty) {
      return CloudBackupPruneResult(index: index);
    }

    final sorted = [...index.entries]
      ..sort((a, b) => b.exportedAt.compareTo(a.exportedAt));
    final kept = <CloudBackupEntry>[];
    final removed = <CloudBackupEntry>[];
    final cutoff = now.subtract(Duration(days: maxBackupAgeDays));

    for (final entry in sorted) {
      final isProtectedManual =
          manualBackupProtected && entry.source == CloudBackupSource.manual;
      final isTooOld = entry.exportedAt.isBefore(cutoff);
      final exceedsCount = kept.length >= maxBackupCount;

      if (entry.isCurrent || isProtectedManual) {
        kept.add(entry);
        continue;
      }

      if (isTooOld || exceedsCount) {
        removed.add(entry);
        continue;
      }

      kept.add(entry);
    }

    return CloudBackupPruneResult(
      index: CloudBackupIndex(entries: kept),
      removedEntries: removed,
    );
  }

  static int countCoursesInSnapshotJson(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final profiles = json['profiles'];
      if (profiles is! List) {
        return 0;
      }
      var total = 0;
      for (final profile in profiles) {
        if (profile is Map && profile['courses'] is List) {
          total += (profile['courses'] as List).length;
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  static int countProfilesInSnapshotJson(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final profiles = json['profiles'];
      return profiles is List ? profiles.length : 0;
    } catch (_) {
      return 0;
    }
  }
}
