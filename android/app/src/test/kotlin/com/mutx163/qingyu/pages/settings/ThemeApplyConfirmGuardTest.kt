package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「应用已存主题」的**草稿态确认**守卫（2026-11-10 收口；同日按发布版改回三动作）。
 *
 * ## 这笔账是什么
 *
 * 主题管理页的「我的主题」有两处「应用」入口（预览弹层底部、动作表第一行），
 * 它们都汇到 `SettingsHost.runSavedThemeAction(APPLY)`。发布版在草稿态会先拦一下：
 * `settings_appearance.dart:636-645` → `confirmApplyThemeWithUnsavedCheck`
 * （`theme_manage_sheets.dart:327-347`）→ `showThemeUnsavedChangesDialog`
 * （同文件 `:60-69`）弹一个**三动作框**：取消 / 保存当前主题 / 放弃并应用
 * （`app_dialogs.dart` 的 `showAppTripleActionDialog`，>2 个动作走竖排 Column，primary 是「放弃并应用」）。
 * 保存那条**打开保存框、不应用**（`onSaveRequested` 后返回 false）。
 * Kotlin 迁移时丢了这一步（三条 ARB 键在发布版有消费者，只是 Kotlin 侧没接线）。
 *
 * ## 判据（源码级 + 纯函数行为各一半）
 *
 * 1. **门控与极性**：APPLY 分支里 `if (hasThemeModifications(model)) { … } else { … }`
 *    ——`if` 体内只许出现 `APPLY_CONFIRM`（草稿态弹确认），`} else {` 之后才许
 *    `applySavedThemeNow(id)`（干净态直通）。**极性/归属都要钉**：条件取反、两分支对调
 *    都必须红（复核退回过的正是「只判存在、不判归属」）。
 * 2. 确认框的「放弃并应用」必须走**绕过门控**的 `onApplyConfirmed`，不许回调
 *    `onAction(APPLY, …)`——那样会重新命中门控，弹框关不掉。
 * 3. 弹层形态按发布版：竖排三动作（取消 / 保存当前主题 / 放弃并应用），
 *    「保存当前主题」打开保存框且**不**应用；主按钮 primary 色（不是 error 红）。
 * 4. 行为侧用真模型钉 [SettingsActionDispatcher.hasThemeModifications] 的三种形态
 *    （无检查点 / 与检查点一致 / 已改动），保证门控判据本身不是摆设。
 *
 * ## 为什么一半读源码
 *
 * `SettingsHost` 在 `composeP1` 源集，`src/test` 只挂 `main`，L0 编不进来
 * （与 `SettingsHostIntentWiringGuardTest` 同一套做法）。找不到文件**判失败而不是跳过**。
 *
 * ## 咬合探针（三条坏改，各 改坏→红→还原→绿）
 *
 * `!` 取反 / `.not()` 取反 / 两分支对调。证据落
 * `.agents/notes/implemented/2026-11-10-theme-apply-confirm.md`。
 * 首版只钉「存在 + 顺序」，条件取反（含 `.not()` 这类同义写法）与两分支对调都能照样绿
 * ——那次退回就是本闸的由来；条件判据现在是**精确等值**，不是「禁 `!` + 包含」。
 */
class ThemeApplyConfirmGuardTest {

    private val hostSource: String by lazy { stripKotlinComments(settingsHostSource()) }

    // ── 1. 门控与极性 ────────────────────────────────────────────────────

    @Test
    fun `门控必须判草稿态且两个分支不许对调`() {
        val gate = parseApplyGate(applyBranchBody())
        assertNotNull(
            "APPLY 分支里找不到 `if (…hasThemeModifications(model)…) { … } else { … }` 门控——" +
                "草稿会被静默丢弃，或干净态每次都要确认",
            gate,
        )
        gate!!

        // ① 极性：条件必须**精确等于**判据本身。
        //    不用「禁 `!` + 包含」那种写法——`.not()` 与 `== false` 是同义取反，能绕过去
        //    就等于没钉（2026-11-10 复核指出的口子）。
        val condition = normalize(gate.condition)
        assertEquals(
            "门控条件必须精确等于 `$EXPECTED_GATE_CONDITION`（`.not()`、`== false`、" +
                "取反后再判断等任何形式都必须红），实际是：`$condition`",
            EXPECTED_GATE_CONDITION,
            condition,
        )

        // ② 归属：if 体内只许弹确认；else 体才许直接落盘（两分支对调必红）。
        assertTrue(
            "`if (hasThemeModifications)` 分支里没有 `ThemeDialogMode.APPLY_CONFIRM`——" +
                "草稿态不会弹确认。",
            "ThemeDialogMode.APPLY_CONFIRM" in gate.ifBody,
        )
        assertFalse(
            "`if (hasThemeModifications)` 分支里出现了 `applySavedThemeNow(`——" +
                "两分支被对调：草稿态会直接落盘、干净态反而弹确认。",
            "applySavedThemeNow(" in gate.ifBody,
        )
        assertTrue(
            "`} else {` 分支里没有 `applySavedThemeNow(id)`——干净态点应用不会生效。",
            "applySavedThemeNow(id)" in gate.elseBody,
        )
        assertFalse(
            "`} else {` 分支里出现了 `ThemeDialogMode.APPLY_CONFIRM`——两分支被对调。",
            "ThemeDialogMode.APPLY_CONFIRM" in gate.elseBody,
        )
    }

    /** 判据自检：给四份样本（正确 / `!` 取反 / `.not()` 取反 / 对调）跑同一个解析器，判别力自证。 */
    @Test
    fun `极性判据自检——取反与对调都要被判出来`() {
        val good = """
            ThemeRowAction.APPLY -> {
                if (SettingsActionDispatcher.hasThemeModifications(model)) {
                    themeDialog = ThemeDialogState(mode = ThemeDialogMode.APPLY_CONFIRM)
                } else {
                    applySavedThemeNow(id)
                }
            }
        """.trimIndent()
        val negated = good.replace(
            "if (SettingsActionDispatcher.hasThemeModifications(model))",
            "if (!SettingsActionDispatcher.hasThemeModifications(model))",
        )
        // 同义取反的另一种写法：`!x` 写成 `x.not()`——「禁 `!`」的旧判据对它无效。
        val notCall = good.replace(
            "if (SettingsActionDispatcher.hasThemeModifications(model))",
            "if (SettingsActionDispatcher.hasThemeModifications(model).not())",
        )
        val swapped = """
            ThemeRowAction.APPLY -> {
                if (SettingsActionDispatcher.hasThemeModifications(model)) {
                    applySavedThemeNow(id)
                } else {
                    themeDialog = ThemeDialogState(mode = ThemeDialogMode.APPLY_CONFIRM)
                }
            }
        """.trimIndent()

        val goodGate = parseApplyGate(good)
        assertNotNull("正确样本应当解析出闸形状", goodGate)
        assertEquals(
            "正确样本的条件应当精确等于判据",
            EXPECTED_GATE_CONDITION,
            normalize(goodGate!!.condition),
        )
        assertFalse("正确样本的 if 体不该出现直接落盘", "applySavedThemeNow(" in goodGate.ifBody)

        val negatedGate = parseApplyGate(negated)
        assertNotNull("取反样本应当仍能解析出门控（否则判据靠解析失败来红，判别力说不清）", negatedGate)
        assertFalse(
            "`!` 取反样本必须被判成条件不等值",
            normalize(negatedGate!!.condition) == EXPECTED_GATE_CONDITION,
        )

        val notCallGate = parseApplyGate(notCall)
        assertNotNull("`.not()` 样本应当仍能解析出门控", notCallGate)
        assertFalse(
            "`.not()` 取反样本必须被判成条件不等值（这是复核点出的绕过口子）",
            normalize(notCallGate!!.condition) == EXPECTED_GATE_CONDITION,
        )

        val swappedGate = parseApplyGate(swapped)
        assertNotNull("对调样本应当仍能解析出门控", swappedGate)
        assertTrue(
            "对调样本必须被判成 if 体里出现直接落盘",
            "applySavedThemeNow(" in swappedGate!!.ifBody,
        )
        assertTrue(
            "对调样本必须被判成 else 体里出现 APPLY_CONFIRM",
            "ThemeDialogMode.APPLY_CONFIRM" in swappedGate.elseBody,
        )
    }

    // ── 2. 绕行 ──────────────────────────────────────────────────────────

    @Test
    fun `确认后不再走一次门控`() {
        assertTrue(
            "宿主必须给弹层传 `onApplyConfirmed`（绕过门控的直接落盘），" +
                "否则「放弃并应用」会重新命中门控、弹框关不掉",
            "onApplyConfirmed = { id ->" in hostSource,
        )
        assertTrue(
            "`onApplyConfirmed` 必须调 `applySavedThemeNow(`",
            "onApplyConfirmed = { id -> themeDialog = null; applySavedThemeNow(id) }" in hostSource,
        )
        // 弹层的「放弃并应用」按钮只能走 onApplyConfirmed，不许走 onAction(APPLY)。
        val confirmBranch = dialogBranchBody("APPLY_CONFIRM")
        assertTrue(
            "确认框的确认按钮没有接 `onApplyConfirmed`",
            "onApplyConfirmed)" in confirmBranch || "onApplyConfirmed(" in confirmBranch,
        )
        assertFalse(
            "确认框的确认按钮不许回调 `onAction(ThemeRowAction.APPLY`——会重新命中门控形成循环",
            "onAction(ThemeRowAction.APPLY" in confirmBranch,
        )
    }

    // ── 3. 弹层形态（按发布版三动作） ────────────────────────────────────

    @Test
    fun `确认框按发布版给三动作且主按钮是 primary`() {
        val branch = dialogBranchBody("APPLY_CONFIRM")
        listOf(
            "SettingsStrings.themeUnsavedChangesTitle.text" to "标题（未保存的修改）",
            "SettingsStrings.themeUnsavedChangesMessage.text" to "正文（是否保存？）",
            "SettingsStringsExt4.cancelAction.text" to "取消",
            "SettingsStrings.themeSaveCurrent.text" to "保存当前主题",
            "SettingsStrings.themeDiscardAndApply.text" to "放弃并应用",
        ).forEach { (needle, why) ->
            assertTrue("确认框缺少 $why：预期出现 `$needle`", needle in branch)
        }
        // 发布版 >2 个动作走竖排 Column（`hyperos_dialog.dart` 的 actions 分支）。
        assertTrue(
            "三动作必须竖排（发布版 `_HyperosDialogActions` 对 >2 个走 Column），当前没看到 Column 布局",
            "Column(" in branch,
        )
        // 「保存当前主题」绑 onSaveBeforeApply（打开保存框、不应用），不许绑确认落盘。
        val saveClickIdx = branch.indexOf("onSaveBeforeApply")
        assertTrue(
            "「保存当前主题」按钮没有绑 `onSaveBeforeApply`（发布版语义：打开保存框、不应用）",
            saveClickIdx >= 0,
        )
        // 只看这个按钮自身那段（往前 220 字符覆盖 text/modifier 两行）：
        // 后面的「放弃并应用」按钮本来就该绑 onApplyConfirmed，不能算进来。
        val saveButtonZone = branch.substring(
            maxOf(0, saveClickIdx - 220),
            minOf(branch.length, saveClickIdx + 40),
        )
        assertTrue(
            "「保存当前主题」按钮的文案必须是 `themeSaveCurrent`（发布版 secondaryLabel）",
            "SettingsStrings.themeSaveCurrent.text" in saveButtonZone,
        )
        assertFalse(
            "「保存当前主题」按钮不许绑 `onApplyConfirmed`——那会保存后立刻应用，偏离发布版",
            "onApplyConfirmed" in saveButtonZone,
        )
        // 宿主那一侧：onSaveBeforeApply 必须换成保存框，且不落盘。
        assertTrue(
            "宿主的 `onSaveBeforeApply` 应当把弹层换成 `ThemeDialogMode.SAVE_CURRENT`（不应用）",
            "onSaveBeforeApply = { themeDialog = ThemeDialogState(ThemeDialogMode.SAVE_CURRENT) }" in hostSource,
        )
        // 按钮色：发布版 primary（`app_dialogs.dart:76` isPrimary: true），不是 error 红。
        assertTrue(
            "「放弃并应用」必须用 primary 色（发布版 isPrimary: true）",
            "ButtonDefaults.buttonColorsPrimary()" in branch,
        )
        assertFalse(
            "「放弃并应用」不该再用 error 危险色（发布版是 primary）",
            "MiuixTheme.colorScheme.error" in branch,
        )
    }

    // ── 4. 门控判据本身的行为（真模型） ──────────────────────────────────

    @Test
    fun `草稿态判据三种形态`() {
        // ① 没有检查点（从没保存过主题）⇒ 不算草稿。
        assertFalse(SettingsActionDispatcher.hasThemeModifications(TimetableSettingsModel()))

        // ② 检查点与当前值一致 ⇒ 干净态（点应用直接生效）。
        val base = TimetableSettingsModel()
        val checkpointed = base.copy(
            themeCheckpointName = "测试主题",
            themeCheckpointConfig = SettingsActionDispatcher.themeConfigOf(base),
        )
        assertFalse(
            "检查点与当前值一致时不该判成草稿（否则每次点应用都弹确认）",
            SettingsActionDispatcher.hasThemeModifications(checkpointed),
        )

        // ③ 改过主题字段 ⇒ 草稿态（点应用要先确认）。取 `seed`（主题色，检查点字段之一），
        // 换成一个与当前值不同的合法 hex。
        val changed = checkpointed.copy(
            themeSeedColor = "#123456".takeIf { it != checkpointed.themeSeedColor } ?: "#654321",
        )
        assertTrue(
            "改过主题字段后必须判成草稿（否则确认框永远不出现）",
            SettingsActionDispatcher.hasThemeModifications(changed),
        )
    }

    // ------------------------------------------------------------------ 工具

    /** 唯一正确的门控条件（精确等值，不做「包含」判断）。 */
    private companion object {
        const val EXPECTED_GATE_CONDITION =
            "SettingsActionDispatcher.hasThemeModifications(model)"
    }

    /** 折行与缩进不影响等值判断。 */
    private fun normalize(text: String): String = text.replace(Regex("\\s+"), " ").trim()

    /** 门控的三段：条件、`if` 体、`} else {` 之后的体。解析不出返回 null（由调用方判红）。 */
    private data class ApplyGate(val condition: String, val ifBody: String, val elseBody: String)

    /**
     * 只看 APPLY 分支里的**第一处** `if (…) { … } else { … }`：
     * 大写括号配对取 `if` 体，再从 `} else {` 之后取到分支尾。不是正则，避免再次放水。
     */
    private fun parseApplyGate(branch: String): ApplyGate? {
        val ifIdx = branch.indexOf("if (")
        if (ifIdx < 0) return null
        val condEnd = branch.indexOf(") {", ifIdx)
        if (condEnd < 0) return null
        val condition = branch.substring(ifIdx + 4, condEnd)
        val ifBodyStart = condEnd + 3
        val elseMarker = "} else {"
        val elseIdx = branch.indexOf(elseMarker, ifBodyStart)
        if (elseIdx < 0) return null
        val ifBody = branch.substring(ifBodyStart, elseIdx)
        val elseBody = branch.substring(elseIdx + elseMarker.length)
        return ApplyGate(condition = condition, ifBody = ifBody, elseBody = elseBody)
    }

    /** APPLY 分支的函数体：从 `ThemeRowAction.APPLY ->` 到分支结束（下一个 `ThemeRowAction.` 之前）。 */
    private fun applyBranchBody(): String {
        val start = hostSource.indexOf("ThemeRowAction.APPLY ->")
        assertTrue("SettingsHost 里找不到 `ThemeRowAction.APPLY ->` 分支", start >= 0)
        val end = hostSource.indexOf("ThemeRowAction.RENAME ->", start)
        assertTrue("找不到 APPLY 分支的终点（RENAME 分支）", end > start)
        return hostSource.substring(start, end)
    }

    /** 某个弹层分支的函数体：从 `ThemeDialogMode.X ->` 到下一个 `ThemeDialogMode.` 分支之前。 */
    private fun dialogBranchBody(mode: String): String {
        val needle = "ThemeDialogMode.$mode ->"
        val start = hostSource.indexOf(needle)
        assertTrue("SettingsHost 里找不到弹层分支 `$needle`", start >= 0)
        val next = hostSource.indexOf("ThemeDialogMode.", start + needle.length)
        val grownLayout = hostSource.indexOf("val current?.mode", start + needle.length)
        val candidates = listOf(next, grownLayout).filter { it > 0 }
        val end = candidates.minOrNull() ?: hostSource.length
        return hostSource.substring(start, end)
    }

    private fun settingsHostSource(): String {
        val host = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/app/SettingsHost.kt",
        )
        assertTrue("SettingsHost.kt 不存在：${host.path}", host.isFile)
        return host.readText()
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

    /** 剥注释：注释里提到判据名不能当免死金牌（与同族守卫同一套状态机）。 */
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
                    i += 2
                }
                ch == '/' && next == '*' -> {
                    inBlockComment = true
                    blockDepth = 1
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
}
