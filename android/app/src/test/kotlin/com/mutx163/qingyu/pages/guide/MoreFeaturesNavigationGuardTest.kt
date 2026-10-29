package com.mutx163.qingyu.pages.guide

import com.mutx163.qingyu.pages.shell.ShellPageCatalog
import com.mutx163.qingyu.pages.shell.ShellPageDataKind
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「全部功能」页**每条都跳得出去**的契约守卫（2026-10-29 建）。
 *
 * ## 它防的是哪一类事故
 *
 * 「全部功能」（`MoreFeaturesWithSearch`）是一张索引：39 行，每行一个 `item.id`。
 * 点一行 → 壳用一张 id→页面 id 的表（`ShellWiring.shellTimetableMenuPageId`）翻成页面，
 * 再交给分派层（`ShellPageIndex.kt`）渲染。这条链上有三处**编译期查不出来**的断点：
 *
 * 1. 条目 id 在表里没有 → 点了**完全没反应**（2026-10-29 之前的真实现状：
 *    `onOpenFeature = {}` 是空 lambda，整页 39 行全死）；
 * 2. 表里的目标页面 id 在 `ShellPageCatalog` 里不存在 → 点了进 `ShellMissingPage`；
 * 3. 目标页面标着「暂不可用」→ 用户以为能进，进去一片空白。
 *
 * 这里把 1、2、3 全钉成机器可判的断言。**第 4 环（目录 → 分派分支）由
 * `ShellPageDispatchCoverageTest` 保证**：目标在目录里且可进入 ⇒ 分派层一定有分支。
 * 两条守卫合起来才等于「点每一行都跳到对的页」。
 *
 * ## 为什么读文本而不是直接调函数
 *
 * `shellTimetableMenuPageId` 住在 `ShellWiring.kt`，那个文件 import 了 `android.*`
 * 与 Compose，进不了 L0 的 JVM classpath（`scripts/test-kotlin-module.ps1` 会把整目录跳过）。
 * 所以这里读源码文本——与 `SettingsRouteWiringGuardTest` 同一套做法。
 *
 * **代价写清**：文本解析对格式敏感，表里必须写成 `"<id>" -> "<pageId>"` 且一行一条；
 * 哪天改成多行或动态拼装，这条会先红——那是故意的，提醒改的人同时更新这里。
 */
class MoreFeaturesNavigationGuardTest {

    /** 全部功能页里真实存在的条目 id（顺序 = 界面顺序）。 */
    private fun featureItemIds(): List<String> =
        MoreFeaturesModel.buildDefaultFeatureGroups()
            .flatMap { group -> group.items }
            .map { it.id }

    /** 壳的 id → 页面 id 表（解析源码文本）。 */
    private fun shellMenuTable(): Map<String, String> {
        val text = shellWiringSource()
        val body = text.substringAfter("fun shellTimetableMenuPageId", "")
        assertTrue(
            "没在 ShellWiring.kt 里找到 shellTimetableMenuPageId",
            body.isNotBlank(),
        )
        // 只取函数体：从 { 到配对的 } —— 用「下一个顶层 fun」截断更简单可靠。
        val untilNextTopLevel = body.substringBefore("\nfun ")
        return ENTRY.findAll(untilNextTopLevel).associate { it.groupValues[1] to it.groupValues[2] }
    }

    // ------------------------------------------------------------------ 守卫

    @Test
    fun `每个功能条目都能解析到壳页面`() {
        val table = shellMenuTable()
        assertTrue("壳的 id→页面表解析为空，正则可能失效", table.size >= 30)
        val missing = featureItemIds().filter { it !in table.keys }
        assertEquals(
            "以下「全部功能」条目在 shellTimetableMenuPageId 里没有落点（点了没反应）：\n" +
                missing.joinToString("\n") { "  $it" },
            emptyList<String>(),
            missing,
        )
    }

    @Test
    fun `每个目标页面都在壳目录里且标着可进入`() {
        val table = shellMenuTable()
        val known = ShellPageCatalog.batches.flatMap { it.pages }.associateBy { it.id }
        val problems = mutableListOf<String>()
        for (id in featureItemIds()) {
            val target = table[id] ?: continue // 上一条断言负责报缺失
            val entry = known[target]
            when {
                entry == null -> problems += "$id -> $target（目录里没有这个页面 id）"
                entry.kind == ShellPageDataKind.UNAVAILABLE ->
                    problems += "$id -> $target（目录标着暂不可用：${entry.note}）"
                entry.kind == ShellPageDataKind.ALWAYS_VISIBLE ->
                    problems += "$id -> $target（常驻槽位不是可推的页）"
            }
        }
        assertEquals(
            "「全部功能」里这些行跳不到一个真页面：\n" + problems.joinToString("\n") { "  $it" },
            emptyList<String>(),
            problems,
        )
    }

    @Test
    fun `关键条目的落点与Dart目录一致`() {
        // 逐条对照 lib/widgets/home_menu_catalog.dart 里同名条目的 open 目标。
        // 这组是「用户抱怨找不到」的高频入口，落错页比不跳更难发现。
        val expected = mapOf(
            "overview" to "d1.overview",
            "statistics" to "e.statistics",
            "profiles" to "c1.profiles",
            "timeSchemes" to "d3.timeSchemes",
            "locationTimeMatch" to "d3.locationMatch",
            "scheduleDateRule" to "d2.dateRule",
            "exams" to "d3.examList",
            "tasks" to "d2.taskList",
            "scheduleList" to "d2.scheduleList",
            "courseConflict" to "k.conflict",
            "monthView" to "c2.month",
            "pickupCode" to "g3.pickupCodes",
            "liveSettings" to "b.live",
            "homeWidgetSettings" to "b.homeWidget",
            "importCourses" to "g1.importEntry",
            "icsExport" to "g3.icsExport",
            "dataTransfer" to "g3.dataTransfer",
            "cloudSync" to "f.cloudSync",
            "lanEdit" to "g3.lanEdit",
            "aboutApp" to "a.about",
            "changelog" to "a.changelog",
            "feedback" to "k.feedback",
            "openSourceLicenses" to "a.licenses",
            "support" to "a.support",
            "memoryStats" to "h.memory",
            "userGuide" to "i.userGuide",
            "update" to "a.update",
        )
        val table = shellMenuTable()
        val wrong = expected.filter { (id, page) -> table[id] != page }
            .map { (id, page) -> "$id 期望 $page，实际 ${table[id]}" }
        assertEquals(
            "以下条目跳到了错的页：\n" + wrong.joinToString("\n") { "  $it" },
            emptyList<String>(),
            wrong,
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        // 防空转：如果条目表被改成空、或正则失效返回空 map，上面几条「零违规」会全部变绿。
        val ids = featureItemIds()
        assertTrue("功能条目太少（${ids.size}），模型可能被改坏", ids.size >= 35)
        assertTrue("功能条目 id 有重复：${ids.groupBy { it }.filterValues { it.size > 1 }.keys}", ids.size == ids.toSet().size)
        assertTrue("壳的 id→页面表条目太少（${shellMenuTable().size}）", shellMenuTable().size >= 30)
    }

    // ------------------------------------------------------------------ 定位

    /**
     * 从工作目录向上找 `android/app/src`，再定位壳的路由表。
     *
     * 与 `SettingsRouteWiringGuardTest` 同一套：L0 与 Gradle 的工作目录不同，
     * 所以按「向上找标志目录」而不是写死相对路径；**找不到判失败，不静默跳过**。
     */
    private fun shellWiringSource(): String {
        val candidates = listOf(
            "main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
            "composeUi/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
        )
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (dir != null) {
                val src = File(dir, "android/app/src")
                if (src.isDirectory) {
                    for (relative in candidates) {
                        val file = File(src, relative)
                        if (file.isFile) return file.readText(Charsets.UTF_8)
                    }
                }
            }
            dir = dir?.parentFile
        }
        error(
            "找不到 ShellWiring.kt（工作目录 ${File("").absolutePath}）；试过：\n" +
                candidates.joinToString("\n") { "  android/app/src/$it" },
        )
    }

    private companion object {
        /** 表里的一条：`"条目id" -> "页面id"`。id 允许驼峰与小写点分。 */
        val ENTRY = Regex(""""([A-Za-z0-9_]+)"\s*->\s*"([A-Za-z0-9._-]+)"""")
    }
}
