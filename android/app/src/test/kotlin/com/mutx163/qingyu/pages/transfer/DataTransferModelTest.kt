package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * 数据备份与迁移页模型层单元测试。
 *
 * 期望值从 Dart 源手推（`lib/screens/data_transfer_screen.dart`、
 * `lib/screens/transfer_preview_dialog.dart`、`lib/services/data_transfer_service.dart`），
 * 不从 Kotlin 实现里抄：
 * - `_splitOverviewLabelValue`（data_transfer_screen.dart:200-218）：先找全角「：」，再找「: 」。
 * - `_buildOverviewRow` 的 7 条文案（158-191）与 `_formatDate`（835-837，`yyyy-MM-dd`）。
 * - `_shareTransferPackage`（290-317）：文件名 `前缀-yyyyMMdd-HHmm.mikcb`。
 * - `_chooseQrScope`（696-736）：四个可选项与其顺序。
 * - `_previewAndApply` 的恢复提示拼装（640-661）。
 * - `showTransferPreviewDialog`（transfer_preview_dialog.dart:18-34）：message 由固定行 + 摘要拼成。
 */
class DataTransferModelTest {

    // ── 概览行的「标签 / 取值」拆分 ──

    @Test
    fun `全角冒号优先拆分`() {
        assertEquals(
            "课程数量" to "12 门",
            DataTransferLogic.splitOverviewLabelValue("课程数量：12 门"),
        )
    }

    @Test
    fun `半角冒号加空格也能拆`() {
        assertEquals(
            "开始日期" to "2026-10-27",
            DataTransferLogic.splitOverviewLabelValue("开始日期: 2026-10-27"),
        )
    }

    @Test
    fun `没有冒号时整句作为取值`() {
        assertEquals("" to "没有冒号", DataTransferLogic.splitOverviewLabelValue("没有冒号"))
    }

    @Test
    fun `取值两端空白会被裁掉`() {
        assertEquals("A" to "b", DataTransferLogic.splitOverviewLabelValue("A：  b  "))
    }

    @Test
    fun `全角冒号与半角冒号同时出现时按全角拆`() {
        assertEquals(
            "标题" to "x: y",
            DataTransferLogic.splitOverviewLabelValue("标题：x: y"),
        )
    }

    // ── 概览七行 ──

    private fun overviewInput(
        courseCount: Int = 12,
        activeProfileName: String? = "2026 春",
        profileCount: Int = 3,
        timeSchemeCount: Int = 2,
        currentWeek: Int = 5,
        semesterStartDate: LocalDate? = LocalDate.of(2026, 3, 2),
    ) = TransferOverviewInput(
        courseCount = courseCount,
        activeProfileName = activeProfileName,
        profileCount = profileCount,
        timeSchemeCount = timeSchemeCount,
        currentWeek = currentWeek,
        semesterStartDate = semesterStartDate,
    )

    @Test
    fun `概览按 Dart 原文给出七行`() {
        val rows = DataTransferLogic.overviewRows(overviewInput())
        assertEquals(
            listOf(
                TransferOverviewRow("课程数量", "12 门"),
                TransferOverviewRow("当前课表", "2026 春"),
                TransferOverviewRow("全部课表", "3 个"),
                TransferOverviewRow("时间模板", "2 套"),
                TransferOverviewRow("当前周", "第 5 周"),
                TransferOverviewRow("开学日期", "2026-03-02"),
                TransferOverviewRow("文件后缀", ".mikcb"),
            ),
            rows,
        )
    }

    @Test
    fun `没设开学日期时该行显示未设置`() {
        val rows = DataTransferLogic.overviewRows(overviewInput(semesterStartDate = null))
        assertTrue(rows.any { it.label == "开学日期" && it.value == "未设置" })
    }

    @Test
    fun `没有当前课表时用产品名兜底`() {
        val rows = DataTransferLogic.overviewRows(overviewInput(activeProfileName = null))
        assertTrue(rows.any { it.label == "当前课表" && it.value == "轻屿课表" })
    }

    @Test
    fun `日期按补零的年月日渲染`() {
        assertEquals("2026-10-07", DataTransferLogic.formatDate(LocalDate.of(2026, 10, 7)))
        assertEquals("2026-01-01", DataTransferLogic.formatDate(LocalDate.of(2026, 1, 1)))
    }

    // ── 分享文件名 ──

    @Test
    fun `分享文件名带前缀与分钟级时间戳`() {
        assertEquals(
            "mikcb-backup-20261027-1130.mikcb",
            DataTransferLogic.buildShareFileName(
                prefix = "mikcb-backup",
                now = LocalDateTime.of(2026, 10, 27, 11, 30),
            ),
        )
    }

    @Test
    fun `时间戳月日时分都补零`() {
        assertEquals(
            "mikcb-full-backup-20260105-0905.mikcb",
            DataTransferLogic.buildShareFileName(
                prefix = "mikcb-full-backup",
                now = LocalDateTime.of(2026, 1, 5, 9, 5),
            ),
        )
    }

    @Test
    fun `文件后缀是 mikcb`() {
        assertEquals("mikcb", DataTransferLogic.FILE_EXTENSION)
    }

    @Test
    fun `整表备份与时间模板各有自己的文件名前缀`() {
        assertEquals(
            "mikcb-full-backup",
            DataTransferLogic.shareFilePrefix(TransferScope.ALL_DATA, isFullBackup = true),
        )
        assertEquals(
            "mikcb-timescheme",
            DataTransferLogic.shareFilePrefix(TransferScope.TIME_TEMPLATE, isFullBackup = false),
        )
        assertEquals(
            "mikcb-backup",
            DataTransferLogic.shareFilePrefix(TransferScope.CURRENT_TIMETABLE, isFullBackup = false),
        )
    }

    // ── 二维码发送的 scope 选项 ──

    @Test
    fun `二维码发送弹窗四个选项按 Dart 顺序`() {
        val options = DataTransferLogic.qrScopeOptions()
        assertEquals(
            listOf(
                TransferScope.WEEK_TIMETABLE,
                TransferScope.SELECTED_COURSES,
                TransferScope.TIME_TEMPLATE,
                TransferScope.CURRENT_TIMETABLE,
            ),
            options.map { it.scope },
        )
        assertEquals(
            listOf("分享本周课表", "分享勾选的课程", "分享时间模板", "二维码发送当前课表"),
            options.map { it.label },
        )
    }

    @Test
    fun `只有勾选课程这一项需要先选课`() {
        val options = DataTransferLogic.qrScopeOptions()
        val needsPick = options.filter { it.requiresCourseSelection }.map { it.scope }
        assertEquals(listOf(TransferScope.SELECTED_COURSES), needsPick)
    }

    // ── 导入完成后的提示拼装 ──

    @Test
    fun `导入成功的默认提示`() {
        val notice = DataTransferLogic.restoredNotice(
            beyondSchemeCount = 0,
            sectionCount = 10,
            droppedCount = 0,
        )
        assertEquals("导入成功，备份数据已恢复", notice.message)
        assertFalse(notice.isWarning)
    }

    @Test
    fun `超出作息范围时追加说明并降级为警告`() {
        val notice = DataTransferLogic.restoredNotice(
            beyondSchemeCount = 2,
            sectionCount = 10,
            droppedCount = 0,
        )
        assertEquals(
            "导入成功，备份数据已恢复，另有 2 节超出当前作息范围 共 10 节，课表暂不显示",
            notice.message,
        )
        assertTrue(notice.isWarning)
    }

    @Test
    fun `有损坏条目被跳过时追加说明并降级为警告`() {
        val notice = DataTransferLogic.restoredNotice(
            beyondSchemeCount = 0,
            sectionCount = 10,
            droppedCount = 3,
        )
        assertEquals("导入成功，备份数据已恢复，其中 3 条格式损坏已跳过", notice.message)
        assertTrue(notice.isWarning)
    }

    @Test
    fun `两种后缀同时出现时按超出作息在前损坏在后拼接`() {
        val notice = DataTransferLogic.restoredNotice(
            beyondSchemeCount = 2,
            sectionCount = 8,
            droppedCount = 1,
        )
        assertEquals(
            "导入成功，备份数据已恢复，另有 2 节超出当前作息范围 共 8 节，课表暂不显示，其中 1 条格式损坏已跳过",
            notice.message,
        )
    }

    // ── 预览弹窗 ──

    @Test
    fun `单个实体的差异摘要按 新增 更新 删除 三段拼`() {
        assertEquals(
            "course: +2 / ~1 / -0",
            DataTransferLogic.diffSummaryLine(TransferDiffSummary("course", 2, 1, 0)),
        )
    }

    @Test
    fun `多实体摘要逐行拼接`() {
        assertEquals(
            "course: +2 / ~1 / -0\nexam: +0 / ~0 / -1",
            DataTransferLogic.diffSummary(
                listOf(
                    TransferDiffSummary("course", 2, 1, 0),
                    TransferDiffSummary("exam", 0, 0, 1),
                ),
            ),
        )
    }

    @Test
    fun `预览弹窗正文包含通道 scope 与传输号`() {
        val content = DataTransferLogic.previewContent(
            channel = "file",
            scope = "current_timetable",
            transferId = "transfer-1-2",
            overwrite = listOf(TransferDiffSummary("course", 2, 1, 0)),
        )
        assertEquals("选择导入方式", content.title)
        assertEquals(
            listOf(
                "你可以覆盖当前课表，或者把备份导入成一个新的独立课表",
                "channel=file",
                "scope=current_timetable",
                "transferId=transfer-1-2",
                "course: +2 / ~1 / -0",
            ),
            content.message.split("\n\n"),
        )
    }

    @Test
    fun `同时给了两种模式时先 merge 再 overwrite`() {
        val content = DataTransferLogic.previewContent(
            channel = "qr",
            scope = "current_timetable",
            transferId = "transfer-9-9",
            overwrite = listOf(TransferDiffSummary("course", 2, 0, 0)),
            merge = listOf(TransferDiffSummary("course", 0, 1, 0)),
        )
        val blocks = content.message.split("\n\n")
        assertEquals("merge:\ncourse: +0 / ~1 / -0", blocks[4])
        assertEquals("overwrite:\ncourse: +2 / ~0 / -0", blocks[5])
    }

    @Test
    fun `预览弹窗三个动作的顺序与结果`() {
        val actions = DataTransferLogic.previewActions()
        assertEquals(
            listOf("取消", "合并更改", "覆盖当前课表"),
            actions.map { it.label },
        )
        assertNull(actions[0].mode)
        assertEquals(TransferApplyMode.MERGE, actions[1].mode)
        assertEquals(TransferApplyMode.OVERWRITE, actions[2].mode)
    }
}
