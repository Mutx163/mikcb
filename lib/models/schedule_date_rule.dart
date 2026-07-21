import 'dart:convert';

/// A date-range rule that switches the profile default time scheme.
///
/// Priority in resolve: course override > location group > **this layer** >
/// [TimetableSettings.activeTimeSchemeId].
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
    return ScheduleDateRule(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String? ?? '').trim(),
      timeSchemeId: json['timeSchemeId'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      startDate: (json['startDate'] as String? ?? '').trim(),
      endDate: (json['endDate'] as String? ?? '').trim(),
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
