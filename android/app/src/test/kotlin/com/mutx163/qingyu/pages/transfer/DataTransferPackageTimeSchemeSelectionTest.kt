package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * **单套时间模板分享**的拼包选材（2026-11-10，D22 接线随行）。
 *
 * ## 它防的是哪一类事故
 *
 * 时间模板页的「分享」在 Dart 里是
 * `buildCurrentPackage(scope: timeTemplate, selectedTimeSchemeIds: [scheme.id])`
 * （`time_scheme_management_screen.dart` `_shareTimeSchemeAsFile` / `_shareTimeSchemeAsQr`）。
 * Kotlin 的拼包器原先只有 `selectedCourseIds`，没有模板收窄参数——直接复用 `TIME_TEMPLATE`
 * 会把用户的**所有**作息一起打进包发给对方。这不会编译失败、不会崩，
 * 现有单测也全绿（「全带」本身就是合法包）；错的是**分享粒度**，只有对包内容断言才看得出来。
 *
 * ## 期望值从哪来（人推，不抄实现）
 *
 * - 夹具三条作息 `ts1`（默认）/`ts2`（夏季）/`ts3`（备用）；
 * - 点名 `ts2` ⇒ 包内 `timeSchemes` 只有 1 条、id 就是 `ts2`；
 * - 不点名（空集合，数据备份页那条路）⇒ 三条都在，行为不变；
 * - 点名的 id 一条都不在快照里 ⇒ 提前失败 `no_selected_time_schemes`，
 *   不产「模板为空」的坏包让接收端去报 `transfer_package_empty`。
 */
class DataTransferPackageTimeSchemeSelectionTest {

    private val now: LocalDateTime = LocalDateTime.of(2026, 3, 2, 8, 30)

    private fun timeScheme(id: String, name: String) = TimeScheme(
        id = id,
        name = name,
        sections = listOf(SectionTime("08:00", "08:45")),
        createdAt = LocalDateTime.of(2026, 2, 1, 0, 0),
        updatedAt = LocalDateTime.of(2026, 2, 1, 0, 0),
    )

    private fun snapshot(): TimetableSnapshot = TimetableSnapshot(
        profiles = emptyList(),
        activeProfileId = null,
        courses = emptyList(),
        scheduleItems = emptyList(),
        scheduleDateRules = emptyList(),
        settings = TimetableSettings.defaults(),
        currentWeek = 1,
        semesterStartEpochDay = null,
        timeSchemes = listOf(
            timeScheme("ts1", "默认作息"),
            timeScheme("ts2", "夏季作息"),
            timeScheme("ts3", "备用作息"),
        ),
        activeTimeSchemeId = "ts1",
    )

    private fun request(selected: Set<String>) = TransferPackageRequest(
        scope = TransferScope.TIME_TEMPLATE,
        channel = TransferChannel.FILE,
        packageId = "pkg-ts",
        now = now,
        selectedTimeSchemeIds = selected,
    )

    @Suppress("UNCHECKED_CAST")
    private fun schemeIds(json: String): List<String> {
        val root = MiniJson.parse(json) as Map<String, Any?>
        val schemes = root["timeSchemes"] as? List<Any?> ?: error("包里没有 timeSchemes")
        return schemes.map { entry ->
            ((entry as Map<String, Any?>)["id"] as? String) ?: error("模板条目没有字符串 id")
        }
    }

    private fun success(result: TransferPackageResult): TransferPackageResult.Success {
        assertTrue("期望 Success，实际 $result", result is TransferPackageResult.Success)
        return result as TransferPackageResult.Success
    }

    @Test
    fun `点名一套模板时包里只带那一套`() {
        val built = success(
            DataTransferPackageLogic.build(
                snapshot = snapshot(),
                request = request(setOf("ts2")),
            ),
        )
        assertEquals(listOf("ts2"), schemeIds(built.json))
        // 文件名前缀与 Dart `_shareTimeSchemeAsFile` 同一口径（`mikcb-timescheme-`）。
        assertEquals("mikcb-timescheme-20260302-0830.mikcb", built.fileName)
        assertEquals(TransferScope.TIME_TEMPLATE, built.scope)
    }

    @Test
    fun `不点名时保持全带（数据备份页的导出时间模板）`() {
        val built = success(
            DataTransferPackageLogic.build(
                snapshot = snapshot(),
                request = request(emptySet()),
            ),
        )
        assertEquals(listOf("ts1", "ts2", "ts3"), schemeIds(built.json))
    }

    @Test
    fun `点名的模板已经不在快照里时提前失败`() {
        val result = DataTransferPackageLogic.build(
            snapshot = snapshot(),
            request = request(setOf("gone")),
        )
        assertTrue("期望 Failure，实际 $result", result is TransferPackageResult.Failure)
        assertEquals("no_selected_time_schemes", (result as TransferPackageResult.Failure).code)
    }

    @Test
    fun `单套模板包仍然自带课程与日程的清理`() {
        // TIME_TEMPLATE 的语义是「只发作息」：即便点名了模板，课程/作业/考试/日程也必须为空。
        val built = success(
            DataTransferPackageLogic.build(
                snapshot = snapshot(),
                request = request(setOf("ts1")),
            ),
        )
        val root = MiniJson.parse(built.json) as Map<*, *>
        assertEquals(emptyList<Any?>(), root["courses"])
        assertEquals(emptyList<Any?>(), root["tasks"])
        assertEquals(emptyList<Any?>(), root["exams"])
        assertEquals(emptyList<Any?>(), root["scheduleItems"])
    }
}
