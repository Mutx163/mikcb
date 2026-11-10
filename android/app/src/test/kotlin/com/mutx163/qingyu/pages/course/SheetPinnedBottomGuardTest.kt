package com.mutx163.qingyu.pages.course

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 弹层「按钮钉底」契约（2026-11-10 用户真机报：沿用课程的模板弹层，取消按钮排在滚动内容末尾，
 * 课多时要拉到最底才看得见）。
 *
 * 发布版 sheet 口径是「**内容滚、按钮钉底**」。组件实现上：
 * - `QingyuSheet(contentScrolls = true)` 表示内容自己管滚动；
 * - 正文用 `LazyColumn`（限高）+ 固定按钮，底部让位垫在按钮下面；
 * - 顺序必须成立：取消/确认按钮在列表**之后**且不在列表**内部**（否则会跟着滚走）。
 *
 * 本守卫扫我域内三处会滚动的选择弹层：加课页模板弹层、教师/地点弹层、调课地点弹层。
 */
class SheetPinnedBottomGuardTest {

    @Test
    fun `加课模板弹层取消按钮钉底 不跟列表滚`() {
        val body = pageFunction("AddCoursePage.kt", "private fun AddCourseTemplatePickerSheet(")
        assertTrue("模板弹层必须自己管滚动（contentScrolls = true；按代码行判，注释不算）", codeLine(body, "contentScrolls = true"))
        assertTrue("候选区必须是有界惰性列表", body.contains("LazyColumn("))
        val listAt = body.indexOf("LazyColumn(")
        val cancelAt = body.indexOf("text = AddCourseStrings.cancelAction.text")
        assertTrue("取消按钮必须存在", cancelAt >= 0)
        assertTrue("取消按钮必须排在列表之后（钉底），不能挪进列表内部", cancelAt > listAt)
        assertTrue("底部让位必须由内容自己落实（代码行锚定）", codeLine(body, ".padding(bottom = bottomInset)"))
    }

    @Test
    fun `教师地点弹层取消确认钉底`() {
        val body = pageFunction("CourseFieldPickerSheet.kt", "fun CourseFieldPickerSheet(")
        assertTrue("地点/教师弹层必须自己管滚动（代码行锚定）", codeLine(body, "contentScrolls = true"))
        val listAt = body.indexOf("LazyColumn(")
        val buttonAt = body.indexOf("TextButton(")
        assertTrue("候选区必须有界", listAt >= 0)
        assertTrue("确认/取消必须排在列表之后", buttonAt > listAt)
        assertTrue("底部让位必须由内容自己落实（代码行锚定）", codeLine(body, ".padding(bottom = bottomInset)"))
    }

    @Test
    fun `调课地点弹层按钮钉底`() {
        val body = pageFunction("CourseFollowupSheets.kt", "private fun FollowupLocationSheet(")
        assertTrue("地点子弹层必须自己管滚动（代码行锚定）", codeLine(body, "contentScrolls = true"))
        val listAt = body.indexOf("LazyColumn(")
        val buttonAt = body.indexOf("TextButton(")
        assertTrue("候选区必须有界", listAt >= 0)
        assertTrue("确认/取消必须排在列表之后", buttonAt > listAt)
    }

    /** 截取一个函数体（从声明行到下一个顶层函数声明/文件尾），避免跨函数误判。 */
    private fun pageFunction(fileName: String, signature: String): String {
        val path = when (fileName) {
            "AddCoursePage.kt", "CourseFieldPickerSheet.kt", "CourseFollowupSheets.kt" ->
                "composeP1/kotlin/com/mutx163/qingyu/pages/course/$fileName"
            else -> throw AssertionError("未知文件：$fileName")
        }
        val file = File(androidSrc(), path)
        assertTrue("$path 不存在", file.isFile)
        val source = file.readText().replace("\r\n", "\n")
        val start = source.indexOf(signature)
        assertTrue("$fileName 里找不到函数：$signature", start >= 0)
        val rest = source.substring(start)
        // 截到下一个「也许另一个函数声明」的起始注释或声明：用下一个 "\nprivate fun " / "\nfun " 近似。
        val nextPrivate = rest.indexOf("\nprivate fun ", 1)
        val nextPublic = rest.indexOf("\nfun ", 1)
        val candidates = listOf(nextPrivate, nextPublic).filter { it > 0 }
        val end = if (candidates.isEmpty()) rest.length else candidates.min()
        return rest.substring(0, end)
    }


    /** 代码行锚定：注释里提到同名字样不算（反引号包着的旧写法常骗过 contains）。 */
    private fun codeLine(body: String, token: String): Boolean =
        Regex("^\\s*" + Regex.escape(token) + ",?\\s*$", RegexOption.MULTILINE).containsMatchIn(body)

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
