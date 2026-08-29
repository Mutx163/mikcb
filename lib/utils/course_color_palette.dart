import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import 'home_page_background.dart';

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

// ---------------------------------------------------------------------------
// Course-card ink readability (WCAG contrast).
// ---------------------------------------------------------------------------

/// A preset pastel card color paired with its intended deep-ink text color.
class CourseColorPair {
  const CourseColorPair({required this.cardHex, required this.textHex});

  final String cardHex;
  final String textHex;
}

/// Shipped card/ink pairings. Each ink is designed to stay legible on its own
/// pastel card (all clear the [courseCardCriticalContrastRatio] bar).
const List<CourseColorPair> kPresetCourseColorPairs = [
  CourseColorPair(cardHex: '#90CAF9', textHex: '#0D47A1'), // blue
  CourseColorPair(cardHex: '#A5D6A7', textHex: '#1B5E20'), // green
  // 橙墨加深至 #B34700：原 #E65100 在 #FFCC80 上对比度仅 2.56，
  // 未达自家 courseCardMinContrastRatio(3.0)；#B34700 实测 3.72。
  CourseColorPair(cardHex: '#FFCC80', textHex: '#B34700'), // orange
  CourseColorPair(cardHex: '#F48FB1', textHex: '#880E4F'), // pink
  CourseColorPair(cardHex: '#CE93D8', textHex: '#4A148C'), // purple
  CourseColorPair(cardHex: '#80DEEA', textHex: '#006064'), // cyan
  CourseColorPair(cardHex: '#EF9A9A', textHex: '#B71C1C'), // red
  CourseColorPair(cardHex: '#BCAAA4', textHex: '#3E2723'), // brown
  CourseColorPair(cardHex: '#B0BEC5', textHex: '#263238'), // blue grey
];

/// WCAG AA-large threshold: below this an ink is auto-adjusted for legibility.
const double courseCardMinContrastRatio = 3.0;

/// Invisibility bar: below this an ink is effectively unreadable and always
/// overridden; between this and [courseCardMinContrastRatio] the user's choice
/// is kept but flagged as advisory.
const double courseCardCriticalContrastRatio = 2.0;

/// WCAG relative-contrast ratio between two colors (1.0–21.0, symmetric).
double courseCardContrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Whether wallpaper shows through the given surface style, so the solid card
/// color is no longer the reliable background for contrast checks.
bool courseCardSurfaceShowsWallpaper(CourseCardSurfaceStyle style) {
  switch (style) {
    case CourseCardSurfaceStyle.solid:
      return false;
    case CourseCardSurfaceStyle.gaussian:
      return true;
  }
}

/// Whether [ink] is a neutral ink (white / black / grey family) rather than a
/// hue-bearing colour.
///
/// 双重判定：绝对色程（max-min）≤0.04 放行近黑的深色墨（如 #0D0D14），
/// 其余按 HSL 饱和度 ≤0.15 判定，白/黑/灰系全部中性。
bool courseCardInkIsNeutral(Color ink) {
  final channels = <double>[ink.r, ink.g, ink.b]..sort();
  if (channels.last - channels.first <= 0.04) {
    return true;
  }
  return HSLColor.fromColor(ink).saturation <= 0.15;
}

/// 玻璃（高斯模糊）卡面的墨色规则。
///
/// 玻璃卡的实际背景 = 壁纸磨砂 + 约 42% 课程色调染色，壁纸亮度不可控——
/// - 彩色墨（含导入深墨、用户自选彩色）：为实体卡纯色底设计，玻璃上没有
///   那个底，直接回落自动黑白；
/// - 中性墨（黑白灰）：保留用户选择，但对混合背景对比度 < 3:1（与首页
///   chrome 壁纸策略 [homePageInkHasSufficientContrast] 一致）时同样回落。
///
/// 自动黑白按课程 tint 与壁纸带亮度各 50% 混合判定，与日视图议程卡
/// （`_dayAgendaAutoInk`）同一公式。
Color resolveReadableCourseCardGlassInk({
  required Color preferred,
  required Color cardColor,
  required double wallpaperLuminance,
}) {
  final effectiveLuminance =
      cardColor.computeLuminance() * 0.5 + wallpaperLuminance * 0.5;
  if (courseCardInkIsNeutral(preferred) &&
      homePageInkHasSufficientContrast(preferred, effectiveLuminance)) {
    return preferred;
  }
  return homePageChromeForegroundForLuminance(effectiveLuminance);
}

Color _parsePairColor(String hex) {
  final value = hex.replaceFirst('#', '').trim();
  final full = value.length == 6 ? 'FF$value' : value;
  return Color(int.tryParse(full, radix: 16) ?? 0xFFFFFFFF);
}

/// Picks pure white or near-black — whichever contrasts best with [background].
Color _bestContrastInk(Color background) {
  const light = Color(0xFFFFFFFF);
  const dark = Color(0xFF1A1A1A);
  return courseCardContrastRatio(light, background) >=
          courseCardContrastRatio(dark, background)
      ? light
      : dark;
}

/// Resolves a legible title ink.
///
/// 实心卡面：保留用户墨色，仅在对比度低于隐身线（2.0）时替换为黑白最优墨。
/// 玻璃卡面（[surfaceShowsWallpaper]）：背景是壁纸 + tint，按玻璃规则处理
/// （[resolveReadableCourseCardGlassInk]）；[wallpaperLuminance] 未知时背景
/// 不可判定，维持旧行为保留用户墨色。
Color resolveReadableCourseCardTitleColor({
  required Color preferred,
  required Color cardColor,
  required bool surfaceShowsWallpaper,
  double? wallpaperLuminance,
}) {
  if (surfaceShowsWallpaper) {
    if (wallpaperLuminance == null) {
      return preferred;
    }
    return resolveReadableCourseCardGlassInk(
      preferred: preferred,
      cardColor: cardColor,
      wallpaperLuminance: wallpaperLuminance,
    );
  }
  if (courseCardContrastRatio(preferred, cardColor) >=
      courseCardCriticalContrastRatio) {
    return preferred;
  }
  return _bestContrastInk(cardColor);
}

/// Resolves the softened detail (subtitle) ink for a course card.
///
/// 实心卡面：详情墨先走与标题一致的对比度守卫，再把结果约束到与
/// [resolvedTitleInk] 相同的明暗极性——详情墨可能单独达标（黑字在中明度卡上
/// 对比度 9+），却与被保留的白标题（对比度仅 2.2 左右、处于 advisory 区间）
/// 极性相反，画出「白标题 + 黑简介」的半洗白混色卡。
///
/// 玻璃卡面：壁纸亮度已知时详情一律跟随标题墨软化——背景是壁纸 + tint，
/// 无法为详情单独配色，彩色详情/反向极性都不会再出现；壁纸亮度未知时
/// 维持旧行为保留用户墨色。
Color resolveReadableCourseCardDetailColor({
  required Color preferred,
  required Color resolvedTitleInk,
  required Color cardColor,
  required bool surfaceShowsWallpaper,
  double? wallpaperLuminance,
}) {
  final guarded = resolveReadableCourseCardTitleColor(
    preferred: preferred,
    cardColor: cardColor,
    surfaceShowsWallpaper: surfaceShowsWallpaper,
    wallpaperLuminance: wallpaperLuminance,
  );
  if (surfaceShowsWallpaper) {
    if (wallpaperLuminance == null) {
      return guarded.withValues(alpha: 0.7);
    }
    return resolvedTitleInk.withValues(alpha: 0.7);
  }
  const lightInkLuminance = 0.5;
  final titleIsLight =
      resolvedTitleInk.computeLuminance() >= lightInkLuminance;
  final detailIsLight = guarded.computeLuminance() >= lightInkLuminance;
  final ink = titleIsLight == detailIsLight ? guarded : resolvedTitleInk;
  return ink.withValues(alpha: 0.7);
}

/// Preset card hexes on which [ink] is unreadable (below the AA-large bar) for
/// the given [surfaceStyle]; used to warn the user about a risky ink choice.
List<String> courseCardUnreadablePresetCardHexes({
  required Color ink,
  required CourseCardSurfaceStyle surfaceStyle,
}) {
  if (courseCardSurfaceShowsWallpaper(surfaceStyle)) {
    return const [];
  }
  final failures = <String>[];
  for (final pair in kPresetCourseColorPairs) {
    final card = _parsePairColor(pair.cardHex);
    if (courseCardContrastRatio(ink, card) < courseCardMinContrastRatio) {
      failures.add(pair.cardHex);
    }
  }
  return failures;
}
