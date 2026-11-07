package com.mutx163.qingyu.calendar

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime

/**
 * `HolidaySnapshot.remoteFetchSucceeded` 的判据（2026-11-05 新增）。
 *
 * ## 为什么需要这个字段
 *
 * 高级页「检查更新」原来刷完一律弹按钮名「检查更新」——provider 从不抛异常，所以
 * 「跑完了」和「真的更新了」在界面上不可区分（远端全失败时数据是内置资产兜底，
 * 一条 error 都没有）。要按结果分流提示，就必须由 provider 记录「这一轮有没有
 * 把远端拉下来」：
 *
 * - `true`：至少有一年从远端拿到了非空数据（页面提示「节假日数据已更新」）；
 * - `false`：发过请求但全部失败（数据是内置兜底，页面提示「更新失败，已使用本地数据」）；
 * - `null`：这一轮**没发请求**（命中内存 / 本地缓存），不能报「失败」。
 */
class HolidayProviderRemoteOutcomeTest {

    /** 固定「今天」，否则跨年/跨周会让 `holidayYearsToLoad` 多要几年，断言跟着漂。 */
    private val today = LocalDate.of(2026, 10, 1)

    private fun entry(name: String = "国庆节"): HolidayEntry = HolidayEntry(
        date = LocalDateTime.of(2026, 10, 1, 0, 0),
        name = name,
        type = HolidayType.Vacation,
        groupId = "national-day-2026",
    )

    private fun provider(
        gateway: HolidayRemoteGateway,
        preferences: HolidayPreferences = HolidayPreferences(InMemoryKeyValueStore()),
    ): HolidayProvider = HolidayProvider(
        service = gateway,
        preferences = preferences,
        builtinJson = { null },
        clock = { today },
        nowTime = { LocalTime.NOON },
    )

    /** 永远失败的网关（模拟网络全挂）。 */
    private class FailingGateway : HolidayRemoteGateway {
        var calls = 0
        override fun fetchYear(year: Int, log: (String) -> Unit): HolidayData? {
            calls++
            return null
        }
    }

    /** 永远成功的网关。 */
    private class SucceedingGateway(private val data: HolidayData) : HolidayRemoteGateway {
        var calls = 0
        override fun fetchYear(year: Int, log: (String) -> Unit): HolidayData? {
            calls++
            return data
        }
    }

    @Test
    fun `远端全部失败时记为 false 且仍给出兜底数据`() {
        val gateway = FailingGateway()
        val provider = provider(gateway)

        provider.refresh()

        assertTrue("刷新必须真的发过请求", gateway.calls > 0)
        assertEquals(
            "远端全失败必须记 false（页面据此提示「更新失败，已使用本地数据」）",
            false,
            provider.snapshot.remoteFetchSucceeded,
        )
        // 失败不等于没有数据：内置兜底（这里没有资产 → 空条目）照样要给出一份，
        // 否则页面会永远停在「加载中」。
        assertNotNull("快照里必须有 data（退化为空数据，而不是 null）", provider.snapshot.data)
    }

    @Test
    fun `远端成功时记为 true`() {
        val gateway = SucceedingGateway(HolidayData(year = 2026, version = 1, entries = listOf(entry())))
        val provider = provider(gateway)

        provider.refresh()

        assertTrue("远端必须真的发过请求", gateway.calls > 0)
        assertEquals(
            "拉到远端数据必须记 true（页面提示「节假日数据已更新」）",
            true,
            provider.snapshot.remoteFetchSucceeded,
        )
        assertTrue(
            "远端数据要落进快照",
            provider.snapshot.data?.entries?.any { it.name == "国庆节" } == true,
        )
    }

    @Test
    fun `命中缓存不发请求时记为 null 不能报失败`() {
        val gateway = SucceedingGateway(HolidayData(year = 2026, version = 1, entries = listOf(entry())))
        val provider = provider(gateway)

        provider.initialize()
        assertEquals("首次加载走远端", true, provider.snapshot.remoteFetchSucceeded)
        val callsAfterFirst = gateway.calls

        provider.initialize()

        assertEquals("第二次 initialize 命中内存缓存，不该再发请求", callsAfterFirst, gateway.calls)
        assertNull(
            "没发请求 ⇒ null（页面不能把「没问网」说成「更新失败」）",
            provider.snapshot.remoteFetchSucceeded,
        )
    }

    @Test
    fun `刷新会绕过已有缓存重新取网 从 true 翻成 false`() {
        // 同一个 preferences（同一份内存 KV + 本地缓存），两个 provider 前后接力：
        // 先成功一次把缓存写热，再刷新时必须无视缓存重新取网。
        val preferences = HolidayPreferences(InMemoryKeyValueStore())
        val warmed = provider(
            SucceedingGateway(HolidayData(year = 2026, version = 1, entries = listOf(entry()))),
            preferences,
        )
        warmed.initialize()
        assertEquals(true, warmed.snapshot.remoteFetchSucceeded)

        val failing = FailingGateway()
        val refreshed = provider(failing, preferences)
        refreshed.refresh()

        assertTrue("刷新必须真的重新取网（forceRemote 会清缓存）", failing.calls > 0)
        assertEquals(
            "缓存是热的也必须重新取网，结果按这一轮的真实情况记 false",
            false,
            refreshed.snapshot.remoteFetchSucceeded,
        )
    }
}
