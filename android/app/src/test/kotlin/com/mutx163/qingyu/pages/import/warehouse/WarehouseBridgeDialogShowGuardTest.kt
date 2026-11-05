package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * **弹层关闭守卫**（2026-11-05 审核阻断项）：读 `WarehouseBridgeDialogHost.kt` 的源码，
 * 钉住「四类网页对话框必须关得掉」这一件事。
 *
 * ## 防的是哪一类事故
 *
 * 旧实现四个弹层的 `show` 全部判 `shown`（`remember` 保留的**最后一份非空请求**），
 * 而 `shown` 没有任何复位路径；宿主回答/取消只把 `pendingDialog` 置 null，
 * `request` 变 null 后 `shown` 仍是旧请求 → `show` 恒 true →
 * confirm / prompt / 单选 / 配置表单**点确定、点取消、点空白全部无效**，
 * 用户只能退出页面（第一次跑导入脚本弹 confirm 就锁死）。
 *
 * 修法：`show` 一律判**当前挂起请求**（`request is WarehouseBridgeDialogRequest.XXX`），
 * 正文用 `request ?: shown` 保留退场渲染，`shown` 由 `LaunchedEffect` 延迟清空。
 *
 * ## 为什么守卫要读源码
 *
 * 本文件在 `composeP1` 源集，**不在 L0 的编译范围**，弹层「能不能收起」的接线事实
 * 只有真机能看，而源码结构是确定的；仓库已有同款先例（`WarehouseWebLoginPageWiringGuardTest`）。
 *
 * ⚠️ 守卫的牙齿来自「改坏必须红」：把任意一处 `show =` 改回判保留值
 * （如 `confirm != null`），这里立刻红（本次交付做过咬合探针）。
 *
 * 读源码的判据**先剥注释**：KDoc 里为了解释根因写了 `confirm != null`、
 * `prompt != null` 这些字样，不剥会把文档当成违规（Handoff 守卫踩过的坑）。
 */
class WarehouseBridgeDialogShowGuardTest {

    private val hostSource: String by lazy { readHostSource(stripComments = true) }
    private val hostSourceRaw: String by lazy { readHostSource(stripComments = false) }

    /** 四类弹层的 `show =` 必须逐个出现的判定（新弹层类型要同步进这份清单）。 */
    private val expectedShowPredicates = listOf(
        "WarehouseBridgeDialogRequest.Confirm",
        "WarehouseBridgeDialogRequest.Prompt",
        "WarehouseBridgeDialogRequest.SingleSelection",
        "WarehouseBridgeDialogRequest.SaveConfig",
    )

    @Test
    fun `四个弹层的 show 必须逐个判当前挂起请求`() {
        val shows = Regex("""show\s*=\s*([^,\n]+)""").findAll(hostSource).map { it.groupValues[1].trim() }.toList()
        assertEquals(
            "本文件应当恰好有 4 个弹层 show 标志（confirm / prompt / 单选 / 配置表单），" +
                "新增弹层类型时同步更新本守卫；实际：$shows",
            4,
            shows.size,
        )
        for (expected in expectedShowPredicates) {
            assertTrue(
                "弹层 show 必须判当前挂起请求（`show = request is $expected`），" +
                    "不许判 remember 保留值（shown）——那会让弹层在宿主置 null 后永远关不掉。" +
                    "实际 4 个 show：$shows",
                shows.any { it == "request is $expected" },
            )
        }
        // 旧写法（判保留值）一个都不许在：`confirm != null` / `prompt != null` /
        // `selection != null` / `form != null` 任何一处回来都等于复发。
        for (stale in listOf("confirm != null", "prompt != null", "selection != null", "form != null")) {
            assertFalse(
                "发现旧写法 `show = $stale`：show 判保留值（shown）会让弹层关不掉，必须判 `request is …`",
                shows.any { it == stale },
            )
        }
    }

    @Test
    fun `正文必须用 request 优先_shown 兜底`() {
        assertTrue(
            "弹层正文必须写 `val current = request ?: shown`：" +
                "request 挂起时用它，归 null 后退场动画期间仍渲染最后一份请求（不塌空板）",
            hostSource.contains("val current = request ?: shown"),
        )
        assertFalse(
            "不许退回旧写法 `val current = shown`（它把保留值同时当 show 与正文，等于永远关不掉）",
            hostSource.contains("val current = shown"),
        )
    }

    @Test
    fun `shown 必须由 LaunchedEffect 延迟清空`() {
        val effect = blockAfter(hostSourceRaw, "LaunchedEffect(request)")
        assertTrue(
            "必须有 `LaunchedEffect(request)` 在 request 归 null 后清空 shown（否则保留值永久残留，" +
                "下一个不同类型的弹层首帧会闪出旧内容）",
            effect.isNotEmpty(),
        )
        assertTrue(
            "清空 effect 里必须真的置 `shown = null`",
            effect.contains("shown = null"),
        )
        assertTrue(
            "清空必须延迟（退场动画期间还要用 shown 渲染），直接清会闪空板",
            effect.contains("delay("),
        )
    }

    // -----------------------------------------------------------------------
    // 工具（与 WarehouseWebLoginPageWiringGuardTest 同款）
    // -----------------------------------------------------------------------

    /** 从当前目录向上找仓库根，再定位宿主源码；可选剥掉行注释与块注释。 */
    private fun readHostSource(stripComments: Boolean): String {
        val relative =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseBridgeDialogHost.kt"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) {
                val text = candidate.readText(Charsets.UTF_8)
                return if (stripComments) stripKotlinComments(text) else text
            }
            dir = dir?.parentFile
        }
        error("找不到宿主源码 $relative（当前目录 ${File("").absolutePath}）")
    }

    /** 剥 `/*…*/` 块注释与 `//…` 行注释（字符串里的 `//` 会被误剥，本守卫判据不依赖这类串）。 */
    private fun stripKotlinComments(source: String): String =
        source
            .replace(Regex("/\\*.*?\\*/", RegexOption.DOT_MATCHES_ALL), "")
            .lineSequence()
            .map { line -> line.substringBefore("//") }
            .joinToString("\n")

    /** 取 `marker` 之后**第一对配平的 `{}`**（含两端）。 */
    private fun blockAfter(source: String, marker: String): String {
        val markerAt = source.indexOf(marker)
        if (markerAt < 0) return ""
        val begin = source.indexOf('{', markerAt)
        if (begin < 0) return ""
        var depth = 0
        var i = begin
        while (i < source.length) {
            when (source[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return source.substring(begin, i + 1)
                }
            }
            i++
        }
        return source.substring(begin)
    }
}
