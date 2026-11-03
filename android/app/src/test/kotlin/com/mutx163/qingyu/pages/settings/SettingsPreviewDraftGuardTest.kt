package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「课程卡片 / 课表页面两页的挖洞预览不跟草稿」的判据与守卫（2026-11-03 用户实报：
 * 改开关 / 拖滑杆预览不动，必须退出重进）。
 *
 * ## 根因（为什么要这条守卫）
 *
 * 两页的预览槽由壳注入（`ShellPageIndex.SettingsTimetablePreviewSlot`），旧实现在槽里
 * 自己 `remember(wiring) { wiring.settingsModel.load() }` 读了一次盘；而页面里的写入
 * 走「先改内存草稿、滑杆 250ms 防抖才落盘」⇒ 预览永远停在进页那一刻的存档。
 *
 * 修法：宿主把当前草稿顺着 `preview(model)` 传给槽，取用口径收在 [settingsPreviewDraft]
 * 一条窄函数里（签名只有草稿，没有存档入口）。
 *
 * 源码判据**先剥注释**；找不到文件判失败而不是跳过。
 */
class SettingsPreviewDraftGuardTest {

    // ── 判据（settingsPreviewDraft）────────────────────────────────────

    @Test
    fun `草稿一改预览输入就换新值不必等落盘`() {
        val persisted = TimetableSettingsModel()
        val draft = persisted.copy(courseCardShowTeacher = false)
        val input = settingsPreviewDraft(draft)
        assertEquals("预览必须拿到草稿本身", draft, input)
        assertNotEquals("预览不能退回进页时的存档", persisted, input)
    }

    @Test
    fun `滑杆拖动中未落盘也逐帧跟手`() {
        val persisted = TimetableSettingsModel(sectionHeight = 68.0)
        var draft = persisted
        val seen = mutableListOf<Double>()
        // 模拟一次拖动：宿主只改内存草稿，盘上始终是旧值。
        listOf(69.0, 70.0, 72.0).forEach { height ->
            draft = draft.copy(sectionHeight = height)
            seen += settingsPreviewDraft(draft).sectionHeight
        }
        assertEquals(listOf(69.0, 70.0, 72.0), seen)
        assertEquals("盘上存档没动过", 68.0, persisted.sectionHeight, 0.0)
    }

    @Test
    fun `落盘失败回滚的盘上真值也立刻成为预览输入`() {
        val persisted = TimetableSettingsModel(sectionHeight = 68.0)
        val rolledBack = persisted
        assertEquals(persisted, settingsPreviewDraft(rolledBack))
    }

    // ── 源码守卫 ────────────────────────────────────────────────────────

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

    /** 去掉块注释与行注释再判（KDoc 里摆的说明不能算违规）。 */
    private fun codeOf(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .replace(Regex("""//[^\n]*"""), "")

    /** 从声明后的第一个 `{` 起按花括号配平，截出函数体（不必依赖下一个函数的位置）。 */
    private fun bodyAfter(code: String, declaration: String): String {
        val start = code.indexOf(declaration)
        if (start < 0) return ""
        val brace = code.indexOf('{', start)
        if (brace < 0) return ""
        var depth = 0
        for (i in brace until code.length) {
            when (code[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return code.substring(brace, i + 1)
                }
            }
        }
        return code.substring(brace)
    }

    @Test
    fun `两个宿主都按同一份草稿回推预览`() {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/app/SettingsHost.kt",
        )
        assertTrue("SettingsHost.kt 不存在：${file.path}", file.isFile)
        val code = codeOf(file.readText())

        assertEquals(
            "课程卡片 / 课表页面两个宿主都要收「草稿 → 预览」的回推参数（不许一个跟一个不跟）",
            2,
            Regex("""preview:\s*\(@Composable\s*\(TimetableSettingsModel\)\s*->\s*Unit\)\?""")
                .findAll(code)
                .count(),
        )
        assertEquals(
            "两处必须走同一个取用口径 settingsPreviewDraft(model)",
            2,
            Regex("""settingsPreviewDraft\(model\)""").findAll(code).count(),
        )
        assertEquals(
            "两个宿主的 SettingsPageScreen 都要喂回推后的槽，不许裸传 preview",
            2,
            Regex("""preview\s*=\s*previewSlot""").findAll(code).count(),
        )
        assertFalse(
            "宿主不许再把原始 preview（无草稿）直接交给渲染层",
            Regex("""preview\s*=\s*preview,""").containsMatchIn(code),
        )
    }

    @Test
    fun `壳的预览槽接草稿且不再自己读盘`() {
        val file = File(
            androidSrc(),
            "main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt",
        )
        assertTrue("ShellPageIndex.kt 不存在：${file.path}", file.isFile)
        val code = codeOf(file.readText())

        assertEquals(
            "课程卡片 / 课表页面两处都必须把草稿传进同一个预览槽",
            2,
            Regex("""SettingsTimetablePreviewSlot\(wiring, it\)""").findAll(code).count(),
        )
        val declaration = "private fun SettingsTimetablePreviewSlot(wiring: ShellWiring, settingsModel: TimetableSettingsModel)"
        assertTrue(
            "预览槽必须收宿主草稿（两个参数），否则只能回头自己读盘",
            declaration in code,
        )
        val body = bodyAfter(code, declaration)
        assertFalse(
            "预览槽内部又读盘了：preview 会停在进页时的存档，改开关要重进才变",
            "wiring.settingsModel.load()" in body,
        )
        assertTrue(
            "预览槽要把收到的草稿交给 TimetableHost",
            "settingsModel = settingsModel" in body,
        )
    }
}
