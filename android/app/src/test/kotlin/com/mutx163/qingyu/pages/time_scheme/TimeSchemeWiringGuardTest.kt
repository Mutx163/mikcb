package com.mutx163.qingyu.pages.time_scheme

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **时间模板族壳接线守卫**（2026-11-04 建立，随 7 文件「收口 + 测试加固」批补齐）。
 *
 * ## 它防的是哪一类事故
 *
 * `2026-10-29-compose-time-scheme-audit.md` 抓到的 P0 实况：`ShellPageIndex.kt` 的
 * `d3.timeSchemes` 曾喂 `TimeSchemeManagementModel()` 空模型 + 7 个空回调，
 * `d3.locationMatch` 曾喂 `LocationTimeMatchModel()` 空模型 + 5 个空回调 ——
 * 表现是「页面打开永远空列表、点哪都没反应」。这类事故**不会让编译失败**，
 * 模型层/渲染层单测也全绿（空态也是合法状态）；错的是「谁把数据喂给页面」。
 *
 * ## 它钉住的接线事实（全部对当前 `ShellPageIndex.kt` 源码结构判）
 *
 * 1. `"d3.timeSchemes" ->` 分支必须调用真宿主 `TimeSchemeManagementHost(`，
 *    且「编辑节次」子页意图走 `pendingTimeSchemeEditId`（不是空回调）；
 * 2. `"d3.timeSchemeEditor" ->` 分支必须调用 `TimeSchemeEditorHost(`；
 * 3. `"d3.locationMatch" ->` 分支必须调用真宿主 `LocationTimeMatchHost(`，
 *    且真数据来自 `snapshot.locationTimeGroups` / `snapshot.timeSchemes`，
 *    写盘走 `onSaveGroups` → `updateLocationTimeGroups(` **且带 `resync = true`**；
 * 4. 「重新匹配当前课表」**已接入**（2026-11-05）：`onApplyActive` 必须是真执行入口
 *    （`LocationTimeApplyLogic.plan(` 算 + `replaceActiveProfileContent(` 落盘），
 *    不许退回 `null`（按钮恒不可用），也不许退化成空 `{}` 假成功；
 * 5. 三个分支里都不许再出现空模型构造 `TimeSchemeManagementModel(` / `LocationTimeMatchModel(`。
 *
 * ## 为什么要文本守卫而不是单测
 *
 * 「壳把一个空模型喂给页面」在类型系统里完全合法，只有看**调用点文本**才能区分
 * 「真宿主」与「假数据」。同仓先例：`TaskWiringGuardTest`、`DiagnosticsWiringGuardTest`、
 * `WarehouseWebLoginHostWiringGuardTest`。
 */
class TimeSchemeWiringGuardTest {

    /** `ShellPageIndex.kt` 去掉行注释后的源码（注释里写「原先喂空模型」不算复发）。 */
    private val indexSource: String by lazy { stripLineComments(readIndexSource()) }

    @Test
    fun `时间模板列表页在分派层走真宿主`() {
        val branch = branch("d3.timeSchemes", "d3.timeSchemeEditor")
        assertTrue(
            "ShellPageIndex.kt 的 d3.timeSchemes 分支没有调用 TimeSchemeManagementHost(——" +
                "列表页必须走真宿主（app/TimeSchemeHost.kt），不能喂空模型 + 空回调",
            branch.contains("TimeSchemeManagementHost("),
        )
        assertTrue(
            "「编辑节次」子页意图必须经 pendingTimeSchemeEditId 传递，而不是空回调",
            branch.contains("pendingTimeSchemeEditId"),
        )
    }

    @Test
    fun `编辑节次子页在分派层走真宿主`() {
        val branch = branch("d3.timeSchemeEditor", "d3.locationMatch")
        assertTrue(
            "ShellPageIndex.kt 的 d3.timeSchemeEditor 分支没有调用 TimeSchemeEditorHost(——" +
                "编辑节次子页必须走真宿主（app/TimeSchemeHost.kt）",
            branch.contains("TimeSchemeEditorHost("),
        )
    }

    @Test
    fun `地点作息匹配页走真宿主且接真数据`() {
        val branch = branch("d3.locationMatch", "d3.addExam")
        assertTrue(
            "d3.locationMatch 分支没有调用 LocationTimeMatchHost(——" +
                "地点匹配页必须走真宿主，不能喂 LocationTimeMatchModel() 空模型",
            branch.contains("LocationTimeMatchHost("),
        )
        assertTrue(
            "分组数据必须来自仓储快照 snapshot.locationTimeGroups",
            branch.contains("snapshot.locationTimeGroups"),
        )
        assertTrue(
            "模板名必须来自仓储快照 snapshot.timeSchemes",
            branch.contains("snapshot.timeSchemes"),
        )
        assertTrue(
            "增删改开关必须经 onSaveGroups 真写盘（updateLocationTimeGroups）",
            branch.contains("onSaveGroups") && branch.contains("updateLocationTimeGroups("),
        )
        assertTrue(
            "增删改开关落盘必须带 `resync = true`——少了它分组写进盘、课表时间却不重算，" +
                "用户看到「已保存 + 模板名变了」但课还是旧楼的节次（Dart 三个 CRUD 入口都跟着 resyncAllProfiles）",
            branch.contains("resync = true"),
        )
    }

    @Test
    fun `重新匹配当前课表必须接真执行入口`() {
        val branch = branch("d3.locationMatch", "d3.addExam")
        // 2026-11-05 前这里是 `onApplyActive = null`（诚实未接，按钮恒「不可用」）；
        // 现在能力已落地成 LocationTimeApplyLogic + 仓储写盘，守卫改为钉住「真接上」。
        assertFalse(
            "d3.locationMatch 分支又把 onApplyActive 写回 null——能力已落地，" +
                "退回 null 就是「按钮永远只回一句不可用、用户没有任何补救入口」",
            branch.contains("onApplyActive = null"),
        )
        assertTrue(
            "onApplyActive 必须是真执行入口（`onApplyActive = {`）；空 `{}` 是假成功，" +
                "会报「已重新匹配」而盘上没变",
            branch.contains("onApplyActive = {"),
        )
        assertTrue(
            "重新匹配必须经 LocationTimeApplyLogic.plan( 算（Dart applyToActiveProfile 的移植），" +
                "不许在壳里另写一套匹配",
            branch.contains("LocationTimeApplyLogic.plan("),
        )
        assertTrue(
            "算出来的课程必须真写盘（replaceActiveProfileContent()），否则「报了成功、盘上没变」",
            branch.contains("replaceActiveProfileContent("),
        )
    }

    @Test
    fun `三个分支都不许再出现空模型构造`() {
        // 只在各分支体内判，避免误伤 import / 注释 / 别处代码。
        val timeSchemes = branch("d3.timeSchemes", "d3.timeSchemeEditor")
        val editor = branch("d3.timeSchemeEditor", "d3.locationMatch")
        val locationMatch = branch("d3.locationMatch", "d3.addExam")
        for ((name, body) in listOf(
            "d3.timeSchemes" to timeSchemes,
            "d3.timeSchemeEditor" to editor,
            "d3.locationMatch" to locationMatch,
        )) {
            assertFalse(
                "$name 分支里又出现了空模型构造 TimeSchemeManagementModel(——这就是死页根因",
                body.contains("TimeSchemeManagementModel("),
            )
            assertFalse(
                "$name 分支里又出现了空模型构造 LocationTimeMatchModel(——这就是死页根因",
                body.contains("LocationTimeMatchModel("),
            )
        }
    }

    @Test
    fun `守卫本身没有空转`() {
        // 文本定位一旦因格式化失效，上面「分支里含某串」会全部变红（不会静默变绿），
        // 但仍钉一下「确实截到了有内容的三个分支」，防止 marker 改名后截出空串。
        val timeSchemes = branch("d3.timeSchemes", "d3.timeSchemeEditor")
        val locationMatch = branch("d3.locationMatch", "d3.addExam")
        assertTrue(
            "d3.timeSchemes 分支截出来太短（${timeSchemes.length} 字符），定位可能失效",
            timeSchemes.length >= 120,
        )
        assertTrue(
            "d3.locationMatch 分支截出来太短（${locationMatch.length} 字符），定位可能失效",
            locationMatch.length >= 150,
        )
    }

    // ------------------------------------------------------------------ 定位

    /** 截取 `"<start>" ->` 到下一个 `"<end>" ->` 之间的分支正文（含起止标记）。 */
    private fun branch(startId: String, endId: String): String {
        val startMarker = "\"$startId\" ->"
        val endMarker = "\"$endId\" ->"
        val start = indexSource.indexOf(startMarker)
        check(start >= 0) { "ShellPageIndex.kt 里找不到分支标记 $startMarker" }
        val end = indexSource.indexOf(endMarker, start + startMarker.length)
        check(end > start) { "ShellPageIndex.kt 里找不到 $startId 之后的 $endMarker" }
        return indexSource.substring(start, end)
    }

    private fun readIndexSource(): String {
        val candidates = listOf(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
        )
        var dir: File? = File("").absoluteFile
        repeat(8) {
            for (relative in candidates) {
                val candidate = File(dir, relative)
                if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            }
            dir = dir?.parentFile
        }
        error(
            "找不到 ShellPageIndex.kt（工作目录 ${File("").absolutePath}）；试过：\n" +
                candidates.joinToString("\n") { "  $it" },
        )
    }

    /** 去掉 `//` 行注释（保留换行）。分支里的注释说明「原先喂空模型」不算复发。 */
    private fun stripLineComments(text: String): String =
        text.lineSequence().joinToString("\n") { line -> line.substringBefore("//") }
}
