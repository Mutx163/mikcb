package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.DartTime
import java.time.LocalDateTime

/**
 * Dart `lib/utils/bing_wallpaper_date_label.dart` 的移植（纯判定部分）。
 *
 * Bing 的 `startdate` 形如 `20261005`。Dart 侧把它直接渲染成文案
 * （今天 / 昨天 / M 月 D 日）；Kotlin 侧不搬 l10n（那要 AppLocalizations），
 * 搬的是**判定**：解析 + 该走哪一档。文案由界面层按 [BingDateLabelKind] 拼。
 */

/** 日期标签该走哪一档（对应 Dart 三档说法）。 */
sealed class BingDateLabelKind {
    /** 列表头两张是最新的：直接说「今天」。 */
    data object Today : BingDateLabelKind()

    /** 「昨天」。 */
    data object Yesterday : BingDateLabelKind()

    /** 更早（或未来）的走「M 月 D 日」，不带年（列表最多 8 天，不会跨年）。 */
    data class MonthDay(val month: Int, val day: Int) : BingDateLabelKind()

    /** 解析不出来就原样退回那串数字，绝不显示空白。 */
    data class Raw(val raw: String) : BingDateLabelKind()
}

/**
 * 解析 `YYYYMMDD`；长度不对、非数字、月/日越界都算失败（返回 null）。
 *
 * 月日越界那条别省：接口若哪天给了 `20261345` 这类脏值，`DateTime` 会自动进位
 * （13 月变成次年 1 月），于是用户看到「1 月 45 日」这种不存在的日期还不报错。
 *
 * ⚠️ 先卡「全是数字」再 parse：Dart `int.tryParse` 会默默接受首尾空白
 * （`'  26'` 解析成 26），`'  261005'` 这种被补位/带空格的脏值必须直接拒。
 */
fun parseBingWallpaperDateKey(raw: String): LocalDateTime? {
    if (raw.length != 8) return null
    for (ch in raw) {
        if (ch < '0' || ch > '9') return null
    }
    val year = raw.substring(0, 4).toIntOrNull() ?: return null
    val month = raw.substring(4, 6).toIntOrNull() ?: return null
    val day = raw.substring(6, 8).toIntOrNull() ?: return null
    if (month < 1 || month > 12 || day < 1 || day > 31) return null
    // 与 Dart DateTime(year, month, day) 同口径：越界日按日历顺延（2 月 31 → 3 月 3）。
    return DartTime.dateTime(year, month, day)
}

/**
 * Bing `dateKey` 的三档判定。
 *
 * Dart 侧 `daysAgo = today.difference(parsed).inDays`：today 是当日零点、
 * parsed 也是零点，inDays 即纯日历日差。0 → 今天、1 → 昨天；未来日期
 * （enddate 偶尔跨到明天）与更早的一起走月日，不给「-1 天前」这种负数说法。
 */
fun bingWallpaperDateKind(dateKey: String, now: LocalDateTime): BingDateLabelKind {
    val parsed = parseBingWallpaperDateKey(dateKey) ?: return BingDateLabelKind.Raw(dateKey)
    val today = LocalDateTime.of(now.year, now.monthValue, now.dayOfMonth, 0, 0)
    val daysAgo = kotlin.math.abs(
        java.time.temporal.ChronoUnit.DAYS.between(today, parsed),
    ).let { diff -> if (parsed.isBefore(today)) diff else -diff }
    // daysAgo：parsed 在过去为正、未来为负（与 Dart difference 同号）。
    return when {
        daysAgo == 0L -> BingDateLabelKind.Today
        daysAgo == 1L -> BingDateLabelKind.Yesterday
        else -> BingDateLabelKind.MonthDay(parsed.monthValue, parsed.dayOfMonth)
    }
}
