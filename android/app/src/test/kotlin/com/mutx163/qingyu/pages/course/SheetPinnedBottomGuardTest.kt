package com.mutx163.qingyu.pages.course

import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 弹层「按钮钉底」契约（2026-11-10 用户真机报：沿用课程的模板弹层，取消按钮排在滚动内容末尾，
 * 课多时要拉到最底才看得见）。
 *
 * 发布版 sheet 口径是「**内容滚、按钮钉底**」。实现上：
 * - `QingyuSheet(contentScrolls = true)` 表示内容自己管滚动；
 * - 正文用 `LazyColumn`（限高）+ 固定按钮，底部让位垫在按钮下面；
 * - 按钮必须在 `LazyColumn` **括号之外**（C5：只看文本先后会被「按钮写在列表下方但仍在括号内」
 *   骗过，所以这里用括号配平把列表块截出来，再断言按钮不在块内）。
 *
 * 2026-11-11 已裁口径：双键弹层统一用两个 `Button`（取消 secondary / 确认 primary），
 * 不再混用 `TextButton` + `Button`（C3）。
 *
 * 读源码走 `testutil` 共享剥离 [readKotlinSourceNoStrings]（2026-11-11 迁移）：
 * 判据全是代码结构，字符串里写 `contentScrolls = true` 之类的片段也骗不过去。
 */
class SheetPinnedBottomGuardTest {

    @Test
    fun templateSheet_cancel_pinned_below_list() {
        val body = pageFunction("AddCoursePage.kt", "private fun AddCourseTemplatePickerSheet(")
        assertTrue("模板弹层必须自己管滚动（按代码行判，注释不算）", codeLine(body, "contentScrolls = true"))
        assertTrue("底部让位必须由内容自己落实", codeLine(body, ".padding(bottom = bottomInset)"))
        val list = lazyColumnBlock(body) ?: throw AssertionError("找不到候选列表 LazyColumn")
        val cancelAt = body.indexOf("text = AddCourseStrings.cancelAction.text")
        assertTrue("取消按钮必须存在", cancelAt >= 0)
        assertTrue(
            "取消按钮必须钉在列表**括号之外**（排在列表之后且不在 LazyColumn 内）",
            cancelAt > list.second,
        )
    }

    @Test
    fun fieldPickerSheet_buttons_pinned_below_list() {
        val body = pageFunction("CourseFieldPickerSheet.kt", "fun CourseFieldPickerSheet(")
        assertTrue("教师/地点弹层必须自己管滚动", codeLine(body, "contentScrolls = true"))
        assertTrue("底部让位必须由内容自己落实", codeLine(body, ".padding(bottom = bottomInset)"))
        val list = lazyColumnBlock(body) ?: throw AssertionError("找不到候选列表 LazyColumn")
        // 双键同组件：取消 / 确认都应是 Button（C3）。
        val firstButton = plainButtonIndex(body)
        assertTrue("按钮必须存在", firstButton >= 0)
        assertTrue("按钮必须钉在列表括号之外", firstButton > list.second)
        assertTrue("双键都用 Button（不再混用 TextButton）", !body.contains("TextButton("))
    }

    @Test
    fun followupLocationSheet_buttons_pinned_below_list() {
        val body = pageFunction("CourseFollowupSheets.kt", "private fun FollowupLocationSheet(")
        assertTrue("地点子弹层必须自己管滚动", codeLine(body, "contentScrolls = true"))
        val list = lazyColumnBlock(body) ?: throw AssertionError("找不到候选列表 LazyColumn")
        val firstButton = plainButtonIndex(body)
        assertTrue("按钮必须存在", firstButton >= 0)
        assertTrue("按钮必须钉在列表括号之外", firstButton > list.second)
        assertTrue("双键都用 Button（不再混用 TextButton）", !body.contains("TextButton("))
    }

    /** 纯 `Button(`（排除 IconButton / TextButton）第一次出现的下标。 */
    private fun plainButtonIndex(body: String): Int =
        Regex("""(?<![A-Za-z])Button\(""").find(body)?.range?.first ?: -1

    /** 代码行锚定：注释里提到同名字样不算（反引号包着的旧写法常骗过 contains）。 */
    private fun codeLine(body: String, token: String): Boolean =
        Regex("^\\s*" + Regex.escape(token) + ",?\\s*$", RegexOption.MULTILINE).containsMatchIn(body)

    /**
     * 把 `LazyColumn(...) { ... }` 整块按括号配平截出来：返回 (起始下标, 结束下标)。
     * 找不到返回 null。
     */
    private fun lazyColumnBlock(body: String): Pair<Int, Int>? {
        val start = body.indexOf("LazyColumn(")
        if (start < 0) return null
        val brace = body.indexOf('{', start)
        if (brace < 0) return null
        var depth = 0
        var i = brace
        while (i < body.length) {
            when (body[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return start to i
                }
            }
            i++
        }
        return null
    }

    /** 截取一个函数体（从声明行到下一个顶层函数声明/文件尾），避免跨函数误判。 */
    private fun pageFunction(fileName: String, signature: String): String {
        val path = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/course/$fileName"
        val source = readKotlinSourceNoStrings(path)
        val start = source.indexOf(signature)
        assertTrue("$fileName 里找不到函数：$signature", start >= 0)
        val rest = source.substring(start)
        val nextPrivate = rest.indexOf("\nprivate fun ", 1)
        val nextPublic = rest.indexOf("\nfun ", 1)
        val candidates = listOf(nextPrivate, nextPublic).filter { it > 0 }
        val end = if (candidates.isEmpty()) rest.length else candidates.min()
        return rest.substring(0, end)
    }
}
