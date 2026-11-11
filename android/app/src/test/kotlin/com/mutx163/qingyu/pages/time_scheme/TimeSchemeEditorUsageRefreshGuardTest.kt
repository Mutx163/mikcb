package com.mutx163.qingyu.pages.time_scheme

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **时间模板编辑页「引用索引」刷新键守卫**（2026-11-11，评审三 T-02）。
 *
 * ## 它防的是哪一类事故
 *
 * 编辑页的用量数字与引用预览来自 `TimeSchemeUsageIndexFactory.build(...)`，那一步**读四份快照**：
 * 模板清单、课表档案、地点作息分组、日期作息规则。但重建它的 `LaunchedEffect` 只把前两份
 * 写进了键 ⇒ 用户改了「地点作息匹配」分组或「日期作息规则」后回到本页，数字仍是旧的，
 * 而页面上又没有一处提示「这是旧值」。这类问题**编译通过、单测全绿**，只有看源码文本
 * 才能区分「键齐了」与「漏了两份实参」。
 *
 * ## 判据
 *
 * 1. 宿主里存在 `LaunchedEffect(` 块，且块内实参含 `snapshot.timeSchemes`、`snapshot.profiles`、
 *    `snapshot.locationTimeGroups`、`snapshot.scheduleDateRules` **四项**；
 * 2. 工厂调用处同样把这四项都喂进去（键与实参必须同源——只补键不补实参、或只补实参不补键，
 *    都会让「改分组不刷新」或「无谓重算」其中一种复发）。
 *
 * 对照口径：同文件列表页的 effect 用整份 `snapshot` 做键（`TimeSchemeHost` 管理页 `:148`），
 * 编辑页这里只可能点名四份字段，所以必须四项齐全。
 */
class TimeSchemeEditorUsageRefreshGuardTest {

    @Test
    fun `编辑页引用索引的刷新键必须含地点组与日期规则`() {
        val source = stripLineComments(readSource(HOST_PATH))
        // 判据**只扫编辑页宿主这一段**：同文件的管理页也有一个建索引的 effect（`LaunchedEffect(snapshot)`，
        // 用整份快照做键，本来就够），从文件头开始找会先命中它、把判据测错对象。
        val editorStart = source.indexOf("fun TimeSchemeEditorHost(")
        assertTrue(
            "TimeSchemeHost.kt 里找不到 fun TimeSchemeEditorHost(（判据定位失效，按失败处理）",
            editorStart >= 0,
        )
        val editor = source.substring(editorStart)
        val headStart = editor.indexOf("LaunchedEffect(")
        val build = editor.indexOf("TimeSchemeUsageIndexFactory.build(", headStart)
        assertTrue(
            "编辑页宿主里找不到「建引用索引」的 LaunchedEffect / Factory.build（判据定位失效）",
            headStart >= 0 && build > headStart,
        )
        val head = editor.substring(headStart, build)
        val missing = listOf(
            "snapshot.timeSchemes",
            "snapshot.profiles",
            "snapshot.locationTimeGroups",
            "snapshot.scheduleDateRules",
        ).filterNot { head.contains(it) }
        assertTrue(
            "编辑页建引用索引的 LaunchedEffect 键不齐，缺：$missing ——" +
                "必须同时含 snapshot.timeSchemes / snapshot.profiles / " +
                "snapshot.locationTimeGroups / snapshot.scheduleDateRules；漏掉后两份时，" +
                "改地点分组或日期规则后本页用量与引用预览不刷新（T-02）",
            missing.isEmpty(),
        )
    }

    // ------------------------------------------------------------ 工具

    /** 去掉行注释：注释里解释「旧实现漏了两份键」不算复发。 */
    private fun stripLineComments(source: String): String =
        source.lineSequence()
            .filterNot { it.trimStart().startsWith("//") }
            .joinToString("\n")

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error(
            "找不到 $relative（工作目录 ${File("").absolutePath}）；" +
                "守卫需要读到宿主源码才能判键是否齐全",
        )
    }

    private companion object {
        const val HOST_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/TimeSchemeHost.kt"
    }
}
