package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 壁纸面板两页的节点树：**「每天自动更换」只在第二页「设置」**。
 *
 * 用户 2026-11-07 口径：「外观编辑页面的 Bing 壁纸下面的设置，改到右边设置页面」。
 * 第一页仍留图库入口按钮（那是导航，不是设置），开关行整行搬到第二页，接在
 * 「壁纸模糊」后面；取值口径（台账快照 / 认不出来就禁用）跟以前一样，只是换了页。
 *
 * 纯节点层断言，不需要 Compose 运行时；「真的画在哪一页」由 `WallpaperPageList`
 * 按 `SettingsBackdropFlowPage.SETTINGS_GROUP_ID` / `BING_GROUP_ID` 分支渲染，
 * 两条分支都以本文件的 id 判据为入口。
 */
class WallpaperSheetNodesTest {

    private val state = AppearanceEditorState()

    private fun nodes(
        index: Int,
        source: WallpaperAutoApplySource = WallpaperAutoApplySource.UNKNOWN,
        snapshot: WallpaperAutoApplySnapshot? = null,
    ): List<SettingsNode> = wallpaperPageNodes(
        state = state,
        selection = SelectionPageState(backdropFlowState(state)),
        index = index,
        autoApplySource = source,
        autoApplySnapshot = snapshot,
    )

    @Test
    fun `第一页只剩图库入口，不再画「每天自动更换」`() {
        val page = nodes(WallpaperSheetPages.PICKER)
        assertEquals(
            "Bing 每日壁纸",
            page.row("backdrop.bing.entry")?.title,
        )
        // 开关行整行搬走：同 id 不许在两页各画一次（两处都可点 = 两个写入入口）。
        assertFalse(
            "第一页不该再有 backdrop.bing.autoApply",
            page.flattenedIds().contains("backdrop.bing.autoApply"),
        )
    }

    @Test
    fun `第二页把「每天自动更换」接在壁纸模糊后面`() {
        // 用台账快照代表真源已接（否则这颗开关是禁用的「不可用」形态，看不到模型文案）。
        val page = nodes(
            WallpaperSheetPages.SETTINGS,
            snapshot = WallpaperAutoApplySnapshot(enabled = false),
        )
        // 原有两根不动、顺序不变；新来的那根排最后。
        assertEquals(
            listOf("backdrop.followsWeekPager", "backdrop.blur", "backdrop.bing.autoApply"),
            page.group("backdrop.settings")?.childRowIds(),
        )
        val autoApply = page.row("backdrop.bing.autoApply")
        assertEquals("每天自动更换", autoApply?.title)
        assertEquals(SettingsStringsExt1.bingWallpaperAutoApplySubtitle.text, autoApply?.subtitle)
        // 动作与 target 与模型逐字一致：搬家不改语义，宿主分派器不必跟着改。
        assertEquals(SettingsAction.WRITE_SETTING, autoApply?.action)
    }

    @Test
    fun `没接台账时开关禁用并写明不可用`() {
        val row = nodes(WallpaperSheetPages.SETTINGS).row("backdrop.bing.autoApply")
        assertEquals(false, row?.enabled)
        // 用 ARB 已有的「不可用」，不新造一句。
        assertEquals(SettingsStrings.aboutUnavailable.text, row?.subtitle)
    }

    @Test
    fun `台账快照是唯一真源：值取快照且可点`() {
        val on = WallpaperAutoApplySnapshot(enabled = true)
        val row = nodes(WallpaperSheetPages.SETTINGS, snapshot = on).row("backdrop.bing.autoApply")
        assertEquals(true, row?.enabled)
        assertEquals(true, row?.switchValue)
        // 与「认不出来」那支必须真的不同，否则上一条会假绿。
        assertNotEquals(
            SettingsStrings.aboutUnavailable.text,
            row?.subtitle,
        )
        // 快照说关，就显示关（不是回落到模型的出厂值）。
        val off = nodes(
            WallpaperSheetPages.SETTINGS,
            source = WallpaperAutoApplySource.LEDGER,
            snapshot = WallpaperAutoApplySnapshot(enabled = false),
        ).row("backdrop.bing.autoApply")
        assertEquals(false, off?.switchValue)
        assertTrue(off?.enabled == true)
    }

    // ---------------------------------------------------------------- 节点树小工具

    private fun List<SettingsNode>.flatten(): List<SettingsNode> = flatMap { node ->
        if (node is SettingsGroup) listOf(node) + node.children.flatten() else listOf(node)
    }

    private fun List<SettingsNode>.flattenedIds(): List<String> = flatten().map { it.id }

    private fun List<SettingsNode>.row(id: String): SettingsRow? =
        flatten().filterIsInstance<SettingsRow>().firstOrNull { it.id == id }

    private fun List<SettingsNode>.group(id: String): SettingsGroup? =
        flatten().filterIsInstance<SettingsGroup>().firstOrNull { it.id == id }

    private fun SettingsGroup.childRowIds(): List<String> =
        children.filterIsInstance<SettingsRow>().map { it.id }
}
