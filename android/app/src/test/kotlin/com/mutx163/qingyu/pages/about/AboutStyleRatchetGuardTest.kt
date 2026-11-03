package com.mutx163.qingyu.pages.about

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 关于族版面收口棘轮（2026-11-03）——把「关于 / 更新 / 捐助 / 高级选项」一套视觉刻度钉住：
 *
 * 1. **入口行形态**：关于页的三段入口列表必须走官方 `ArrowPreference`（分组卡 + 行自带
 *    16dp 内边距 = 文字左缘 28 轴线），不许回退成自拼 `QingyuRow` / `Modifier.clickable` 行
 *    （第一版「廉价感」的来源，2026-10-27 返工过一次）。
 * 2. **圆角语义**：设置组类卡片（关于页分段入口卡、高级选项页 GroupCard）必须
 *    [QingyuCardDefaults.SettingsGroupCorner]（24dp）；内容/展示类不显式传 16/20
 *    （走 [QingyuCardDefaults.Corner] 默认），同层不许出现第二种圆角。
 * 3. **一套列表刻度**：四页列表间距/底部留白一律用共享参数
 *    （[AboutPageListSpacing] / [AboutPageListBottomPadding]），不许各页写死。
 * 4. **共享身份图标**：`ic_launcher_background/foreground` 两层 PNG 只允许住在
 *    PagesCommon（[AboutAppIconBadge]），关于页与更新页都调它，不许各画各的，
 *    更不许回退 `painterResource(applicationInfo.icon)`（adaptive-icon 必崩）。
 * 5. **发布说明摘要一套渲染**：更新页与更新日志页共用 ReleaseDigestViews 的共享件，
 *    不许再各写私有 HighlightRow/GroupedEntries/ExpandToggle。
 *
 * 所有源码匹配都**先剥注释**（与弹层守卫同一纪律）：注释里讲历史、引用旧写法不算违规。
 */
class AboutStyleRatchetGuardTest {

    // ---- 定位仓库根（与 FlutterAssetsDecouplingGuardTest 同一找法） ----

    private fun repoRoot(): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "pubspec.yaml").isFile && File(dir, "android").isDirectory) return dir
            dir = dir.parentFile
        }
        error("找不到仓库根（user.dir=${System.getProperty("user.dir")}）")
    }

    private fun pageSource(pathUnderSrc: String): File =
        File(repoRoot(), "android/app/src/$pathUnderSrc")

    /** 剥掉 Kotlin 行/块注释再匹配；注释里讲历史（引用旧写法）不算违规。 */
    private fun stripKotlinComments(source: String): String {
        val withoutBlock = Regex("/\\*.*?\\*/", RegexOption.DOT_MATCHES_ALL).replace(source, "")
        return withoutBlock.lineSequence().map { it.substringBefore("//") }.joinToString("\n")
    }

    private fun codeOf(relative: String): String =
        stripKotlinComments(pageSource(relative).readText())

    private val aboutDir = "composeP1/kotlin/com/mutx163/qingyu/pages/about"

    // ---- 1. 入口行形态：官方 preference，不许自拼 ----

    @Test
    fun `about entry rows use official ArrowPreference not hand rolled rows`() {
        val code = codeOf("$aboutDir/AboutStaticPage.kt")
        assertTrue(
            "关于页入口列表没走官方 ArrowPreference（自拼行是「廉价感」的根源，见 PagesCommon 头注）",
            code.contains("ArrowPreference("),
        )
        assertFalse(
            "关于页入口列表回退成了自拼 QingyuRow（应走分组卡 + 官方 ArrowPreference）",
            code.contains("QingyuRow("),
        )
        assertFalse(
            "关于页出现 Modifier.clickable 自拼行（官方行控件的按压反馈才是对的）",
            code.contains("Modifier.clickable"),
        )
    }

    // ---- 2. 圆角语义：设置组 24，内容类不显式写 16/20 ----

    @Test
    fun `settings tier cards use the settings group corner`() {
        for (relative in listOf(
            "$aboutDir/AboutStaticPage.kt",
            "$aboutDir/AdvancedOptionsPage.kt",
        )) {
            val code = codeOf(relative)
            assertTrue(
                "设置组卡片没用 24dp 语义圆角（QingyuCardDefaults.SettingsGroupCorner）：$relative",
                code.contains("QingyuCardDefaults.SettingsGroupCorner"),
            )
            assertFalse(
                "设置组卡片显式写了 cornerRadius = 16（同层混第二种圆角）：$relative",
                code.contains("cornerRadius = 16.dp"),
            )
        }
        val support = codeOf("$aboutDir/SupportCreatorPage.kt")
        assertFalse(
            "内容/展示类卡片显式写 cornerRadius = 20（与同层默认 16 混角）：SupportCreatorPage.kt",
            support.contains("cornerRadius = 20.dp"),
        )
    }

    // ---- 3. 一套列表刻度：共享参数，不许各页写死 ----

    @Test
    fun `about family lists share one spacing constant`() {
        for (relative in listOf(
            "$aboutDir/AboutStaticPage.kt",
            "$aboutDir/AboutUpdatePage.kt",
            "$aboutDir/SupportCreatorPage.kt",
            "$aboutDir/AdvancedOptionsPage.kt",
        )) {
            val code = codeOf(relative)
            assertTrue(
                "列表刻度没走共享参数 AboutPageListSpacing（各页写死间距就是轴线漂移的起点）：$relative",
                code.contains("AboutPageListSpacing"),
            )
            // 只禁**列表级**写死间距（verticalArrangement = spacedBy(8.dp)）；
            // 卡内组件自己的间隙（图标与文字、按钮排布）不属页面轴线，不管。
            assertFalse(
                "列表又出现了写死的 8dp 间距（全族统一 12dp）：$relative",
                code.contains("verticalArrangement = Arrangement.spacedBy(8.dp)"),
            )
        }
    }

    // ---- 4. 共享身份图标：两层 PNG 只住 PagesCommon ----

    @Test
    fun `launcher two layer png lives only in PagesCommon and pages call the shared badge`() {
        // 只扫 about 域目录本身；别收编整个 pages 树——settings/statistics 域有它们
        // 自己的两层 PNG 合法用法（SettingsPageRenderers / StatisticsExportCards）。
        val dir = pageSource(aboutDir)
        val kotlinFiles = dir.walkTopDown().filter { it.isFile && it.extension == "kt" }.toList()
        val offenders = kotlinFiles
            .filter { it.name != "PagesCommon.kt" }
            .filter { stripKotlinComments(it.readText()).contains("ic_launcher_background") }
            .map { it.name }
        assertTrue(
            "ic_launcher_background 两层 PNG 实现泄漏出 PagesCommon（身份块只此一份）：$offenders",
            offenders.isEmpty(),
        )
        for (relative in listOf(
            "$aboutDir/AboutStaticPage.kt",
            "$aboutDir/AboutUpdatePage.kt",
        )) {
            assertTrue(
                "页面没调共享身份图标 AboutAppIconBadge（不许各画各的）：$relative",
                codeOf(relative).contains("AboutAppIconBadge("),
            )
        }
        val update = codeOf("$aboutDir/AboutUpdatePage.kt")
        assertFalse(
            "更新页回退 painterResource(applicationInfo.icon)（adaptive-icon 必抛，进页闪退）",
            update.contains("applicationInfo.icon"),
        )
    }

    // ---- 5. 发布说明摘要一套渲染 ----

    @Test
    fun `release digest rendering is shared not duplicated`() {
        val update = codeOf("$aboutDir/AboutUpdatePage.kt")
        val changelog = codeOf("$aboutDir/ChangelogPage.kt")
        // 两页都吃共享的重点行；更新页的完整条目经 ReleaseNotesExpandableBody（默认收起），
        // 日志页自持展开状态直接调分组件。
        assertTrue(
            "更新页发布说明没走共享件（ReleaseNotesHighlightRow / ReleaseNotesExpandableBody）",
            update.contains("ReleaseNotesHighlightRow(") && update.contains("ReleaseNotesExpandableBody("),
        )
        assertTrue(
            "更新日志页发布说明没走共享件（ReleaseNotesHighlightRow / ReleaseNotesGroupedEntries）",
            changelog.contains("ReleaseNotesHighlightRow(") && changelog.contains("ReleaseNotesGroupedEntries("),
        )
        for ((name, code) in listOf("AboutUpdatePage.kt" to update, "ChangelogPage.kt" to changelog)) {
            assertFalse(
                "页面里又长出私有摘要实现（两页各写一套就是这么来的）：$name",
                Regex("""private fun (Update)?HighlightRow\(""").containsMatchIn(code) ||
                    Regex("""private fun (Update)?GroupedEntries\(""").containsMatchIn(code),
            )
        }
        assertTrue(
            "更新页发布说明没有展开/收起入口（长文不许一坨灰字堆着）",
            update.contains("ReleaseNotesExpandableBody("),
        )
    }
}
