package com.mutx163.qingyu.pages.timetable.day

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 非本周课固定灰必须走域内 token（2026-11-04，样式基线欠账清理）。
 *
 * Dart 把非本周灰命名为 `kNonCurrentWeekCourseColorHex`（`#94A3B8`），Kotlin
 * 已在 `pages/timetable/WeekGridCourseMapping.NON_CURRENT_WEEK_COLOR_HEX` 落成常量。
 * 日卡曾经自己再写一份 `Color(0xFF94A3B8)`：两处灰一旦漂移，周/日视图的非本周课
 * 观感就不一致，R5 也会一直挂着一条可还的债。
 *
 * composeP1 不进 L0 编译单元，故读源码文本；判据行首锚定，注释里提字面量不会假红。
 */
class DayViewColorTokenGuardTest {

    @Test
    fun `日卡非本周灰必须复用 WeekGridCourseMapping 的 token`() {
        val source = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewCourseCard.kt",
        )
        assertTrue(
            "日卡非本周灰没有引用 `WeekGridCourseMapping.NON_CURRENT_WEEK_COLOR_HEX`：" +
                "又写回了第二份字面量，非本周灰两处会漂移。",
            source.contains("WeekGridCourseMapping.NON_CURRENT_WEEK_COLOR_HEX"),
        )
        assertFalse(
            "日卡仍把非本周灰写死成 `Color(0xFF94A3B8)`：应改走域内 token。",
            Regex("""^[ \t]*Color\(0xFF94A3B8\)""", RegexOption.MULTILINE).containsMatchIn(source),
        )
    }

    @Test
    fun `守卫本身没有空转`() {
        val source = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/day/DayViewCourseCard.kt",
        )
        assertTrue(
            "DayViewCourseCard 源码读取太短（${source.length} 字符），路径解析可能坏了",
            source.length > 1000,
        )
    }

    /** 从工作目录向上找仓库根再定位文件；找不到仍判失败，不静默跳过。 */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }
}
