package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * [ArbCatalog] 与 6 份 ARB 的逐键对拍。
 *
 * 生成的文案表是 Compose 壳唯一的运行时文案源；它一旦与 ARB 漂移，界面就会说
 * 「上个月的英文」。这里把 6 份 ARB 全量比一遍：键缺、值被手改、脚本忘了重跑，
 * 都会红。
 */
class ArbCatalogTest {

    private val arbByLang: Map<String, Map<String, String>> by lazy { loadAllArb() }

    @Test
    fun `六份 ARB 的每一条都在文案表里`() {
        var checked = 0
        for ((language, entries) in arbByLang) {
            for ((key, value) in entries) {
                val actual = ArbCatalog.text(language, key)
                assertEquals("$language 的 `$key` 与 ARB 不一致", value, actual)
                checked++
            }
        }
        assertTrue("对拍条数异常：$checked", checked >= 6 * 3000)
    }

    @Test
    fun `缺键返回 null，由调用方回落中文原文`() {
        assertEquals(null, ArbCatalog.text("en", "thisKeyDoesNotExist"))
        assertEquals(null, ArbCatalog.text("fr", "aboutTitle"))
    }

    @Test
    fun `源码里声明的每个 ArbText 键都能在中文 ARB 里找到`() {
        val zh = arbByLang.getValue("zh")
        val keys = declaredKeys()
        assertTrue("源码里扫到的 ArbText 键太少：${keys.size}", keys.size >= 2000)
        val missing = keys.filterNot { zh.containsKey(it) }
        assertTrue("ARB 缺键：$missing", missing.isEmpty())
    }

    /** 全部 `ArbText("key", …)` 声明的键（文案表本身就是真源，测试反查源码防漏键）。 */
    private fun declaredKeys(): Set<String> {
        val regex = Regex("""ArbText\(\s*"([^"]+)"""")
        val out = LinkedHashSet<String>()
        for (rootName in listOf("main", "composeP1")) {
            val root = File(repoRoot(), "android/app/src/$rootName")
            root.walkTopDown().filter { it.isFile && it.extension == "kt" }.forEach { file ->
                regex.findAll(file.readText(Charsets.UTF_8)).forEach { out += it.groupValues[1] }
            }
        }
        return out
    }

    private fun loadAllArb(): Map<String, Map<String, String>> {
        val files = mapOf(
            "en" to "app_en.arb",
            "ja" to "app_ja.arb",
            "ko" to "app_ko.arb",
            "zh" to "app_zh.arb",
            "zh_HK" to "app_zh_HK.arb",
            "zh_TW" to "app_zh_TW.arb",
        )
        val out = LinkedHashMap<String, Map<String, String>>()
        for ((language, name) in files) {
            val file = File(repoRoot(), "i18n/$name")
            assertTrue("找不到 ARB：${file.absolutePath}", file.isFile)
            val parsed = MiniJson.parse(file.readText(Charsets.UTF_8))
            check(parsed is Map<*, *>) { "$name 顶层不是对象" }
            val map = LinkedHashMap<String, String>()
            parsed.forEach { (k, v) ->
                if (k is String && !k.startsWith("@") && v is String) map[k] = v
            }
            assertNotNull(map)
            out[language] = map
        }
        return out
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
