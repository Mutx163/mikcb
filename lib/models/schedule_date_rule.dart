import 'dart:convert';

/// A date-range rule that switches the profile default time scheme.
///
/// Product semantics (not a continuous soft overlay):
/// - On the rule's start day (or the first app open after that day while the
///   range is still active), bulk-apply [timeSchemeId] as the profile default
///   and rewrite unlocked course clocks (same path as applying a time scheme).
/// - Afterwards users may manually edit courses; daily opens do not re-apply.
/// - Course override and location groups still win for individual courses.
///
/// Product cap: at most 2 enabled rules per device (enforced by provider).
class ScheduleDateRule {
  final String id;
  final String name;
  final String timeSchemeId;
  final bool enabled;

  /// Inclusive start date as `yyyy-MM-dd` (local calendar).
  final String startDate;

  /// Inclusive end date as `yyyy-MM-dd` (local calendar).
  final String endDate;

  const ScheduleDateRule({
    required this.id,
    required this.name,
    required this.timeSchemeId,
    required this.startDate,
    required this.endDate,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'timeSchemeId': timeSchemeId,
      'enabled': enabled,
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  factory ScheduleDateRule.fromJson(Map<String, dynamic> json) {
    final rawStartDate = json['startDate'];
    final rawEndDate = json['endDate'];
    if (rawStartDate is! String || rawStartDate.trim().isEmpty) {
      throw const FormatException('missing schedule date rule start date');
    }
    if (rawEndDate is! String || rawEndDate.trim().isEmpty) {
      throw const FormatException('missing schedule date rule end date');
    }
    return ScheduleDateRule(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String? ?? '').trim(),
      timeSchemeId: json['timeSchemeId'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      startDate: rawStartDate.trim(),
      endDate: rawEndDate.trim(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory ScheduleDateRule.fromJsonString(String jsonString) {
    return ScheduleDateRule.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }

  ScheduleDateRule copyWith({
    String? id,
    String? name,
    String? timeSchemeId,
    bool? enabled,
    String? startDate,
    String? endDate,
  }) {
    return ScheduleDateRule(
      id: id ?? this.id,
      name: name ?? this.name,
      timeSchemeId: timeSchemeId ?? this.timeSchemeId,
      enabled: enabled ?? this.enabled,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}
