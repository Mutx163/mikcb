package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.weather.BingWallpaperResolution
import com.mutx163.qingyu.weather.WallpaperTargetSize
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 设备级 Bing 台账存储（Dart `lib/services/bing_wallpaper_store.dart`）。
 *
 * 断言四件事：
 * 1. 开关缺省关、写入后能读回，且落盘键与 Dart 逐字一致；
 * 2. 记账写进台账后，**换一个 store 实例**仍能读回（证明真落了盘，不是进程内缓存）；
 * 3. 台账坏掉当空表、不抛错（设置页不能被一条脏数据带崩）；
 * 4. 台账封顶 12 条，溢出路径原样返回给宿主过白名单后再删。
 */
class BingWallpaperStoreTest {

    private fun store(): Pair<BingWallpaperStore, InMemoryKeyValueStore> {
        val prefs = InMemoryKeyValueStore()
        return BingWallpaperStore(prefs) to prefs
    }

    @Test
    fun `自动换缺省关闭 写入后读回为开 且键名与 Dart 一致`() {
        val (bing, prefs) = store()
        assertFalse(bing.autoApplyEnabled())

        bing.setAutoApplyEnabled(true)

        assertTrue(bing.autoApplyEnabled())
        assertEquals(
            "true",
            prefs.rawSnapshot()["flutter.${BingWallpaperStore.PREF_AUTO_APPLY}"],
        )
    }

    @Test
    fun `记账后换一个实例仍能读回台账`() {
        val (bing, prefs) = store()
        val recorded = bing.recordApplied(
            dateKey = "20261101",
            resolution = BingWallpaperResolution.HIGH,
            path = "/w/20261101.jpg",
            targetSize = WallpaperTargetSize(1440, 3200),
        )

        assertEquals(emptyList<String>(), recorded.evictedPaths)
        // 新实例 = 冷启动后重新读盘；值必须还在。
        val reopened = BingWallpaperStore(prefs).ledger()
        assertEquals(1, reopened.entries.size)
        assertEquals("20261101", reopened.lastAutoAppliedDate)
        assertEquals(listOf("/w/20261101.jpg"), reopened.downloadedPaths)
    }

    @Test
    fun `台账坏数据当空表 不抛错`() {
        val prefs = InMemoryKeyValueStore(mapOf(BingWallpaperStore.PREF_LEDGER to "{not-json"))
        val bing = BingWallpaperStore(prefs)
        assertTrue(bing.ledger().entries.isEmpty())
        assertTrue(bing.snapshot().downloadedPaths.isEmpty())
    }

    @Test
    fun `台账封顶十二条 溢出路径返回给宿主`() {
        val (bing, _) = store()
        var evicted: List<String> = emptyList()
        repeat(13) { index ->
            val day = (index + 1).toString().padStart(2, '0')
            evicted = bing.recordApplied(
                dateKey = "202611$day",
                resolution = BingWallpaperResolution.HIGH,
                path = "/w/202611$day.jpg",
            ).evictedPaths
        }

        assertEquals(12, bing.ledger().entries.size)
        // 最新在前；第 13 条进来时把最早那条挤出。
        assertEquals("20261113", bing.ledger().lastAutoAppliedDate)
        assertEquals(listOf("/w/20261101.jpg"), evicted)
    }

    @Test
    fun `开关与记账各通知一次 移除监听后不再通知`() {
        val (bing, _) = store()
        var calls = 0
        val listener = { calls += 1 }
        bing.addListener(listener)

        bing.setAutoApplyEnabled(true)
        bing.recordApplied(
            dateKey = "20261101",
            resolution = BingWallpaperResolution.HIGH,
            path = "/w/a.jpg",
        )
        assertEquals(2, calls)

        bing.removeListener(listener)
        bing.setAutoApplyEnabled(false)
        assertEquals(2, calls)
    }
}
