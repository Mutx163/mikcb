import 'package:flutter/material.dart';

import '../models/timetable_settings.dart';
import 'home_page_background.dart';

/// Shared preset colors for course cards (manual add, import random, LAN edit).
///
/// 色板组成：以 Tailwind CSS v3 标准色阶（300–700，共 17 个彩色族 + slate/stone
/// 两个灰族）为骨架，按「色相族分组、由浅到深」排序；初版 9 个 Material 色
/// （含新建课程默认色 #2196F3）按色相就近插入各族，保证老数据与默认值仍在
/// 预设范围内。卡片墨色由对比度守卫自动回落（黑白），任意色阶都安全。
const List<String> kPresetCourseColorHexes = [
  // 红 red
  '#FCA5A5', '#F87171', '#EF4444', '#DC2626', '#B91C1C',
  // 橙红（含原深橙）orange
  '#FF5722', '#FDBA74', '#FB923C', '#F97316', '#EA580C', '#C2410C',
  // 琥珀（含原橙）amber
  '#FCD34D', '#FBBF24', '#F59E0B', '#FF9800', '#D97706', '#B45309',
  // 黄 yellow
  '#FDE047', '#FACC15', '#EAB308', '#CA8A04', '#A16207',
  // 青柠 lime
  '#BEF264', '#A3E635', '#84CC16', '#65A30D', '#4D7C0F',
  // 绿（含原绿）green
  '#86EFAC', '#4ADE80', '#4CAF50', '#22C55E', '#16A34A', '#15803D',
  // 翠绿 emerald
  '#6EE7B7', '#34D399', '#10B981', '#059669', '#047857',
  // 青绿 teal
  '#5EEAD4', '#2DD4BF', '#14B8A6', '#0D9488', '#0F766E',
  // 青（含原青）cyan
  '#67E8F9', '#22D3EE', '#06B6D4', '#00BCD4', '#0891B2', '#0E7490',
  // 天蓝 sky
  '#7DD3FC', '#38BDF8', '#0EA5E9', '#0284C7', '#0369A1',
  // 蓝（含原默认蓝）blue
  '#93C5FD', '#60A5FA', '#2196F3', '#3B82F6', '#2563EB', '#1D4ED8',
  // 靛蓝 indigo
  '#A5B4FC', '#818CF8', '#6366F1', '#4F46E5', '#4338CA',
  // 紫罗兰 violet
  '#C4B5FD', '#A78BFA', '#8B5CF6', '#7C3AED', '#6D28D9',
  // 紫（含原紫）purple
  '#D8B4FE', '#C084FC', '#A855F7', '#9333EA', '#9C27B0', '#7E22CE',
  // 品红 fuchsia
  '#F0ABFC', '#E879F9', '#D946EF', '#C026D3', '#A21CAF',
  // 粉（含原粉）pink
  '#F9A8D4', '#F472B6', '#EC4899', '#E91E63', '#DB2777', '#BE185D',
  // 玫红 rose
  '#FDA4AF', '#FB7185', '#F43F5E', '#E11D48', '#BE123C',
  // 蓝灰（含原蓝灰）slate
  '#CBD5E1', '#94A3B8', '#607D8B', '#64748B', '#475569', '#334155',
  // 棕灰（含原棕）stone
  '#D6D3D1', '#A8A29E', '#78716C', '#795548', '#57534E', '#44403C',
];

/// 一族一色的精简快捷色，用于选色行的横向快选（完整色板见
/// [kPresetCourseColorHexes]，经调色盘 sheet 呈现）。首色为新建课程默认色。
const List<String> kCourseColorQuickPickHexes = [
  '#2196F3', // 默认蓝
  '#EF4444', // 红
  '#F97316', // 橙
  '#F59E0B', // 琥珀
  '#FACC15', // 黄
  '#84CC16', // 青柠
  '#22C55E', // 绿
  '#10B981', // 翠绿
  '#14B8A6', // 青绿
  '#06B6D4', // 青
  '#0EA5E9', // 天蓝
  '#6366F1', // 靛蓝
  '#8B5CF6', // 紫罗兰
  '#A855F7', // 紫
  '#D946EF', // 品红
  '#EC4899', // 粉
  '#F43F5E', // 玫红
  '#64748B', // 蓝灰
  '#78716C', // 棕灰
];

// ---------------------------------------------------------------------------
// 随机配色颜色组
// ---------------------------------------------------------------------------

/// 「全部颜色」颜色组的保留 id，对应 [kPresetCourseColorHexes]。
const String kCourseColorGroupAllId = 'all';

/// 一组可用于导入随机配色的预设颜色组。
///
/// 组名沿用配色站通行的风格标签（Color Hunt 的 Pastel / Dark 等主题词）与
/// 设计圈对同类色系的通行叫法（马卡龙色系 / 活泼系 / 深色系）；显示名在
/// l10n（colorGroup* 键）里定义，这里只存 id 与色值。色值全部取自
/// [kPresetCourseColorHexes]（Tailwind v3 MIT + Material Apache 2.0），
/// 无新增版权面。
class CourseColorGroup {
  const CourseColorGroup({required this.id, required this.hexes});

  /// 持久化到 SharedPreferences 的稳定标识。
  final String id;

  /// 该组随机取色的色值（均为 [kPresetCourseColorHexes] 的子集）。
  final List<String> hexes;
}

/// 马卡龙系：各族 300 浅阶，淡雅柔和（浅卡靠墨色守卫自动回落深字）。
const List<String> kPastelCourseColorGroupHexes = [
  '#FCA5A5', '#FDBA74', '#FCD34D', '#FDE047', '#BEF264',
  '#86EFAC', '#6EE7B7', '#5EEAD4', '#67E8F9', '#7DD3FC',
  '#93C5FD', '#A5B4FC', '#C4B5FD', '#D8B4FE', '#F0ABFC',
  '#F9A8D4', '#FDA4AF', '#CBD5E1', '#D6D3D1',
];

/// 活泼系：各族 500 中阶，明快饱和，随机导入的默认观感区间。
const List<String> kVibrantCourseColorGroupHexes = [
  '#EF4444', '#F97316', '#F59E0B', '#EAB308', '#84CC16',
  '#22C55E', '#10B981', '#14B8A6', '#06B6D4', '#0EA5E9',
  '#3B82F6', '#6366F1', '#8B5CF6', '#A855F7', '#D946EF',
  '#EC4899', '#F43F5E', '#64748B', '#78716C',
];

/// 深色系：各族 700 深阶，沉稳内敛（白字对比充裕）。
const List<String> kDeepCourseColorGroupHexes = [
  '#B91C1C', '#C2410C', '#B45309', '#A16207', '#4D7C0F',
  '#15803D', '#047857', '#0F766E', '#0E7490', '#0369A1',
  '#1D4ED8', '#4338CA', '#6D28D9', '#7E22CE', '#A21CAF',
  '#BE185D', '#BE123C', '#334155', '#44403C',
];

/// 多巴胺系：整条彩虹的糖果 400 亮阶铺底 + 紫/品红/粉/玫四枚 500 深糖锚点，
/// 高饱和撞色、零灰调零土调（亮阶白墨居多少黑墨点睛，深糖锚点白墨充裕）。
const List<String> kDopamineCourseColorGroupHexes = [
  '#F87171', '#FB923C', '#FBBF24', '#FACC15', '#A3E635',
  '#4ADE80', '#34D399', '#2DD4BF', '#22D3EE', '#38BDF8',
  '#60A5FA', '#818CF8', '#A78BFA', '#A855F7', '#D946EF',
  '#EC4899', '#F43F5E',
];

/// 落日系：全暖域同温层配色，金黄→琥珀→橘→珊瑚红→玫粉→暮紫收尾；
/// 只取暖族中高饱和阶位（不碰 600+ 土棕琥珀），任意两卡相邻不打架。
const List<String> kSunsetCourseColorGroupHexes = [
  '#FACC15', '#FBBF24', '#F59E0B', '#FF9800', '#FB923C',
  '#F97316', '#EA580C', '#FF5722', '#F87171', '#EF4444',
  '#FB7185', '#F43F5E', '#F472B6', '#EC4899', '#E91E63',
  '#C084FC', '#A855F7',
];

/// 海洋系：全冷域同温层配色，翠绿浅滩→青绿→天蓝→靛蓝深海由浅入深；
/// 600 深阶保白墨充裕，整周课表冷色统一有秩序感。
const List<String> kOceanCourseColorGroupHexes = [
  '#34D399', '#10B981', '#059669', '#2DD4BF', '#14B8A6',
  '#0D9488', '#22D3EE', '#06B6D4', '#0891B2', '#38BDF8',
  '#0EA5E9', '#0284C7', '#60A5FA', '#3B82F6', '#2563EB',
  '#818CF8', '#6366F1',
];

/// 预设颜色组（「全部颜色」不入列，由 [kCourseColorGroupAllId] 单独表示）。
const List<CourseColorGroup> kCourseColorGroups = [
  CourseColorGroup(id: 'pastel', hexes: kPastelCourseColorGroupHexes),
  CourseColorGroup(id: 'vibrant', hexes: kVibrantCourseColorGroupHexes),
  CourseColorGroup(id: 'deep', hexes: kDeepCourseColorGroupHexes),
  CourseColorGroup(id: 'dopamine', hexes: kDopamineCourseColorGroupHexes),
  CourseColorGroup(id: 'sunset', hexes: kSunsetCourseColorGroupHexes),
  CourseColorGroup(id: 'ocean', hexes: kOceanCourseColorGroupHexes),
];

/// 解析随机取色色板：'all' 与未知 id（历史残留值）都兜底回全量色板。
List<String> courseColorGroupPalette(String groupId) {
  if (groupId != kCourseColorGroupAllId) {
    for (final group in kCourseColorGroups) {
      if (group.id == groupId) {
        return group.hexes;
      }
    }
  }
  return kPresetCourseColorHexes;
}

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
const double courseCardMinContrastRatio = 3;

/// Invisibility bar: below this an ink is effectively unreadable and always
/// overridden; between this and [courseCardMinContrastRatio] the user's choice
/// is kept but flagged as advisory.
const double courseCardCriticalContrastRatio = 2;

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

/// 公开给预览场景的自动墨色：白/近黑中对比度更高的一档。
/// 与实心卡隐身线之下的自动回落（[_bestContrastInk]）同一结论。
Color bestContrastCourseCardInk(Color background) =>
    _bestContrastInk(background);

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
