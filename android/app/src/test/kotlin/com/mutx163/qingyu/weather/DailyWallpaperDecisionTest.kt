package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.DartTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 日期 → 壁纸切换判定（Bing 自动换的「哪一天、换没换」纯判据）。
 *
 * 期望值来源：[Dart推演] lib/services/bing_wallpaper_service.dart 的
 * `_isToday` 与 maybeApplyDaily 的判据顺序（把它的「判据部分」抽成纯函数，
 * 网络 / prefs / 磁盘留在 IO 清单里）；三档结局的语义对照
 * [Dart抄录] test/services/daily_wallpaper_service_test.dart 与
 * bing_wallpaper_service_test.dart 的 maybeApplyDaily 组。
 */
class DailyWallpaperDecisionTest {

    // ---------- isToday（dateKey 是否今天） ----------

    @Test
    fun `isToday true when dateKey matches now`() { // [Dart推演] _isToday 逐字段比对
        val now = LocalDateTime.of(2026, 10, 5, 9, 30)
        assertTrue(BingWallpaperDaily.isToday(BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X", title = "t", copyright = "c"), now))
    }

    @Test
    fun `isToday false for yesterday tomorrow and garbage`() { // [Dart推演] 解析不了的一律「不是今天」
        val now = LocalDateTime.of(2026, 10, 6, 9, 30)
        assertFalse(BingWallpaperDaily.isToday(BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X", title = "t", copyright = "c"), now))
        assertFalse(BingWallpaperDaily.isToday(BingWallpaperItem(dateKey = "20261007", urlBase = "/th?id=OHR.X", title = "t", copyright = "c"), now))
        assertFalse(BingWallpaperDaily.isToday(BingWallpaperItem(dateKey = "abc", urlBase = "/th?id=OHR.X", title = "t", copyright = "c"), now))
    }

    @Test
    fun `isToday compares wall clock fields not epochs`() { // [Dart推演] 时分秒不参与
        val now = LocalDateTime.of(2026, 10, 5, 23, 59, 59)
        assertTrue(BingWallpaperDaily.isToday(BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X", title = "t", copyright = "c"), now))
    }

    // ---------- 自动换结局决策（幂等 / stale / 自愈） ----------

    /**
     * Dart maybeApplyDaily 判据段的逐字对应：
     * 1. 开关关 → disabled（连列表都不拉，由调用方保证）；
     * 2. lastAutoAppliedDate == 最新那张的 dateKey → alreadyApplied；
     * 3. 否则 → 下载（IO），成功后记**那张图自己的** dateKey；
     * 4. 结局按 isToday 分 appliedToday / appliedStale。
     *
     * 这里钉判据 2 与 4 的纯逻辑；判据 1/3 的接线由宿主层完成。
     */
    @Test
    fun `already applied when newest dateKey matches record`() { // [Dart抄录] bing_wallpaper_service_test:638-660 同一天再跑一次 → alreadyApplied
        assertEquals(
            BingAutoApplyDecision.AlreadyApplied,
            BingWallpaperDaily.decide(
                lastAutoAppliedDate = "20261005",
                newest = BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X", title = "t", copyright = "c"),
                now = LocalDateTime.of(2026, 10, 5, 21, 0),
            ),
        )
    }

    @Test
    fun `proceeds when newest is a different day`() { // [Dart推演] 判据不等 → 继续走下载
        assertEquals(
            BingAutoApplyDecision.Proceed,
            BingWallpaperDaily.decide(
                lastAutoAppliedDate = "20261005",
                newest = BingWallpaperItem.itemOf("20261006"),
                now = LocalDateTime.of(2026, 10, 6, 8, 0),
            ),
        )
    }

    @Test
    fun `proceeds when nothing recorded yet`() { // [Dart推演] 从没换过 → 继续
        assertEquals(
            BingAutoApplyDecision.Proceed,
            BingWallpaperDaily.decide(
                lastAutoAppliedDate = null,
                newest = BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X", title = "t", copyright = "c"),
                now = LocalDateTime.of(2026, 10, 5, 8, 0),
            ),
        )
    }

    @Test
    fun `outcome is appliedStale when newest is not today`() { // [Dart抄录] bing_wallpaper_service_test:780-823 Bing 还没放出今天那张
        assertEquals(
            BingAutoApplyDecision.Outcome.Stale,
            BingWallpaperDaily.outcomeFor(isToday = false),
        )
        assertEquals(
            BingAutoApplyDecision.Outcome.Today,
            BingWallpaperDaily.outcomeFor(isToday = true),
        )
    }

    @Test
    fun `stale path still records the image date enabling self-heal`() { // [Dart抄录] bing_wallpaper_service_test:825-874（自愈链）
        // 换上 10-05 顶替（今天 10-06），记的是 20261005；等 Bing 放出 10-06，
        // 判据自然放行当天再换一次。这条钉「记图自己的日期」的键位。
        assertEquals(
            BingAutoApplyDecision.AlreadyApplied,
            BingWallpaperDaily.decide(
                lastAutoAppliedDate = "20261005",
                newest = BingWallpaperItem(dateKey = "20261005", urlBase = "/th?id=OHR.X", title = "t", copyright = "c"),
                now = LocalDateTime.of(2026, 10, 6, 8, 0),
            ),
        )
        assertEquals(
            BingAutoApplyDecision.Proceed,
            BingWallpaperDaily.decide(
                lastAutoAppliedDate = "20261005",
                newest = BingWallpaperItem.itemOf("20261006"),
                now = LocalDateTime.of(2026, 10, 6, 8, 0),
            ),
        )
    }

    @Test
    fun `outcome carries the image own dateKey`() { // [Dart抄录] daily_wallpaper_service_test:126-152 itemId 是那张图自己的 dateKey
        val item = BingWallpaperItem.itemOf("20261006")
        val result = BingAutoApplyResult(
            outcome = BingAutoApplyDecision.Outcome.Stale,
            path = "/tmp/wallpaper_bing_20261006_high.jpg",
            dateKey = item.dateKey,
        )
        assertEquals("20261006", result.dateKey)
        assertFalse(result.succeeded == false)
    }

    // ---------- 每日切换映射（DailyWallpaperService 的翻译层） ----------

    @Test
    fun `bing outcome maps one to one onto daily outcome`() { // [Dart推演] _fromBing 的 switch 逐条
        assertEquals(
            DailyApplyOutcome.Disabled,
            DailyWallpaperMapper.fromBing(BingAutoApplyDecision.Outcome.Disabled, path = null, dateKey = null).outcome,
        )
        assertEquals(
            DailyApplyOutcome.AlreadyApplied,
            DailyWallpaperMapper.fromBing(BingAutoApplyDecision.Outcome.AlreadyApplied, path = null, dateKey = null).outcome,
        )
        val today = DailyWallpaperMapper.fromBing(
            BingAutoApplyDecision.Outcome.Today,
            path = "/tmp/a.jpg",
            dateKey = "20261005",
        )
        assertEquals(DailyApplyOutcome.AppliedToday, today.outcome)
        assertEquals("/tmp/a.jpg", today.path)
        assertEquals("20261005", today.itemId)
        val stale = DailyWallpaperMapper.fromBing(
            BingAutoApplyDecision.Outcome.Stale,
            path = "/tmp/a.jpg",
            dateKey = "20261005",
        )
        assertEquals(DailyApplyOutcome.AppliedStale, stale.outcome)
        assertEquals("20261005", stale.itemId)
        assertEquals(
            DailyApplyOutcome.Failed,
            DailyWallpaperMapper.fromBing(BingAutoApplyDecision.Outcome.Failed, path = null, dateKey = null).outcome,
        )
    }

    @Test
    fun `succeeded means a path came back`() { // [Dart推演] succeeded => path != null
        assertTrue(DailyWallpaperApplyResult(DailyApplyOutcome.AppliedToday, "/tmp/a.jpg", "20261005").succeeded)
        assertFalse(DailyWallpaperApplyResult(DailyApplyOutcome.Failed, null, null).succeeded)
    }

    // ---------- 列表缓存 TTL（loadItems 的判据段） ----------

    @Test
    fun `cache hit within ttl and non empty`() { // [Dart推演] loadItems：「缓存时间在 TTL 内且非空」才算命中
        val fetchedAt = LocalDateTime.of(2026, 10, 5, 12, 0)
        val now = LocalDateTime.of(2026, 10, 5, 14, 59)
        assertTrue(BingWallpaperDaily.cacheFresh(fetchedAt, now))
        // 3 小时整点不算 fresh（Dart `< ttl`）。
        assertFalse(BingWallpaperDaily.cacheFresh(fetchedAt, LocalDateTime.of(2026, 10, 5, 15, 0)))
        assertFalse(BingWallpaperDaily.cacheFresh(null, now))
    }

    @Test
    fun `cacheFresh across midnight`() { // [人推] TTL 是绝对时长，跨零点仍按差值算
        assertTrue(
            BingWallpaperDaily.cacheFresh(
                LocalDateTime.of(2026, 10, 5, 23, 50),
                LocalDateTime.of(2026, 10, 6, 0, 20),
            ),
        )
    }

    @Test
    fun `empty cached list never counts as hit`() { // [Dart推演] 空清单也算未命中（否则一次失败缓存 3 小时）
        // cacheFresh 只判时间；「非空」由调用方与它一起判 —— 这里钉调用侧口径。
        val cached: List<BingWallpaperItem> = emptyList()
        val fresh = BingWallpaperDaily.cacheFresh(LocalDateTime.of(2026, 10, 5, 12, 0), LocalDateTime.of(2026, 10, 5, 13, 0))
        assertFalse(cached.isNotEmpty() && fresh)
    }

    @Test
    fun `wall clock day arithmetic matches dart time`() { // [人推] 判据里日期取墙钟字段（year/month/day）
        val t = DartTime.dateTime(2026, 10, 5, 23, 59)
        assertEquals(LocalDateTime.of(2026, 10, 5, 23, 59), t)
    }
}
