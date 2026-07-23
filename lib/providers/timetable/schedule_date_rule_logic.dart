import '../../models/schedule_date_rule.dart';

/// Pure helpers for [ScheduleDateRule] matching and validation.
class ScheduleDateRuleLogic {
  ScheduleDateRuleLogic._();

  static const int maxRulesPerDevice = 2;

  static final RegExp _isoDatePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// Parses `yyyy-MM-dd` into a local date-only [DateTime], or null.
  static DateTime? parseIsoDate(String? raw) {
    final value = (raw ?? '').trim();
    if (!_isoDatePattern.hasMatch(value)) {
      return null;
    }
    final parts = value.split('-');
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    try {
      final parsed = DateTime(year, month, day);
      // Reject overflow (e.g. 2026-02-31 → March).
      if (parsed.year != year || parsed.month != month || parsed.day != day) {
        return null;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static String formatIsoDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Whether [date] is inside the closed [start]–[end] range.
  static bool containsDate({
    required DateTime date,
    required DateTime start,
    required DateTime end,
  }) {
    final day = dateOnly(date);
    final rangeStart = dateOnly(start);
    final rangeEnd = dateOnly(end);
    return !day.isBefore(rangeStart) && !day.isAfter(rangeEnd);
  }

  static bool rangesOverlap({
    required DateTime leftStart,
    required DateTime leftEnd,
    required DateTime rightStart,
    required DateTime rightEnd,
  }) {
    final a0 = dateOnly(leftStart);
    final a1 = dateOnly(leftEnd);
    final b0 = dateOnly(rightStart);
    final b1 = dateOnly(rightEnd);
    return !a1.isBefore(b0) && !b1.isBefore(a0);
  }

  /// Validates a single rule. Returns a stable error code or null if ok.
  static String? validateRule(ScheduleDateRule rule) {
    if (rule.id.isEmpty) {
      return 'schedule_date_rule_id_required';
    }
    if (rule.name.trim().isEmpty) {
      return 'schedule_date_rule_name_required';
    }
    if (rule.timeSchemeId.isEmpty) {
      return 'schedule_date_rule_scheme_required';
    }
    final start = parseIsoDate(rule.startDate);
    final end = parseIsoDate(rule.endDate);
    if (start == null || end == null) {
      return 'schedule_date_rule_invalid_date';
    }
    if (end.isBefore(start)) {
      return 'schedule_date_rule_end_before_start';
    }
    return null;
  }

  /// Validates the full list (cap + pairwise overlap for enabled rules).
  static String? validateRules(List<ScheduleDateRule> rules) {
    if (rules.length > maxRulesPerDevice) {
      return 'schedule_date_rule_max_exceeded';
    }
    for (final rule in rules) {
      final message = validateRule(rule);
      if (message != null) {
        return message;
      }
    }
    final enabled = rules.where((rule) => rule.enabled).toList();
    for (var leftIndex = 0; leftIndex < enabled.length; leftIndex++) {
      final left = enabled[leftIndex];
      final leftStart = parseIsoDate(left.startDate)!;
      final leftEnd = parseIsoDate(left.endDate)!;
      for (
        var rightIndex = leftIndex + 1;
        rightIndex < enabled.length;
        rightIndex++
      ) {
        final right = enabled[rightIndex];
        final rightStart = parseIsoDate(right.startDate)!;
        final rightEnd = parseIsoDate(right.endDate)!;
        if (rangesOverlap(
          leftStart: leftStart,
          leftEnd: leftEnd,
          rightStart: rightStart,
          rightEnd: rightEnd,
        )) {
          return 'schedule_date_rule_overlap';
        }
      }
    }
    return null;
  }

  /// Picks the enabled rule containing [date], or null.
  ///
  /// When multiple match (legacy dirty data), prefer later start, then narrower
  /// span, then smaller id.
  static ScheduleDateRule? match(DateTime date, List<ScheduleDateRule> rules) {
    final hits = <ScheduleDateRule>[];
    for (final rule in rules) {
      if (!rule.enabled || rule.timeSchemeId.isEmpty) {
        continue;
      }
      final start = parseIsoDate(rule.startDate);
      final end = parseIsoDate(rule.endDate);
      if (start == null || end == null) {
        continue;
      }
      if (containsDate(date: date, start: start, end: end)) {
        hits.add(rule);
      }
    }
    if (hits.isEmpty) {
      return null;
    }
    if (hits.length == 1) {
      return hits.first;
    }

    hits.sort((left, right) {
      final leftStart = parseIsoDate(left.startDate)!;
      final rightStart = parseIsoDate(right.startDate)!;
      final startCompare = rightStart.compareTo(leftStart);
      if (startCompare != 0) {
        return startCompare;
      }
      final leftEnd = parseIsoDate(left.endDate)!;
      final rightEnd = parseIsoDate(right.endDate)!;
      final leftSpan = leftEnd.difference(leftStart).inDays;
      final rightSpan = rightEnd.difference(rightStart).inDays;
      final spanCompare = leftSpan.compareTo(rightSpan);
      if (spanCompare != 0) {
        return spanCompare;
      }
      return left.id.compareTo(right.id);
    });
    return hits.first;
  }

  /// Stable signature for a bulk-apply event.
  ///
  /// When the signature changes (new rule, new scheme, new range), the default
  /// time scheme is re-applied once. While it stays the same, daily opens do
  /// not rewrite clocks so manual edits remain.
  static String appliedSignature(ScheduleDateRule rule) {
    return '${rule.id}|${rule.timeSchemeId}|${rule.startDate}|${rule.endDate}';
  }

  /// Whether [today] should trigger a one-shot bulk apply of [matchedRule].
  ///
  /// [lastAppliedSignature] is the last successful apply for any rule (or null).
  static bool shouldBulkApply({
    required ScheduleDateRule? matchedRule,
    required String? lastAppliedSignature,
  }) {
    if (matchedRule == null || !matchedRule.enabled) {
      return false;
    }
    if (matchedRule.timeSchemeId.isEmpty) {
      return false;
    }
    final signature = appliedSignature(matchedRule);
    return signature != lastAppliedSignature;
  }
}
