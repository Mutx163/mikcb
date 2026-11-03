package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 顶栏返回键显隐判据的单测（2026-11-03）。
 *
 * 三条契约：从底栏进入的根页不出箭头；推入的二级页出箭头；更深层同样出箭头；
 * 外加无壳环境（预览卡）保持出箭头。
 *
 * 咬合探针（2026-11-03 已做）：把 [ShellRootEntryRule.shouldShowBackButton] 的
 * `!= true` 临时改成 `== true`（判反）→ 根页 / 二级页两例必红；还原后全绿。
 */
class ShellRootEntryRuleTest {

    @Test
    fun `从底栏进入的根页不出返回箭头`() {
        // 取件码 / 任务 / 设置 / 月视图这类：壳在 Dock entry 注入 true。
        assertFalse(ShellRootEntryRule.shouldShowBackButton(true))
    }

    @Test
    fun `二级页出返回箭头`() {
        // 设置 → 关于、取件码所在面板推入的任意子页：壳在 Page entry 注入 false。
        assertTrue(ShellRootEntryRule.shouldShowBackButton(false))
    }

    @Test
    fun `更深层的页面同样出返回箭头`() {
        // 三层及更深（仓库 → 学校 → 适配器详情）与二级页同判：仍是 Page entry，false。
        assertTrue(ShellRootEntryRule.shouldShowBackButton(false))
    }

    @Test
    fun `无壳环境保持出箭头`() {
        // 外观编辑页的缩尺预览卡等不注入：null 保持判据引入前的行为（显示）。
        assertTrue(ShellRootEntryRule.shouldShowBackButton(null))
    }
}
