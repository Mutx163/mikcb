class PartnerTimetableBinding {
  final String partnerProfileId;
  final String partnerName;
  final DateTime linkedAt;
  final DateTime? lastImportedAt;
  final String? sourceFileHash;

  const PartnerTimetableBinding({
    required this.partnerProfileId,
    required this.partnerName,
    required this.linkedAt,
    this.lastImportedAt,
    this.sourceFileHash,
  });

  Map<String, dynamic> toJson() => {
    'partnerProfileId': partnerProfileId,
    'partnerName': partnerName,
    'linkedAt': linkedAt.toIso8601String(),
    if (lastImportedAt != null)
      'lastImportedAt': lastImportedAt!.toIso8601String(),
    if (sourceFileHash != null) 'sourceFileHash': sourceFileHash,
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
    );
  }

  PartnerTimetableBinding copyWith({
    String? partnerProfileId,
    String? partnerName,
    DateTime? linkedAt,
    DateTime? lastImportedAt,
    String? sourceFileHash,
  }) {
    return PartnerTimetableBinding(
      partnerProfileId: partnerProfileId ?? this.partnerProfileId,
      partnerName: partnerName ?? this.partnerName,
      linkedAt: linkedAt ?? this.linkedAt,
      lastImportedAt: lastImportedAt ?? this.lastImportedAt,
      sourceFileHash: sourceFileHash ?? this.sourceFileHash,
    );
  }
}
