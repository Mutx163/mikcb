package com.mutx163.qingyu.pages.guide

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
 * 与 Compose，进不了 L0 的 JVM classpath（`scripts/test-kotlin-module.ps1` 会把整目录跳过）；
 * `ShellPageCatalog` 倒是纯 Kotlin，但它是 `pages/shell` 域的类型——guide 域的测试
 * 直接 import 它，guide 的 L0 就得把 shell 域整个拉进来（跨域引用治理，2026-11-03）。
 * 所以两处都读源码文本——与 `SettingsRouteWiringGuardTest` 同一套做法。
 *
 * **代价写清**：文本解析对格式敏感，表里必须写成 `"<id>" -> "<pageId>"` 且一行一条；
 * 目录条目必须保持 `page("P3-X", "<name>", "<标题>", ShellPageDataKind.<KIND>)` 的
 * 单调用形状。哪天改成多行拆装或动态拼装，这条会先红——那是故意的，提醒改的人同时更新这里。
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

    /** 壳页面目录里的一条（只取本守卫需要的字段；kind 用枚举名的文本）。 */
    private data class CatalogEntry(val id: String, val kind: String, val note: String?)

    /**
     * 解析 `ShellPageCatalog.kt` 的全部 `page(...)` 调用（`fun page(` 定义因首参不是
     * 带引号字符串而天然不匹配）。
     */
    private fun shellCatalogEntries(): List<CatalogEntry> {
        val text = shellCatalogSource()
        val entries = mutableListOf<CatalogEntry>()
        var index = text.indexOf("page(")
        while (index >= 0) {
            var depth = 1
            var cursor = index + "page(".length
            while (cursor < text.length && depth > 0) {
                when (text[cursor]) {
                    '(' -> depth++
                    ')' -> depth--
                }
                cursor++
            }
            parsePageCall(text.substring(index + "page(".length, cursor - 1))?.let { entries += it }
            index = text.indexOf("page(", cursor)
        }
        assertTrue("没在 ShellPageCatalog.kt 里解析出任何目录条目", entries.isNotEmpty())
        return entries
    }

    private fun parsePageCall(body: String): CatalogEntry? {
        val head = PAGE_CALL.find(body) ?: return null
        val (code, name, _, kind) = head.destructured
        val id = "${code.lowercase().removePrefix("p3-")}.$name"
        // note 只用于失败信息：命名参数或 kind 后的第一个位置参数，二选一。
        val note = NOTE_NAMED.find(body)?.groupValues?.get(1)
            ?: NOTE_POSITIONAL.find(body)?.groupValues?.get(1)
        return CatalogEntry(id, kind, note)
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
        val known = shellCatalogEntries().associateBy { it.id }
        val problems = mutableListOf<String>()
        for (id in featureItemIds()) {
            val target = table[id] ?: continue // 上一条断言负责报缺失
            val entry = known[target]
            when {
                entry == null -> problems += "$id -> $target（目录里没有这个页面 id）"
                entry.kind == "UNAVAILABLE" ->
                    problems += "$id -> $target（目录标着暂不可用：${entry.note ?: "没写原因"}）"
                entry.kind == "ALWAYS_VISIBLE" ->
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
        // 目录改文本解析后没有编译兜底了，条目总数自证解析没退化（当前 88 条，下限留余量）。
        assertTrue(
            "壳页面目录只解析出 ${shellCatalogEntries().size} 条（应 ≥ 80），正则可能失效",
            shellCatalogEntries().size >= 80,
        )
    }

    // ------------------------------------------------------------------ 定位

    /**
     * 从工作目录向上找 `android/app/src`，再定位壳的路由表 / 页面目录。
     *
     * 与 `SettingsRouteWiringGuardTest` 同一套：L0 与 Gradle 的工作目录不同，
     * 所以按「向上找标志目录」而不是写死相对路径；**找不到判失败，不静默跳过**。
     */
    private fun locateSource(relativeCandidates: List<String>): String {
        val candidates = relativeCandidates
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
            "找不到壳源码文件（工作目录 ${File("").absolutePath}）；试过：\n" +
                candidates.joinToString("\n") { "  android/app/src/$it" },
        )
    }

    private fun shellWiringSource(): String = locateSource(
        listOf(
            "main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
            "composeUi/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt",
        ),
    )

    private fun shellCatalogSource(): String = locateSource(
        listOf(
            "main/kotlin/com/mutx163/qingyu/pages/shell/ShellPageCatalog.kt",
            "composeUi/kotlin/com/mutx163/qingyu/pages/shell/ShellPageCatalog.kt",
        ),
    )

    private companion object {
        /** 表里的一条：`"条目id" -> "页面id"`。id 允许驼峰与小写点分。 */
        val ENTRY = Regex(""""([A-Za-z0-9_]+)"\s*->\s*"([A-Za-z0-9._-]+)"""")

        /**
         * `page("P3-X", "<name>", "<标题>", ShellPageDataKind.<KIND>` 的调用头。
         * `fun page(` 的参数表首参不是带引号字符串，天然不匹配。
         */
        val PAGE_CALL = Regex(
            "^\\s*\"([A-Za-z0-9-]+)\"\\s*,\\s*\"([A-Za-z0-9_.]+)\"\\s*," +
                "\\s*\"((?:[^\"\\\\]|\\\\.)*)\"\\s*,\\s*ShellPageDataKind\\.([A-Z_]+)",
        )

        /** note 的两种写法：命名参数，或 kind 后紧跟的位置参数（允许跨行）。 */
        val NOTE_NAMED = Regex("""note\s*=\s*"((?:[^"\\]|\\.)*)"""")
        val NOTE_POSITIONAL = Regex("""ShellPageDataKind\.[A-Z_]+\s*,\s*"((?:[^"\\]|\\.)*)"""")
    }
}
