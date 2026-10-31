package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 桥接层把 `LivePageData` 传给实时活动入口页的**契约测试**。
 *
 * 钉的是 [SettingsPageBridge.specFor] 的第三个参数：`b.live` 的摘要行只认
 * `LivePageData`（`SettingsLivePage.spec` 的 `state` 参数通篇未使用）。
 * 一旦有人把该分支改回 `SettingsLivePage.spec(state)`，摘要立刻退回默认值，
 * 下面第一条断言就会红 —— 这就是本批的咬合探针。
 *
 * 真值读取（`LiveDisplayStore` → `timetable_settings`）在宿主
 * `composeP1: app/LiveSettingsPageHost.kt` 里，属于 Android 侧，不在 JVM 单测范围。
 */
class SettingsLivePageBridgeDataTest {

    /** 全关档：摘要会落成「最简显示」，与默认档（简称 · 地点 · 倒计时）必不相同。 */
    private fun minimalInput() = LiveDisplayInput(
        showCourseName = false,
        showLocation = false,
        showCountdown = false,
        showStageText = false,
        useShortName = false,
        enableMiuiIslandLabelImage = false,
    )

    @Test
    fun `specFor 把 liveData 原样转给入口页的两行摘要`() {
        val custom = LivePageData(
            beforeClass = minimalInput(),
            duringEnd = minimalInput(),
            duringEndFollowBeforeClass = false,
        )
        val spec = SettingsPageBridge.specFor(SettingsLivePage.ID, SettingsPageState(), custom)!!
        assertEquals(
            SettingsLivePage.displaySummary(custom.beforeClass).text,
            spec.row("live.beforeClassDisplay").value,
        )
        assertEquals(
            SettingsLivePage.displaySummary(custom.duringEnd).text,
            spec.row("live.duringEndDisplay").value,
        )
        // 与默认构造必须不同，否则这条测试挡不住「忘了传 data」。
        // 默认档：上课前 = 默认六布尔摘要；课中 = 跟随上课前（`duringEndFollowBeforeClass` 默认 true）。
        val default = SettingsPageBridge.specFor(SettingsLivePage.ID, SettingsPageState())!!
        val defaultBefore = default.row("live.beforeClassDisplay").value
        assertEquals(SettingsLivePage.displaySummary(LiveDisplayInput()).text, defaultBefore)
        assertEquals(
            SettingsStringsExt3.followBeforeClassSetting.zh,
            default.row("live.duringEndDisplay").value,
        )
        // 自定义档的「最简显示」与默认档必不相同 —— 传没传 data 一眼能看出来。
        if (defaultBefore == SettingsLivePage.displaySummary(minimalInput()).text) {
            error("自定义档与默认档摘要相同，测试失去辨别力")
        }
    }

    @Test
    fun `跟随上课前时课中行取跟随文案 忽略课中自己的显示项`() {
        val custom = LivePageData(
            beforeClass = LiveDisplayInput(),
            duringEnd = minimalInput(),
            duringEndFollowBeforeClass = true,
        )
        val spec = SettingsPageBridge.specFor(SettingsLivePage.ID, SettingsPageState(), custom)!!
        val during = spec.row("live.duringEndDisplay")
        assertEquals("followBeforeClassSetting", during.valueKey)
        assertEquals(SettingsStringsExt3.followBeforeClassSetting.zh, during.value)
    }
}
