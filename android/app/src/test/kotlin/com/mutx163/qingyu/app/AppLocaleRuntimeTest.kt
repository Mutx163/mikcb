package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.MiniJson
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 语言运行时：标签归一、按语言取文案、切换后 `filled` 也跟着换语言。
 *
 * 这是「语言开关不再是无效果控件」的最小证据链——同一个 [ArbText] 在三种语言下
 * 必须给出三份不同的、与 ARB 一致的文案。
 *
 * ## 为什么在测试里内联文案例子，而不是借 `pages/export/ExportStrings`
 *
 * 本测试只验证「运行时按语言查表」，用例里需要的只是一条**带 key 的 ArbText**。
 * 旧版借了 `pages.export.ExportStrings`（12 处，含 `allTexts`），等于让 app 层测试
 * 反向依赖 pages 层的文案对象——页面一改文案，这条运行时测试跟着红。
 *
 * 为什么不用 `app/CommonUiStrings` 替代：它目前只有一条 `back: String`（不是 `ArbText`，
 * 也没有 `{count}` 占位符形态），用它测不到「占位符按语言替换」这条核心行为。
 * **为省一行 import 去给生产文案对象加形状，是把测试的方便变成生产层的耦合**，
 * 所以这里退一步内联两条 `ArbText`，并保持断言从真实 ARB（`i18n/` 下的 `app_*.arb`，本文件自己加载）
 * 取期望值——"它当初守住的东西"（运行时查表 / 占位符替换 / 缺键回落）一条没少。
 */
class AppLocaleRuntimeTest {

    /** 借一条普通文案验证运行时查表（key 与 ARB 逐字一致，期望值从 ARB 读，不是这里写死）。 */
    private val sampleTitle = ArbText("icsExportTitle", "导出日历")

    /** 借一条带 `{count}` 的模板验证占位符替换。 */
    private val sampleShared = ArbText("icsExportShared", "已导出并分享 {count} 个日历事件")

    private val en: Map<String, String> by lazy { loadArb("app_en.arb") }
    private val ja: Map<String, String> by lazy { loadArb("app_ja.arb") }
    private val ko: Map<String, String> by lazy { loadArb("app_ko.arb") }
    private val zh: Map<String, String> by lazy { loadArb("app_zh.arb") }

    @After
    fun tearDown() {
        AppLocaleRuntime.onLocaleChanged = null
        AppLocaleRuntime.revisionReader = { 0 }
        AppLocaleRuntime.resetForTest()
    }

    @Test
    fun `标签归一与设置页同口径`() {
        assertEquals("en", AppLocaleRuntime.normalize("en_US_POSIX"))
        assertEquals("en", AppLocaleRuntime.normalize(" en-US "))
        assertEquals("zh_HK", AppLocaleRuntime.normalize("zh-Hant-HK"))
        assertEquals("zh_TW", AppLocaleRuntime.normalize("zh-Hant-TW"))
        assertEquals("zh", AppLocaleRuntime.normalize("zh-CN"))
        assertEquals("ja", AppLocaleRuntime.normalize("ja_JP"))
        assertEquals("", AppLocaleRuntime.normalize("system"))
        assertEquals("", AppLocaleRuntime.normalize(null))
    }

    @Test
    fun `未初始化时保持中文原文，单测与老断言不被打乱`() {
        AppLocaleRuntime.resetForTest()
        assertEquals("导出日历", sampleTitle.text)
        assertEquals("导出日历", sampleTitle.zh)
    }

    @Test
    fun `同一条文案在三种语言下取到 ARB 对应值`() {
        val key = sampleTitle.key
        AppLocaleRuntime.set("en")
        assertEquals(en.getValue(key), sampleTitle.text)
        AppLocaleRuntime.set("ja")
        assertEquals(ja.getValue(key), sampleTitle.text)
        AppLocaleRuntime.set("ko")
        assertEquals(ko.getValue(key), sampleTitle.text)
        AppLocaleRuntime.set("zh")
        assertEquals(zh.getValue(key), sampleTitle.text)
    }

    @Test
    fun `占位符按当前语言替换`() {
        val key = sampleShared.key
        AppLocaleRuntime.set("en")
        assertTrue(en.getValue(key).contains("{count}"))
        assertEquals(
            en.getValue(key).replace("{count}", "12"),
            sampleShared.filled("count", "12"),
        )
        AppLocaleRuntime.set("ja")
        assertEquals(
            ja.getValue(key).replace("{count}", "12"),
            sampleShared.filled("count", "12"),
        )
    }

    @Test
    fun `界面文案里不残留运行时替换不了的 ICU 控制语法`() {
        AppLocaleRuntime.set("en")
        // 运行时只做 `{name}` 单占位替换；`{count, plural, …}` 这种 ICU 控制语法它替换不了。
        // 全仓目前**只有一条**：`lanEditConnectedClientsValue`，由 LanEditModel 手工展开
        // （见 ArbText.kt 类注释）。这里把它钉成白名单——**新增第二条就红**，逼作者显式
        // 决定怎么处理，而不是让 ICU 语法直接上屏。
        //
        // 旧版是用 `ExportStrings.allTexts` 扫导出页文案；改成扫 ARB 全量后覆盖面更大，
        // 所以必然命中这条已知例外——这是"看见它并登记"，不是放水。
        val knownIcuKeys = setOf("lanEditConnectedClientsValue")
        val unexpected = en
            .filterKeys { it !in knownIcuKeys }
            .filterValues { it.contains(", plural,") || it.contains(", select,") }
        assertTrue(
            "ARB 里出现了运行时替换不了、又没登记的 ICU 控制语法：$unexpected",
            unexpected.isEmpty(),
        )
    }

    @Test
    fun `未初始化时语言为 null，设置后返回实际语言`() {
        AppLocaleRuntime.resetForTest()
        assertEquals(null, AppLocaleRuntime.language)
        AppLocaleRuntime.set("en")
        assertEquals("en", AppLocaleRuntime.language)
        AppLocaleRuntime.set("")
        assertTrue(AppLocaleRuntime.language in AppLocaleRuntime.SUPPORTED_TAGS)
    }

    @Test
    fun `语言真正变化才通知 UI 一次`() {
        AppLocaleRuntime.resetForTest()
        var bumps = 0
        AppLocaleRuntime.onLocaleChanged = { bumps++ }
        AppLocaleRuntime.set("en")
        assertEquals(1, bumps)
        AppLocaleRuntime.set("en")
        assertEquals(1, bumps)
        AppLocaleRuntime.set("ja")
        assertEquals(2, bumps)
    }

    /**
     * 2026-11-10 用户报障：切到英语后选「跟随系统」仍显示外语。
     *
     * 根因是「跟随系统」去读 `Locale.getDefault()`，而切英语时 App 刚把它改成 en——
     * 自指。修法是真源改为壳注入的系统语言。这条用例把它钉住：
     * 注入中文系统语言后，无论之前手选过什么，切回跟随系统都必须回中文，
     * 且默认 Locale 也要恢复（日期格式化随之正确）。
     */
    @Test
    fun `切过英语再选跟随系统要回真实系统语言`() {
        val original = java.util.Locale.getDefault()
        try {
            AppLocaleRuntime.resetForTest()
            AppLocaleRuntime.setSystemLocaleTag("zh-Hans-CN")
            AppLocaleRuntime.set("en")
            assertEquals("en", AppLocaleRuntime.language)

            AppLocaleRuntime.set("")
            assertEquals("跟随系统必须回到注入的系统语言，而不是上一次手选的 en", "zh", AppLocaleRuntime.language)
            assertEquals(
                "默认 Locale 也要恢复成系统语言（否则日期格式仍停在英语）",
                "zh",
                java.util.Locale.getDefault().language,
            )
        } finally {
            AppLocaleRuntime.resetForTest()
            java.util.Locale.setDefault(original)
        }
    }

    @Test
    fun `跟随系统期间系统语言变化要立刻跟上`() {
        val original = java.util.Locale.getDefault()
        try {
            AppLocaleRuntime.resetForTest()
            AppLocaleRuntime.setSystemLocaleTag("zh-Hans-CN")
            AppLocaleRuntime.set("")
            assertEquals("zh", AppLocaleRuntime.language)

            var bumps = 0
            AppLocaleRuntime.onLocaleChanged = { bumps++ }
            // 用户在系统设置里改成了日语，App 没重启：壳在 onConfigurationChanged 里刷进来。
            AppLocaleRuntime.setSystemLocaleTag("ja-JP")
            assertEquals("ja", AppLocaleRuntime.language)
            assertEquals("系统语言变化要通知 UI 重组", 1, bumps)
            assertEquals("ja", java.util.Locale.getDefault().language)
        } finally {
            AppLocaleRuntime.resetForTest()
            java.util.Locale.setDefault(original)
        }
    }

    @Test
    fun `刷新系统语言不能影响手选语言`() {
        // L-03：这条也改了 `Locale.setDefault`，必须原样保存/恢复，
        // 否则后面的用例会读到上一条留下的 ko，断言全变成「看似通过」。
        val original = java.util.Locale.getDefault()
        try {
            AppLocaleRuntime.resetForTest()
            AppLocaleRuntime.setSystemLocaleTag("zh-Hans-CN")
            AppLocaleRuntime.set("ko")
            AppLocaleRuntime.setSystemLocaleTag("ja-JP")
            assertEquals("手选了韩语就不该被系统语言变化带走", "ko", AppLocaleRuntime.language)
        } finally {
            AppLocaleRuntime.resetForTest()
            java.util.Locale.setDefault(original)
        }
    }

    @Test
    fun `取文案会读 UI 订阅点`() {
        var reads = 0
        AppLocaleRuntime.revisionReader = { reads++; 0 }
        sampleTitle.text
        assertTrue("text 没有读 revisionReader，Composable 不会重组：reads=$reads", reads > 0)
    }

    private fun loadArb(name: String): Map<String, String> {
        val file = File(repoRoot(), "i18n/$name")
        val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
        check(parsed is Map<*, *>) { "$name 顶层不是对象" }
        val map = LinkedHashMap<String, String>()
        parsed.forEach { (k, v) -> if (k is String && !k.startsWith("@") && v is String) map[k] = v }
        return map
    }

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "i18n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（i18n/app_zh.arb），工作目录 ${File("").absolutePath}")
    }
}
