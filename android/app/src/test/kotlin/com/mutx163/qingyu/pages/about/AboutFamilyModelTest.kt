package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.infra.MaintainerGroup
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 「关于页族」本轮新增纯逻辑的测试（2026-10-28）。
 *
 * 覆盖三件事，期望值都独立于实现：
 * 1. `NOTICES` 解析（许可证真实数据源）：用**手工构造**的极简样本，期望值是「按格式读出来应该是什么」，
 *    不是从实现里抄的；
 * 2. 贡献者分组排序：按名字升序；
 * 3. 新增文案与 `i18n/app_zh.arb` **逐字对拍**（不手抄信任）。
 */
class AboutFamilyModelTest {

    private val separator = "-".repeat(80)

    // ---------- NOTICES 解析 ----------

    @Test
    fun `parseFlutterNotices 按 80 连字符切分条目`() {
        val text = buildString {
            appendLine("pkg-a")
            appendLine()
            appendLine("License A line 1")
            appendLine()
            appendLine("License A line 2")
            appendLine(separator)
            appendLine("pkg-b")
            appendLine("pkg-b-second")
            appendLine()
            appendLine("License B")
        }
        val entries = parseFlutterNotices(text)
        assertEquals(2, entries.size)
        assertEquals(listOf("pkg-a"), entries[0].packages)
        assertEquals(listOf("License A line 1", "License A line 2"), entries[0].paragraphs)
        assertEquals(listOf("pkg-b", "pkg-b-second"), entries[1].packages)
        assertEquals(listOf("License B"), entries[1].paragraphs)
    }

    @Test
    fun `parseFlutterNotices 跳过空块与无正文块`() {
        // 开头空块、两个连续分隔符、最后一条有包名无正文——都该被跳过，只留中间那条完整条目。
        val text = "\n\n$separator\n$separator\npkg\n\nbody\n$separator\ndangling-pkg\n"
        val entries = parseFlutterNotices(text)
        assertEquals(1, entries.size)
        assertEquals(listOf("pkg"), entries[0].packages)
        assertEquals(listOf("body"), entries[0].paragraphs)
    }

    @Test
    fun `parseFlutterNotices 对空文本返回空列表`() {
        assertEquals(0, parseFlutterNotices("").size)
        assertEquals(0, parseFlutterNotices("   \n\n  ").size)
    }

    @Test
    fun `buildOpenSourcePackageLicenses 聚合解析结果时同名包合并正文`() {
        val text = "pkg-a\n\nbody1\n$separator\npkg-a\n\nbody2\n"
        val packages = buildOpenSourcePackageLicenses(parseFlutterNotices(text))
        assertEquals(1, packages.size)
        assertEquals("pkg-a", packages[0].packageName)
        assertEquals(listOf("body1", "body2"), packages[0].licenseBodies)
    }

    // ---------- 贡献者分组排序 ----------

    @Test
    fun `sortedContributorGroups 按名字升序`() {
        val groups = listOf(
            MaintainerGroup(name = "zoe", adapterLabels = emptyList()),
            MaintainerGroup(name = "alice", adapterLabels = emptyList()),
        )
        assertEquals(listOf("alice", "zoe"), sortedContributorGroups(groups).map { it.name })
    }

    // ---------- 文案与 ARB 逐字对拍 ----------

    @Test
    fun `本轮新增关于文案与 ARB 逐字一致`() {
        val map = mapOf(
            "aboutTitle" to AboutInfoStrings.aboutTitle,
            "timetableAppName" to AboutInfoStrings.appName,
            "aboutHeroSubtitle" to AboutInfoStrings.heroSubtitle,
            "platformLabel" to AboutInfoStrings.platformLabel,
            "focusLabel" to AboutInfoStrings.focusLabel,
            "updateLabel" to AboutInfoStrings.updateLabel,
            "prereleaseIncluded" to AboutInfoStrings.prereleaseIncluded,
            "stableOnly" to AboutInfoStrings.stableOnly,
            "thirdPartyDisclaimer" to AboutInfoStrings.thirdPartyDisclaimer,
            "aboutRepositorySheetTitle" to AboutRepositoryStrings.sheetTitle,
            "aboutRepositorySheetHint" to AboutRepositoryStrings.sheetHint,
            "aboutOpenGitHubAction" to AboutRepositoryStrings.openGitHubAction,
            "aboutOpenWarehouseRepoAction" to AboutRepositoryStrings.openWarehouseRepoAction,
            "copyAddress" to AboutRepositoryStrings.copyAddress,
            "copiedRepositoryAddress" to AboutRepositoryStrings.copiedAddress,
            "aboutContributorsTitle" to ContributorsStrings.screenTitle,
            "aboutDevelopersTitle" to ContributorsStrings.developersTitle,
            "aboutDeveloperMaintainerSubtitle" to ContributorsStrings.developerSubtitle,
            "aboutWarehouseMaintainersTitle" to ContributorsStrings.maintainersTitle,
            "aboutWarehouseMaintainersIntro" to ContributorsStrings.maintainersIntro,
            "aboutWarehouseMaintainersEmpty" to ContributorsStrings.maintainersEmpty,
            "aboutParticipateWarehouseTitle" to ContributorsStrings.participateTitle,
            "aboutParticipateWarehouseSubtitle" to ContributorsStrings.participateSubtitle,
            "copiedWarehouseRepositoryAddress" to ContributorsStrings.copiedAddress,
        )
        for ((key, value) in map) {
            assertEquals("ARB 键 $key 与模型不一致", arbString(key), value)
        }
    }

    @Test
    fun `布局文案格式化函数与 ARB 模板一致`() {
        // versionLabel = 版本 {version}
        assertEquals("版本 1.2.3 (45)", AboutInfoStrings.versionLabel("1.2.3 (45)"))
        // 适配项计数 = {count} 个适配项
        assertEquals("3 个适配项", ContributorsStrings.maintainerCount(3))
    }

    private fun arbString(key: String): String {
        val candidates = listOf(
            File("../../i18n/app_zh.arb"),
            File("../i18n/app_zh.arb"),
            File("i18n/app_zh.arb"),
        )
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 i18n/app_zh.arb，工作目录=${File(".").absolutePath}")
        @Suppress("UNCHECKED_CAST")
        val json = MiniJson.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>
        return json[key] as? String ?: error("ARB 缺少键 $key")
    }
}
