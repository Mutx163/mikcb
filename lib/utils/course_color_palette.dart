/// Shared preset colors for course cards (manual add, import random, LAN edit).
const List<String> kPresetCourseColorHexes = [
  '#2196F3',
  '#4CAF50',
  '#FF9800',
  '#E91E63',
  '#9C27B0',
  '#00BCD4',
  '#FF5722',
  '#795548',
  '#607D8B',
];

String? _normalizeColorHex(String? hex) {
  if (hex == null) {
    return null;
  }
  final trimmed = hex.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Resolves the effective title color hex for a course card.
///
/// A per-course [courseTextColorHex] override wins; otherwise the
/// brightness-appropriate settings title color is used. Returns `null` when no
/// color is configured so the card falls back to its default (white).
String? resolveCourseCardTitleColorHex({
  required String? courseTextColorHex,
  required String? settingsTitleColorLight,
  required String? settingsTitleColorDark,
  required bool isDark,
}) {
  final override = _normalizeColorHex(courseTextColorHex);
  if (override != null) {
    return override;
  }
  return _normalizeColorHex(
    isDark ? settingsTitleColorDark : settingsTitleColorLight,
  );
}

/// Resolves the effective detail (subtitle) color hex for a course card.
///
/// A per-course [courseTextColorHex] override wins; otherwise the
/// brightness-appropriate settings detail color is used, falling back to the
/// title color when no detail color is configured. Returns `null` when nothing
/// is configured so the card falls back to its default.
String? resolveCourseCardDetailColorHex({
  required String? courseTextColorHex,
  required String? settingsDetailColorLight,
  required String? settingsDetailColorDark,
  required String? settingsTitleColorLight,
  required String? settingsTitleColorDark,
  required bool isDark,
}) {
  final override = _normalizeColorHex(courseTextColorHex);
  if (override != null) {
    return override;
  }
  final detail = _normalizeColorHex(
    isDark ? settingsDetailColorDark : settingsDetailColorLight,
  );
  if (detail != null) {
    return detail;
  }
  return _normalizeColorHex(
    isDark ? settingsTitleColorDark : settingsTitleColorLight,
  );
}
