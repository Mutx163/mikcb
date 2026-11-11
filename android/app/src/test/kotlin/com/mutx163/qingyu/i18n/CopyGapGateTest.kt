package com.mutx163.qingyu.i18n

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 文案缺口棘轮（规则 v1 / 白名单 v1）：挡住「该语种没翻译」与「非中文语种混入中文」。
 *
 * 与 `scripts/i18n-copy-gap.py` **逐字一致**（改一边必须改另一边，否则基线会漂）。
 *
 * ## 两条规则
 *
 * - **A 未翻译**：`ja` / `ko` 的值与 `en` 逐字相同、不含假名（ja）或谚文（ko）、
 *   且剥掉占位符 / 品牌名 / 技术标识后仍有 ≥ [MIN_WORDS] 个英文词。
 *   短标签（`MiSans`、`WebDAV URL`、`{start} – {end}`）不算。
 * - **B 中文污染**：`en` 或 `ko` 的值里出现汉字（U+4E00..U+9FFF）。
 * - **ja 不走 B**：日语本来就用汉字（当前 2061 条含汉字），按「含汉字」判会全线误报。
 *   「ja 等于中文且无假名」的漏译（约 39 条）**故意不做**：大半是 `保存` / `更新` 这类
 *   日文同形词，收益低、误报高。
 *
 * ## 为什么是棘轮
 *
 * 存量缺口 1240 条（A|ja 597 / A|ko 599 / B|en 7 / B|ko 37）。门禁不要求今天修完，
 * 只要求**不许新增**；修好一条必须同步下调基线（只许降不许升），与 `CjkLiteralGateTest`
 * 同一套路。
 *
 * ## 已知限制
 *
 * L0 的跨域守卫到不了这里，本门禁只在 L2/CI 生效——与 CJK 棘轮同一处境。
 *
 * ## ⚠️ 从未在 L2 跑过（首次跑的人请看这里）
 *
 * 本测试是照着 `scripts/i18n-copy-gap.py` 逐行镜像写出来的，**Python 侧跑过（探针 6/6 +
 * 注入→红→还原→绿），Kotlin 侧一次都没执行过**。别把绿当成「已验证」。
 *
 * 首次跑 L2 时重点盯这三处，它们正是「Python 绿、Kotlin 红」的典型位置：
 *
 * 1. `Regex.escape(...)` 拼品牌名交替式：Python 用 `re.escape`，两者的转义字符集不完全一致，
 *    若某个品牌名被转义成 Kotlin 不认的形态，白名单会失效 → 缺口暴涨。
 * 2. `MiniJson.parse` 解析 ARB：返回 `Any?`，靠 `Map<*, *>` 强转；ARB 里一旦出现新的值类型
 *    （数字数组、null、嵌套对象），这里会先炸——那说明 ARB 结构变了，是信号不是噪音。
 * 3. `sortedSetOf` 的排序：基线是逐行字符串集合。排序口径（大小写/`|`/Unicode）只要有一点差异，
 *    表现不是「差几条」而是整片红，别误判成判据写错。
 *
 * 三处都验过之后，把这段改成「已在 L2 验证（时间 + 命令 + 结果）」。
 */
class CopyGapGateTest {

    // ---------------------------------------------------------------- 判据常量

    companion object {
        /** 与脚本 RULES_VERSION 一致。判据改了要 +1 并重写基线。 */
        private const val RULES_VERSION = 1

        /** 与脚本 WHITELIST_VERSION 一致。改 BRANDS / TECH / MIN_WORDS 就要 +1。 */
        private const val WHITELIST_VERSION = 1

        /** 剥掉占位符/品牌/技术标识后，少于这么多个英文词就当成短标签，不判未翻译。 */
        private const val MIN_WORDS = 2

        private val LANGS = listOf("zh", "zh_HK", "zh_TW", "en", "ja", "ko")

        /** 基线文件（相对仓库根）。 */
        private const val BASELINE_RELATIVE =
            "android/app/src/test/kotlin/com/mutx163/qingyu/i18n/copy-gap-baseline.txt"

        private val BRANDS = listOf(
            "MiSans", "HarmonyOS", "OPPO", "PingFang", "Noto", "Bing", "GitHub", "Gitee",
            "WeChat", "Alipay", "Coolapk", "Bilibili", "Xiaohongshu", "WebDAV", "Jianguoyun",
            "HyperOS", "MIUI", "Android", "iOS", "Windows", "macOS", "Linux", "Flutter",
            "Dart", "Kotlin", "Compose", "Miuix", "ClassIn", "Zoom", "Teams", "DingTalk", "QQ",
        )

        private val TECH = Regex(
            "\\.(ics|csv|xlsx|json|pdf|zip|apk|mikcb|png|jpg)|https?://|" +
                "\\b(URL|API|SDK|HTTP|HTTPS|DNS|ID|UID|IP|PSS|MB|GB|KB|ms|OK|CSV|ICS|XLSX|JSON|PDF|ZIP|APK)\\b",
        )

        private val WORD = Regex("[A-Za-z][A-Za-z'\\-]{1,}")
        private val KANA = Regex("[\\u3040-\\u30ff]")
        private val HANGUL = Regex("[\\uac00-\\ud7af]")
        private val CJK = Regex("[\\u4e00-\\u9fff]")
        private val PLACEHOLDER = Regex("\\{[^}]*}")
        private val BRANDS_RE = Regex(BRANDS.joinToString("|") { Regex.escape(it) })
    }

    // ---------------------------------------------------------------- 判据实现

    /** 剥掉占位符 / 品牌 / 技术标识后剩下的英文词数。 */
    private fun wordCount(value: String): Int {
        var rest = PLACEHOLDER.replace(value, "")
        rest = BRANDS_RE.replace(rest, "")
        rest = TECH.replace(rest, "")
        return WORD.findAll(rest).count()
    }

    private fun ruleA(language: String, value: String, enValue: String): Boolean {
        if (language != "ja" && language != "ko") return false
        if (value != enValue || value.isBlank()) return false
        val native = if (language == "ja") KANA else HANGUL
        if (native.containsMatchIn(value)) return false
        return wordCount(value) >= MIN_WORDS
    }

    private fun ruleB(language: String, value: String): Boolean {
        if (language != "en" && language != "ko") return false
        return CJK.containsMatchIn(value)
    }

    /** `A|ja|key` 形式的缺口集合（排序后与基线逐行比对）。 */
    private fun violations(languages: Map<String, Map<String, String>>): List<String> {
        val en = languages.getValue("en")
        val out = sortedSetOf<String>()
        for (language in listOf("en", "ja", "ko")) {
            for ((key, value) in languages.getValue(language)) {
                if (ruleA(language, value, en[key].orEmpty())) out += "A|$language|$key"
                if (ruleB(language, value)) out += "B|$language|$key"
            }
        }
        return out.toList()
    }

    // ---------------------------------------------------------------- 取数

    private fun loadLanguages(): Map<String, Map<String, String>> {
        val out = LinkedHashMap<String, Map<String, String>>()
        for (language in LANGS) {
            val file = File(repoRoot(), "i18n/app_$language.arb")
            assertTrue("找不到 ARB：${file.absolutePath}", file.isFile)
            val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
            check(parsed is Map<*, *>) { "$language ARB 顶层不是对象" }
            val map = LinkedHashMap<String, String>()
            parsed.forEach { (k, v) -> if (k is String && !k.startsWith("@") && v is String) map[k] = v }
            out[language] = map
        }
        return out
    }

    private fun baselineLines(): List<String> {
        val file = File(repoRoot(), BASELINE_RELATIVE)
        assertTrue("找不到基线：${file.absolutePath}（先跑 --write）", file.isFile)
        return file.readLines(Charsets.UTF_8).map { it.trim() }
            .filter { it.isNotEmpty() && !it.startsWith("#") }
    }

    // ---------------------------------------------------------------- 门禁

    @Test
    fun `六份 ARB 都要真的读到（防门禁空跑）`() {
        val languages = loadLanguages()
        assertEquals("语种数不对", 6, languages.size)
        for ((language, entries) in languages) {
            assertTrue("$language 只读到 ${entries.size} 条文案，疑似判据失效", entries.size >= 3000)
        }
    }

    @Test
    fun `基线不为空且规则版本与脚本一致`() {
        val baseline = baselineLines()
        assertTrue("基线为空，门禁无法判定", baseline.isNotEmpty())
        assertTrue("基线只有 ${baseline.size} 条，疑似判据失效", baseline.size >= 1100)
        val header = File(repoRoot(), BASELINE_RELATIVE).readText(Charsets.UTF_8)
        assertTrue(
            "基线头部的规则版本与测试不一致（脚本 RULES v$RULES_VERSION / WHITELIST v$WHITELIST_VERSION）",
            header.contains("RULES_VERSION=$RULES_VERSION") && header.contains("WHITELIST_VERSION=$WHITELIST_VERSION"),
        )
    }

    @Test
    fun `文案缺口不高于棘轮基线`() {
        val actual = violations(loadLanguages())
        val baseline = baselineLines().toSet()
        val actualSet = actual.toSet()
        val added = actual.filterNot { it in baseline }
        val removed = baseline.filterNot { it in actualSet }
        assertTrue(
            buildString {
                appendLine("文案缺口门禁失败：新增 ${added.size} 条、该降未降 ${removed.size} 条")
                added.take(30).forEach { appendLine("  新增：$it") }
                removed.take(30).forEach { appendLine("  已修复但基线未下调：$it") }
                appendLine()
                appendLine("新文案必须六份 ARB 同步；日/韩不要留英文原文，en/ko 不要留汉字。")
                appendLine("修好后执行：python scripts/i18n-copy-gap.py --write")
            },
            added.isEmpty() && removed.isEmpty(),
        )
    }

    /**
     * 咬合探针：判据必须真的咬、且不能乱咬。
     *
     * 三条对应评审要求：ja 塞英文必红、ko 塞中文必红、ja 塞「保存」必不红。
     * 另外两条防误报：ja 正常日文、ja 短标签 `WebDAV URL`。
     */
    @Test
    fun `咬合探针`() {
        assertTrue(
            "ja 里塞一句英文必须判成未翻译",
            ruleA("ja", "This course is still running", "This course is still running"),
        )
        assertTrue("ko 里塞中文必须判成中文污染", ruleB("ko", "轻屿课表·{profileName}"))
        assertTrue("en 里塞中文必须判成中文污染", ruleB("en", "Supports 上课周 import"))
        assertTrue(
            "`保存` 是日文同形词，不能判成未翻译（不然整个 ja 全是误报）",
            !ruleA("ja", "保存", "保存"),
        )
        assertTrue("短标签 `WebDAV URL` 不该判未翻译", !ruleA("ja", "WebDAV URL", "WebDAV URL"))
        assertTrue("正常日文不该被判成未翻译", !ruleA("ja", "この壁紙は使用中です", "この壁紙は使用中です"))
        assertTrue("ja 不走中文污染规则（日语本来用汉字）", !ruleB("ja", "保存"))
    }

    /** 仓库根：以 `i18n/app_zh.arb` 为标志向上找（L0 与 Gradle 工作目录不同）。 */
    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "i18n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（i18n/app_zh.arb），工作目录 ${File("").absolutePath}")
    }
}
