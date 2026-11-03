package com.mutx163.qingyu.pages.course

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 弹窗玻璃试点守卫（2026-11-03 材质批；同日按用户批准「改库」改为钉本地 fork 玻璃）。
 *
 * ## 三条判据
 *
 * 1. **试点弹窗确实走 fork 玻璃**：加课页「删除课程确认」调用 `glass = DialogGlass(`，
 *    且不再出现 `GlassOverlayDialog(`（表面材质由库内 `DialogContentLayout` 画，调用侧封装已下线）。
 * 2. **一键回退开关存在且默认开**：`core/DialogGlassSpec` 有 `var enabled: Boolean = true`。
 *    用户看过真机效果后，`false` 一行即全量回实心，不用改调用点。
 * 3. **试点没有变全量**：`glass = DialogGlass(` 在整个 composeP1 渲染层只允许出现
 *    **1 个调用点**（其余官方 `OverlayDialog` 调用与全部底部弹层保持现状）——
 *    防止后续改动顺手扩散；铺开必须经用户看过效果拍板后再加。
 *
 * 判据**先剥注释再数**（字符串感知，`ComposeSheetGuardTest` 同款）：注释里写
 * `glass = DialogGlass(` 不计数，也不会把真调用藏进注释里绕过。
 *
 * 放在 course 域随 L0 跑（宿主域 git 状态干净；被钉文件在 core/ 与 course 域）。
 */
class QingyuGlassDialogGuardTest {

    private val addCourseSource: String by lazy {
        stripKotlinComments(readAndroidSource(ADD_COURSE_PATH))
    }

    private val specSource: String by lazy {
        stripKotlinComments(readAndroidSource(DIALOG_GLASS_SPEC_PATH))
    }

    private val allPageSources: List<String> by lazy {
        readAllSources(PAGES_ROOT).map { stripKotlinComments(it) }
    }

    @Test
    fun `试点弹窗必须走 fork 玻璃`() {
        assertTrue(
            "加课页「删除课程确认」没走本地 fork 玻璃（缺 `DialogGlass(` 或 `glass =`）——" +
                "这是用户批准的唯一试点；若要撤试点请连守卫一起改并说明。",
            addCourseSource.contains("DialogGlass(") && addCourseSource.contains("glass ="),
        )
        assertTrue(
            "加课页仍在用 GlassOverlayDialog ——材质已进本地 fork 的 DialogContentLayout，" +
                "调用侧封装留着会变成两条并行玻璃路径。",
            !addCourseSource.contains("GlassOverlayDialog("),
        )
    }

    @Test
    fun `一键回退开关必须存在且默认开启`() {
        assertTrue(
            "DialogGlassSpec 缺少回退开关（var enabled: Boolean = true）——" +
                "一键回退是试点的交付承诺，删掉开关等于把玻璃硬编进调用点。",
            specSource.contains("var enabled: Boolean = true"),
        )
    }

    @Test
    fun `玻璃调用点必须保持唯一试点`() {
        val calls = allPageSources.sumOf { Regex("""\bDialogGlass\(""").findAll(it).count() }
        assertTrue(
            "fork 玻璃调用点 $calls 处 ≠ 1。试点期全仓只允许加课页删除确认这一个玻璃弹窗；" +
                "铺开须经用户看过真机效果拍板，届时连同本守卫的计数一起改。",
            calls == 1,
        )
    }

    // ------------------------------------------------------------------
    // 判据工具
    // ------------------------------------------------------------------

    private fun stripKotlinComments(source: String): String {
        val sb = StringBuilder(source.length)
        var i = 0
        var inLineComment = false
        var inBlockComment = false
        var blockDepth = 0
        var stringQuote: Char? = null
        while (i < source.length) {
            val ch = source[i]
            val next = if (i + 1 < source.length) source[i + 1] else ' '
            when {
                inLineComment -> {
                    if (ch == '\n') {
                        inLineComment = false
                        sb.append(ch)
                    }
                    i++
                }
                inBlockComment -> {
                    if (ch == '/' && next == '*') {
                        blockDepth++
                        i += 2
                    } else if (ch == '*' && next == '/') {
                        blockDepth--
                        i += 2
                        if (blockDepth == 0) inBlockComment = false
                    } else {
                        if (ch == '\n') sb.append(ch)
                        i++
                    }
                }
                stringQuote != null -> {
                    sb.append(ch)
                    if (ch == '\\' && i + 1 < source.length) {
                        sb.append(source[i + 1])
                        i += 2
                    } else {
                        if (ch == stringQuote) stringQuote = null
                        i++
                    }
                }
                ch == '/' && next == '/' -> {
                    inLineComment = true
                    sb.append(' ')
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
                    sb.append(' ')
                    i += 2
                }
                ch == '"' || ch == '\'' -> {
                    stringQuote = ch
                    sb.append(ch)
                    i++
                }
                else -> {
                    sb.append(ch)
                    i++
                }
            }
        }
        return sb.toString()
    }

    private fun readAndroidSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        throw AssertionError("找不到 $relative —— 守卫无法验证，按失败处理")
    }

    private fun readAllSources(rootRelative: String): List<String> {
        var dir: File? = File("").absoluteFile
        while (dir != null && !(File(dir, rootRelative).isDirectory)) {
            dir = dir.parentFile
        }
        val root = dir?.let { File(it, rootRelative) }
            ?: throw AssertionError("找不到 $rootRelative —— 守卫无法验证，按失败处理")
        return root.walkTopDown().filter { it.isFile && it.extension == "kt" }.map { it.readText(Charsets.UTF_8) }.toList()
    }

    private companion object {
        const val ADD_COURSE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/AddCoursePage.kt"

        const val DIALOG_GLASS_SPEC_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/core/DialogGlassSpec.kt"

        // 只扫 pages/ 子树：玻璃参数定义在库内（`data class DialogGlass(` 不计入），
        // 这里数的是「调用点」。
        const val PAGES_ROOT = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages"
    }
}
