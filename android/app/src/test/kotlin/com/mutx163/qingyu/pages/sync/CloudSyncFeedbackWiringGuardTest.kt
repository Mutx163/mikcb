package com.mutx163.qingyu.pages.sync

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 云同步反馈三键的接线守卫（2026-11-06 ARB 批）+「已断开」不补裁决的防回归。
 *
 * ## 它防的是哪一类事故
 *
 * ARB 新键若只登记、不接消费点，就成了死键（copy_style 死键守卫也会拦）；反过来，
 * 接好的消费点被后续改动悄悄删掉，键又退回零消费。这里把「键 ↔ 渲染点」的绑定
 * 钉死，谁删消费点谁红。另外 Chief 裁决（2026-11-05）：发布版断开也是静默 +
 * 状态翻转，**「已断开」提示键不补**——这条反向守卫防止有人顺手把它加回来。
 *
 * ## 为什么读源码文本
 *
 * 「提示弹在哪」写在 Compose lambda / 模型层映射里，编译产物与反射都不保留；
 * 与 `WebdavConnectSheetWiringGuardTest` 同一套做法，判据是「出现/不出现某些字样」。
 */
class CloudSyncFeedbackWiringGuardTest {

    // ── 保存成功：cloudSyncSaved（2026-11-06 ARB 批新增键） ──

    @Test
    fun `保存成功提示必须消费cloudSyncSaved键`() {
        val model = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncModel.kt",
        )
        assertTrue(
            "CloudSyncLogic.advancedSaveFeedback 不再消费 cloudSyncSaved：保存成功回到静默，" +
                "2026-11-06 ARB 批补的键成了死键（copy_style 死键守卫也会拦）。",
            "SyncStrings.cloudSyncSaved.zh" in model,
        )
        val page = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncControllerPage.kt",
        )
        val onSuccessIndex = page.indexOf("onSuccess = { verdict ->")
        val consumeIndex = page.indexOf("advancedSaveFeedback(verdict)")
        assertTrue(
            "saveAdvanced 的成功分支没有消费 advancedSaveFeedback 映射：cloudSyncSaved 无渲染点。",
            onSuccessIndex >= 0 && consumeIndex > onSuccessIndex,
        )
    }

    // ── 保存失败：saveFailed（复用 ARB 既有通用键） ──

    @Test
    fun `保存失败提示必须消费saveFailed键`() {
        val model = readSource(
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncModel.kt",
        )
        assertTrue(
            "advancedSaveFailureFeedback 不再引用 saveFailed：落盘失败提示丢失了 ARB 出处。",
            "SyncStrings.saveFailed.zh" in model,
        )
        val page = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncControllerPage.kt",
        )
        val onFailureIndex = page.indexOf("onFailure = { error ->")
        val consumeIndex = page.indexOf("advancedSaveFailureFeedback()")
        assertTrue(
            "saveAdvanced 的失败分支没有弹 advancedSaveFailureFeedback：落盘失败（commitOrThrow " +
                "IOException 被兜住后）回到静默，用户保存失败却毫无提示。",
            onFailureIndex >= 0 && consumeIndex > onFailureIndex,
        )
    }

    // ── 重试：cloudBackupRetryAction（2026-11-06 ARB 批新增键） ──

    @Test
    fun `备份列表的重试出口两个状态都要可见`() {
        // 2026-11-06 第三轮返工①（hy1 推翻「有缓存静默用缓存」）：errorText **有 errorCode
        // 即透出**（模型层口径，CloudBackupListModelTest「errorCode有值即透出」钉住）——
        // 空态与非空列表都要有可见出口：空态 = 失败原因 + 重试；非空 = 顶部轻量错误条 +
        // 重试（列表照常展示缓存）。上一轮「只挂空态、非空不许有」的断言正是把 S2 原病
        // 钉死的那个错误，已改。
        //
        // 断的是（剥注释后的）**分支位置 + 真调用**，不是字符串存在：
        // - onClick 掏空（`onClick = {}` 之类没接真调用）要红；
        // - 失败态的 `if (viewState.errorText != null)` 被删/掏空要红。
        val raw = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudBackupListPage.kt",
        )
        val page = stripComments(raw)
        val emptyBranchStart = page.indexOf("viewState.isEmpty -> Box(")
        val listBranchStart = page.indexOf("else -> QingyuPageList(")
        assertTrue(
            "找不到空态分支 / 列表分支的分界（页面结构变了，守卫要跟着改）。",
            emptyBranchStart >= 0 && listBranchStart > emptyBranchStart,
        )
        val emptyBranch = page.substring(emptyBranchStart, listBranchStart)
        val listBranch = page.substring(listBranchStart)
        // 失败态判断：空态分支是 if 形态（失败原因替代 emptyText），非空分支是 ?.let
        // 形态（errorText 有值才挂错误条）——两形态被删/掏空都要红。
        assertTrue(
            "空态分支的失败态被掏空（找不到 `if (viewState.errorText != null)`）：失败判断" +
                "没了，errorText 有值也不会走到重试出口。",
            "if (viewState.errorText != null)" in emptyBranch,
        )
        assertTrue(
            "非空列表分支的失败态被掏空（找不到 `viewState.errorText?.let`）：errorText 有值" +
                "也不会挂错误条，有缓存时刷新失败回到静默（S2 原病）。",
            "viewState.errorText?.let" in listBranch,
        )
        // 键引用与真调用**绑定同窗**（第五轮复核①：上一版退化成「只查串在分支内」，
        // hy1 探针「掏空 clickable + 把文案串挪到同分支别处」能全绿——洞）。
        //
        // 空态分支：TextButton 的 text→onClick 紧邻，键后小窗必须含真调用；
        // 非空分支：错误条整条 Row 的 clickable 是真调用，键引用必须落在
        // `item(key = "refresh_error_bar")` 与 `item(key = "create_backup")` 的
        // **错误条窗口**内——挪出窗口（挂到别处当死文案）→ 窗口内无键 → 红；
        // 掏空 clickable → 窗口内无 onClick → 红。
        val emptyRetryIndex = emptyBranch.indexOf("SyncStrings.cloudBackupRetryAction.zh")
        assertTrue(
            "空态分支里没有重试出口（cloudBackupRetryAction 无渲染点）：刷新失败在该状态下" +
                "没有任何可点的东西，变成死提示（第三轮返工①两状态都要可见出口）。",
            emptyRetryIndex >= 0,
        )
        val emptyWindow = emptyBranch.substring(
            emptyRetryIndex,
            minOf(emptyRetryIndex + 200, emptyBranch.length),
        )
        assertTrue(
            "空态分支的重试钮没接真调用（键后 200 字符内找不到 `onClick = onRetryRefresh`）：键在、" +
                "点击不动。",
            "onClick = onRetryRefresh" in emptyWindow,
        )
        val barStart = listBranch.indexOf("item(key = \"refresh_error_bar\")")
        val barEnd = listBranch.indexOf("item(key = \"create_backup\")")
        assertTrue(
            "找不到非空分支的错误条窗口边界（refresh_error_bar / create_backup，页面结构变了守卫跟着改）。",
            barStart >= 0 && barEnd > barStart,
        )
        val barWindow = listBranch.substring(barStart, barEnd)
        assertTrue(
            "错误条窗口里没有键引用（cloudBackupRetryAction 被挪出错误条窗口）：重试动作词" +
                "与错误条脱钩，绑不住真调用。",
            "SyncStrings.cloudBackupRetryAction.zh" in barWindow,
        )
        // 绑定同窗的精确形态：键引用必须落在**错误条 Row 的组合体内**（Row(参数) { … }
        // 的 trailing lambda——Text/键引用在 lambda 里，onClick 在圆括号参数里），且与该
        // Row 的 `onClick = onRetryRefresh` 同一条 Row。体边界用**括号配对**定位（纯索引
        // 比较分不清「Row 体内」与「Row 之后的窗口内其他 item」）——挪到窗口内别的 item
        // （Row 体外）照样红。
        val rowIndex = barWindow.indexOf("Row(")
        val barKeyIndex = barWindow.indexOf("SyncStrings.cloudBackupRetryAction.zh")
        val barClickIndex = barWindow.indexOf("onClick = onRetryRefresh")
        assertTrue(
            "错误条窗口里找不到 Row（页面结构变了守卫跟着改）。",
            rowIndex >= 0,
        )
        // 1) 圆括号配对：Row( 的**参数列表**闭合处（modifier/verticalAlignment 在此内）。
        var depth = 0
        var parenEnd = -1
        var scan = rowIndex
        while (scan < barWindow.length) {
            val ch = barWindow[scan]
            if (ch == '"') {
                scan++
                while (scan < barWindow.length && barWindow[scan] != '"') {
                    if (barWindow[scan] == '\\') scan++
                    scan++
                }
            } else if (ch == '(') {
                depth++
            } else if (ch == ')') {
                depth--
                if (depth == 0) {
                    parenEnd = scan
                    break
                }
            }
            scan++
        }
        assertTrue("错误条 Row 的圆括号配对失败（源码结构异常，守卫跟着改）", parenEnd > rowIndex)
        // 2) 参数列表后的第一个非空白字符是 `{`（trailing lambda），花括号配对找组合体结束。
        var braceStart = parenEnd + 1
        while (braceStart < barWindow.length && barWindow[braceStart].isWhitespace()) braceStart++
        assertTrue(
            "Row 参数列表后不是 trailing lambda `{`（页面结构变了守卫跟着改）。",
            braceStart < barWindow.length && barWindow[braceStart] == '{',
        )
        depth = 0
        var bodyEnd = -1
        scan = braceStart
        while (scan < barWindow.length) {
            val ch = barWindow[scan]
            if (ch == '"') {
                scan++
                while (scan < barWindow.length && barWindow[scan] != '"') {
                    if (barWindow[scan] == '\\') scan++
                    scan++
                }
            } else if (ch == '{') {
                depth++
            } else if (ch == '}') {
                depth--
                if (depth == 0) {
                    bodyEnd = scan
                    break
                }
            }
            scan++
        }
        assertTrue("错误条 Row 的花括号配对失败（源码结构异常，守卫跟着改）", bodyEnd > braceStart)
        assertTrue(
            "键引用挪到了错误条 Row 组合体外（同分支别处当死文案）：重试动作词与错误条脱钩。",
            barKeyIndex in rowIndex until bodyEnd,
        )
        assertTrue(
            "错误条 Row 的重试没接真调用（找不到 `onClick = onRetryRefresh`，clickable 被掏空）：键在、" +
                "点击不动。",
            barClickIndex in rowIndex until barKeyIndex,
        )
    }

    // ── 「已断开」不补（Chief 裁决 2026-11-05：发布版断开也是静默 + 状态翻转） ──

    @Test
    fun `断开连接维持静默裁决不许加已断开提示`() {
        val arbNames = listOf(
            "app_zh.arb", "app_en.arb", "app_ja.arb", "app_ko.arb", "app_zh_TW.arb", "app_zh_HK.arb",
        )
        for (name in arbNames) {
            val text = readSource("lib/l10n/$name")
            assertTrue(
                "$name 出现了断开结果提示键（cloudSyncDisconnected）：违反「已断开不补」裁决" +
                    "（发布版 _disconnectAccount 静默，界面状态翻转即反馈）。",
                "\"cloudSyncDisconnected\"" !in text,
            )
        }
        for (name in listOf("app_zh.arb", "app_zh_TW.arb", "app_zh_HK.arb")) {
            val text = readSource("lib/l10n/$name")
            assertTrue(
                "$name 出现了「已断开」类断开结果文案（cloudSync 前缀键）：违反「已断开不补」裁决。",
                !Regex(""""cloudSync[A-Za-z]*":\s*"[^"]*已断开[^"]*"""").containsMatchIn(text),
            )
        }
        val page = readSource(
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/CloudSyncControllerPage.kt",
        )
        // 断开确认按钮的执行段必须保持静默（无提示胶囊）：从确认按钮的 onClick 起到
        // 按钮样式声明为止，中间不许出现 cloudToast。
        val confirmStart = page.indexOf("showDisconnectConfirm = false\n                        scope.launch {")
        assertTrue("找不到断开确认按钮的执行段（页面结构变了，守卫要跟着改）", confirmStart >= 0)
        val confirmEnd = page.indexOf("colors = ButtonDefaults.buttonColors(", confirmStart)
        assertTrue("找不到断开确认按钮的样式声明（页面结构变了）", confirmEnd > confirmStart)
        val confirmBody = page.substring(confirmStart, confirmEnd)
        assertTrue(
            "断开确认的执行段弹了提示胶囊：违反「已断开不补」裁决（发布版静默 + 状态翻转）。",
            "cloudToast" !in confirmBody,
        )
    }

    // ── 辅助：从仓库根定位文件（同 WebdavConnectSheetWiringGuardTest） ──

    /**
     * 剥掉 `//` 行注释与 `/* */` 块注释（字符串字面量内的 `/` 不剥）——防「把实现
     * 注释掉、字符串还在」骗过守卫（第三轮返工②判别力补洞：两行只留注释 → 全绿是洞）。
     * 断言目标串（`if (…` / `onClick = …` / 键引用）都不含 `//`，URL 字符串的误剥
     * 不会影响判红绿。
     */
    private fun stripComments(source: String): String {
        val out = StringBuilder(source.length)
        var i = 0
        var inString = false
        while (i < source.length) {
            val c = source[i]
            if (inString) {
                out.append(c)
                if (c == '\\' && i + 1 < source.length) {
                    out.append(source[i + 1])
                    i += 2
                    continue
                }
                if (c == '"') inString = false
                i++
                continue
            }
            if (c == '"') {
                inString = true
                out.append(c)
                i++
                continue
            }
            if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
                while (i < source.length && source[i] != '\n') i++
                continue
            }
            if (c == '/' && i + 1 < source.length && source[i + 1] == '*') {
                i += 2
                while (i + 1 < source.length && !(source[i] == '*' && source[i + 1] == '/')) i++
                i += 2
                continue
            }
            out.append(c)
            i++
        }
        return out.toString()
    }

    /** 从工作目录向上找仓库根再定位文件；找不到仍判失败，守卫不许静默跳过。 */
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
