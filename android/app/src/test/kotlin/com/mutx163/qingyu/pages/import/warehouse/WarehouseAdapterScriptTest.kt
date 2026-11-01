package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Base64

/**
 * F28：登录之后「拉适配脚本 → 校验 → 包垫片 → 注入」这一段的 JVM 单测。
 *
 * 覆盖：
 * - 脚本路径拼接（缺字段不许拼出必然 404 的地址）；
 * - SHA-256 校验（空声明放行、错哈希拦住、坏格式按不匹配）；
 * - 执行判定（没脚本 / 网页没加载完 / 可以执行）；
 * - 注入垫片（脚本原文必须原样嵌进去、v2 别名在、确认文案被转义）；
 * - 拉取层（候选链、校验失败不换候选、空脚本文案、缺路径不发请求）。
 */
class WarehouseAdapterScriptTest {

    private val school = WarehouseSchoolEntry(
        id = "pku",
        name = "北京大学",
        initial = "B",
        resourceFolder = "pku",
    )

    private val adapter = WarehouseAdapterEntry(
        id = "zhengfang-v2",
        name = "正方新版",
        script = "zhengfang.js",
        importUrl = "https://jw.example.edu.cn/login",
    )

    /** `sha256("abc")` 的标准值。 */
    private val abcSha256 = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

    private class FakeFetch(
        private val respond: (String) -> WarehouseHttpResponse?,
    ) : WarehouseFetch {
        val calls = mutableListOf<String>()
        override fun get(url: String): WarehouseHttpResponse? {
            calls.add(url)
            return respond(url)
        }
    }

    private fun ok(body: String) = WarehouseHttpResponse(statusCode = 200, body = body)

    // ── 路径 ───────────────────────────────────────────────────────────

    @Test
    fun `脚本路径按 resources 学校目录拼`() {
        assertEquals("resources/pku/zhengfang.js", warehouseAdapterScriptPath(school, adapter))
    }

    @Test
    fun `脚本路径剥掉前导斜杠 缺任何一段都回空串`() {
        assertEquals(
            "resources/pku/a/b.js",
            warehouseAdapterScriptPath(school, adapter.copy(script = "/a/b.js")),
        )
        assertEquals("", warehouseAdapterScriptPath(school, adapter.copy(script = "  ")))
        assertEquals("", warehouseAdapterScriptPath(school.copy(resourceFolder = ""), adapter))
        assertEquals("", warehouseAdapterScriptPath(null, adapter))
        assertEquals("", warehouseAdapterScriptPath(school, null))
    }

    // ── 校验 ───────────────────────────────────────────────────────────

    @Test
    fun `没有声明 sha256 时跳过校验`() {
        assertTrue(verifyWarehouseScriptSha256("abc".toByteArray(), ""))
        assertTrue(verifyWarehouseScriptSha256("abc".toByteArray(), null))
    }

    @Test
    fun `声明的 sha256 匹配才放行 大小写不敏感`() {
        assertTrue(verifyWarehouseScriptSha256("abc".toByteArray(), abcSha256))
        assertTrue(verifyWarehouseScriptSha256("abc".toByteArray(), abcSha256.uppercase()))
        assertFalse(verifyWarehouseScriptSha256("abd".toByteArray(), abcSha256))
    }

    @Test
    fun `声明格式坏了按不匹配处理 不许 fail-open`() {
        assertFalse(verifyWarehouseScriptSha256("abc".toByteArray(), "abc"))
        assertFalse(verifyWarehouseScriptSha256("abc".toByteArray(), "z".repeat(64)))
    }

    // ── 执行判定 ───────────────────────────────────────────────────────

    @Test
    fun `页面加载完成后才允许执行`() {
        val plan = planWarehouseScriptExecution(WarehouseWebLoginStage.LOADED, school, adapter)
        assertTrue(plan is WarehouseScriptExecutionPlan.Ready)
        assertEquals("resources/pku/zhengfang.js", (plan as WarehouseScriptExecutionPlan.Ready).scriptPath)
    }

    @Test
    fun `加载中 报错 空闲 执行中都不允许执行`() {
        listOf(
            WarehouseWebLoginStage.IDLE,
            WarehouseWebLoginStage.LOADING,
            WarehouseWebLoginStage.INJECTING_SCRIPT,
            WarehouseWebLoginStage.EXECUTING,
            WarehouseWebLoginStage.SUCCESS,
            WarehouseWebLoginStage.ERROR,
        ).forEach { stage ->
            val plan = planWarehouseScriptExecution(stage, school, adapter)
            assertEquals(
                "阶段 $stage 不该放行执行",
                WarehouseScriptBlockReason.PAGE_NOT_LOADED,
                (plan as WarehouseScriptExecutionPlan.Blocked).reason,
            )
        }
    }

    @Test
    fun `没有脚本路径时优先报缺脚本`() {
        val plan = planWarehouseScriptExecution(
            WarehouseWebLoginStage.IDLE,
            school,
            adapter.copy(script = ""),
        )
        assertEquals(
            WarehouseScriptBlockReason.NO_SCRIPT_PATH,
            (plan as WarehouseScriptExecutionPlan.Blocked).reason,
        )
    }

    // ── 注入垫片 ───────────────────────────────────────────────────────

    @Test
    fun `垫片原样嵌入脚本 并暴露 v1 与 v2 两套桥`() {
        val script = "console.log('from adapter');"
        val wrapped = warehouseImportScriptWrapper(script, "确认导入")

        assertTrue(wrapped.contains(script))
        assertTrue(wrapped.contains("window.AndroidBridge = {"))
        assertTrue(wrapped.contains("window.AndroidBridgePromise = {"))
        assertTrue(wrapped.contains("window.shiguangBridge = window.AndroidBridge;"))
        assertTrue(wrapped.contains("window.shiguangBridgePromise = window.AndroidBridgePromise;"))
        assertTrue(wrapped.contains("saveImportedCourses"))
        assertTrue(wrapped.contains("type: 'courses'"))
        assertTrue(wrapped.contains("confirmText ?? '确认导入'"))
    }

    @Test
    fun `确认按钮文案里的引号被转义 不破坏脚本`() {
        val wrapped = warehouseImportScriptWrapper("x", "it's \"ok\"")
        assertTrue(wrapped.contains("""confirmText ?? 'it\'s "ok"'"""))
    }

    // ── 原生回答 ───────────────────────────────────────────────────────

    @Test
    fun `合法 requestId 生成 resolve 调用`() {
        val js = warehouseBridgeResolveScript("confirm_1_abc", "true")
        assertEquals(
            "(window.__qingyuResolvers && window.__qingyuResolvers['confirm_1_abc']) ? " +
                "window.__qingyuResolvers['confirm_1_abc'](true) : undefined;",
            js,
        )
    }

    @Test
    fun `不可信 requestId 一律拒绝 防止脚本注入`() {
        listOf(
            "",
            "a'b",
            "a');alert(1);//",
            "a b",
            "😀",
            "x".repeat(129),
        ).forEach { id ->
            assertEquals("id=$id 应被拒绝", "", warehouseBridgeResolveScript(id, "true"))
        }
    }

    // ── 拉取层 ─────────────────────────────────────────────────────────

    @Test
    fun `成功拉到脚本 走 resources 路径`() {
        val expectedUrl = WarehouseRepositoryUrls.rawGitHubUrl(
            WarehouseRepositorySource.DEFAULT,
            "resources/pku/zhengfang.js",
        )
        val fetch = FakeFetch { url -> if (url == expectedUrl) ok("console.log(1)") else null }
        val service = WarehouseRepositoryService(fetch, mirrorUrlPrefix = null)

        val loaded = service.loadAdapterScript(school, adapter)

        assertTrue(loaded is WarehouseLoad.Ok)
        assertEquals("console.log(1)", (loaded as WarehouseLoad.Ok).value)
        assertEquals(listOf(expectedUrl), fetch.calls)
    }

    @Test
    fun `校验失败不换候选 直接报仓库声明的错误码`() {
        val wrongHash = "0".repeat(64)
        val fetch = FakeFetch { ok("console.log(1)") }
        val service = WarehouseRepositoryService(fetch, mirrorUrlPrefix = null)

        val loaded = service.loadAdapterScript(school, adapter.copy(sha256 = wrongHash))

        assertTrue(loaded is WarehouseLoad.Failed)
        val failure = loaded as WarehouseLoad.Failed
        assertEquals(WarehouseFeedCodes.SCRIPT_CHECKSUM_FAILED, failure.code)
        assertEquals(1, failure.attempts)
        assertEquals("校验失败后不该再试别的候选", 1, fetch.calls.size)
    }

    @Test
    fun `声明的 sha256 匹配时正常返回脚本`() {
        val fetch = FakeFetch { ok("abc") }
        val service = WarehouseRepositoryService(fetch, mirrorUrlPrefix = null)

        val loaded = service.loadAdapterScript(school, adapter.copy(sha256 = abcSha256))

        assertEquals("abc", (loaded as WarehouseLoad.Ok).value)
    }

    @Test
    fun `空脚本在数据层就被拦住`() {
        val fetch = FakeFetch { ok("   \n  ") }
        val service = WarehouseRepositoryService(fetch, mirrorUrlPrefix = null)

        val loaded = service.loadAdapterScript(school, adapter)

        assertEquals(WarehouseFeedCodes.SCRIPT_EMPTY, (loaded as WarehouseLoad.Failed).code)
    }

    @Test
    fun `拼不出脚本路径时不发任何请求`() {
        val fetch = FakeFetch { ok("x") }
        val service = WarehouseRepositoryService(fetch, mirrorUrlPrefix = null)

        val loaded = service.loadAdapterScript(school, adapter.copy(script = ""))

        assertTrue(loaded is WarehouseLoad.Failed)
        val failure = loaded as WarehouseLoad.Failed
        assertEquals(WarehouseFeedCodes.SCRIPT_PATH_MISSING, failure.code)
        assertEquals(0, failure.attempts)
        assertTrue(fetch.calls.isEmpty())
    }

    @Test
    fun `GitCode 主地址的 base64 信封能解出脚本`() {
        val source = WarehouseRepositorySource.DEFAULT.withHost(WarehouseRepositoryHost.GITCODE)
        val encoded = Base64.getEncoder().encodeToString("console.log('gitcode')".toByteArray())
        val envelope = """{"content":"$encoded","encoding":"base64"}"""
        val fetch = FakeFetch { ok(envelope) }
        val service = WarehouseRepositoryService(fetch, source = source, mirrorUrlPrefix = null)

        val loaded = service.loadAdapterScript(school, adapter)

        assertEquals("console.log('gitcode')", (loaded as WarehouseLoad.Ok).value)
    }
}
