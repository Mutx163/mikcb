package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readSourceNormalized
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **页面接线守卫**（task-21）：读 `WarehouseWebLoginPage.kt` 的源码，钉住三件事。
 *
 * ## 为什么守卫要读源码
 *
 * 这一页的接线在 `composeP1` 源集，**不在 L0 的编译范围**（L0 只编 `main/` + 共享目录），
 * 所以「宿主回调有没有过门禁」「占位块有没有真的被换掉」这类**接线事实**
 * 没有别的机器可判的办法：Compose 的渲染行为只有真机能看，而源码结构是确定的。
 *
 * 仓库已有同款先例：`test/architecture/` 的守卫就是读源码判结构的。
 *
 * ⚠️ 守卫的牙齿来自「改坏必须红」：把页面里那次 `shouldDeliverBridgeMessage(...)` 调用
 * 删掉、或把占位块放回去，这里立刻红（2026-10-28 实测做过一次反向验证）。
 *
 * ## 两档读法（2026-11-14）
 *
 * 原来整份文件只有 `readText()` 一个原文视图：把 `onProgress = onWebProgress` 那行
 * **注释掉**，文本还留在注释里，`contains` 照样为真——实测 `pages/import/warehouse`
 * 583 例全绿。现在按判据性质分开：
 *
 * - **接线判据**（门禁调用、进度/错误回写、刷新与桌面切换、绕过写法）走 [pageCode]
 *   = 中性化档：剥注释 + 抹掉字符串内容，注释掉的接线不再算接线；
 * - **「某段被删掉的原文不许回来」**走 [rawPage] = 原文（第三档）：这类判据要的正是
 *   那句文案/注释本身，剥掉就恒真。用原文的否定式断言**必须先判原文非空**。
 */
class WarehouseWebLoginPageWiringGuardTest {

    /** 接线视图：剥注释 + 字符串内容中性化。 */
    private val pageCode: String by lazy { readKotlinSourceNoStrings(PAGE_SOURCE) }

    /** 原文视图：只归一行尾，不剥任何东西（判「被删掉的原文不许回来」）。 */
    private val rawPage: String by lazy {
        val raw = readSourceNormalized(PAGE_SOURCE)
        // 否定式断言在空串上恒真：原文读不到就先红在这里。
        assertTrue("页面原文没读到内容（路径写错？）", raw.isNotBlank())
        raw
    }

    @Test
    fun `桥接消息必须过 6_2 门禁才交给调用方`() {
        val block = blockAfter(pageCode, "onBridgeMessage = {")
        assertTrue(
            "页面必须给宿主接 onBridgeMessage（否则适配脚本回不了话）",
            block.isNotEmpty(),
        )
        assertTrue(
            "桥接消息必须先过 §6.2 门禁：onBridgeMessage 里必须出现 shouldDeliverBridgeMessage(...)。\n" +
                "它是安全修复（Dart 修过的钓鱼洞），不是可选优化。实际拿到：\n$block",
            block.contains("shouldDeliverBridgeMessage("),
        )
        assertTrue(
            "门禁判定要带上当前阶段（importExecutionActive = 阶段 == EXECUTING）",
            block.contains("sessionState.stage"),
        )

        // 门禁必须是**那一个 if 的条件**，且不许被常量短路：
        // 否则 `if (true && shouldDeliverBridgeMessage(...))` 这种写法能骗过上面两条断言，
        // 而门禁实际上等于没开（2026-10-28 写守卫时想到的绕过形状）。
        val condition = Regex("""if\s*\(([^)]*)\)""").find(block)?.groupValues?.get(1)
        assertTrue("onBridgeMessage 里必须有 if 判定，实际：\n$block", condition != null)
        assertTrue(
            "门禁判定必须出现在 if 条件里，实际条件：`$condition`",
            condition!!.contains("shouldDeliverBridgeMessage("),
        )
        assertFalse(
            "门禁条件不许被常量短路（`$condition`）：那等于门禁没开",
            Regex("""\b(true|false)\b""").containsMatchIn(condition),
        )
        assertFalse(
            "门禁条件不许用 || 短路（`$condition`）：那等于门禁没开",
            condition.contains("||"),
        )
    }

    @Test
    fun `不许出现绕过门禁的直通写法`() {
        // 这些写法都会把任意网页的 postMessage 原样交给调用方 —— 正是门禁要挡的事
        val bypasses = listOf(
            "onBridgeMessage = onWebBridgeMessage",
            "onBridgeMessage = { raw -> onWebBridgeMessage?.invoke(raw) }",
            "onBridgeMessage = { onWebBridgeMessage?.invoke(it) }",
        )
        for (bypass in bypasses) {
            assertFalse(
                "发现绕过门禁的直通写法：`$bypass`",
                pageCode.contains(bypass),
            )
        }
    }

    @Test
    fun `占位块必须已被真宿主替换且不许回来`() {
        assertTrue(
            "页面必须渲染真 WebView 宿主 WarehouseWebViewHost(...)",
            pageCode.contains("WarehouseWebViewHost("),
        )
        // 下面两条判的是「被删掉的那段原文」本身（注释标题 / 硬编码文案），必须读原文：
        // 剥了注释或字符串，这两句就再也命中不了，断言恒真。
        assertFalse(
            "「WebView 视口占位与引导」那段占位代码不许回来（它意味着这一页又不加载网页了）",
            rawPage.contains("WebView 视口占位与引导"),
        )
        // 占位块里的引导文案是硬编码中文，随占位块一起消失
        assertFalse(
            "占位块的引导文案不该再出现在页面里",
            rawPage.contains("请在上方登录教务系统"),
        )
    }

    @Test
    fun `进度与错误必须回写给调用方`() {
        assertTrue(
            "加载进度要回写（调用方据此更新 sessionState.stage）",
            pageCode.contains("onProgress = onWebProgress"),
        )
        assertTrue(
            "主框架错误要回写",
            pageCode.contains("onError = onWebError"),
        )
    }

    @Test
    fun `刷新与桌面切换必须作用在真视图上`() {
        assertTrue(
            "顶栏刷新必须调 controller.reload()（原来只调外部回调，页面根本没在动）",
            pageCode.contains("webViewController.reload()"),
        )
        assertTrue(
            "桌面/移动切换必须调 controller.toggleDesktopMode()",
            pageCode.contains("webViewController.toggleDesktopMode()"),
        )
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private companion object {
        /** 仓库根相对路径：`readSourceNormalized` 会自己向上找仓库根，不依赖 cwd。 */
        const val PAGE_SOURCE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginPage.kt"
    }

    /**
     * 取 `marker` 之后**第一对配平的 `{}`**（含两端）。
     *
     * 用配平而不是「往后截 N 个字符」：截长度会因为格式化差异假红/假绿，
     * 而这一页的 lambda 里还有嵌套的花括号。
     */
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
