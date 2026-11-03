package com.mutx163.qingyu.pages.exam

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 考试域两处删除确认弹层的**常驻组合**守卫（2026-11-04 建立）。
 *
 * 原来两处都写成 `if (状态) { OverlayDialog(show = true, …) }`：状态一置 false，
 * 整棵弹层在同一帧被摘出组合，miuix 0.9.4 `DialogLayout` 的退场动画
 * （fadeOut + scaleOut + slideOut）一次都播不出来。修法与 `pages/task/TaskListPage`
 * 同款：弹层常驻组合、`show` 显式驱动。
 *
 * composeP1 源集不进 `src/test` 的编译单元，所以读源码文本；找不到文件判失败而不是跳过。
 * 判据全部行首锚定：注释 / KDoc 里提到同一写法不会造成假红。
 */
class ExamDialogMountGuardTest {

    @Test
    fun `考试列表删除弹层必须常驻组合 显隐只由 show 驱动`() {
        val source = pageSource("ExamListPage.kt")
        assertFalse(
            "禁止条件挂载：`if (target != null) { OverlayDialog(show = true, …) }` " +
                "会在关闭瞬间把弹层摘出组合，退场动画一次都播不出来",
            conditionalMount("target != null").containsMatchIn(source),
        )
        assertTrue(
            "弹层必须常驻组合，显隐由 `show = pendingDelete != null` 驱动",
            source.contains("show = pendingDelete != null"),
        )
        assertTrue(
            "关闭时 pendingDelete 立刻置空，正文必须用 `rememberLastNonNull` 钉住最后一份考试",
            source.contains("rememberLastNonNull(pendingDelete)"),
        )
        assertTrue(
            "摘要必须渲染退场快照（否则退场动画期间课名闪空）",
            source.contains("deleteTarget?.name.orEmpty()"),
        )
        assertFalse(
            "组件常驻后不许再写死 `show = true`",
            Regex("""^\s*show = true""", RegexOption.MULTILINE).containsMatchIn(source),
        )
    }

    @Test
    fun `添加考试页删除弹层必须常驻组合 显隐只由 show 驱动`() {
        val source = pageSource("AddExamPage.kt")
        assertFalse(
            "禁止条件挂载：`if (confirmDelete) { OverlayDialog(show = true, …) }` " +
                "会让退场动画一次都播不出来",
            conditionalMount("confirmDelete").containsMatchIn(source),
        )
        assertTrue(
            "弹层必须常驻组合，显隐由 `show = confirmDelete` 驱动",
            source.contains("show = confirmDelete"),
        )
        assertFalse(
            "组件常驻后不许再写死 `show = true`",
            Regex("""^\s*show = true""", RegexOption.MULTILINE).containsMatchIn(source),
        )
    }

    /** 行首锚定的条件挂载判据：注释 / KDoc 里的同名字样不算命中。 */
    private fun conditionalMount(condition: String): Regex =
        Regex("""^\s*if \(${Regex.escape(condition)}\) \{""", RegexOption.MULTILINE)

    private fun pageSource(fileName: String): String {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/exam/$fileName",
        )
        assertTrue("${file.path} 不存在", file.isFile)
        return file.readText().replace("\r\n", "\n")
    }

    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }
}
