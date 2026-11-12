package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.testutil.normalizedTextHash
import com.mutx163.qingyu.testutil.releaseNotesMirrorProblems
import com.mutx163.qingyu.testutil.sha256Hex
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.util.zip.GZIPInputStream

/**
 * 「删 Flutter 前资产迁移」断供守卫（2026-11-02）。
 *
 * 四类 Compose 读路径已从 Flutter 打包的 `flutter_assets/` 换到主 assets：
 * `lan_edit/`（局域网控制台）、`docs/releases/`（更新日志正文）、
 * `licenses/NOTICES.gz`（开源许可快照）、`donate/` + `branding/`（二维码与图标）。
 * 本守卫钉五件事：
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
 * 5. **读路径与磁盘对拍（2026-11-03 补）**：页面引用的资产路径必须真实存在于
 *    主 assets。AssetManager 的路径本就相对 assets 根，多带一层 `assets/` 前缀
 *    是在找 `assets/assets/…`，必 FileNotFound——而 about 域读图全走
 *    `runCatching` 静默吞掉，症状是「不显示」（捐助页二维码实测）而非崩溃，
 *    机器上不看图标根本发现不了。另钉一条：版本更新页不得用
 *    `painterResource(applicationInfo.icon)` 画启动图（adaptive-icon XML 在
 *    compose ui 1.12 直接抛 `IllegalArgumentException`，进页即闪退）。
 */
class FlutterAssetsDecouplingGuardTest {

    // ---- 定位仓库根（L0 脚本与 Gradle 的 user.dir 不同，向上找最稳） ----

    private fun repoRoot(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            // 锚点改 Kotlin 侧：Dart 已删（P4-C），不能再要求 pubspec 存在。
            if (File(dir, "i18n/app_zh.arb").isFile && File(dir, "android/app/build.gradle").isFile) return dir
            dir = dir.parentFile
        }
        error("找不到仓库根（user.dir=${System.getProperty("user.dir")}）")
    }

    private fun asset(relative: String): File =
        File(repoRoot(), "android/app/src/main/assets/$relative")

    private fun pageSource(pathUnderSrc: String): File =
        File(repoRoot(), "android/app/src/$pathUnderSrc")

    // `sha256Hex` / `normalizedTextHash` 已抽到 `testutil/ReleaseNotesMirror.kt`（2026-11-12）：
    // 发版说明镜像判据要在 crossguard 的 L0 入口复用同一份实现，哈希工具跟着搬过去，
    // 避免两个包各留一份、改了一边另一边悄悄漂。

    // ---- 1. 迁移后的资产内容钉死 ----

    /**
     * 二进制资产（png / gz）：钉原始字节哈希。哈希取自迁移当日与仓库原件逐字节比对的结果。
     *
     * 2026-11-10 `licenses/NOTICES.gz` 重生成（去 Flutter 化后首次）：旧快照是 Flutter 时代的
     * Dart 包与引擎第三方（flutter_miuix / skia / angle / icu…），androidx / Compose / 友盟 /
     * ML Kit 一条都没有。新快照由 `tool/license_notices/generate_notices.py` 从
     * `prodReleaseRuntimeClasspath` 生成，234 条、gzip 38,837 B。哈希换成重生成后的新值：
     * 再漂移就说明有人换了资产却没重跑生成器（或没同步这里的钉值）。
     */
    private val binaryPins = mapOf(
        "branding/launcher_icon.png" to "01671df7bb8f058496089cb50f5041ac6016453ae11629d16130fc02b8d73bfb",
        "donate/wechatpay.png" to "c011931ca9e5f1eb171e6f6d1c47ebddf8fc6e8a9b7f6e0c3ff291d13571ffc9",
        "donate/alipay.png" to "7b307a7e926a4b672594faac1b10266285de0a8f0893142a159a0ac9a401b387",
        "licenses/NOTICES.gz" to "41de0ee219f29cfc6ed46f1058336495de85d33341c943ea5c63be1415a977bb",
    )

    /**
     * 文本资产（lan_edit 控制台）：钉规范化换行后的哈希。
     *
     * 2026-11-07 更新 `app.js` / `i18n.js` 两个钉值：局域网撤销的**部分成功**要如实说——
     * 后端已经产出 `skipped` / `skippedCount`，网页端 `undoLastTransfer` 现在会读它，
     * 有未撤条目时改说「撤销完成，其中 N 套时间模板未撤销」（`transferUndoPartial`，
     * en/zh 各一份）。改动只在这两个文件，`index.html` / 两份 css 钉值不变。
     *
     * **同时把仓库根 `assets/lan_edit/` 那份旧拷贝同步成主 assets 的内容**：根那份自
     * `6c4a40dd0`（整份恢复预演 + 四语错误文案）起就没跟上，两边内容长期漂移；
     * 本次起两份归一化后逐字节一致（本地 `normalizedTextHash` 对拍验证过）。
     */
    private val textPins = mapOf(
        "lan_edit/index.html" to "c405bc1a2b2a3777e1fa32384378ffb2faa98965c9b2830242a3394ec9580d1a",
        "lan_edit/app.js" to "0a6cc14f0c5aed942ddfb455dcf1cf6d30123040e552a99c0d998c691e12b9ff",
        "lan_edit/i18n.js" to "1cd8784fe9eac6567e579365c6701650b3f58300f0ca8d139afbc2283d28be42",
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

    // ---- 2b. 镜像与真源逐份对拍（2026-11-11 补；2026-11-12 判据抽到 testutil）----

    /**
     * 更新日志镜像必须与真源一一对应（审计「发版说明进 APK 是手工复制，无自动化」，2026-11-11）。
     *
     * 真源是仓库根的 `docs/releases/v*.md`；进包的是 `assets/docs/releases/` 那份**手工**拷贝
     * （没有任何自动化，历史上一律人工提交同步）。上面那条测试只校验「不少于回退清单」，
     * 漏拷**新增**版本时它照样绿——症状是应用内更新日志少最新一版，只有用户翻到才发现。
     *
     * 判据本体已抽到 `testutil/ReleaseNotesMirror.kt`（[releaseNotesMirrorProblems]，2026-11-12）：
     * 这段原先只随全量 L2 跑，`9b10a1b1d`（改真源没同步镜像）排到 L2 末尾、2 分多钟才暴露；
     * 抽出来后 crossguard 的 L0 入口用**同一个函数**做秒级判定，这里只负责把问题列表转成断言——
     * 两处各写一份判据，改了一边另一边会悄悄漂，而且「哪份算准」没有答案。
     *
     * 真源里另外那三份内部文档（`3.0.0-1-*.md`）**不进包**，由共享函数按文件名过滤，不参与对拍。
     */
    @Test
    fun `assets changelog mirror matches docs releases one to one`() {
        val sourceDir = File(repoRoot(), "docs/releases")
        val mirrorDir = asset("docs/releases")
        val problems = releaseNotesMirrorProblems(sourceDir, mirrorDir)
        assertTrue(
            buildString {
                problems.forEach { appendLine(it) }
                appendLine("真源：${sourceDir.path}")
                appendLine("镜像：${mirrorDir.path}")
            },
            problems.isEmpty(),
        )
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
                "\"donate/wechatpay.png\"",
            // 2026-11-03 补：控制台映射表同款路径病（照抄 Dart 的 assets/ 前缀 → 整表 404）。
            "main/kotlin/com/mutx163/qingyu/transfer/lan/LanEditStaticAssets.kt" to
                "\"lan_edit/index.html\"",
        )
        for ((relative, needle) in expectations) {
            val text = pageSource(relative).readText()
            assertTrue(
                "新读路径字面量被改掉了（若是有意迁移请同步本守卫）：$relative 应含 $needle",
                text.contains(needle),
            )
        }
        // 关于页图标 2026-11-03 起换两层 PNG（AboutAppIconBadge），不再读 branding 资产；
        // 该页从此不应再出现任何 assets.open 调用（先剥注释再判）。
        val staticCode = stripKotlinComments(
            pageSource("composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutStaticPage.kt").readText(),
        )
        assertFalse(
            "关于页不应再直接读资产（图标已收编 PagesCommon.AboutAppIconBadge）",
            staticCode.contains(".open("),
        )
    }

    // ---- 5. 读路径与磁盘文件对拍（2026-11-03，二维码不显示的根因守卫） ----

    /**
     * 页面引用的资产读路径 → 主 assets 磁盘文件逐条对拍。
     * AssetManager 路径相对 assets 根；这里同时钉「字面量在源码里」与「文件在磁盘上」，
     * 两边任一漂移都红。有意迁移时同步改表与磁盘落点。
     */
    private val pageAssetPathPins = mapOf(
        "composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt" to listOf(
            "branding/launcher_icon.png",
            "donate/wechatpay.png",
            "donate/alipay.png",
        ),
        // AboutStaticPage 2026-11-03 起图标走 PagesCommon.AboutAppIconBadge（两层 PNG），
        // 不再读 branding 资产，从本表移除；上面「前缀棘轮」测试仍盯着它不读任何资产。
    )

    @Test
    fun `asset paths referenced by about pages exist on disk at the bare path`() {
        for ((relative, paths) in pageAssetPathPins) {
            val text = pageSource(relative).readText()
            for (path in paths) {
                assertTrue(
                    "页面读路径字面量漂了（若是有意迁移请同步本守卫）：$relative 应含 \"$path\"",
                    text.contains("\"$path\""),
                )
                assertTrue(
                    "代码引用的资产在主 assets 不存在。AssetManager 相对 assets 根取路径，" +
                        "写 assets/… 前缀会找成 assets/assets/…，读不到且被 runCatching 吞掉" +
                        "（症状：图不显示）：$path",
                    asset(path).isFile,
                )
            }
        }
    }

    /**
     * `assets.open("assets/…")` 形态棘轮：assets 根下没有再嵌一层的 assets/ 目录，
     * 这种写法必 FileNotFound。只认 `assets.open/list(` 紧跟的字符串，注释提及不拦。
     */
    private val redundantAssetsPrefixOpen = Regex("""\.open\(\s*"assets/""")
    private val redundantAssetsPrefixList = Regex("""\.list\(\s*"assets/""")

    @Test
    fun `about pages never open or list assets through a redundant assets prefix`() {
        val pages = listOf(
            "composeP1/kotlin/com/mutx163/qingyu/pages/about/SupportCreatorPage.kt",
            "composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutStaticPage.kt",
            "composeP1/kotlin/com/mutx163/qingyu/pages/about/ChangelogPage.kt",
            "composeP1/kotlin/com/mutx163/qingyu/pages/about/OpenSourceLicensesHost.kt",
            "composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdatePage.kt",
            // 2026-11-03 全仓前缀病扫描补：壳里的节假日读取（只读源码，不改该文件）。
            "main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
        )
        for (relative in pages) {
            val text = pageSource(relative).readText()
            val openHit = redundantAssetsPrefixOpen.containsMatchIn(text)
            val listHit = redundantAssetsPrefixList.containsMatchIn(text)
            assertTrue(
                "资产读路径多了 assets/ 前缀（AssetManager 相对 assets 根，这样必读不到）：$relative",
                !openHit && !listHit,
            )
        }
    }

    /**
     * 剥掉 Kotlin 行/块注释再匹配，注释里讲历史（引用旧写法）不算违规——
     * 与弹层守卫「先剥注释」同一纪律（.agents 笔记 2026-11-03）。
     */
    private fun stripKotlinComments(source: String): String {
        val withoutBlock = Regex("/\\*.*?\\*/", RegexOption.DOT_MATCHES_ALL).replace(source, "")
        return withoutBlock.lineSequence().map { it.substringBefore("//") }.joinToString("\n")
    }

    /**
     * 版本更新页不得用 `painterResource(applicationInfo.icon)` 画启动图：
     * API 26+ 解析到 adaptive-icon XML，本仓 classpath 的 compose ui 1.12 里
     * painterResource 对非 `<vector>` XML 直接抛 IllegalArgumentException，
     * 进页即闪退（2026-11-03 用户实测）。两层 PNG 的避法见 AboutUpdatePage.AppIconBadge。
     */
    @Test
    fun `update page never paints the launcher icon via painterResource on applicationInfo`() {
        val code = stripKotlinComments(
            pageSource("composeP1/kotlin/com/mutx163/qingyu/pages/about/AboutUpdatePage.kt").readText(),
        )
        assertFalse(
            "版本更新页在用 painterResource 读 applicationInfo.icon（adaptive-icon XML 会抛 " +
                "IllegalArgumentException，进页即闪退）。改用 ic_launcher_background/foreground " +
                "两层 PNG，见 AboutUpdatePage.AppIconBadge 注释",
            code.contains("applicationInfo.icon"),
        )
    }

    // ---- 6. painterResource 资源类型对拍（2026-11-03 全仓扫描，同类闪退棘轮） ----

    /** 源码里 `painterResource(id = R.<type>.<name>)` 的调用形态（先剥注释后匹配）。 */
    private val painterResourceCall = Regex("""painterResource\s*\(\s*id\s*=\s*R\.(\w+)\.(\w+)""")

    /**
     * 把每一处 `painterResource` 的资源常量反查到 res 目录里的**真实文件**：
     * 本仓 classpath 的 compose ui 1.12 只认 `<vector>` XML 与位图；adaptive-icon /
     * layer-list / selector / shape XML 会直接抛 IllegalArgumentException
     * （2026-11-03「进版本更新页闪退」的根因类，详见 AboutUpdatePage.AppIconBadge 注释）。
     * 全仓 5 处调用（about 背景层 1（单层，2026-11-04 去重影）/ settings 2 / statistics 2）已核为位图——
     * 本守卫把它们与「以后任何人新加的调用」一起钉住：喂 XML 非 vector 资源就红。
     */
    @Test
    fun `painterResource targets resolve to vector xml or bitmaps never other xml types`() {
        val resDir = File(repoRoot(), "android/app/src/main/res")
        val srcRoots = listOf(
            File(repoRoot(), "android/app/src/composeP1/kotlin"),
            File(repoRoot(), "android/app/src/main/kotlin"),
        )
        val checked = LinkedHashMap<String, Int>()
        val offenders = mutableListOf<String>()
        for (root in srcRoots) {
            val sources = root.walkTopDown().filter { it.isFile && it.extension == "kt" }.toList()
            for (f in sources) {
                val code = stripKotlinComments(f.readText())
                for (m in painterResourceCall.findAll(code)) {
                    val type = m.groupValues[1]
                    val name = m.groupValues[2]
                    val key = "R.$type.$name"
                    checked[key] = (checked[key] ?: 0) + 1
                    if (checked[key] != 1) continue // 同一资源只反查一次
                    // 资源目录形如 res/<type>-<限定符>/，如 mipmap-anydpi-v26 / drawable-night。
                    val dirs = resDir.listFiles { d -> d.isDirectory }?.filter {
                        it.name == type || it.name.startsWith("$type-")
                    }.orEmpty()
                    val files = dirs.flatMap { d ->
                        d.listFiles { x -> x.isFile && x.nameWithoutExtension == name }.orEmpty().toList()
                    }
                    if (files.isEmpty()) {
                        offenders.add("$key 反查不到 res 文件（扫描器目录口径要修，见本测试）")
                        continue
                    }
                    for (file in files.filter { it.extension == "xml" }) {
                        val isVector = Regex("<vector[\\s>]").containsMatchIn(file.readText())
                        if (!isVector) {
                            offenders.add(
                                "$key → res/${file.parentFile.name}/${file.name} 不是 <vector> XML" +
                                    "（adaptive-icon / layer-list / selector / shape 喂给 " +
                                    "painterResource 必抛 IllegalArgumentException），改用位图或两层 PNG",
                            )
                        }
                    }
                }
            }
        }
        assertTrue(
            "全仓 painterResource 调用反查数异常（现状：2 个位图资源 × 5 处调用 = " +
                "about 背景层 1 处（2026-11-04 去重影后只画单层背景，不再叠 foreground）" +
                " + settings 2 处 + statistics 2 处）。实际资源 ${checked.keys}，" +
                "调用 ${checked.values.sum()} 处",
            checked.size >= 2 && checked.values.sum() >= 5,
        )
        assertTrue(
            "painterResource 喂了非 <vector> 的 XML 资源（真机进页即闪退）：\n" +
                offenders.joinToString("\n"),
            offenders.isEmpty(),
        )
    }
}
