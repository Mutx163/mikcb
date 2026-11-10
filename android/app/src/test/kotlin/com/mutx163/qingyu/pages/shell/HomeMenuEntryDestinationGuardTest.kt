package com.mutx163.qingyu.pages.shell

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「编辑器里排得进 ⇒ 屏上一定点得到」的契约守卫（2026-11-09 建）。
 *
 * ## 它防的是哪一类事故
 *
 * 八宫格 / 底栏的候选目录（`SettingsHomeNavigationPage.catalog`、
 * `SettingsGlassDockEditorPage.catalog`，都镜像 Dart `kHomeMenuCatalog`）与**渲染层**
 * 曾经各用一套过滤口径：
 *
 * * 编辑器按「目录里有这条」清洗（`sanitizeSeed`）；
 * * 渲染按「`shellTimetableMenuPageId` 有没有页面」清洗。
 *
 * 两个口径一旦不一致，用户能加进去的条目在首页被静默丢掉：排了 8 个，
 * 屏上只画 7 格（2026-11-09 用户报「八宫格只显示 7 格」的源码级同源判据）。
 * 第一版事故是 `courseRecolor`（弹重配色面板，不是页面）；`shareTimetable` 同族。
 *
 * ## 判据（唯一一份）
 *
 * 有去处 = `shellTimetableMenuPageId(id) != null` **或** `HomeMenuNavModel.isMenuAction(id)`
 * （= [HomeMenuNavModel.MENU_ACTION_IDS]）。这个组合在 `ShellWiring.shellTimetableMenuSupported`
 * 里只写一份，八宫格（`homeTopMenuItems`）与底栏（`PagesShellActivity` 的 `isNavigable`）
 * 必须都调它 —— 本文件同时钉「目录 ⊆ 判据」与「两处表面都调同一函数」。
 *
 * ## 为什么读文本而不是直接调函数
 *
 * `ShellWiring.kt` 与 `PagesShellActivity.kt` 都 import 了 `android.*` 与 Compose，
 * 进不了 L0 的 JVM classpath（`scripts/test-kotlin-module.ps1` 会跳过整目录）。
 * 与 `MoreFeaturesNavigationGuardTest` / `SettingsRouteWiringGuardTest` 同一套做法：
 * 按「向上找 android/app/src」的原则定位源文件再正则解析；**找不到判失败，不静默跳过**。
 */
class HomeMenuEntryDestinationGuardTest {

    // ---------------------------------------------------------------- 契约

    @Test
    fun `八宫格候选目录每一条都有去处`() {
        val missing = catalogIds(GridCatalog).filterNot { it in supportedIds() }
        assertEquals(
            "以下八宫格候选在渲染层没有去处（用户加得进去、首页不显示 ⇒ 少一格）：\n" +
                missing.joinToString("\n") { "  $it" },
            emptyList<String>(),
            missing,
        )
    }

    @Test
    fun `底栏候选目录每一条都有去处`() {
        // 底栏多两种视图动作（day / week / monthView），它们由首页自己处理，不走页面映射。
        // 「页面索引」同样是开发壳专属条目：`PagesShellActivity` 有专门渲染分支
        // （`ShellPageIndexScreen`），不在 `shellTimetableMenuPageId` 表里，但它确实点得开。
        val allowed = supportedIds() + HomeDockNavModel.VIEW_ACTION_IDS + HomeDockNavModel.DEV_INDEX_ID
        val missing = catalogIds(DockCatalog).filterNot { it in allowed }
        assertEquals(
            "以下底栏候选在渲染层没有去处（加了不出现在坞上）：\n" +
                missing.joinToString("\n") { "  $it" },
            emptyList<String>(),
            missing,
        )
    }

    @Test
    fun `弹层动作不许塞假路由`() {
        val table = pageTable()
        HomeMenuNavModel.MENU_ACTION_IDS.forEach { id ->
            assertFalse(
                "$id 是弹层动作，不能出现在 shellTimetableMenuPageId 里当页面（会造成假路由）",
                table.containsKey(id),
            )
        }
        assertTrue(
            "弹层动作白名单被清空：courseRecolor/shareTimetable 会重新被渲染层丢掉",
            HomeMenuNavModel.MENU_ACTION_IDS.containsAll(
                setOf(
                    HomeMenuNavModel.ACTION_COURSE_RECOLOR,
                    HomeMenuNavModel.ACTION_SHARE_TIMETABLE,
                ),
            ),
        )
    }

    @Test
    fun `八宫格与底栏共用同一条判据`() {
        val wiring = source(ShellWiringSource)
        val homeItems = wiring.substringAfter("fun homeTopMenuItems", "")
        assertTrue(
            "homeTopMenuItems 没找到（ShellWiring.kt 结构变了？）",
            homeItems.isNotBlank(),
        )
        assertTrue(
            "八宫格的可见性判据没有调 shellTimetableMenuSupported —— 又会回到「只认页面」的旧口径",
            homeItems.substringBefore("fun ").contains("shellTimetableMenuSupported("),
        )

        val shell = source(ShellActivitySource)
        val navCalls = Regex("""isNavigable\s*=\s*\{\s*id\s*->\s*shellTimetableMenuSupported\(id\)\s*}""")
            .findAll(shell).count()
        assertEquals(
            "底栏（坞）与宽屏 Rail 两处 isNavigable 都必须调 shellTimetableMenuSupported",
            2,
            navCalls,
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：目录或页面表被改空、正则失效时，「零违规」会全部变绿。
        assertTrue("八宫格候选太少（${catalogIds(GridCatalog).size}）", catalogIds(GridCatalog).size >= 40)
        assertTrue("底栏候选太少（${catalogIds(DockCatalog).size}）", catalogIds(DockCatalog).size >= 40)
        assertTrue("壳的 id→页面表条目太少（${pageTable().size}）", pageTable().size >= 40)
        assertTrue(
            "弹层动作白名单为空 —— 守卫没东西可守",
            HomeMenuNavModel.MENU_ACTION_IDS.isNotEmpty(),
        )
    }

    // ---------------------------------------------------------------- 解析

    private fun supportedIds(): Set<String> = pageTable().keys + HomeMenuNavModel.MENU_ACTION_IDS

    /** 壳的 id → 页面 id 表（解析 `ShellWiring.shellTimetableMenuPageId` 的函数体）。 */
    private fun pageTable(): Map<String, String> {
        val text = source(ShellWiringSource)
        val body = text.substringAfter("fun shellTimetableMenuPageId", "")
        assertTrue("没在 ShellWiring.kt 里找到 shellTimetableMenuPageId", body.isNotBlank())
        // 函数体到列 0 的 `}` 为止（`else -> null` 后面那一个）。
        val tableBody = body.substringBefore("\n}\n")
        return ENTRY.findAll(tableBody).associate { it.groupValues[1] to it.groupValues[2] }
    }

    /** 候选目录里的条目 id（`SettingsHomeNavigationPage` / `SettingsGlassDockEditorPage`）。 */
    private fun catalogIds(file: String): List<String> {
        val text = source(file)
        val matches = CATALOG_ENTRY.findAll(text).map { it.groupValues[1] }.toList()
        assertTrue("$file 里没解析出候选条目（正则失效？）", matches.isNotEmpty())
        return matches
    }

    /**
     * 从工作目录向上找 `android/app/src`，再定位源文件。
     *
     * 与 `MoreFeaturesNavigationGuardTest` 同一套：L0 与 Gradle 的工作目录不同，
     * 所以按「向上找标志目录」而不是写死相对路径。
     */
    private fun source(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(10) {
            dir?.let { current ->
                val candidate = File(current, "android/app/src/$relative")
                if (candidate.isFile) {
                    // 工作区是 core.autocrlf=true 检出的（部分文件 w/crlf）：先归一成 LF，
                    // 否则下面的「到列 0 的 } 为止」会按 "\n}\n" 切不到（CRLF 文件里没有它）。
                    return candidate.readText(Charsets.UTF_8).replace("\r\n", "\n")
                }
            }
            dir = dir?.parentFile
        }
        error("找不到壳源码 android/app/src/$relative（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        const val ShellWiringSource = "main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt"
        const val ShellActivitySource = "main/kotlin/com/mutx163/qingyu/pages/PagesShellActivity.kt"
        const val GridCatalog =
            "main/kotlin/com/mutx163/qingyu/pages/settings/SettingsHomeNavigationPage.kt"
        const val DockCatalog =
            "main/kotlin/com/mutx163/qingyu/pages/settings/SettingsGlassDockEditorPage.kt"

        /** 表里的一条：`"条目id" -> "页面id"`。 */
        val ENTRY = Regex(""""([A-Za-z0-9_:]+)"\s*->\s*"([A-Za-z0-9._-]+)"""")

        /** 候选目录的一条：`CatalogEntry("id"` / `DockCatalogEntry("id"`（数据类定义没有引号，天然不匹配）。 */
        val CATALOG_ENTRY = Regex("""(?:Dock)?CatalogEntry\(\s*"([A-Za-z0-9_:]+)"""")
    }
}
