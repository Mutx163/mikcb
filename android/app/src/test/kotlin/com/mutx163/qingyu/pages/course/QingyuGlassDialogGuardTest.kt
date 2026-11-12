package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertEquals
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
 * 判据**先剥注释再数**，并且**把字符串内容中性化**：注释里写 `glass = DialogGlass(` 不计数，
 * 字符串 / 原始字符串里写 `DialogGlass(` 也不计数——那是提示语、日志模板，不是调用点。
 *
 * 2026-11-12 修误报（本守卫实测到的一例）：此前用私有剥离器只剥注释、保留字符串内容，
 * 页面里任何一处 `"""…DialogGlass(…"""` 都会被当成第二个调用点（探针实测数到 2 处 ≠ 1）。
 * 现在改走 `testutil.stripKotlinComments(..., neutralizeStrings = true)`，顺带去掉那份
 * 私有拷贝（它没有原始字符串状态，抄来抄去只会再退化成第二份弱实现）。
 *
 * 放在 course 域随 L0 跑（宿主域 git 状态干净；被钉文件在 core/ 与 course 域）。
 */
class QingyuGlassDialogGuardTest {

    private val addCourseSource: String by lazy {
        codeOnly(readAndroidSource(ADD_COURSE_PATH))
    }

    private val specSource: String by lazy {
        codeOnly(readAndroidSource(DIALOG_GLASS_SPEC_PATH))
    }

    private val allPageSources: List<String> by lazy {
        readAllSources(PAGES_ROOT).map { codeOnly(it) }
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
        val calls = allPageSources.sumOf { callSites(it) }
        assertTrue(
            "fork 玻璃调用点 $calls 处 ≠ 1。试点期全仓只允许加课页删除确认这一个玻璃弹窗；" +
                "铺开须经用户看过真机效果拍板，届时连同本守卫的计数一起改。",
            calls == 1,
        )
    }

    @Test
    fun `字符串里的 DialogGlass 不算调用点`() {
        val sample = buildString {
            appendLine("val raw = \"\"\"")
            appendLine("DialogGlass(")
            appendLine("\"\"\"")
            appendLine("val normal = \"DialogGlass(\"")
        }
        assertEquals(
            "字符串 / 原始字符串里的 DialogGlass 被数成了调用点——判据必须先中性化字符串内容。",
            0,
            callSites(codeOnly(sample)),
        )
        assertEquals(
            "真实调用必须仍被数到，否则守卫会退化成永远绿。",
            1,
            callSites(codeOnly("val x = DialogGlass(")),
        )
    }

    // ------------------------------------------------------------------
    // 判据工具
    // ------------------------------------------------------------------

    /** 判据只看代码骨架：剥注释 + **把字符串内容中性化**（提示语 / 日志模板不算调用点）。 */
    private fun codeOnly(raw: String): String = stripKotlinComments(raw, neutralizeStrings = true)

    private fun callSites(source: String): Int = DIALOG_GLASS_CALL.findAll(source).count()

    private val DIALOG_GLASS_CALL = Regex("""\bDialogGlass\(""")

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
