package com.mutx163.qingyu.pages.transfer

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **「导入为新课表」接线守卫**（2026-11-06 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 这条动作的落盘点与「覆盖当前课表」**完全不同**：不是写当前档，而是
 * `replaceAllProfilesAndSettings(...)` 多出一份新档并切过去；撤销也必须整份还原档案表
 * （按单档内容还原会把新档写成旧档、新档还留着）。这三件事**编译都不会红**，
 * 只有看宿主源码才能发现接错，所以用文本守卫钉住，同仓先例 `TimeSchemeWiringGuardTest`。
 *
 * ## 钉住的事实
 *
 * 1. 宿主里有真正的执行入口 `applyImportAsNew(`；
 * 2. 该入口里必须调 `replaceAllProfilesAndSettings(`（新建档案表，而不是写当前档内容）；
 * 3. 该入口里必须用 `TransferUndoScope.FULL_PROFILES` 抓撤销快照；
 * 4. 该入口里必须 `writeRawSettingsPatch(` 铺本机全局偏好（否则新档丢外观 / 语言）；
 * 5. 「导入为新课表」只由 `ImportEntry.EXTERNAL_OPEN` 那条入口开启，且经
 *    `importAsNewRejectionCode(` 兜底（全量包防御）。
 */
class DataTransferAsNewWiringGuardTest {

    /** 宿主源码去 `//` 行注释：注释里写「原先没接」不算复发。 */
    private val hostSource: String by lazy { stripLineComments(readRepoFile(HOST_PATH)) }

    @Test
    fun `导入为新课表必须走真执行入口`() {
        assertTrue(
            "DataTransferHost 里没有 applyImportAsNew(——动作摆出来却没有落盘实现",
            hostSource.contains("applyImportAsNew("),
        )
    }

    @Test
    fun `执行入口新建档案表并整份抓撤销快照`() {
        // 注意：`applyImportAsNew` 排在 `applyImport` **之后**、`reconcileTimeSchemes` 之前；
        // 切片结束标记必须跟着函数位置走，否则截到空串会让下面四条断言一起假失败。
        val body = functionBody("private fun applyImportAsNew(", "private fun reconcileTimeSchemes(")
        assertTrue(
            "as-new 必须用 replaceAllProfilesAndSettings( 多出一份档案（写当前档内容就是错的语义）",
            body.contains("replaceAllProfilesAndSettings("),
        )
        assertTrue(
            "as-new 的撤销快照必须是 TransferUndoScope.FULL_PROFILES（整份档案表）",
            body.contains("TransferUndoScope.FULL_PROFILES"),
        )
        assertTrue(
            "as-new 必须把本机全局偏好铺到新档（writeRawSettingsPatch），否则新档丢外观 / 语言",
            body.contains("writeRawSettingsPatch("),
        )
        assertTrue(
            "as-new 必须经 planImportAsNew 建新档（纯逻辑层，别在宿主里手搓）",
            body.contains("DataTransferApplyLogic.planImportAsNew("),
        )
    }

    @Test
    fun `入口只在外部打开备份时开启且全量包有防御`() {
        assertTrue(
            "外部打开备份必须传 ImportEntry.EXTERNAL_OPEN（否则那条入口看不到这条动作）",
            hostSource.contains("ImportEntry.EXTERNAL_OPEN"),
        )
        assertTrue(
            "预览弹窗必须按入口决定是否给「导入为新课表」（canImportAsNew = …）",
            hostSource.contains("canImportAsNew ="),
        )
        assertTrue(
            "全量备份的防御判据必须接 importAsNewRejectionCode(",
            hostSource.contains("DataTransferApplyLogic.importAsNewRejectionCode("),
        )
        // 三处判据不仅要有 entry，**方向也必须对**（只验字面量出现会把「==」写成「!=」也放过）：
        // 1) 弹窗按钮 canMerge：外部打开必须 `!=`（关掉合并）；
        // 2) 弹窗 canImportAsNew：外部打开必须 `==`（只有它开）；
        // 3) 正文局部 canMerge：外部打开必须 `!=`（正文不许出现合并段）。
        for ((label, anchor, direction) in listOf(
            Triple("弹窗按钮 canMerge", "canMerge = pendingImport", "!="),
            Triple("弹窗 canImportAsNew", "canImportAsNew = pendingImport", "=="),
            Triple("正文局部 canMerge", "val canMerge =", "!="),
        )) {
            val at = hostSource.indexOf(anchor)
            check(at >= 0) { "DataTransferHost.kt 里找不到「$label」（$anchor）" }
            val expr = hostSource.substring(at, minOf(at + 260, hostSource.length))
            assertTrue(
                "「$label」的判据方向必须是 `entry $direction ImportEntry.EXTERNAL_OPEN`（外部打开必须与其它入口区别开）：$expr",
                expr.contains("entry $direction ImportEntry.EXTERNAL_OPEN"),
            )
        }
        // 外部打开这条入口的正文必须是发布版那句话（selectImportModeMessage），不带 channel/scope/差异段。
        assertTrue(
            "外部打开备份的预览正文必须只用 selectImportModeMessage（发布版那条弹框正文只有一句）",
            hostSource.contains("if (entry == ImportEntry.EXTERNAL_OPEN)") &&
                hostSource.contains("TransferStrings.selectImportModeMessage"),
        )
    }

    @Test
    fun `会重排所有档的导入必须整份抓快照`() {
        // 2026-11-06 三轮返工：resync=true 改所有档钟点，快照必须同时覆盖所有档。
        val body = functionBody("private fun applyImport(", "private fun applyImportAsNew(")
        assertTrue(
            "applyImport 必须按 resync 判据决定快照范围（找不到 rewritesAllProfiles = willResyncAllProfiles）",
            body.contains("rewritesAllProfiles = willResyncAllProfiles"),
        )
        assertTrue(
            "判据必须来自 planWrites 的 locationTimeGroups / all_data（找不到 locationTimeGroups.isNotEmpty()）",
            body.contains("locationTimeGroups.isNotEmpty()"),
        )
    }

    // ── 2026-11-06 返工：模板表整份还原 / 不许改写本机模板 / 回滚码不许吞 ──

    @Test
    fun `回滚必须逐步尽力还原_不许一挂全停`() {
        val body = functionBody("private fun restoreFromSnapshot(", "private fun sectionCountOf(")
        assertTrue(
            "restoreFromSnapshot 没有「每步各自 catch、失败继续」的结构（找不到内联的 fun step(）——" +
                "一个 runCatching 包全部的话，第一笔写挂后面全不还原 = 半还原",
            body.contains("fun step("),
        )
        assertTrue(
            "restoreFromSnapshot 必须聚合各步结果（找不到 allSucceeded）",
            body.contains("allSucceeded"),
        )
        assertTrue(
            "restoreFromSnapshot 又退回「单个 runCatching 包全部」的旧写法了（出现了 `}.isSuccess`）",
            !body.contains("}.isSuccess"),
        )
    }

    @Test
    fun `撤销与回滚必须整份还原时间模板表`() {
        val body = functionBody("private fun restoreFromSnapshot(", "private fun sectionCountOf(")
        assertTrue(
            "restoreFromSnapshot 没有整份写回模板表（找不到 replaceTimeSchemes）——" +
                "导入新建的模板会永久留在本机、救不回来",
            body.contains("replaceTimeSchemes"),
        )
        assertTrue(
            "还原模板表必须走快照里的 timeSchemes（不能拿当前表瞎猜）",
            body.contains("snapshot.timeSchemes"),
        )
    }

    @Test
    fun `对模板表只许新建_不许改写本机已有模板`() {
        val body = functionBody("private fun reconcileTimeSchemes(", "private fun undoImport(")
        assertTrue(
            "reconcileTimeSchemes 里又出现了 updateTimeScheme(——那会改写用户已有模板的" +
                "name/sections，违反「本机有→复用」的三段设计，且回滚救不回",
            !body.contains("updateTimeScheme("),
        )
        assertTrue(
            "落盘哪些模板必须经 timeSchemeStepsToCreate(（只返回 Create），别在宿主里手搓",
            body.contains("DataTransferApplyLogic.timeSchemeStepsToCreate("),
        )
    }

    @Test
    fun `回滚失败必须报 import_rollback_incomplete_不许吞`() {
        for ((name, body) in listOf(
            "applyImport" to functionBody("private fun applyImport(", "private fun applyImportAsNew("),
            "applyImportAsNew" to functionBody("private fun applyImportAsNew(", "private fun reconcileTimeSchemes("),
        )) {
            assertTrue(
                "$name 的失败分支没有把 restoreFromSnapshot 的布尔结果翻成 " +
                    "`import_rollback_incomplete`——回滚不完整却报成普通导入失败，用户不知道数据可能只回了一半",
                body.contains("import_rollback_incomplete"),
            )
        }
    }

    // ------------------------------------------------------------------ 定位

    private fun functionBody(startMarker: String, endMarker: String): String {
        val start = hostSource.indexOf(startMarker)
        check(start >= 0) { "DataTransferHost.kt 里找不到 $startMarker" }
        val end = hostSource.indexOf(endMarker, start + startMarker.length)
        check(end > start) { "找不到 $startMarker 之后的 $endMarker" }
        return hostSource.substring(start, end)
    }

    private fun readRepoFile(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private fun stripLineComments(text: String): String =
        text.lineSequence().joinToString("\n") { line -> line.substringBefore("//") }

    private companion object {
        const val HOST_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferHost.kt"
    }
}
