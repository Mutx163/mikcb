package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 空白格「两步式添加」守卫（2026-11-10，迁移退化审计补建）。
 *
 * ## 它防的是哪一类事故
 *
 * 发布版 v2.1.4.1 的长按空格加课是**两步式**（`lib/screens/timetable_screen.dart`）：
 *
 * * `:4751-4810` `_buildEmptySlotGestureArea`：长按空白格先出虚线框标记，按住拖动跟手换格；
 * * `:4822-4870` `_buildEmptySlotCell`：虚线框 + 居中加号；
 * * `:4935-4980` `_resizeEmptySlotMarker`：拖框上/下边把框拉长成多节；
 * * `:4982-5002` `_openAddCourseFromEmptySlot`：**点虚线框**才进加课表单，预填星期 + 起止节次。
 *
 * Compose 迁移时这一步被简化成「一长按直接 `onOpenAddCourse(day, section)`」——
 * 虚线框、跟手换格、跨节拉长三件全丢（2026-11-09 审计判定为退化）。本守卫钉住：
 *
 * 1. 网格里**不许再出现**一步式长按（`onLongPress =` / `onLongClick =`）；
 * 2. 两步式四件（长按+拖动识别器 / 虚线框标记 / 拖边把手 / 有课格判据）必须齐；
 * 3. 加课回调只允许在**确认路径**（`confirmEmptySlotMarker`）里派发，
 *    长按手势块里出现派发即判红 —— 那正是一长按就跳页的老写法。
 *
 * ## 为什么读文本而不是跑 Compose 手势
 *
 * `TimetableWeekGrid.kt` 是 Compose 页面，进不了 L0 的 JVM 单测 classpath；
 * 与 `DayViewBackToTodayFabGuardTest` / `HomeMenuEntryDestinationGuardTest` 同一套做法：
 * 向上找 `android/app/src` 定位源文件再按正则/括号配对解析，**找不到判失败、不静默跳过**。
 */
class EmptySlotLongPressGuardTest {

    private val gridSource: String by lazy {
        stripKotlinComments(readAndroidSource(GRID_PATH))
    }

    // ---------------------------------------------------------------- 扫描器自检

    @Test
    fun `扫描器必须真的读到网格代码`() {
        assertTrue(
            "TimetableWeekGrid.kt 读出来太短（${gridSource.length} 字符）——扫描根疑似失效，守卫会空转。",
            gridSource.length > 5000,
        )
        assertTrue(
            "剥注释后找不到 `fun TimetableWeekGrid(` —— 剥注释把代码也吃了，判据不可信。",
            gridSource.contains("fun TimetableWeekGrid("),
        )
    }

    // ---------------------------------------------------------------- 契约

    @Test
    fun `不许退回一长按就跳加课页的一步式`() {
        assertFalse(
            "TimetableWeekGrid 又出现 `onLongPress =` / `onLongClick =` 的一步式长按 —— " +
                "发布版 v2.1.4.1（timetable_screen.dart:4751-4810）是「长按出虚线框 → " +
                "拖动换格 / 拖边拉长 → 点框才进表单」。一长按就直接 onOpenAddCourse " +
                "是 2026-11-09 审计判定的退化，别回退。",
            ONE_SHOT_LONG_PRESS.containsMatchIn(gridSource),
        )
    }

    @Test
    fun `两步式四件必须齐`() {
        assertTrue(
            "缺长按+拖动识别器（detectDragGesturesAfterLongPress）——跟手换格没了。",
            gridSource.contains("detectDragGesturesAfterLongPress("),
        )
        assertTrue(
            "缺虚线框标记（EmptySlotAddMarker）——长按后屏上什么都不出现。",
            gridSource.contains("EmptySlotAddMarker("),
        )
        assertTrue(
            "缺拖边把手（detectVerticalDragGestures）——不能把框拉长成多节。",
            gridSource.contains("detectVerticalDragGestures("),
        )
        assertTrue(
            "缺有课格判据（emptySlotCellAt）——标记会压到课卡上。",
            gridSource.contains("emptySlotCellAt("),
        )
        assertTrue(
            "缺三参确认入口 onLongPressEmptySlotSpan —— 起止节次回传不了。",
            gridSource.contains("onLongPressEmptySlotSpan:"),
        )
        assertTrue(
            "虚线框没有挂到确认回调（onConfirm = { confirmEmptySlotMarker() }）——点框进不了表单。",
            gridSource.contains("onConfirm = { confirmEmptySlotMarker() }"),
        )
    }

    @Test
    fun `长按手势块里不许直接派发加课回调`() {
        val dragDetector = callBlock(gridSource, "detectDragGesturesAfterLongPress(")
        assertNotNull("找不到 detectDragGesturesAfterLongPress( 的调用块。", dragDetector)
        assertTrue(
            "长按手势块里没有落标记（markerDay = …）——标记不是长按产生的。",
            dragDetector!!.contains("markerDay = "),
        )
        assertFalse(
            "长按手势块里直接派发了加课回调（onLongPressEmptySlot / onLongPressEmptySlotSpan）——" +
                "就是一长按就跳页的老写法；派发只允许留在 confirmEmptySlotMarker。",
            dragDetector.contains("onLongPressEmptySlot"),
        )

        val tapDetector = callBlock(gridSource, "detectTapGestures(")
        assertNotNull("找不到 detectTapGestures( 的调用块。", tapDetector)
        assertFalse(
            "点空白的手势块里又挂了 onLongPress —— 长按会被这里接走，两步式失效。",
            tapDetector!!.contains("onLongPress"),
        )
    }

    @Test
    fun `加课回调只在确认路径里派发`() {
        val confirmBlock = functionBlock(gridSource, "fun confirmEmptySlotMarker()")
        assertNotNull("找不到 confirmEmptySlotMarker —— 点框确认的入口被删了。", confirmBlock)
        assertTrue(
            "确认路径没有派发三参回调（onLongPressEmptySlotSpan）——起止节次丢了。",
            confirmBlock!!.contains("onLongPressEmptySlotSpan"),
        )
        assertTrue(
            "确认路径没有两参回退（onLongPressEmptySlot）——还没接三参的宿主会收不到回调。",
            confirmBlock.contains("onLongPressEmptySlot"),
        )
    }

    // ---------------------------------------------------------------- 读取 / 解析

    /**
     * 取 `anchor` 之后第一个 `(` 起、括号配对到 `)` 的整段调用文本。
     *
     * 只用于 `detectXxxGestures(` 这类**参数全是 lambda、括号内没有字符串**的调用，
     * 靠深度计数足够；找不到 anchor 返回 null（由调用方判红）。
     */
    private fun callBlock(source: String, anchor: String): String? {
        val start = source.indexOf(anchor)
        if (start < 0) return null
        var depth = 0
        for (i in start until source.length) {
            when (source[i]) {
                '(' -> depth++
                ')' -> {
                    depth--
                    if (depth == 0) return source.substring(start, i + 1)
                }
            }
        }
        return null
    }

    /** 取 `anchor`（函数声明，参数为 `()`）之后第一个 `{` 起、花括号配对的函数体。 */
    private fun functionBlock(source: String, anchor: String): String? {
        val start = source.indexOf(anchor)
        if (start < 0) return null
        val open = source.indexOf('{', start)
        if (open < 0) return null
        var depth = 0
        for (i in open until source.length) {
            when (source[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return source.substring(start, i + 1)
                }
            }
        }
        return null
    }

    /**
     * 剥掉行注释与块注释（保留换行，行号不漂）。
     *
     * 该文件没有含 `//` 的字符串字面量，所以正则剥注释足够；扫描器自检
     * （`fun TimetableWeekGrid(` 仍在）会兜住「剥多了」。
     */
    private fun stripKotlinComments(source: String): String {
        val block = Regex("/\\*.*?\\*/", RegexOption.DOT_MATCHES_ALL)
            .replace(source) { match -> "\n".repeat(match.value.count { it == '\n' }) }
        return Regex("//[^\n]*").replace(block, "")
    }

    private fun readAndroidSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        // 找不到就失败，不静默跳过——跳过等于守卫不存在。
        throw AssertionError("找不到 $relative —— 守卫无法验证，按失败处理")
    }

    private companion object {
        /** 一步式长按：`onLongPress =` / `onLongClick =`（属性名，不匹配 onLongPressEmptySlot）。 */
        val ONE_SHOT_LONG_PRESS = Regex("""(?i)(onlongpress|onlongclick)\s*=""")

        const val GRID_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/timetable/TimetableWeekGrid.kt"
    }
}
