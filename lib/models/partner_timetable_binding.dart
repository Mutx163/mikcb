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
    return PartnerTimetableBinding(
      partnerProfileId: json['partnerProfileId'] as String,
      partnerName: json['partnerName'] as String? ?? 'TA的课表',
      linkedAt:
          DateTime.tryParse(json['linkedAt'] as String? ?? '') ??
          DateTime.now(),
      lastImportedAt: json['lastImportedAt'] == null
          ? null
          : DateTime.tryParse(json['lastImportedAt'] as String),
      sourceFileHash: json['sourceFileHash'] as String?,
      weekOffset: (json['weekOffset'] as num?)?.toInt() ?? 0,
      mineColorHex: json['mineColorHex'] as String? ?? '#2196F3',
      partnerColorHex: json['partnerColorHex'] as String? ?? '#E91E63',
      togetherColorHex: json['togetherColorHex'] as String? ?? '#9C27B0',
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
