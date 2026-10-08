class PartnerTimetableBinding {
  final String partnerProfileId;
  final String partnerName;
  final DateTime linkedAt;
  final DateTime? lastImportedAt;
  final String? sourceFileHash;
  final int weekOffset;
  final String mineColorHex;
  final String partnerColorHex;
  final String togetherColorHex;

  const PartnerTimetableBinding({
    required this.partnerProfileId,
    required this.partnerName,
    required this.linkedAt,
    this.lastImportedAt,
    this.sourceFileHash,
    this.weekOffset = 0,
    this.mineColorHex = '#2196F3',
    this.partnerColorHex = '#E91E63',
    this.togetherColorHex = '#9C27B0',
  });

  Map<String, dynamic> toJson() => {
    'partnerProfileId': partnerProfileId,
    'partnerName': partnerName,
    'linkedAt': linkedAt.toIso8601String(),
    if (lastImportedAt != null)
      'lastImportedAt': lastImportedAt!.toIso8601String(),
    if (sourceFileHash != null) 'sourceFileHash': sourceFileHash,
    'weekOffset': weekOffset,
    'mineColorHex': mineColorHex,
    'partnerColorHex': partnerColorHex,
    'togetherColorHex': togetherColorHex,
  };

  factory PartnerTimetableBinding.fromJson(Map<String, dynamic> json) {
    // 这份绑定来自**云同步 / 备份恢复**（外部数据），原先六处 `as String`
    // 裸转换：任何一项类型不对都抛 TypeError，情侣绑定这条数据直接读不出来。
    // 口径与 `Course.fromJson` / `TimetableProfile.fromJson` 同款（2026-10-08 统一）：
    // 取不到就退回安全默认，不让一条脏数据带走整个绑定。
    String readStr(String key, {String fallback = ''}) {
      final raw = json[key];
      if (raw is String) {
        return raw;
      }
      return raw == null ? fallback : raw.toString();
    }

    String? readStrOrNull(String key) {
      final raw = json[key];
      if (raw == null) {
        return null;
      }
      return raw is String ? raw : raw.toString();
    }

    return PartnerTimetableBinding(
      partnerProfileId: readStr('partnerProfileId'),
      partnerName: readStr('partnerName', fallback: 'TA的课表'),
      linkedAt: DateTime.tryParse(readStr('linkedAt')) ?? DateTime.now(),
      lastImportedAt: json['lastImportedAt'] == null
          ? null
          : DateTime.tryParse(readStr('lastImportedAt')),
      sourceFileHash: readStrOrNull('sourceFileHash'),
      weekOffset: (json['weekOffset'] as num?)?.toInt() ?? 0,
      mineColorHex: readStr('mineColorHex', fallback: '#2196F3'),
      partnerColorHex: readStr('partnerColorHex', fallback: '#E91E63'),
      togetherColorHex: readStr('togetherColorHex', fallback: '#9C27B0'),
    );
  }

  PartnerTimetableBinding copyWith({
    String? partnerProfileId,
    String? partnerName,
    DateTime? linkedAt,
    DateTime? lastImportedAt,
    String? sourceFileHash,
    int? weekOffset,
    String? mineColorHex,
    String? partnerColorHex,
    String? togetherColorHex,
  }) {
    return PartnerTimetableBinding(
      partnerProfileId: partnerProfileId ?? this.partnerProfileId,
      partnerName: partnerName ?? this.partnerName,
      linkedAt: linkedAt ?? this.linkedAt,
      lastImportedAt: lastImportedAt ?? this.lastImportedAt,
      sourceFileHash: sourceFileHash ?? this.sourceFileHash,
      weekOffset: weekOffset ?? this.weekOffset,
      mineColorHex: mineColorHex ?? this.mineColorHex,
      partnerColorHex: partnerColorHex ?? this.partnerColorHex,
      togetherColorHex: togetherColorHex ?? this.togetherColorHex,
    );
  }
}
