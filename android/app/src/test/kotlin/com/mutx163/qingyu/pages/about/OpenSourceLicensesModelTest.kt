package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 开源许可页模型层测试。
 *
 * 期望值来源（独立于实现）：
 * - 分组/排序/过滤：逐条对照 `lib/screens/open_source_licenses_screen.dart` 的行号语义；
 * - 文案：**直接读 `lib/l10n/app_zh.arb` 对拍**，不手抄（见 [arbStringsMatchModel]）；
 * - 边界：空段落、空包名、空白 query、大小写混排，人推得出。
 */
class OpenSourceLicensesModelTest {

    // ---------- 分组与正文拼接 ----------

    @Test
    fun `段落trim后以空行连接且空段落丢弃`() {
        val packages = buildOpenSourcePackageLicenses(
            listOf(
                LicenseRegistryEntry(
                    packages = listOf("alpha"),
                    paragraphs = listOf("  第一段  ", "", "   ", "第二段"),
                ),
            ),
        )
        assertEquals(1, packages.size)
        assertEquals("alpha", packages[0].packageName)
        // Dart :33 —— 段落 join('\n\n')，trim 后的空段不产生多余空行。
        assertEquals(listOf("第一段\n\n第二段"), packages[0].licenseBodies)
    }

    @Test
    fun `全空段落整条跳过`() {
        val packages = buildOpenSourcePackageLicenses(
            listOf(
                LicenseRegistryEntry(packages = listOf("ghost"), paragraphs = listOf("", "   ")),
                LicenseRegistryEntry(packages = listOf("real"), paragraphs = listOf("正文")),
            ),
        )
        // Dart :30-32 —— paragraphs.isEmpty() 时 continue，ghost 不应出现。
        assertEquals(listOf("real"), packages.map { it.packageName })
    }

    @Test
    fun `包名trim空名跳过同名累积`() {
        val packages = buildOpenSourcePackageLicenses(
            listOf(
                LicenseRegistryEntry(packages = listOf("  dup  ", "   ", ""), paragraphs = listOf("A")),
                LicenseRegistryEntry(packages = listOf("dup"), paragraphs = listOf("B")),
            ),
        )
        assertEquals(1, packages.size)
        assertEquals("dup", packages[0].packageName)
        // 同名包按出现顺序累积（Dart :39）。
        assertEquals(listOf("A", "B"), packages[0].licenseBodies)
    }

    @Test
    fun `一条记录可归属多个包`() {
        val packages = buildOpenSourcePackageLicenses(
            listOf(
                LicenseRegistryEntry(packages = listOf("p1", "p2"), paragraphs = listOf("共享正文")),
            ),
        )
        assertEquals(listOf("p1", "p2"), packages.map { it.packageName })
        assertTrue(packages.all { it.licenseBodies == listOf("共享正文") })
    }

    @Test
    fun `combinedLicenseText用分隔线拼接`() {
        val license = OpenSourcePackageLicense("pkg", listOf("A", "B", "C"))
        // Dart :17 —— join('\n\n---\n\n')。
        assertEquals("A\n\n---\n\nB\n\n---\n\nC", license.combinedLicenseText)
    }

    @Test
    fun `单份正文不带分隔线`() {
        assertEquals("only", OpenSourcePackageLicense("pkg", listOf("only")).combinedLicenseText)
    }

    // ---------- 排序 ----------

    @Test
    fun `按包名小写字典序排序`() {
        val packages = buildOpenSourcePackageLicenses(
            listOf(
                LicenseRegistryEntry(packages = listOf("Zebra"), paragraphs = listOf("z")),
                LicenseRegistryEntry(packages = listOf("alpha"), paragraphs = listOf("a")),
                LicenseRegistryEntry(packages = listOf("Beta"), paragraphs = listOf("b")),
            ),
        )
        // Dart :52-56 —— 比较的是 toLowerCase()，所以 Zebra 排在最后而不是最前。
        assertEquals(listOf("alpha", "Beta", "Zebra"), packages.map { it.packageName })
    }

    // ---------- 过滤 ----------

    @Test
    fun `空白query原样返回同一个列表`() {
        val all = buildOpenSourcePackageLicenses(
            listOf(LicenseRegistryEntry(packages = listOf("alpha"), paragraphs = listOf("a"))),
        )
        // Dart :112-114 —— 返回 _packages 本身。
        assertSame(all, filterOpenSourcePackages(all, ""))
        assertSame(all, filterOpenSourcePackages(all, "   "))
    }

    @Test
    fun `query做trim与小写包含匹配`() {
        val all = buildOpenSourcePackageLicenses(
            listOf(
                LicenseRegistryEntry(packages = listOf("flutter_markdown"), paragraphs = listOf("a")),
                LicenseRegistryEntry(packages = listOf("okhttp"), paragraphs = listOf("b")),
            ),
        )
        assertEquals(listOf("flutter_markdown"), filterOpenSourcePackages(all, "  MARK ").map { it.packageName })
        assertEquals(listOf("okhttp"), filterOpenSourcePackages(all, "HTTP").map { it.packageName })
    }

    @Test
    fun `无匹配返回空表`() {
        val all = buildOpenSourcePackageLicenses(
            listOf(LicenseRegistryEntry(packages = listOf("alpha"), paragraphs = listOf("a"))),
        )
        assertTrue(filterOpenSourcePackages(all, "zzz").isEmpty())
    }

    @Test
    fun `空输入返回空表`() {
        assertTrue(buildOpenSourcePackageLicenses(emptyList()).isEmpty())
    }

    // ---------- 文案与 ARB 逐字对拍 ----------

    private fun arbString(key: String): String {
        val candidates = listOf(
            File("../../lib/l10n/app_zh.arb"),
            File("../lib/l10n/app_zh.arb"),
            File("lib/l10n/app_zh.arb"),
        )
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 lib/l10n/app_zh.arb，工作目录=${File(".").absolutePath}")
        @Suppress("UNCHECKED_CAST")
        val json = MiniJson.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>
        return json[key] as? String ?: error("ARB 缺少键 $key")
    }

    @Test
    fun `arbStringsMatchModel`() {
        assertEquals(arbString("aboutOpenSourceLicensesTitle"), OpenSourceLicensesStrings.title)
        assertEquals(arbString("aboutOpenSourceLicensesSubtitle"), OpenSourceLicensesStrings.subtitle)
        assertEquals(arbString("aboutOpenSourceLicensesSearchHint"), OpenSourceLicensesStrings.searchHint)
        assertEquals(arbString("aboutOpenSourceLicensesAppSectionTitle"), OpenSourceLicensesStrings.appSectionTitle)
        assertEquals(arbString("aboutOpenSourceLicensesAppLicenseLabel"), OpenSourceLicensesStrings.appLicenseLabel)
        assertEquals(arbString("aboutOpenSourceLicensesIntro"), OpenSourceLicensesStrings.intro)
        assertEquals(arbString("aboutOpenSourceLicensesExtraUmeng"), OpenSourceLicensesStrings.extraUmeng)
        assertEquals(arbString("aboutOpenSourceLicensesLoadFailed"), OpenSourceLicensesStrings.loadFailed)
        assertEquals(arbString("aboutOpenSourceLicensesEmpty"), OpenSourceLicensesStrings.empty)
    }

    @Test
    fun `带参文案与ARB占位符一致`() {
        // ARB 是 "开源组件 {count}"：把占位符替换成数字后应与格式化函数逐字相同。
        val expectedSection = arbString("aboutOpenSourceLicensesPackagesSectionTitle")
            .replace("{count}", "7")
        assertEquals(expectedSection, OpenSourceLicensesStrings.packagesSectionTitle(7))

        val expectedSubtitle = arbString("aboutOpenSourceLicensesPackageSubtitle")
            .replace("{count}", "3")
        assertEquals(expectedSubtitle, OpenSourceLicensesStrings.packageSubtitle(3))
    }
}
