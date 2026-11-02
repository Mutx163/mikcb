package com.mutx163.qingyu.pages.about

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.security.MessageDigest
import java.util.zip.GZIPInputStream

/**
 * 「删 Flutter 前资产迁移」断供守卫（2026-11-02）。
 *
 * 四类 Compose 读路径已从 Flutter 打包的 `flutter_assets/` 换到主 assets：
 * `lan_edit/`（局域网控制台）、`docs/releases/`（更新日志正文）、
 * `licenses/NOTICES.gz`（开源许可快照）、`donate/` + `branding/`（二维码与图标）。
 * 本守卫钉四件事：
 *
 * 1. **新落点存在且内容未漂移**：二进制文件钉原始字节哈希；文本资产钉
 *    规范化换行（CRRLF→LF）后的哈希——`core.autocrlf=true` 下重新检出会改
 *    工作区字节，钉规范化哈希才不会在别人机器上误红。
 * 2. **更新日志目录可被解析**：目录里每个文件名都必须过 [matchReleaseAssetKey]
 *    （混进一个 `index.html` 就会让列表页读到垃圾），且数量不少于回退清单
 *    [knownChangelogVersions]。
 * 3. **NOTICES 快照端到端可解析**：gunzip → [parseFlutterNotices] →
 *    [buildOpenSourcePackageLicenses] 出非空包列表（换源后解析器零改动的活证据）。
 * 4. **死路径棘轮**：五个页面源文件里不得再出现**字符串字面量**形式的
 *    `flutter_assets` 读路径——删 Flutter 后该目录永不再生成，引用它的读路径
 *    都是白屏炸弹。注释/文档里提它不拦（正则只认引号紧跟的形态）。
 */
class FlutterAssetsDecouplingGuardTest {

    // ---- 定位仓库根（L0 脚本与 Gradle 的 user.dir 不同，向上找最稳） ----

    private fun repoRoot(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "pubspec.yaml").isFile && File(dir, "android").isDirectory) return dir
            dir = dir.parentFile
        }
        error("找不到仓库根（user.dir=${System.getProperty("user.dir")}）")
    }

    private fun asset(relative: String): File =
        File(repoRoot(), "android/app/src/main/assets/$relative")

    private fun pageSource(pathUnderSrc: String): File =
        File(repoRoot(), "android/app/src/$pathUnderSrc")

    private fun sha256Hex(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    /** 文本资产按「换行规范化后」取哈希，与检出方式的 CRLF/LF 无关。 */
    private fun normalizedTextHash(file: File): String {
        val text = file.readText().replace("\r\n", "\n").replace("\r", "\n")
        return sha256Hex(text.toByteArray(Charsets.UTF_8))
    }

    // ---- 1. 迁移后的资产内容钉死 ----

    /** 二进制资产（png / gz）：钉原始字节哈希。哈希取自迁移当日与仓库原件逐字节比对的结果。 */
    private val binaryPins = mapOf(
        "branding/launcher_icon.png" to "01671df7bb8f058496089cb50f5041ac6016453ae11629d16130fc02b8d73bfb",
        "donate/wechatpay.png" to "c011931ca9e5f1eb171e6f6d1c47ebddf8fc6e8a9b7f6e0c3ff291d13571ffc9",
        "donate/alipay.png" to "7b307a7e926a4b672594faac1b10266285de0a8f0893142a159a0ac9a401b387",
        "licenses/NOTICES.gz" to "2cd0a6d59033bb94180d038b4aad6a78bf40e69e13ac22d05a531b7c4a0a134e",
    )

    /** 文本资产（lan_edit 控制台）：钉规范化换行后的哈希。 */
    private val textPins = mapOf(
        "lan_edit/index.html" to "c405bc1a2b2a3777e1fa32384378ffb2faa98965c9b2830242a3394ec9580d1a",
        "lan_edit/app.js" to "b2350c715038487d92fda374f64bdab7f6aae75c8c5c0085e9da5d79265d2c09",
        "lan_edit/i18n.js" to "cd4be7b1541277ca17d72dce2c36c0917f892655132b646358cec2a7021a0c17",
        "lan_edit/lan-timetable.css" to "1775921243900872d299a71b6a2084725cf527142cc8e498c03117cad38d07cc",
        "lan_edit/tabler-icons-subset.css" to "d2e977c5168fecd9f49ff53006da7c676fcf759f68c8caa92e67f9c39df5e2fe",
    )

    @Test
    fun `migrated binary assets exist with pinned bytes`() {
        for ((relative, pin) in binaryPins) {
            val f = asset(relative)
            assertTrue("迁移后的资产缺失：$relative", f.isFile)
            assertEquals(
                "资产内容漂移：$relative（如确需更新，请同步更新守卫里的钉值）",
                pin,
                sha256Hex(f.readBytes()),
            )
        }
    }

    @Test
    fun `migrated console page assets exist with pinned normalized content`() {
        for ((relative, pin) in textPins) {
            val f = asset(relative)
            assertTrue("迁移后的控制台页面资产缺失：$relative", f.isFile)
            assertEquals(
                "控制台页面资产内容漂移：$relative（如确需更新，请同步更新守卫里的钉值）",
                pin,
                normalizedTextHash(f),
            )
        }
    }

    // ---- 2. 更新日志目录可被解析 ----

    @Test
    fun `changelog directory holds only parsable release notes and no fewer than the fallback list`() {
        val dir = asset("docs/releases")
        val names = dir.listFiles()?.map { it.name }.orEmpty()
        assertTrue("主 assets 里 docs/releases 目录为空（迁移被回退了？）", names.isNotEmpty())
        val offending = names.filter { matchReleaseAssetKey("docs/releases/$it") == null }
        assertTrue(
            "目录混进了更新日志页不认的文件（列表页只认 v<数字>.md）：$offending",
            offending.isEmpty(),
        )
        val known = knownChangelogVersions()
        assertTrue(
            "正文文件数(${names.size}) 少于回退清单(${known.size})——清单里的版本会整页缺正文",
            names.size >= known.size,
        )
        for (version in known.take(3)) {
            assertTrue("回退清单最新版本缺正文：$version.md", asset("docs/releases/$version.md").isFile)
        }
    }

    // ---- 3. NOTICES 快照端到端可解析 ----

    @Test
    fun `notices snapshot parses end to end into package licenses`() {
        val f = asset("licenses/NOTICES.gz")
        assertTrue("许可证快照缺失：licenses/NOTICES.gz", f.isFile)
        val text = GZIPInputStream(f.inputStream().buffered())
            .bufferedReader(Charsets.UTF_8).use { it.readText() }
        val packages = buildOpenSourcePackageLicenses(parseFlutterNotices(text))
        assertTrue("解析出的许可证包数异常偏少：${packages.size}", packages.size >= 50)
        val broken = packages.filter { it.packageName.isBlank() || it.licenseBodies.isEmpty() }
        assertTrue("解析出空包或空正文：${broken.map { it.packageName }}", broken.isEmpty())
    }

    // ---- 4. 死路径棘轮 + 新路径正向钉 ----

    /** 引号紧跟 `flutter_assets` = 字符串字面量里的读路径（注释/文档里的反引号提及不拦）。 */
    private val deadAssetPathLiteral = Regex("""["']flutter_assets""")

    /** 五个已换读路径的页面源文件（迁移见各文件内 2026-11-02 注释）。 */
    private val migratedPages = listOf(
        "composeP1/kotlin/com/mutx163/qingyu/pages/transfer/LanEditHost.kt",
        "composeP1/kotlin/com/mutx163/qingyu/pages/about/ChangelogPage.kt",
        "composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesHost.kt",
        "composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt",
        "composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutStaticPage.kt",
    )

    @Test
    fun `page read paths no longer contain the dead flutter_assets literal`() {
        for (relative in migratedPages) {
            val f = pageSource(relative)
            assertTrue("页面源文件缺失：$relative", f.isFile)
            val offenders = f.readLines()
                .withIndex()
                .filter { deadAssetPathLiteral.containsMatchIn(it.value) }
            assertTrue(
                "flutter_assets 读路径回流（删 Flutter 后该目录永不再生成，这条路径只会白屏）：" +
                    "$relative 第 ${offenders.map { it.index + 1 }} 行",
                offenders.isEmpty(),
            )
        }
    }

    @Test
    fun `new read path literals stay pinned`() {
        val expectations = mapOf(
            "composeP1/kotlin/com/mutx163/qingyu/pages/transfer/LanEditHost.kt" to "readConsoleAsset",
            "composeP1/kotlin/com/mutx163/qingyu/pages/about/ChangelogPage.kt" to
                "releaseAssetsDir = \"docs/releases\"",
            "composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesHost.kt" to
                "noticesAssetPath = \"licenses/NOTICES.gz\"",
            "composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt" to
                "\"assets/donate/wechatpay.png\"",
            "composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutStaticPage.kt" to
                "\"assets/branding/launcher_icon.png\"",
        )
        for ((relative, needle) in expectations) {
            val text = pageSource(relative).readText()
            assertTrue(
                "新读路径字面量被改掉了（若是有意迁移请同步本守卫）：$relative 应含 $needle",
                text.contains(needle),
            )
        }
    }
}
