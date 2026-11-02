package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WallpaperHistoryRowModel
import com.mutx163.qingyu.weather.BingAutoApplyDecision
import com.mutx163.qingyu.weather.BingWallpaperItem
import com.mutx163.qingyu.weather.BingWallpaperLedger
import com.mutx163.qingyu.weather.BingWallpaperLedgerEntry
import com.mutx163.qingyu.weather.BingWallpaperResolution
import com.mutx163.qingyu.weather.DailyApplyOutcome
import com.mutx163.qingyu.weather.WallpaperTargetSize
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「每天自动更换」的纯判据（Dart `settings_home_backdrop_flow.dart:501-642`）。
 *
 * 断言四件事：
 * 1. 开关打开**立刻换一次**，关闭只落盘；
 * 2. 四种结局各有一句提示（换今天那张的提示是打开时那句，不重复弹）；
 * 3. 自动换写设置**不碰历史**（否则 10 天后用户自己的图被挤出并删文件）；
 * 4. 台账淘汰文件同样过三路白名单。
 */
class WallpaperAutoApplyLogicTest {

    private val item = BingWallpaperItem(
        dateKey = "20261101",
        urlBase = "/th?id=OHR.Test",
        title = "测试",
        copyright = "© test",
    )

    private fun ledger(lastAuto: String? = null): BingWallpaperLedger =
        if (lastAuto == null) {
            BingWallpaperLedger()
        } else {
            BingWallpaperLedger(
                entries = listOf(
                    BingWallpaperLedgerEntry(
                        dateKey = lastAuto,
                        resolution = BingWallpaperResolution.HIGH,
                        targetSize = WallpaperTargetSize(
                            BingWallpaperResolution.HIGH.width,
                            BingWallpaperResolution.HIGH.height,
                        ),
                        path = "/cache/$lastAuto.jpg",
                        autoApplied = true,
                    ),
                ),
            )
        }

    // ------------------------------------------------------------ 打开即换一次

    @Test
    fun `打开开关落盘并立刻换一次`() {
        val plan = WallpaperAutoApplyLogic.togglePlan(currentEnabled = false, newValue = true)
        assertTrue(plan.persistEnabled)
        assertTrue(plan.showApplying)
        assertTrue(plan.runApplyOnce)
    }

    @Test
    fun `关闭开关只落盘不换`() {
        val plan = WallpaperAutoApplyLogic.togglePlan(currentEnabled = true, newValue = false)
        assertTrue(plan.persistEnabled)
        assertFalse(plan.showApplying)
        assertFalse(plan.runApplyOnce)
    }

    @Test
    fun `值没变时什么都不做`() {
        val plan = WallpaperAutoApplyLogic.togglePlan(currentEnabled = true, newValue = true)
        assertFalse(plan.persistEnabled)
        assertFalse(plan.showApplying)
        assertFalse(plan.runApplyOnce)
    }

    @Test
    fun `打开时那一句是正在换成今天的壁纸`() {
        assertEquals("正在换成今天的壁纸", WallpaperAutoApplyLogic.toggleNotice().text.zh)
    }

    // ---------------------------------------------------------- 四种结局提示

    @Test
    fun `换上今天那张不重复弹提示`() {
        // 打开时已经弹过「正在换成今天的壁纸」，成功不再补一句
        assertNull(WallpaperAutoApplyLogic.outcomeNotice(DailyApplyOutcome.AppliedToday))
    }

    @Test
    fun `今天已换过给一句已换过`() {
        val notice = WallpaperAutoApplyLogic.outcomeNotice(DailyApplyOutcome.AlreadyApplied)
        assertEquals("今天已经换过啦", notice!!.text.zh)
        assertFalse(notice.warning)
    }

    @Test
    fun `换上非今天那张要说清是哪一天`() {
        val notice = WallpaperAutoApplyLogic.outcomeNotice(
            DailyApplyOutcome.AppliedStale,
            dateLabel = "10 月 5 日",
        )
        assertEquals(
            "Bing 还没放出今天的图，先用 10 月 5 日 那张顶一下",
            notice!!.text.zh,
        )
        assertEquals("bingWallpaperAutoApplyStale", notice.text.key)
    }

    @Test
    fun `失败必须出声且是警示样式`() {
        val notice = WallpaperAutoApplyLogic.outcomeNotice(DailyApplyOutcome.Failed)
        assertEquals("没能取到 Bing 每日壁纸，请检查网络后重试", notice!!.text.zh)
        assertTrue(notice.warning)
    }

    @Test
    fun `开关没开这个结局不出声`() {
        assertNull(WallpaperAutoApplyLogic.outcomeNotice(DailyApplyOutcome.Disabled))
    }

    // ------------------------------------------------------------ 台账判据

    @Test
    fun `台账记着同一张时判为已换过`() {
        val snapshot = WallpaperAutoApplySnapshot(enabled = true, ledger = ledger("20261101"))
        assertEquals(
            BingAutoApplyDecision.AlreadyApplied,
            WallpaperAutoApplyLogic.decide(snapshot, item),
        )
    }

    @Test
    fun `台账不是同一张时继续换`() {
        val snapshot = WallpaperAutoApplySnapshot(enabled = true, ledger = ledger("20261031"))
        assertEquals(
            BingAutoApplyDecision.Proceed,
            WallpaperAutoApplyLogic.decide(snapshot, item),
        )
    }

    @Test
    fun `台账空时今天那张的结局是今天`() {
        val now = LocalDateTime.of(2026, 11, 1, 12, 0)
        assertEquals(
            BingAutoApplyDecision.Outcome.Today,
            WallpaperAutoApplyLogic.outcomeFor(item, now),
        )
    }

    // ------------------------------------------------- 自动换写设置不碰历史

    @Test
    fun `自动换只写路径与居中取景且不动历史`() {
        val history = listOf(WallpaperHistoryRowModel("/mine.png", scale = 2.0))
        val current = TimetableSettingsModel(
            homePageWallpaperPath = "/old.png",
            homePageWallpaperAlignX = 0.3,
            homePageWallpaperAlignY = -0.4,
            homePageWallpaperScale = 3.0,
            wallpaperHistory = history,
        )
        val next = WallpaperAutoApplyLogic.settingsAfterApply(current, "/bing.jpg")
        assertNotNull(next)
        assertEquals("/bing.jpg", next!!.homePageWallpaperPath)
        assertEquals(0.0, next.homePageWallpaperAlignX, 0.0)
        assertEquals(0.0, next.homePageWallpaperAlignY, 0.0)
        assertEquals(1.0, next.homePageWallpaperScale, 0.0)
        // ⚠️ 自动换不进「最近使用」：每天一条会把用户自己的图挤出并删文件
        assertEquals(history, next.wallpaperHistory)
    }

    @Test
    fun `没有换上时原样保留设置`() {
        val current = TimetableSettingsModel(homePageWallpaperPath = "/old.png")
        assertNull(WallpaperAutoApplyLogic.settingsAfterApply(current, null))
        assertNull(WallpaperAutoApplyLogic.settingsAfterApply(current, "  "))
    }

    // ---------------------------------------------------------- 淘汰白名单

    @Test
    fun `自动换淘汰文件也过三路白名单`() {
        val snapshot = WallpaperAutoApplySnapshot(
            enabled = true,
            ledger = ledger("20261031"),
        )
        val deletable = WallpaperAutoApplyLogic.deletableAfterApply(
            evictedPaths = listOf(
                "/garbage.jpg",
                "/other-profile.jpg",
                "/draft.jpg",
                "/cache/20261031.jpg",
            ),
            allProfilesCurrentPaths = listOf("/other-profile.jpg"),
            profilesReadable = true,
            draftPath = "/draft.jpg",
            snapshot = snapshot,
        )
        assertEquals(listOf("/garbage.jpg"), deletable)
    }

    @Test
    fun `档案可读但都没壁纸时 垃圾图照常可删`() {
        // P2-18：空列表 ≠ 读取失败；可读性由调用方显式交代。
        // 台账也留空，确保这里测的是「所有引用来源都是合法空集」，而不是被台账撑成非空。
        assertEquals(
            listOf("/garbage.jpg"),
            WallpaperAutoApplyLogic.deletableAfterApply(
                evictedPaths = listOf("/garbage.jpg"),
                allProfilesCurrentPaths = emptyList(),
                profilesReadable = true,
                snapshot = WallpaperAutoApplySnapshot(),
            ),
        )
    }

    @Test
    fun `读不到档案引用时自动换淘汰也一张都不删`() {
        val snapshot = WallpaperAutoApplySnapshot(
            enabled = true,
            ledger = ledger("20261031"),
        )
        for (profiles in listOf<Iterable<String?>?>(null, emptyList())) {
            assertEquals(
                emptyList<String>(),
                WallpaperAutoApplyLogic.deletableAfterApply(
                    evictedPaths = listOf("/garbage.jpg"),
                    allProfilesCurrentPaths = profiles,
                    profilesReadable = false,
                    snapshot = snapshot,
                ),
            )
        }
    }
}
