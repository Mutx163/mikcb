import '../l10n/app_localizations.dart';

/// 把 Bing 的 `startdate`（形如 `20261005`）显示成用户读的日期。
///
/// 三档说法：
/// * **今天 / 昨天**：列表头两张是最新的，说「10 月 5 日」不如「今天」直观；
/// * **M 月 D 日**（由 `bingWallpaperDateMonthDay` 按语言给格式）：更早的走这一档。
///   **不带年** —— 列表最多 8 天，不会跨年；
/// * 解析不出来就原样退回那串数字，绝不显示空白。
///
/// [now] 由调用方注入而不是在这里取：图库页传 `DateTime.now()`，这样这段逻辑在单测里
/// 能钉住「今天」而不受测试运行时刻影响。
String bingWallpaperDateLabel(
  AppLocalizations l10n,
  String dateKey, {
  DateTime? now,
}) {
  final parsed = parseBingWallpaperDateKey(dateKey);
  if (parsed == null) {
    return dateKey;
  }
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final daysAgo = today.difference(parsed).inDays;
  if (daysAgo == 0) {
    return l10n.bingWallpaperDateToday;
  }
  if (daysAgo == 1) {
    return l10n.bingWallpaperDateYesterday;
  }
  // 未来的日期（Bing 的 `enddate` 偶尔跨到明天）与更早的走同一条月日 —— 不给
  // 「-1 天前」这种负数说法。
  return l10n.bingWallpaperDateMonthDay(parsed.month, parsed.day);
}

/// 解析 `YYYYMMDD`；长度不对、非数字、月/日越界都算失败（返回 null）。
///
/// 月日越界那条别省：接口若哪天给了 `20261345` 这类脏值，`DateTime` 会**自动进位**
/// （13 月变成次年 1 月），于是用户看到「1 月 45 日」这种不存在的日期还不报错。
DateTime? parseBingWallpaperDateKey(String raw) {
  if (raw.length != 8) {
    return null;
  }
  // ⚠️ 先卡「全是数字」再 `int.tryParse`：`int.tryParse` 会**默默接受首尾空白**
  // （`'  26'` 解析成 26），于是 `'  261005'` 这种被补位/带空格的脏值会被当成
  // 公元 26 年并正常显示。接口字段是固定宽度的 `YYYYMMDD`，任何非数字都该直接拒。
  for (var i = 0; i < raw.length; i++) {
    final code = raw.codeUnitAt(i);
    if (code < 0x30 || code > 0x39) {
      return null;
    }
  }
  final year = int.tryParse(raw.substring(0, 4));
  final month = int.tryParse(raw.substring(4, 6));
  final day = int.tryParse(raw.substring(6, 8));
  if (year == null || month == null || day == null) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    return null;
  }
  return DateTime(year, month, day);
}