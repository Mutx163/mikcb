package com.mutx163.qingyu.pages.schedule

import com.mutx163.qingyu.app.ScheduleEditDispatcher
import com.mutx163.qingyu.app.TimetableScheduleItemPort
import com.mutx163.qingyu.core.ScheduleItem
import com.mutx163.qingyu.core.TimetableProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDateTime

/**
 * 「单次编辑」判据守卫（2026-11-05 建立）。
 *
 * ## 防的是什么
 *
 * 审核发现：跨天（多日、不重复）日程从周视图点卡进入编辑页、改完保存，**只改到那一天**。
 * 成因是一条链：
 *
 * 1. 周网格给的是 `id@date`（`WeekAgendaModel.kt:148`），壳无条件写
 *    `pendingScheduleOccurrenceDate`（`ShellWiring.kt:900-916`）；
 * 2. 页面把 `occurrenceDate` **无条件**塞进草稿，而它自己判「单次编辑」要
 *    `isRecurring || seriesId != null` 成立才成立——跨天单次日程不成立，所以不弹范围框；
 * 3. 壳只按 `draft.occurrenceDate != null` 判「单次编辑」⇒ 走 `updateOccurrence`：
 *    造一条 `seriesId = 根 id` 的覆盖行，并给原条目打 `exceptionDate`。
 *
 * 用户看到的结果：编辑页里明明是「11-01 至 11-03」，保存后只有 11-02 这一天变了；其余日期
 * 还是旧内容；那条覆盖行又因 `ScheduleListGrouper` 跳过 `seriesId != null` 而在列表里看不见。
 *
 * ## 为什么是「行为测试 + 源码文本守卫」两层
 *
 * - **行为层**：把 `ScheduleEditDispatcher.save` 的分支钉住——`isOccurrenceEditing = false`
 *   必须是整条 `update`（一行、无 exception）；`true` 就会拆行。这证明**判据本身**的后果，
 *   第二条 test 是反证（咬合），不是回归。
 * - **源码层**：判据的计算点在 Compose 页面与壳（`AddScheduleItemPage.kt` / `ShellWiring.kt`
 *   都带 Android/Compose 依赖，进不了 JVM 单测 classpath），所以照本仓既有做法
 *   （`ScheduleDialogGuardTest`）钉源码形态：页面必须 `takeIf { isOccurrenceEditing }`、
 *   壳必须同时看 `isRecurring` / `seriesId`。
 *
 * ⚠️ 判据对格式敏感，只钉「必须出现 / 不得出现的最小集合」；改这两行时守卫会先红，
 * 提醒同步本文件——**不要为了变绿删断言**。
 *
 * 范围：只覆盖日程族的上述两处 + 一次性删除确认（同批 2026-11-05 的修改）。
 */
class ScheduleOccurrenceScopeTest {

    // ───────────────────────── 1. 行为层：判据错一次，数据就被拆一次 ─────────────────────────

    /** 修改点 1（判对）：跨天不重复条目按「整条」更新——不造覆盖行、不打 exception。 */
    @Test
    fun `跨天不重复条目按整条更新`() {
        val root = multiDayRoot()
        val port = FakePort(listOf(root))
        val edited = ScheduleItemBridge.toCore(editedDraft(occurrenceDate = null), preserveCreatedAt = root.createdAt)

        ScheduleEditDispatcher.save(
            port = port,
            item = edited,
            isNew = false,
            isOccurrenceEditing = false,
            applyToAll = null,
        )

        assertEquals(1, port.items.size)
        val saved = port.items.single()
        assertEquals("改后的标题", saved.title)
        assertTrue("整条更新不得给原条目打 exception", saved.exceptionDates.isEmpty())
        assertNull("整条更新不得写 occurrenceDate", saved.occurrenceDate)
        assertFalse("整条更新不得留下覆盖行", saved.isSeriesOverride)
    }

    /**
     * 反证（不是回归）：同一份草稿若被误判成单次编辑，条目就会被拆成两行。
     *
     * 这条不是在要求「行为应该这样」，而是把上面那条 test 的**咬合**摆明：两条断言方向相反，
     * 判据一歪，第一条必红。删掉本条也请连带重读 KDoc 里的成因链。
     */
    @Test
    fun `误判成单次编辑就会把跨天条目拆成两行`() {
        val root = multiDayRoot()
        val port = FakePort(listOf(root))
        val edited = ScheduleItemBridge.toCore(editedDraft(occurrenceDate = "2026-11-02"))

        ScheduleEditDispatcher.save(
            port = port,
            item = edited,
            isNew = false,
            isOccurrenceEditing = true,
            applyToAll = null,
        )

        assertEquals(2, port.items.size)
        assertTrue("误判会留下 seriesId 非空的覆盖行", port.items.any { it.isSeriesOverride })
        assertFalse(
            "误判会给原条目打 exceptionDate（那一天从此不再按原样出现）",
            port.items.first { !it.isSeriesOverride }.exceptionDates.isEmpty(),
        )
    }

    // ───────────────────────── 2. 源码层：判据必须真的这么算 ─────────────────────────

    @Test
    fun `页面只把发生日交给宿主的单次编辑分支`() {
        val text = File(repoRoot(), ADD_SCHEDULE).readText()

        val functionStart = text.indexOf("fun validateAndProceed(")
        assertTrue(
            "AddScheduleItemPage.kt 里找不到 validateAndProceed（判据锚点失效，" +
                "文件被改写/改名后必须同步本守卫，否则它空跑假绿）",
            functionStart >= 0,
        )
        val draftStart = text.indexOf("val draft = ScheduleItemData(", functionStart)
        assertTrue("validateAndProceed 里找不到整条草稿的构造（判据锚点失效）", draftStart > functionStart)
        val scopeBranch = text.indexOf("if (isOccurrenceEditing) {", draftStart)
        assertTrue("找不到整条草稿之后的单次编辑分支（判据锚点失效）", scopeBranch > draftStart)

        val wholeItemDraft = text.substring(draftStart, scopeBranch)
        assertTrue(
            "「新建 / 编辑整条」的草稿必须写成 occurrenceDate = occurrenceDate.takeIf { isOccurrenceEditing }，" +
                "否则跨天（或单日）的单次日程会被壳判成单次编辑并被拆行",
            wholeItemDraft.contains(TAKE_IF_OCCURRENCE),
        )
        assertFalse(
            "「新建 / 编辑整条」的草稿又把 occurrenceDate 无条件带上了（跨天单次日程会被拆行）",
            wholeItemDraft.contains(RAW_OCCURRENCE),
        )
    }

    @Test
    fun `壳按重复系列判单次编辑而不是只看草稿有没有日期`() {
        val text = File(repoRoot(), SHELL_WIRING).readText()
        assertTrue(
            "ShellWiring.kt 里找不到 `isOccurrenceEditing = draft.occurrenceDate != null &&`（判据锚点失效）",
            text.contains(SHELL_DATE_GUARD),
        )
        assertTrue(
            "ShellWiring.kt 的 isOccurrenceEditing 必须同时看目标是不是重复系列" +
                "（`existing?.isRecurring == true || existing?.seriesId != null`）",
            text.contains(SHELL_SERIES_GUARD),
        )
    }

    // ───────────────────────── 3. 同批：一次性删除必须先确认 ─────────────────────────

    @Test
    fun `一次性删除走官方 OverlayDialog 确认而不是直接删`() {
        val text = File(repoRoot(), ADD_SCHEDULE).readText()
        assertTrue(
            "AddScheduleItemPage.kt 里找不到删除确认态 `showDeleteConfirmDialog`；" +
                "发布版 `_confirmDelete` 会先弹确认框，误触顶栏垃圾桶不应立刻删数据",
            text.contains("showDeleteConfirmDialog"),
        )
        assertTrue(
            "删除确认框应复用现成文案键 deleteScheduleTitle / deleteScheduleMessage（不新增文案）",
            text.contains("ScheduleStrings.deleteScheduleTitle.text") &&
                text.contains("ScheduleStrings.deleteScheduleMessage"),
        )
        assertTrue(
            "删除确认按钮必须是破坏性红色（ScheduleActionButton(destructive = true)）",
            text.contains("destructive = true"),
        )
    }

    // ------------------------------------------------------------------
    // 夹具
    // ------------------------------------------------------------------

    /** 跨天、不重复（NONE）的单次日程：11-01 至 11-03。 */
    private fun multiDayRoot(): ScheduleItem = ScheduleItem(
        id = "item-1",
        title = "旧标题",
        startDate = LocalDateTime.of(2026, 11, 1, 0, 0),
        endDate = LocalDateTime.of(2026, 11, 3, 0, 0),
        startTime = "09:00",
        endTime = "10:00",
        createdAt = LocalDateTime.of(2026, 10, 1, 8, 0),
        updatedAt = LocalDateTime.of(2026, 10, 1, 8, 0),
    )

    /** 页面产出的草稿（只改标题，日期原样带回）。 */
    private fun editedDraft(occurrenceDate: String?) = ScheduleItemData(
        id = "item-1",
        title = "改后的标题",
        startDate = "2026-11-01",
        endDate = "2026-11-03",
        startTime = "09:00",
        endTime = "10:00",
        occurrenceDate = occurrenceDate,
    )

    /** 最小端口：只做内存替换，落盘/通知/埋点全为空实现（这里是判据测试，不测存储）。 */
    private class FakePort(initial: List<ScheduleItem>) : TimetableScheduleItemPort {
        override var scheduleItems: List<ScheduleItem> = initial
        override var profiles: List<TimetableProfile> = emptyList()
        override fun initialize() = Unit
        override fun persistActiveProfileState() = Unit
        override fun notifyStateChanged() = Unit
        override fun logEvent(name: String, parameters: Map<String, Any>) = Unit
        override fun syncExamReminders() = Unit

        val items: List<ScheduleItem> get() = scheduleItems
    }

    private fun repoRoot(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "android/app/src").isDirectory) {
                var up: File? = dir
                while (up != null) {
                    if (File(up, "lib/screens").isDirectory && File(up, "pubspec.yaml").isFile) {
                        return up.path
                    }
                    up = up.parentFile
                }
                return dir.path
            }
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（android/app/src）——守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private companion object {
        const val ADD_SCHEDULE =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/AddScheduleItemPage.kt"
        const val SHELL_WIRING =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellWiring.kt"

        const val TAKE_IF_OCCURRENCE = "occurrenceDate = occurrenceDate.takeIf { isOccurrenceEditing }"
        const val RAW_OCCURRENCE = "occurrenceDate = occurrenceDate,"
        const val SHELL_DATE_GUARD = "isOccurrenceEditing = draft.occurrenceDate != null &&"
        const val SHELL_SERIES_GUARD = "existing?.isRecurring == true || existing?.seriesId != null"
    }
}
