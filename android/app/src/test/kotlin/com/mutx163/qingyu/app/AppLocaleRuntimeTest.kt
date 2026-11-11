package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.pages.export.ExportStrings
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 语言运行时：标签归一、按语言取文案、切换后 `filled` 也跟着换语言。
 *
 * 这是「语言开关不再是无效果控件」的最小证据链——同一个 [ArbText] 在三种语言下
 * 必须给出三份不同的、与 ARB 一致的文案。
 */
class AppLocaleRuntimeTest {

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
        assertEquals("导出日历", ExportStrings.icsExportTitle.text)
        assertEquals("导出日历", ExportStrings.icsExportTitle.zh)
    }

    @Test
    fun `同一条文案在三种语言下取到 ARB 对应值`() {
        val key = ExportStrings.icsExportTitle.key
        AppLocaleRuntime.set("en")
        assertEquals(en.getValue(key), ExportStrings.icsExportTitle.text)
        AppLocaleRuntime.set("ja")
        assertEquals(ja.getValue(key), ExportStrings.icsExportTitle.text)
        AppLocaleRuntime.set("ko")
        assertEquals(ko.getValue(key), ExportStrings.icsExportTitle.text)
        AppLocaleRuntime.set("zh")
        assertEquals(zh.getValue(key), ExportStrings.icsExportTitle.text)
    }

    @Test
    fun `占位符按当前语言替换`() {
        val key = ExportStrings.icsExportShared.key
        AppLocaleRuntime.set("en")
        assertTrue(en.getValue(key).contains("{count}"))
        assertEquals(
            en.getValue(key).replace("{count}", "12"),
            ExportStrings.icsExportShared.filled("count", "12"),
        )
        AppLocaleRuntime.set("ja")
        assertEquals(
            ja.getValue(key).replace("{count}", "12"),
            ExportStrings.icsExportShared.filled("count", "12"),
        )
    }

    @Test
    fun `界面文案里不残留未替换的占位符`() {
        AppLocaleRuntime.set("en")
        val withBraces = ExportStrings.allTexts.filter { it.text.contains('{') }
        // 模板键本来就带占位符，未 `filled` 时保留 `{count}` 是预期；这里只保证
        // 没有 `{count, plural,` 这类 ICU 控制语法漏到屏上。
        assertFalse(
            "ICU 语法漏到界面：${withBraces.filter { it.text.contains(", plural,") }}",
            withBraces.any { it.text.contains(", plural,") },
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
        ExportStrings.icsExportTitle.text
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
