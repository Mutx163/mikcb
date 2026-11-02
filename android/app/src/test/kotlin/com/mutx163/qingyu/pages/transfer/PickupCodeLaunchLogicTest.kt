package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 取件码「多级回退」执行器测试。
 *
 * 期望值从 Dart 手推：`lib/services/pickup_code_runner.dart:78-150` 的 `run()` ——
 * 1. `links` 按书写顺序逐条试；2. 全失败后逐个拉起 `appPackages`（已知没装的跳过）；
 * 3. 还不行才用 `webUri`；4. 全失败报最后一个原因码。
 *
 * 用假平台**记调用顺序**，这样「第二条永远没被试过」这类回归能被抓到
 * （只断言最终状态是抓不到的：不试第二条也可能碰巧落在同一状态）。
 */
class PickupCodeLaunchLogicTest {

    /** 记录调用顺序的假平台。 */
    private class FakePlatform(
        override val supported: Boolean = true,
        private val uriResults: Map<String, PickupCodeLaunchOutcome> = emptyMap(),
        private val appResults: Map<String, PickupCodeLaunchOutcome> = emptyMap(),
        private val installed: Set<String>? = null,
        private val defaultOutcome: PickupCodeLaunchOutcome = PickupCodeLaunchOutcome(false, "no_activity"),
        private val throwOnInstalled: Boolean = false,
    ) : PickupCodePlatform {
        val calls = mutableListOf<String>()

        override fun launchUri(
            uri: String,
            packageName: String?,
            clearTask: Boolean,
        ): PickupCodeLaunchOutcome {
            calls.add("uri:$uri")
            return uriResults[uri] ?: defaultOutcome
        }

        override fun launchApp(packageName: String, clearTask: Boolean): PickupCodeLaunchOutcome {
            calls.add("app:$packageName")
            return appResults[packageName] ?: defaultOutcome
        }

        override fun installedPackages(packages: List<String>): Set<String>? {
            if (throwOnInstalled) error("probe failed")
            return installed
        }
    }

    private val preset = PickupCodesModel.Preset(
        titleKey = "pickupCodePresetJdParcels",
        hintKey = "pickupCodePresetJdParcelsHint",
        icon = "parcel",
        group = PickupCodesModel.Group.PARCELS,
        links = listOf(
            PickupCodesModel.Link("demo://first", "com.demo.a"),
            PickupCodesModel.Link("demo://second", "com.demo.a"),
        ),
        appPackages = listOf("com.demo.a"),
        webUri = "https://demo.example/orders",
    )

    // ── 1. 直达链接 ──

    @Test
    fun `第一条直达就成功时不再尝试后面任何一级`() {
        val platform = FakePlatform(
            uriResults = mapOf("demo://first" to PickupCodeLaunchOutcome(true)),
        )
        val result = PickupCodeRunner(platform).run(preset)

        assertEquals(PickupCodeRunStatus.LAUNCHED, result.status)
        assertEquals(listOf("uri:demo://first"), platform.calls)
    }

    @Test
    fun `第一条失败才试第二条`() {
        val platform = FakePlatform(
            uriResults = mapOf("demo://second" to PickupCodeLaunchOutcome(true)),
        )
        val result = PickupCodeRunner(platform).run(preset)

        assertEquals(PickupCodeRunStatus.LAUNCHED, result.status)
        assertEquals(listOf("uri:demo://first", "uri:demo://second"), platform.calls)
    }

    @Test
    fun `空链接直接跳过不发出去`() {
        val platform = FakePlatform(
            uriResults = mapOf("demo://ok" to PickupCodeLaunchOutcome(true)),
        )
        val withBlank = preset.copy(
            links = listOf(
                PickupCodesModel.Link("   ", null),
                PickupCodesModel.Link("demo://ok", "com.demo.a"),
            ),
        )

        val result = PickupCodeRunner(platform).run(withBlank)

        assertEquals(PickupCodeRunStatus.LAUNCHED, result.status)
        assertEquals(listOf("uri:demo://ok"), platform.calls)
    }

    @Test
    fun `链接的包名限定与 clearTask 原样透传`() {
        val seen = mutableListOf<Triple<String, String?, Boolean>>()
        val platform = object : PickupCodePlatform {
            override val supported = true

            override fun launchUri(
                uri: String,
                packageName: String?,
                clearTask: Boolean,
            ): PickupCodeLaunchOutcome {
                seen.add(Triple(uri, packageName, clearTask))
                return PickupCodeLaunchOutcome(true)
            }

            override fun launchApp(packageName: String, clearTask: Boolean) =
                PickupCodeLaunchOutcome(true)

            override fun installedPackages(packages: List<String>) = null
        }

        PickupCodeRunner(platform).run(preset.copy(clearTask = true))

        assertEquals(Triple("demo://first", "com.demo.a", true), seen.single())
    }

    // ── 2. 拉起 App ──

    @Test
    fun `直达全失败后拉起官方 App`() {
        val platform = FakePlatform(
            appResults = mapOf("com.demo.a" to PickupCodeLaunchOutcome(true)),
        )
        val result = PickupCodeRunner(platform).run(preset)

        assertEquals(PickupCodeRunStatus.OPENED_APP, result.status)
        assertEquals(
            listOf("uri:demo://first", "uri:demo://second", "app:com.demo.a"),
            platform.calls,
        )
    }

    @Test
    fun `已知没装的 App 不试，直接落到网页兜底`() {
        val platform = FakePlatform(
            uriResults = mapOf("https://demo.example/orders" to PickupCodeLaunchOutcome(true)),
        )
        val result = PickupCodeRunner(platform).run(preset, alreadyInstalled = emptySet())

        assertEquals(PickupCodeRunStatus.OPENED_WEB, result.status)
        // 关键断言：`app:com.demo.a` 一次都没出现（白等一轮通道超时的来源）。
        assertFalse(platform.calls.contains("app:com.demo.a"))
    }

    // ── 3. 网页兜底与失败 ──

    @Test
    fun `App 级也失败时用网页兜底`() {
        val platform = FakePlatform(
            uriResults = mapOf("https://demo.example/orders" to PickupCodeLaunchOutcome(true)),
            installed = setOf("com.demo.a"),
        )
        val result = PickupCodeRunner(platform).run(preset, alreadyInstalled = setOf("com.demo.a"))

        assertEquals(PickupCodeRunStatus.OPENED_WEB, result.status)
        assertEquals(
            listOf(
                "uri:demo://first",
                "uri:demo://second",
                "app:com.demo.a",
                "uri:https://demo.example/orders",
            ),
            platform.calls,
        )
    }

    @Test
    fun `全部失败时保留最后一个原因码`() {
        val platform = FakePlatform(
            defaultOutcome = PickupCodeLaunchOutcome(false, "invalid_uri"),
        )
        val result = PickupCodeRunner(platform).run(preset)

        assertEquals(PickupCodeRunStatus.FAILED, result.status)
        assertEquals("invalid_uri", result.reason)
        assertFalse(result.ok)
    }

    // ── 4. 平台不支持 / 预算 ──

    @Test
    fun `平台不支持时一次都不调，返回 unsupported`() {
        val platform = FakePlatform(supported = false)
        val result = PickupCodeRunner(platform).run(preset)

        assertEquals(PickupCodeRunStatus.UNSUPPORTED, result.status)
        assertTrue(platform.calls.isEmpty())
    }

    @Test
    fun `预算用尽时收手并报 timeout`() {
        // 第一次读时钟返回 0（记起点），之后每次调用都跳 5 秒 > 4 秒预算。
        var now = 0L
        val platform = FakePlatform()
        val runner = PickupCodeRunner(
            platform = platform,
            budgetMillis = 4_000L,
            clock = {
                val current = now
                now += 5_000L
                current
            },
        )

        val result = runner.run(preset)

        assertEquals(PickupCodeRunStatus.FAILED, result.status)
        assertEquals(PickupCodesModel.REASON_TIMEOUT, result.reason)
        // 超预算发生在第一次尝试之前 ⇒ 一条都不该发出去。
        assertTrue(platform.calls.isEmpty())
    }

    @Test
    fun `结果带上本次耗时`() {
        // 每次读时钟前进 100ms：起点 1000 → 预算检查 1100 → 成功收尾 1200 ⇒ 200ms。
        var now = 1_000L
        val platform = FakePlatform(
            uriResults = mapOf("demo://first" to PickupCodeLaunchOutcome(true)),
        )
        val runner = PickupCodeRunner(
            platform = platform,
            clock = {
                val current = now
                now += 100L
                current
            },
        )

        val result = runner.run(preset)

        assertEquals(PickupCodeRunStatus.LAUNCHED, result.status)
        assertEquals(200L, result.elapsedMillis)
    }

    // ── 5. 批量查安装 ──

    @Test
    fun `没给包名或平台不支持时批量查返回 null`() {
        assertEquals(null, PickupCodeRunner(FakePlatform()).installedPackages(emptyList()))
        assertEquals(null, PickupCodeRunner(FakePlatform(supported = false)).installedPackages(listOf("a.b")))
    }

    @Test
    fun `批量查安装透传平台结果`() {
        val platform = FakePlatform(installed = setOf("com.demo.a"))
        assertEquals(
            setOf("com.demo.a"),
            PickupCodeRunner(platform).installedPackages(listOf("com.demo.a")),
        )
    }

    @Test
    fun `批量查安装抛异常时返回 null 而不是空集`() {
        // 空集会被当成「一个都没装」→ 七行全标未安装、跳过所有 App 兜底。
        val platform = FakePlatform(throwOnInstalled = true)
        assertNull(PickupCodeRunner(platform).installedPackages(listOf("com.demo.a")))
    }

    // ── 6. 结果 → 屏上那句话 ──

    @Test
    fun `直达成功与网页兜底都不弹提示`() {
        assertNull(
            PickupCodeFeedback.toastFor(
                preset,
                PickupCodeRunResult(PickupCodeRunStatus.LAUNCHED),
            ),
        )
        assertNull(
            PickupCodeFeedback.toastFor(
                preset,
                PickupCodeRunResult(PickupCodeRunStatus.OPENED_WEB),
            ),
        )
    }

    @Test
    fun `只拉起 App 时提示用户自己去 App 里找页面`() {
        val message = PickupCodeFeedback.toastFor(
            preset,
            PickupCodeRunResult(PickupCodeRunStatus.OPENED_APP),
        )
        assertEquals(PickupCodesModel.openedAppToast(PickupCodesModel.entryTitle(preset)), message)
    }

    @Test
    fun `彻底失败时标题带原因、并给第二行建议`() {
        val result = PickupCodeRunResult(PickupCodeRunStatus.FAILED, PickupCodesModel.REASON_NO_ACTIVITY)
        val message = PickupCodeFeedback.toastFor(preset, result)

        assertTrue(message!!.contains(PickupCodesModel.entryTitle(preset)))
        assertTrue(message.contains(PickupCodesModel.reasonText(PickupCodesModel.REASON_NO_ACTIVITY)))
        assertEquals(PickupCodesModel.launchFailedHint, PickupCodeFeedback.hintFor(result))
        assertNull(PickupCodeFeedback.hintFor(PickupCodeRunResult(PickupCodeRunStatus.LAUNCHED)))
    }

    @Test
    fun `没有原因码时兜底到未知原因而不是留空`() {
        val message = PickupCodeFeedback.toastFor(
            preset,
            PickupCodeRunResult(PickupCodeRunStatus.FAILED, null),
        )
        assertTrue(message!!.endsWith(PickupCodesModel.reasonText(PickupCodesModel.REASON_UNKNOWN_FALLBACK)))
    }
}
