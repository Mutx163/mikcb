package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 宏回放判据面测试（P2 / N7-N10）。
 *
 * 用例口径机械抄 Dart `warehouse_macro_replay_logic.dart` /
 * `warehouse_macro_dialog_replay.dart` / `warehouse_bridge_gate.dart`（只读参照）。
 * 预算常量逐字钉死（硬要求：10s 元素 / 15s 导航）。
 */
class WarehouseMacroReplayLogicTest {

    // ---------------------------------------------------------------------
    // 预算常量逐字
    // ---------------------------------------------------------------------

    @Test
    fun `预算数值与 Dart 逐字一致`() {
        assertEquals(10000, DEFAULT_MACRO_ELEMENT_WAIT_MS)
        assertEquals(15000L, MACRO_ENTRY_READY_TIMEOUT_MS)
        assertEquals(15000, MACRO_DEFAULT_NAVIGATION_WAIT_MS)
        assertEquals(300L, MACRO_POLL_INTERVAL_MS)
    }

    // ---------------------------------------------------------------------
    // 入口文档就绪
    // ---------------------------------------------------------------------

    @Test
    fun `入口就绪 非空白页且 complete`() {
        assertTrue(isWarehouseEntryDocumentReady("http://jw.example.edu.cn/login", "complete"))
        assertFalse("about:blank 不是学校页面", isWarehouseEntryDocumentReady("about:blank", "complete"))
        assertFalse(isWarehouseEntryDocumentReady("http://jw.example.edu.cn/", "loading"))
        assertFalse(isWarehouseEntryDocumentReady("", "complete"))
        assertFalse(isWarehouseEntryDocumentReady(null, "complete"))
    }

    // ---------------------------------------------------------------------
    // 导航目标加载判据
    // ---------------------------------------------------------------------

    @Test
    fun `导航判据必须文档变化且 complete`() {
        val before = "http://jw.example.edu.cn/login"
        val after = "http://jw.example.edu.cn/xsMain.jsp"
        assertTrue(
            isWarehouseTargetDocumentLoaded(
                beforeHref = before,
                currentHref = after,
                readyState = "complete",
                targetHref = after,
            ),
        )
        // readyState 未 complete：不算好
        assertFalse(
            isWarehouseTargetDocumentLoaded(before, after, "interactive", after),
        )
        // href 没变：不算好（防止「URL 本来就非空」第一拍放行）
        assertFalse(
            isWarehouseTargetDocumentLoaded(before, before, "complete", after),
        )
        // 当前页就是目标（重载场景）：complete 即算好
        assertTrue(
            isWarehouseTargetDocumentLoaded(before, before, "complete", before),
        )
        // fragment 差异不算换页，但目标匹配放行
        assertTrue(
            isWarehouseTargetDocumentLoaded(
                before,
                "$after#tab",
                "complete",
                after,
            ),
        )
        assertFalse(isWarehouseTargetDocumentLoaded(before, null, "complete", after))
    }

    @Test
    fun `文档换页判据忽略 query 与 fragment`() {
        assertTrue(
            warehouseMacroDocumentChanged(
                "http://jw.example.edu.cn/login.jsp",
                "http://jw.example.edu.cn/xsMain.jsp?x=1",
            ),
        )
        assertFalse(
            "只换锚点/查询串不算换页",
            warehouseMacroDocumentChanged(
                "http://jw.example.edu.cn/a.jsp?id=1",
                "http://jw.example.edu.cn/a.jsp?id=2#/tab",
            ),
        )
        assertFalse("任一 href 读不到：判不准不认定换页", warehouseMacroDocumentChanged(null, "http://a/"))
    }

    // ---------------------------------------------------------------------
    // 作废步骤
    // ---------------------------------------------------------------------

    @Test
    fun `作废步骤三条件缺一不可`() {
        assertFalse(
            shouldSkipWarehouseStaleClickStep(
                stepIsClick = false,
                elementNotFound = true,
                previousClickNavigated = true,
            ),
        )
        assertFalse(
            shouldSkipWarehouseStaleClickStep(
                stepIsClick = true,
                elementNotFound = false,
                previousClickNavigated = true,
            ),
        )
        assertFalse(
            shouldSkipWarehouseStaleClickStep(
                stepIsClick = true,
                elementNotFound = true,
                previousClickNavigated = false,
            ),
        )
        assertTrue(
            shouldSkipWarehouseStaleClickStep(
                stepIsClick = true,
                elementNotFound = true,
                previousClickNavigated = true,
            ),
        )
    }

    // ---------------------------------------------------------------------
    // 元素找到 / 明确没找到（读不懂 ≠ 找到 ≠ 没找到）
    // ---------------------------------------------------------------------

    @Test
    fun `元素判据 读不懂不等于找到也不等于没找到`() {
        assertTrue(warehouseMacroElementFound("""{"found":true,"tag":"INPUT"}"""))
        assertFalse(warehouseMacroElementFound("""{"found":false}"""))
        assertFalse("空串读不懂", warehouseMacroElementFound(""))
        assertFalse("半截转义读不懂", warehouseMacroElementFound("""{\"found\":true}"""))
        assertFalse("非 JSON 读不懂", warehouseMacroElementFound("complete"))

        assertTrue(warehouseMacroElementExplicitlyMissing("""{"found":false,"selector":"#a"}"""))
        assertFalse("读不懂不算明确没找到（断言场景不能凭空报错）", warehouseMacroElementExplicitlyMissing(""))
        assertFalse(warehouseMacroElementExplicitlyMissing("""{"found":true}"""))
    }

    // ---------------------------------------------------------------------
    // 选择器候选
    // ---------------------------------------------------------------------

    @Test
    fun `纯 id 形态派生 name 候选 其余不派生`() {
        // #Form1 是纯 id 形态：派生 input[name="Form1"]（旧录制把 id 当选择器、页面只写 name 的兜底）
        assertEquals(listOf("#Form1", "input[name=\"Form1\"]"), warehouseMacroSelectorCandidates("#Form1"))
        assertEquals(listOf("#userAccount", "input[name=\"userAccount\"]"), warehouseMacroSelectorCandidates("#userAccount"))
        assertEquals(listOf("div#a > p"), warehouseMacroSelectorCandidates("div#a > p"))
        assertEquals(listOf("input[name=\"x\"]"), warehouseMacroSelectorCandidates("input[name=\"x\"]"))
        assertEquals(emptyList<String>(), warehouseMacroSelectorCandidates("  "))
        assertEquals(listOf("#"), warehouseMacroSelectorCandidates("#"))
    }

    // ---------------------------------------------------------------------
    // 文字 → 下标（N8）
    // ---------------------------------------------------------------------

    @Test
    fun `录制选项文字还原成下标`() {
        val options = listOf("2025-2026-1", "2026-2027-1（当前学期）", "2026-2027-2")
        assertEquals(
            "文字精确命中",
            1,
            resolveWarehouseRecordedSelectionIndex("2026-2027-1（当前学期）", options, 0)!!,
        )
        assertEquals(
            "数字串下标也要认（宿主可能把值包成字符串）",
            2,
            resolveWarehouseRecordedSelectionIndex("2", options, 0)!!,
        )
        assertEquals(
            "数字下标原样用",
            0,
            resolveWarehouseRecordedSelectionIndex(0, options, 2)!!,
        )
        assertEquals(
            "文字优先于下标：真有叫「1」的选项时它是用户选的那项",
            1,
            resolveWarehouseRecordedSelectionIndex("2026-2027-1（当前学期）", options, 2)!!,
        )
        assertEquals(
            "换算不出回退脚本默认下标（不是取消）",
            2,
            resolveWarehouseRecordedSelectionIndex("不存在的学期", options, 2)!!,
        )
        assertNull("默认下标也越界：返回 null 绝不越界", resolveWarehouseRecordedSelectionIndex("x", options, 9))
        assertNull("recorded 为 null 直接走回退，回退也越界则 null", resolveWarehouseRecordedSelectionIndex(null, options, 9))
    }

    @Test
    fun `小数下标不合法 回退脚本默认值（与 Dart resolveRecordedSelectionIndex 同语义）`() {
        val options = listOf("a", "b")
        // 小数换算不出 → 文字/下标都落空 → 回退脚本给的默认下标 0
        assertEquals(0, resolveWarehouseRecordedSelectionIndex(0.5, options, 0)!!)
        assertEquals(1, resolveWarehouseRecordedSelectionIndex(1.0, options, 0)!!)
        // 默认值越界：返回 null 绝不越界
        assertNull(resolveWarehouseRecordedSelectionIndex(0.5, options, 9))
    }

    // ---------------------------------------------------------------------
    // complete 处置（N10）真值表
    // ---------------------------------------------------------------------

    @Test
    fun `complete 处置四分支真值表`() {
        assertEquals(
            WarehouseImportCompletionAction.IGNORE,
            warehouseImportCompletionAction(
                importExecutionActive = false,
                macroReplayActive = true,
                playbackWaitingForCourses = true,
                quickResultHandled = false,
            ),
        )
        assertEquals(
            WarehouseImportCompletionAction.SHOW_STATUS_ONLY,
            warehouseImportCompletionAction(
                importExecutionActive = true,
                macroReplayActive = true,
                playbackWaitingForCourses = true,
                quickResultHandled = false,
            ),
        )
        assertEquals(
            WarehouseImportCompletionAction.IGNORE,
            warehouseImportCompletionAction(
                importExecutionActive = true,
                macroReplayActive = true,
                playbackWaitingForCourses = false,
                quickResultHandled = true,
            ),
        )
        assertEquals(
            WarehouseImportCompletionAction.FINALIZE,
            warehouseImportCompletionAction(
                importExecutionActive = true,
                macroReplayActive = false,
                playbackWaitingForCourses = false,
                quickResultHandled = false,
            ),
        )
        // 已定局优先于仍在等课程（判定顺序：避免取消后又被写成成功）
        assertEquals(
            WarehouseImportCompletionAction.IGNORE,
            warehouseImportCompletionAction(
                importExecutionActive = false,
                macroReplayActive = true,
                playbackWaitingForCourses = true,
                quickResultHandled = true,
            ),
        )
    }

    // ---------------------------------------------------------------------
    // toast 抑制（N9）
    // ---------------------------------------------------------------------

    @Test
    fun `成功与进度类脚本提示被抑制 普通提示不抑制`() {
        listOf(
            "成功导入 12 条课程",
            "导入成功",
            "导入完成",
            "已导入 8 条课程数据",
            "Import Success",
            "imported 5 courses",
        ).forEach { message ->
            assertTrue("应抑制：$message", isWarehouseScriptImportSuccessToast(message))
        }
        listOf(
            "正在获取课表…",
            "正在导入",
            "正在通过接口拉取",
            "请稍候",
            "请稍等",
        ).forEach { message ->
            assertTrue("进度应抑制：$message", isWarehouseScriptImportProgressToast(message))
        }
        // 普通提示（如「登录成功」不含「导入」+「条课程」组合）不抑制——回放期间也要透出
        assertFalse(isWarehouseScriptImportSuccessToast("登录成功"))
        assertFalse(isWarehouseScriptImportProgressToast("用户名不能为空"))
        assertFalse(isWarehouseScriptImportSuccessToast(""))
        assertFalse(isWarehouseScriptImportSuccessToast(null))
    }

    // ---------------------------------------------------------------------
    // 失败码 → 人话（服务消息本地化）
    // ---------------------------------------------------------------------

    @Test
    fun `失败码本地化 元素没找到与轮询超时`() {
        assertEquals(
            "未找到元素：#Form1",
            WarehouseMacroReplayStrings.localize("macro_element_not_found|selector=#Form1"),
        )
        assertEquals(
            "等待页面加载 超时 15 秒 ",
            WarehouseMacroReplayStrings.localize("macro_poll_timeout|stepLabel=等待页面加载|timeoutSeconds=15|lastError="),
        )
        assertEquals(
            "参数缺失数字补 0",
            "导航到  超时 0 秒 ",
            WarehouseMacroReplayStrings.localize("macro_poll_timeout|stepLabel=导航到 "),
        )
    }

    @Test
    fun `失败码本地化 步骤失败的 detail 递归成人话`() {
        // detail 里的 selector 段被 `|` 切分（Dart parseServiceMessage 同语义）：
        // 递归本地化只认得码本身，selector 参数丢失——与 Dart 线上行为逐字一致。
        assertEquals(
            "第 6/9 步失败：未找到元素：",
            WarehouseMacroReplayStrings.localize(
                "macro_step_failed|stepIndex=6|totalSteps=9|detail=macro_element_not_found|selector=#Form1",
            ),
        )
        // 无参数码的 detail 递归完整
        assertEquals(
            "第 1/3 步失败：用户取消",
            WarehouseMacroReplayStrings.localize("macro_step_failed|stepIndex=1|totalSteps=3|detail=macro_user_cancelled"),
        )
    }

    @Test
    fun `失败码本地化 用户取消与无步骤`() {
        assertEquals("用户取消", WarehouseMacroReplayStrings.localize("macro_user_cancelled"))
        assertEquals("没有录制的步骤", WarehouseMacroReplayStrings.localize("macro_no_steps"))
        assertEquals(
            "manual_input_captcha 是码也是暂停原因",
            "请手动输入验证码；完成后点击继续",
            WarehouseMacroReplayStrings.localize("manual_input_captcha"),
        )
    }

    @Test
    fun `认不出的码原样返回 不猜语义`() {
        val payload = "macro_unknown_future_code|selector=#x"
        assertEquals(payload, WarehouseMacroReplayStrings.localize(payload))
        assertEquals("", WarehouseMacroReplayStrings.localize(null))
        assertEquals("", WarehouseMacroReplayStrings.localize(""))
    }

    @Test
    fun `macro_step_failed 结构化解析`() {
        val info = parseMacroStepFailed(
            "macro_step_failed|stepIndex=3|totalSteps=7|detail=macro_element_not_found|selector=#pwd",
        )
        assertEquals(3, info!!.stepIndex)
        assertEquals(7, info.totalSteps)
        assertEquals("macro_element_not_found", info.detail)
        // detail 的 selector 段被 `|` 切分（与 Dart parseServiceMessage 同语义）
        assertNull(info.missingSelector)
        assertNull(parseMacroStepFailed("macro_poll_timeout|timeoutSeconds=9"))
        assertNull(parseMacroStepFailed(null))
    }
}
