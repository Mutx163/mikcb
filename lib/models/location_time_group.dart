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

  const LocationTimeGroup({
    required this.id,
    required this.name,
    required this.timeSchemeId,
    this.enabled = true,
    this.priority = 0,
    this.keywords = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'timeSchemeId': timeSchemeId,
      'enabled': enabled,
      'priority': priority,
      'keywords': keywords.map((keyword) => keyword.toJson()).toList(),
    };
  }

  factory LocationTimeGroup.fromJson(Map<String, dynamic> json) {
    final rawKeywords = json['keywords'] as List<dynamic>? ?? const [];
    return LocationTimeGroup(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String? ?? '').trim(),
      timeSchemeId: json['timeSchemeId'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      keywords: rawKeywords
          .map(
            (item) => LocationKeyword.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .where((keyword) => keyword.pattern.isNotEmpty)
          .toList(),
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
  }) {
    return LocationTimeGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      timeSchemeId: timeSchemeId ?? this.timeSchemeId,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      keywords: keywords ?? this.keywords,
    );
  }

  String get keywordSummary {
    if (keywords.isEmpty) {
      return '';
    }
    return keywords.map((keyword) => keyword.pattern).join(', ');
  }
}
