import 'dart:convert';

/// How a location keyword is compared against a course location string.
enum LocationKeywordMatchMode {
  prefix,
  contains,
  exact;

  String get value => name;

  static LocationKeywordMatchMode fromValue(String? raw) {
    return LocationKeywordMatchMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => LocationKeywordMatchMode.prefix,
    );
  }
}

/// A single pattern used to match teaching-building locations from the
/// academic-affairs system (e.g. `A主`, `A1`, `A6`).
class LocationKeyword {
  final String pattern;
  final LocationKeywordMatchMode mode;

  const LocationKeyword({
    required this.pattern,
    this.mode = LocationKeywordMatchMode.prefix,
  });

  Map<String, dynamic> toJson() {
    return {'pattern': pattern, 'mode': mode.value};
  }

  factory LocationKeyword.fromJson(Map<String, dynamic> json) {
    return LocationKeyword(
      pattern: (json['pattern'] as String? ?? '').trim(),
      mode: LocationKeywordMatchMode.fromValue(json['mode'] as String?),
    );
  }

  LocationKeyword copyWith({String? pattern, LocationKeywordMatchMode? mode}) {
    return LocationKeyword(
      pattern: pattern ?? this.pattern,
      mode: mode ?? this.mode,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LocationKeyword &&
        other.pattern == pattern &&
        other.mode == mode;
  }

  @override
  int get hashCode => Object.hash(pattern, mode);
}

/// A named place group (e.g. "主教学楼" / "其他教学楼") bound to a [TimeScheme]
/// and matched by one or more [LocationKeyword]s.
class LocationTimeGroup {
  final String id;
  final String name;
  final String timeSchemeId;
  final bool enabled;
  final int priority;
  final List<LocationKeyword> keywords;

  /// 创建来源的学校 ID；null = 用户手建（或本字段引入前的存量数据）。
  ///
  /// 专属作息导入（`qingyu_only/`）按教学楼自动建组，而组名（「A栋」一类）跨校
  /// 撞车很常见、分组又是全局存储——不带来源标记，换校导入后旧校的组会继续
  /// 拦截新校的教室。手建组没有学校归属，不属于任何一次导入的清理范围。
  final String? sourceSchoolId;

  const LocationTimeGroup({
    required this.id,
    required this.name,
    required this.timeSchemeId,
    this.enabled = true,
    this.priority = 0,
    this.keywords = const [],
    this.sourceSchoolId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'timeSchemeId': timeSchemeId,
      'enabled': enabled,
      'priority': priority,
      'keywords': keywords.map((keyword) => keyword.toJson()).toList(),
      'sourceSchoolId': sourceSchoolId,
    };
  }

  factory LocationTimeGroup.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'] is List
        ? json['keywords'] as List<dynamic>
        : const <dynamic>[];
    final keywords = <LocationKeyword>[];
    for (final item in rawKeywords) {
      try {
        if (item is! Map) {
          continue;
        }
        final keyword = LocationKeyword.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (keyword.pattern.isNotEmpty) keywords.add(keyword);
      } catch (_) {
        continue;
      }
    }
    return LocationTimeGroup(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String? ?? '').trim(),
      timeSchemeId: json['timeSchemeId'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      keywords: keywords,
      sourceSchoolId: _cleanOptional(json['sourceSchoolId'] as String?),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory LocationTimeGroup.fromJsonString(String jsonString) {
    return LocationTimeGroup.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  LocationTimeGroup copyWith({
    String? id,
    String? name,
    String? timeSchemeId,
    bool? enabled,
    int? priority,
    List<LocationKeyword>? keywords,
    String? sourceSchoolId,
  }) {
    return LocationTimeGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      timeSchemeId: timeSchemeId ?? this.timeSchemeId,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      keywords: keywords ?? this.keywords,
      sourceSchoolId: sourceSchoolId ?? this.sourceSchoolId,
    );
  }

  /// 空白串归一为 null，避免「来源是空串」和「没有来源」两种状态并存。
  static String? _cleanOptional(String? raw) {
    if (raw == null) {
      return null;
    }
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String get keywordSummary {
    if (keywords.isEmpty) {
      return '';
    }
    return keywords.map((keyword) => keyword.pattern).join(', ');
  }
}
