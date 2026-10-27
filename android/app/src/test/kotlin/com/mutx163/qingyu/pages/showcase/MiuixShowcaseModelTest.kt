package com.mutx163.qingyu.pages.showcase

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Miuix 展示册模型层与状态机单元测试。
 */
class MiuixShowcaseModelTest {

    // ── 目录与检索逻辑测试 ──

    @Test
    fun `目录包含全部 13 个独立分类条目`() {
        val entries = MiuixShowcaseCatalog.allEntries
        assertEquals(13, entries.size)

        val ids = entries.map { it.id }.toSet()
        assertEquals(13, ids.size)

        val categories = entries.map { it.category }.toSet()
        assertEquals(13, categories.size)
    }

    @Test
    fun `根据 ID 和 Category 正常检索条目`() {
        val buttonEntry = MiuixShowcaseCatalog.findEntryById("buttons")
        assertNotNull(buttonEntry)
        assertEquals(ShowcaseCategoryId.BUTTONS, buttonEntry!!.category)

        val inputEntry = MiuixShowcaseCatalog.findEntryByCategory(ShowcaseCategoryId.INPUTS)
        assertEquals("inputs", inputEntry.id)

        assertNull(MiuixShowcaseCatalog.findEntryById("non_existent_category"))
    }

    @Test
    fun `空搜索词与全量条目匹配`() {
        assertEquals(13, MiuixShowcaseCatalog.filterEntries("").size)
        assertEquals(13, MiuixShowcaseCatalog.filterEntries("   ").size)
    }

    @Test
    fun `检索逻辑支持中英文标题与关键词命中`() {
        // 英文标题命中
        val buttonMatches = MiuixShowcaseCatalog.filterEntries("button")
        assertTrue(buttonMatches.any { it.id == "buttons" })

        // 中文标题命中
        val inputMatches = MiuixShowcaseCatalog.filterEntries("输入")
        assertTrue(inputMatches.any { it.id == "inputs" })

        // 关键词命中
        val fabMatches = MiuixShowcaseCatalog.filterEntries("FAB")
        assertEquals(1, fabMatches.size)
        assertEquals("buttons", fabMatches[0].id)

        val switchMatches = MiuixShowcaseCatalog.filterEntries("开关")
        assertTrue(switchMatches.any { it.id == "inputs" })

        val squircleMatches = MiuixShowcaseCatalog.filterEntries("squircle")
        assertTrue(squircleMatches.any { it.id == "foundation" })

        // 无匹配项
        val none = MiuixShowcaseCatalog.filterEntries("xyz_impossible_keyword_123")
        assertTrue(none.isEmpty())
    }

    @Test
    fun `搜索历史管理正常去重并保持上限`() {
        var history = emptyList<String>()

        history = MiuixShowcaseCatalog.addSearchHistory(history, "按钮")
        assertEquals(listOf("按钮"), history)

        history = MiuixShowcaseCatalog.addSearchHistory(history, "滑块")
        assertEquals(listOf("滑块", "按钮"), history)

        // 重复项移动到最前
        history = MiuixShowcaseCatalog.addSearchHistory(history, "按钮")
        assertEquals(listOf("按钮", "滑块"), history)

        // 空输入忽略
        history = MiuixShowcaseCatalog.addSearchHistory(history, "   ")
        assertEquals(listOf("按钮", "滑块"), history)

        // 超过 10 项截断
        for (i in 1..15) {
            history = MiuixShowcaseCatalog.addSearchHistory(history, "SearchItem_$i")
        }
        assertEquals(MiuixShowcaseCatalog.MAX_HISTORY_ITEMS, history.size)
        assertEquals("SearchItem_15", history.first())

        // 删除单项
        history = MiuixShowcaseCatalog.removeSearchHistoryItem(history, "SearchItem_15")
        assertEquals(9, history.size)
        assertFalse(history.contains("SearchItem_15"))
    }

    // ── 交互状态机逻辑测试 ──

    @Test
    fun `按钮交互状态转移正确`() {
        var state = ShowcaseInteractionState()
        assertEquals(0, state.buttonClickCount)
        assertEquals("", state.lastClickedButton)

        state = state.onButtonClick("Primary")
        assertEquals(1, state.buttonClickCount)
        assertEquals("Primary", state.lastClickedButton)

        state = state.onButtonClick("Secondary")
        assertEquals(2, state.buttonClickCount)
        assertEquals("Secondary", state.lastClickedButton)
    }

    @Test
    fun `输入控件开关与单复选状态机`() {
        var state = ShowcaseInteractionState()
        assertTrue(state.wifiEnabled)
        assertFalse(state.bluetoothEnabled)
        assertFalse(state.airplaneMode)

        state = state.toggleWifi()
        assertFalse(state.wifiEnabled)

        state = state.toggleBluetooth()
        assertTrue(state.bluetoothEnabled)

        state = state.toggleAirplaneMode()
        assertTrue(state.airplaneMode)

        // 三态复选框循环：false -> true -> null -> false
        assertEquals(false, state.triState)
        state = state.cycleTriState()
        assertEquals(true, state.triState)
        state = state.cycleTriState()
        assertNull(state.triState)
        state = state.cycleTriState()
        assertEquals(false, state.triState)

        // 单选框选项
        state = state.setRadioOption(1)
        assertEquals(1, state.selectedRadioOption)
        state = state.setRadioOption(5) // 越界夹持在 2
        assertEquals(2, state.selectedRadioOption)
    }

    @Test
    fun `滑块与区间数值范围夹持`() {
        var state = ShowcaseInteractionState()

        state = state.setContinuousSlider(0.85f)
        assertEquals(0.85f, state.continuousSliderValue, 0.001f)

        state = state.setContinuousSlider(1.5f) // 越界上限夹持
        assertEquals(1.0f, state.continuousSliderValue, 0.001f)

        state = state.setContinuousSlider(-0.5f) // 越界下限夹持
        assertEquals(0.0f, state.continuousSliderValue, 0.001f)

        state = state.setSteppedSlider(7)
        assertEquals(7, state.steppedSliderValue)

        state = state.setSteppedSlider(99)
        assertEquals(10, state.steppedSliderValue)

        state = state.setRange(0.3f, 0.9f)
        assertEquals(0.3f, state.rangeStart, 0.001f)
        assertEquals(0.9f, state.rangeEnd, 0.001f)

        // 倒置区间自动修正
        state = state.setRange(0.8f, 0.2f)
        assertEquals(0.8f, state.rangeStart, 0.001f)
        assertEquals(0.8f, state.rangeEnd, 0.001f)
    }

    @Test
    fun `选择器时间计算与首尾循环`() {
        var state = ShowcaseInteractionState()
        state = state.setTime(23, 59)
        assertEquals(23, state.pickerHour)
        assertEquals(59, state.pickerMinute)

        // 顺加 1 小时循环到 0
        state = state.adjustHour(1)
        assertEquals(0, state.pickerHour)

        // 逆减 1 小时循环到 23
        state = state.adjustHour(-1)
        assertEquals(23, state.pickerHour)

        // 分钟循环
        state = state.adjustMinute(1)
        assertEquals(0, state.pickerMinute)

        state = state.adjustMinute(-1)
        assertEquals(59, state.pickerMinute)

        // 日期设置
        state = state.setDate(2027, 10, 1)
        assertEquals(2027, state.pickerYear)
        assertEquals(10, state.pickerMonth)
        assertEquals(1, state.pickerDay)

        // 色彩空间切换
        state = state.setColorSpaceIndex(2)
        assertEquals(2, state.pickerColorSpaceIndex)
    }

    @Test
    fun `反馈弹窗与进度步进`() {
        var state = ShowcaseInteractionState()
        assertFalse(state.isBasicDialogOpen)
        assertFalse(state.isConfirmDialogOpen)

        state = state.showBasicDialog(true)
        assertTrue(state.isBasicDialogOpen)

        state = state.showConfirmDialog(true)
        assertTrue(state.isConfirmDialogOpen)

        state = state.showSnackbar("测试消息")
        assertEquals("测试消息", state.snackbarMessage)

        // 进度步进
        assertEquals(0f, state.progress, 0.001f)
        state = state.stepProgress(0.4f)
        assertEquals(0.4f, state.progress, 0.001f)
        assertTrue(state.isProgressPlaying)

        state = state.stepProgress(0.8f) // 溢出夹持到 1.0f
        assertEquals(1.0f, state.progress, 0.001f)
        assertFalse(state.isProgressPlaying)

        state = state.resetProgress()
        assertEquals(0f, state.progress, 0.001f)
        assertFalse(state.isProgressPlaying)
    }

    @Test
    fun `浮层与计数器状态`() {
        var state = ShowcaseInteractionState()
        assertFalse(state.isBottomSheetOpen)
        assertFalse(state.isActionSheetOpen)
        assertEquals(0, state.counter)

        state = state.showBottomSheet(true)
        assertTrue(state.isBottomSheetOpen)

        state = state.showActionSheet(true)
        assertTrue(state.isActionSheetOpen)

        state = state.incrementCounter()
        state = state.incrementCounter()
        assertEquals(2, state.counter)

        state = state.decrementCounter()
        assertEquals(1, state.counter)
    }

    @Test
    fun `主题与基础视觉参数状态转移`() {
        var state = ShowcaseInteractionState()
        assertEquals(0xFF3482FF, state.selectedSeedColorHex)
        assertFalse(state.isDarkTheme)

        state = state.setSeedColor(0xFFFF5B29)
        assertEquals(0xFFFF5B29, state.selectedSeedColorHex)

        state = state.toggleDarkTheme()
        assertTrue(state.isDarkTheme)

        state = state.setPaletteStyle(2)
        assertEquals(2, state.themePaletteStyleIndex)

        state = state.setBlurRadius(35f)
        assertEquals(35f, state.blurRadius, 0.001f)

        state = state.setBlurSaturation(1.8f)
        assertEquals(1.8f, state.blurSaturation, 0.001f)

        state = state.setSquircleRadius(32f)
        assertEquals(32f, state.squircleRadius, 0.001f)

        state = state.setHapticTypeIndex(1)
        assertEquals(1, state.hapticTypeIndex)
    }
}
