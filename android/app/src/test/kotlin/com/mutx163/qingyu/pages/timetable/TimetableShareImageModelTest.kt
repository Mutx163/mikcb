package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableSettings
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File
import java.time.LocalDate

/**
 * 「干净课表图」导出与分享的纯逻辑单测（[TimetableShareImageModel] /
 * [TimetableShareRequests] / `file_paths.xml` 对拍 / 分享 Intent 契约守卫）。
 *
 * 期望值全部由 Dart 真源人推，不抄 Kotlin 实现：
 * - 宽度 clamp：`timetable_share_service.dart:31-32`（360~460）；
 * - 节高 clamp：`timetable_export_document.dart:53-54`（56~110）；
 * - 表头 40：`timetable_export_document.dart:47`；
 * - 文件名：`timetable_share_service.dart:73`（`timetable_share_$timestamp.png`）；
 * - 周次标题：`app_zh.arb` `timetableShareExportWeekTitle` = 「第 {week} 周课表」；
 * - 日图标题：`timetableShareExportDayTitle` = 「第 {week} 周 · {weekday}」；
 * - 像素比 2.5：`image_export_capture.dart:36`。
 */
class TimetableShareImageModelTest {

    // ------------------------------------------------------------------
    // 宽度 / 节高 / 几何
    // ------------------------------------------------------------------

    @Test
    fun `导出宽度收进 360 到 460`() {
        assertEquals(360f, TimetableShareImageModel.exportWidthDp(320f), 0.001f)
        assertEquals(360f, TimetableShareImageModel.exportWidthDp(360f), 0.001f)
        assertEquals(400f, TimetableShareImageModel.exportWidthDp(400f), 0.001f)
        assertEquals(460f, TimetableShareImageModel.exportWidthDp(520f), 0.001f)
    }

    @Test
    fun `导出节高收进 56 到 110`() {
        assertEquals(56f, TimetableShareImageModel.exportSectionHeightDp(40f), 0.001f)
        assertEquals(68f, TimetableShareImageModel.exportSectionHeightDp(68f), 0.001f)
        assertEquals(110f, TimetableShareImageModel.exportSectionHeightDp(140f), 0.001f)
    }

    @Test
    fun `日列宽按可见天数均分且扣除时间列`() {
        // 7 天、时间列 34：可用 366 - 34 = 332，均分 = 47.428…
        assertEquals(332f / 7f, TimetableShareImageModel.dayColumnWidthDp(366f, 34f, 7), 0.001f)
        // 隐藏周末 = 5 天。
        assertEquals(66.4f, TimetableShareImageModel.dayColumnWidthDp(366f, 34f, 5), 0.001f)
        // 天数 0 保底 1（不除零）。
        assertEquals(366f, TimetableShareImageModel.dayColumnWidthDp(366f, 0f, 0), 0.001f)
    }

    @Test
    fun `课卡几何按起始节定位且跨度保底`() {
        assertEquals(68f * 2f, TimetableShareImageModel.cardTopDp(3, 68f), 0.001f)
        // 起始节 < 1 按 1（第 0 格起）。
        assertEquals(0f, TimetableShareImageModel.cardTopDp(0, 68f), 0.001f)
        assertEquals(68f * 2f, TimetableShareImageModel.cardHeightDp(3, 4, 68f), 0.001f)
        // 跨度倒挂保底 1。
        assertEquals(68f, TimetableShareImageModel.cardHeightDp(5, 2, 68f), 0.001f)
    }

    @Test
    fun `周图文档高度随节数线性增长`() {
        val base = weekDoc(sectionCount = 10)
        val taller = weekDoc(sectionCount = 12)
        val delta = TimetableShareImageModel.documentHeightDp(taller) -
            TimetableShareImageModel.documentHeightDp(base)
        // 差值 = 2 节 × 导出节高（clamp 后 68）。
        assertEquals(136f, delta, 0.01f)
    }

    @Test
    fun `日图文档高度随行数增长且空态不炸`() {
        val rows = listOf(
            TimetableShareImageModel.DayRow("08:00-09:40", "1-2", "高等数学", "张老师 · A101", 0xFF2563EB.toInt()),
            TimetableShareImageModel.DayRow("10:00-11:40", "3-4", "大学英语", null, 0xFF10B981.toInt()),
        )
        val withRows = dayDoc(rows)
        val empty = dayDoc(emptyList())
        assertTrue(
            "有课的日图应比空态高",
            TimetableShareImageModel.documentHeightDp(withRows) > TimetableShareImageModel.documentHeightDp(empty),
        )
        // 第一行去掉详情行后文档应变矮：详情行要计入高度。
        val noDetail = dayDoc(
            listOf(rows[0].copy(details = null), rows[1]),
        )
        assertTrue(
            "详情行应计入高度",
            TimetableShareImageModel.documentHeightDp(withRows) > TimetableShareImageModel.documentHeightDp(noDetail),
        )
    }

    @Test
    fun `超高文档按像素上限等比缩小`() {
        // 1000dp × 2.5 × 3.0 = 7500px < 16384 → 不缩。
        assertEquals(1f, TimetableShareImageModel.pixelScaleClamp(1000f, 3f), 0.0001f)
        // 3000dp × 2.5 × 3.0 = 22500px > 16384 → 缩到放得下。
        val scale = TimetableShareImageModel.pixelScaleClamp(3000f, 3f)
        assertEquals(16384f / 22500f, scale, 0.0001f)
        assertTrue(scale < 1f)
    }

    // ------------------------------------------------------------------
    // 文件名 / 缓存清理 / FileProvider 契约
    // ------------------------------------------------------------------

    @Test
    fun `文件名与 Dart 同口径 前缀加毫秒时间戳加 png`() {
        assertEquals("timetable_share_1730000000000.png", TimetableShareImageModel.fileName(1730000000000L))
    }

    @Test
    fun `落盘路径与 file_paths_xml 白名单逐字对拍`() {
        assertEquals(
            "timetable-share/timetable_share_1.png",
            TimetableShareImageModel.cacheRelativePath("timetable_share_1.png"),
        )
        val xml = repoFile("android/app/src/main/res/xml/file_paths.xml").readText()
        assertTrue(
            "file_paths.xml 缺 timetable_share 白名单条目（FileProvider 会拒发 content Uri）",
            xml.contains("name=\"timetable_share\"") && xml.contains("path=\"timetable-share/\""),
        )
        // 常量与 XML 双向对拍：改一边不改另一边会在这里红。
        assertEquals("timetable_share", TimetableShareImageModel.PROVIDER_PATH_NAME)
        assertEquals("timetable-share", TimetableShareImageModel.CACHE_DIR_NAME)
    }

    @Test
    fun `provider authority 带运行期 applicationId 后缀`() {
        assertEquals(
            "com.example.dev.fileprovider",
            TimetableShareImageModel.providerAuthority("com.example.dev"),
        )
        assertEquals(".fileprovider", TimetableShareImageModel.PROVIDER_AUTHORITY_SUFFIX)
    }

    @Test
    fun `分享 mime 与 Dart 同为 image png`() {
        assertEquals("image/png", TimetableShareImageModel.MIME_PNG)
    }

    @Test
    fun `导出前清理只删同前缀旧图`() {
        val dir = temp.newFolder("timetable-share")
        val stale1 = File(dir, "timetable_share_111.png").apply { writeBytes(byteArrayOf(1)) }
        val stale2 = File(dir, "timetable_share_222.png").apply { writeBytes(byteArrayOf(2)) }
        val foreign = File(dir, "other_export_333.png").apply { writeBytes(byteArrayOf(3)) }
        val subdir = File(dir, "timetable_share_dir.png").apply { mkdirs() }

        assertEquals(2, TimetableShareImageModel.cleanStaleExports(dir))
        assertTrue("旧图 1 应被删", !stale1.exists())
        assertTrue("旧图 2 应被删", !stale2.exists())
        assertTrue("别人的文件不碰", foreign.exists())
        assertTrue("目录不删", subdir.exists())
        // 幂等：再跑一遍不报错、不再删。
        assertEquals(0, TimetableShareImageModel.cleanStaleExports(dir))
    }

    // ------------------------------------------------------------------
    // Intent 契约守卫（源码文本判据——android Intent 进不了 JVM，钉组装点文本）
    // ------------------------------------------------------------------

    @Test
    fun `分享落地文件必须带 ACTION_SEND 与读权限与 ClipData`() {
        val launcher = repoFile(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableShareLauncher.kt",
        ).readText()
        assertTrue("分享必须走 ACTION_SEND", launcher.contains("Intent(Intent.ACTION_SEND)"))
        assertTrue(
            "必须带 FLAG_GRANT_READ_URI_PERMISSION（接收方拿不到读权限会显示裂图）",
            launcher.contains("Intent.FLAG_GRANT_READ_URI_PERMISSION"),
        )
        assertTrue(
            "必须带 ClipData（部分接收方只认 ClipData 里的 Uri）",
            launcher.contains("ClipData.newUri"),
        )
        assertTrue(
            "MIME 必须来自模型常量（image/png），不许散落字面量",
            launcher.contains("TimetableShareImageModel.MIME_PNG"),
        )
    }

    // ------------------------------------------------------------------
    // 参数透传契约（dayOfWeek 丢失会静默变成分享整周——Dart 契约测试点名的风险）
    // ------------------------------------------------------------------

    @Test
    fun `周图文档的 dayOfWeek 恒为 null 且按天分桶`() {
        // 2026-10-21（周三）开学，归一到周一 10-19：第 3 周周三 = 2026-11-04。
        val settings = TimetableSettings.defaults().copy(
            semesterStartDate = java.time.LocalDateTime.of(2026, 10, 21, 0, 0),
        )
        val doc = TimetableShareRequests.weekDocument(
            courses = listOf(
                course("c1", dayOfWeek = 1),
                course("c2", dayOfWeek = 3),
            ),
            week = 3,
            settings = settings,
            style = WeekViewStyle(),
            visibleDays = (1..7).toList(),
            today = LocalDate.of(2026, 11, 4), // 周三
        )
        assertNull("周图的 dayOfWeek 必须是 null", doc.dayOfWeek)
        assertNull("周图没有副标题", doc.subtitle)
        assertEquals(10, doc.sections.size)
        assertEquals("第 3 周课表", doc.title)
        assertEquals("3 周", doc.weekCompactLabel)
        assertEquals("非本周灰化的判据来自今天：2026-11-04 是周三", 3, doc.todayDayOfWeek)
        // 「周三」格里有课；「周一」格里也有课。
        assertEquals(1, doc.cardsByDay[1]?.size)
        assertEquals(1, doc.cardsByDay[3]?.size)
        assertEquals("来自轻屿课表的课表", doc.shareText)
    }

    @Test
    fun `日图文档透传 dayOfWeek 且按当天过滤`() {
        val doc = TimetableShareRequests.dayDocument(
            courses = listOf(
                course("c1", dayOfWeek = 2, startSection = 1, endSection = 2),
                course("c2", dayOfWeek = 2, startSection = 3, endSection = 4),
                course("c3", dayOfWeek = 5, startSection = 1, endSection = 2),
            ),
            week = 2,
            dayOfWeek = 2,
            settings = TimetableSettings.defaults(),
        )
        assertEquals("dayOfWeek 必须原样透传（丢了就静默变成整周图）", 2, doc.dayOfWeek)
        assertEquals(2, doc.dayRows.size)
        // 排序按开始节次。
        assertEquals("1-2", doc.dayRows[0].sectionLabel)
        assertEquals("3-4", doc.dayRows[1].sectionLabel)
        // 标题与副标题：第 2 周 · 周二；开学日没配 → 副标题 null。
        assertEquals("第 2 周 · 周二", doc.title)
        assertNull(doc.subtitle)
        assertEquals("这天没有课", doc.emptyDayText)
    }

    @Test
    fun `日图在开学日已配时给出日期副标题`() {
        // 2026-11-02 是周一：第 2 周周二 = 11 月 10 日。
        val settings = TimetableSettings.defaults().copy(
            semesterStartDate = java.time.LocalDateTime.of(2026, 11, 2, 0, 0),
        )
        val doc = TimetableShareRequests.dayDocument(
            courses = emptyList(),
            week = 2,
            dayOfWeek = 2,
            settings = settings,
        )
        assertEquals("11月10日", doc.subtitle)
        assertTrue("没课也照出图（空态文案），行表为空", doc.dayRows.isEmpty())
    }

    // ------------------------------------------------------------------
    // 咬合探针（改断言先故意改坏被测行为，确认测试真的会红）
    // ------------------------------------------------------------------

    @Test
    fun `色值解析容错`() {
        val fallback = 0xFF2196F3.toInt()
        assertEquals(fallback, TimetableShareImageModel.parseHexArgb(null, fallback))
        assertEquals(fallback, TimetableShareImageModel.parseHexArgb("", fallback))
        assertEquals(fallback, TimetableShareImageModel.parseHexArgb("#XYZ123", fallback))
        assertEquals(fallback, TimetableShareImageModel.parseHexArgb("#12345", fallback))
        assertEquals(0xFF2563EB.toInt(), TimetableShareImageModel.parseHexArgb("#2563EB", fallback))
        assertEquals(0xFF2563EB.toInt(), TimetableShareImageModel.parseHexArgb("2563eb", fallback))
    }

    // ------------------------------------------------------------------
    // 夹具
    // ------------------------------------------------------------------

    @get:Rule
    val temp = TemporaryFolder()

    private fun course(
        id: String,
        dayOfWeek: Int,
        startSection: Int = 1,
        endSection: Int = 2,
    ) = Course(
        id = id,
        name = "课程$id",
        teacher = "张老师",
        location = "A101",
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
        startTime = "08:00",
        endTime = "09:40",
        color = "#2563EB",
    )

    /** 周图夹具：直接构造 Document（与 buildWeekDocument 的产物同形）。 */
    private fun weekDoc(sectionCount: Int): TimetableShareImageModel.Document {
        val style = WeekViewStyle()
        return TimetableShareImageModel.buildWeekDocument(
            week = 1,
            cardsByDay = emptyMap(),
            sections = List(sectionCount) { com.mutx163.qingyu.core.SectionTime("08:00", "08:45") },
            sectionTimeMode = WeekSectionTimeMode.START_AND_END,
            style = style,
            visibleDays = (1..7).toList(),
            weekdayLabels = emptyMap(),
            weekdayDates = emptyMap(),
            todayDayOfWeek = null,
            accentHex = "#2563EB",
            title = "第 1 周课表",
            weekCompactLabel = "1 周",
            overlineLabels = emptyMap(),
            shareText = "来自轻屿课表的课表",
        )
    }

    private fun dayDoc(rows: List<TimetableShareImageModel.DayRow>): TimetableShareImageModel.Document =
        TimetableShareImageModel.buildDayDocument(
            week = 1,
            dayOfWeek = 1,
            dayCourses = emptyList(),
            title = "第 1 周 · 周一",
            subtitle = null,
            emptyDayText = "这天没有课",
            shareText = "来自轻屿课表的课表",
        ).copy(dayRows = rows)

    private fun repoFile(relativePath: String): File {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relativePath)
            if (candidate.isFile) return candidate
            if (File(dir, "android/app/src").isDirectory) {
                // 到了仓库根还没命中，直接报路径（比静默 null 好）。
                return candidate
            }
            dir = dir.parentFile
        }
        assertNotNull("找不到仓库根（user.dir=${System.getProperty("user.dir")}）", null)
        throw IllegalStateException("unreachable")
    }
}
