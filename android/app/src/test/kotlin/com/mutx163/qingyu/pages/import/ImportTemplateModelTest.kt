package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.TimetableSettings
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 「下载轻屿课表模板」的内容契约（F07 · 2026-10-29）。
 *
 * 两个方向各钉一次：
 * 1. **与资产逐字一致**：Kotlin 内联的正文必须等于
 *    `assets/templates/mikcb_course_import_template.csv`——两边漂了，Flutter 版与
 *    Compose 版用户下载到的模板就不是同一份，客服和文档会开始对不上；
 * 2. **模板本身可导入**：把这份正文真的喂进 [SpreadsheetImportModel]，必须解析出 3 门课
 *    且没有任何提醒——否则用户下载到的是一份「填好了也导不进来」的废纸。
 */
class ImportTemplateModelTest {

    @Test
    fun `模板正文与仓库资产逐字节一致`() {
        val asset = loadAsset()
        assertEquals(
            "assets/templates/mikcb_course_import_template.csv 与 ImportTemplateModel.CONTENT 不一致",
            asset,
            ImportTemplateModel.CONTENT,
        )
    }

    @Test
    fun `模板落盘路径在已登记的缓存子目录里`() {
        // res/xml/file_paths.xml 只登记了 ics-export/ transfer-share/ log-share/ 三处；
        // 模板写进未登记目录会被 FileProvider 拒绝（分享那一步稳定失败）。
        assertEquals("transfer-share/mikcb_course_import_template.csv", ImportTemplateModel.CACHE_RELATIVE_PATH)
        assertEquals("text/csv", ImportTemplateModel.MIME_TYPE)
    }

    @Test
    fun `模板自己能导入出三门课`() {
        val result = SpreadsheetImportModel.parseBytes(
            bytes = ImportTemplateModel.CONTENT.toByteArray(Charsets.UTF_8),
            fileName = ImportTemplateModel.FILE_NAME,
            settings = TimetableSettings.defaults(),
        )
        assertEquals("模板里的示例课应该全部能解析", 3, result.courses.size)
        assertTrue("模板不该产生任何提醒：${result.warnings}", result.warnings.isEmpty())
        assertEquals(SpreadsheetImportModel.FORMAT_MIKCB, result.format)

        val math = result.courses.first()
        assertEquals("高等数学", math.name)
        assertEquals(1, math.dayOfWeek)
        assertEquals(1, math.startSection)
        assertEquals(2, math.endSection)
        assertEquals(1, math.startWeek)
        assertEquals(16, math.endWeek)
        assertEquals("张老师", math.teacher)
        assertEquals("A101", math.location)
        assertEquals("#2196F3", math.color)

        // 第三行用「上课周表达式 + 停课周 + 自定义时间 + 时间模板」，是模板里信息最全的一条。
        val programming = result.courses.last()
        assertEquals("程序设计", programming.name)
        // 「1-5、7-11单」= 前段整段全周 1~5，后段只取单周 7/9/11
        // （周次表达式的单双周只作用在它自己那一段上，Dart 同口径）。
        assertEquals(listOf(1, 2, 3, 4, 5, 7, 9, 11), programming.normalizedCustomWeeks)
        assertEquals(listOf(6), programming.suspendedWeeks)
        assertEquals("14:00", programming.startTime)
        assertEquals("15:40", programming.endTime)
        assertEquals("default", programming.timeSchemeIdOverride)
    }

    private fun loadAsset(): String {
        var dir: File? = File("").absoluteFile
        var assetFile: File? = null
        repeat(8) {
            val candidate = File(dir, "assets/templates/mikcb_course_import_template.csv")
            if (candidate.isFile) {
                assetFile = candidate
                return@repeat
            }
            dir = dir?.parentFile
        }
        val file = assetFile
            ?: error("找不到 assets/templates/mikcb_course_import_template.csv（从 ${File("").absolutePath} 向上找了 8 层）")
        return file.readText(Charsets.UTF_8)
    }
}
