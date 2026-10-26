package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.DartTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDateTime

/**
 * Bing `startdate`（YYYYMMDD）解析与「今天/昨天/月日」三档判定。
 *
 * 期望值来源：[Dart抄录] test/utils/bing_wallpaper_date_label_test.dart。
 * 重点是「月/日越界必须当解析失败」——DateTime 会自动进位成不存在的日期还不报错。
 *
 * Kotlin 侧不搬 l10n 文案（那要 AppLocalizations），只搬判定：
 * [BingDateLabelKind] 给出该走哪一档，文案由界面层拼。
 */
class BingWallpaperDateKeyTest {

    // ---------- parseBingWallpaperDateKey ----------

    @Test
    fun `valid yyyymmdd parses to local midnight`() { // [Dart抄录] parse 合法分支
        assertEquals(
            LocalDateTime.of(2026, 10, 5, 0, 0),
            parseBingWallpaperDateKey("20261005"),
        )
        assertEquals(
            LocalDateTime.of(2025, 12, 31, 0, 0),
            parseBingWallpaperDateKey("20251231"),
        )
    }

    @Test
    fun `bad length and non digits are rejected`() { // [Dart抄录] 长度不对 / 非数字一律失败
        for (bad in listOf(
            "",
            "2026",
            "202610051", // 9 位
            "2026100", // 7 位
            "2026ABCD",
            "  261005", // int.tryParse 会吃首尾空白，这里必须拒
        )) {
            assertNull("「$bad」必须当坏值丢掉而不是被截断/进位", parseBingWallpaperDateKey(bad))
        }
    }

    @Test
    fun `out of range month or day fails`() { // [Dart抄录] 月/日越界必须失败（否则 DateTime 自动进位）
        assertNull(parseBingWallpaperDateKey("20261345"))
        assertNull(parseBingWallpaperDateKey("20260010"))
        assertNull(parseBingWallpaperDateKey("20261032"))
        assertNull(parseBingWallpaperDateKey("20261000"))
    }

    @Test
    fun `day 31 passes the guard like dart`() { // [Dart推演] 守卫只卡 1..31，31 日合法
        assertEquals(
            LocalDateTime.of(2026, 1, 31, 0, 0),
            parseBingWallpaperDateKey("20260131"),
        )
    }

    @Test
    fun `day beyond month length still rolls over like dart datetime`() { // [Dart推演] 2 月 31 日 → 与 Dart DateTime(2026,2,31) 同样进位成 3 月 3 日
        // Dart 侧 parseBingWallpaperDateKey 的守卫就只卡到 31，2 月 31 日会经
        // DateTime(2026,2,31) 进位 —— 这是既有口径的已知怪癖，移植保持逐字一致，
        // 由界面文案兜底（显示成「3 月 3 日」而不是崩溃/空白）。
        assertEquals(
            DartTime.dateTime(2026, 3, 3),
            parseBingWallpaperDateKey("20260231"),
        )
    }

    // ---------- 日期标签三档判定 ----------

    private val now = LocalDateTime.of(2026, 10, 5, 21, 30) // [Dart抄录] 固定「今天」

    @Test
    fun `today and yesterday use spoken forms`() { // [Dart抄录] 今天 / 昨天
        assertEquals(BingDateLabelKind.Today, bingWallpaperDateKind("20261005", now))
        assertEquals(BingDateLabelKind.Yesterday, bingWallpaperDateKind("20261004", now))
    }

    @Test
    fun `older dates use month day without year`() { // [Dart抄录] 更早的走月日
        assertEquals(BingDateLabelKind.MonthDay(10, 3), bingWallpaperDateKind("20261003", now))
        assertEquals(BingDateLabelKind.MonthDay(9, 28), bingWallpaperDateKind("20260928", now))
    }

    @Test
    fun `future dates also use month day`() { // [Dart抄录] 未来的日期（enddate 偶尔跨到明天）不给负数说法
        assertEquals(BingDateLabelKind.MonthDay(10, 6), bingWallpaperDateKind("20261006", now))
    }

    @Test
    fun `today holds across the whole day`() { // [Dart抄录] 同一天的后半段不会忽然变成昨天
        assertEquals(
            BingDateLabelKind.Today,
            bingWallpaperDateKind("20261005", LocalDateTime.of(2026, 10, 5, 0, 5)),
        )
        assertEquals(
            BingDateLabelKind.Today,
            bingWallpaperDateKind("20261005", LocalDateTime.of(2026, 10, 5, 23, 55)),
        )
    }

    @Test
    fun `unparseable key falls back to the raw string`() { // [Dart抄录] 解析不出来就原样退回，绝不显示空白
        assertEquals(BingDateLabelKind.Raw("abc"), bingWallpaperDateKind("abc", now))
        assertEquals(BingDateLabelKind.Raw(""), bingWallpaperDateKind("", now))
    }
}
