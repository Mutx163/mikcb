package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 壁纸面板的 target 接收方契约（审计 F4 / F7 / J2「target 无落点」）。
 *
 * 判据只有一条：**只要是面板能发出去的 target，就必须能被解析成一个明确动作**。
 * 解析不出来 = 壳 / 分派器不知道要做什么 = 用户眼里的「死按钮」。
 *
 * 这是纯字符串契约，不需要真机；渲染层发的是不是这些串由
 * `WallpaperSheetTargets`（composeP1）逐字引用本文件的常量保证。
 */
class WallpaperSheetIntentsTest {

    @Test
    fun `五个行导航 target 都有接收方`() {
        assertEquals(
            WallpaperSheetIntent.ChooseImage,
            parseWallpaperSheetTarget(WallpaperSheetActionTargets.ROW_PICK),
        )
        assertEquals(
            WallpaperSheetIntent.MissingImage,
            parseWallpaperSheetTarget(WallpaperSheetActionTargets.ROW_MISSING),
        )
        assertEquals(
            WallpaperSheetIntent.AdjustPosition,
            parseWallpaperSheetTarget(WallpaperSheetActionTargets.ROW_ADJUST),
        )
        assertEquals(
            WallpaperSheetIntent.ClearImage,
            parseWallpaperSheetTarget(WallpaperSheetActionTargets.ROW_CLEAR),
        )
        assertEquals(
            WallpaperSheetIntent.OpenGallery,
            parseWallpaperSheetTarget(WallpaperSheetActionTargets.OPEN_GALLERY),
        )
    }

    @Test
    fun `数据写入 target 带出来的 key 原样保留`() {
        assertEquals(
            WallpaperSheetIntent.Picked("content://media/1"),
            parseWallpaperSheetTarget(WallpaperSheetActionTargets.picked("content://media/1")),
        )
        assertEquals(
            WallpaperSheetIntent.SelectHistory("C:\\wallpapers\\a.jpg"),
            parseWallpaperSheetTarget(
                WallpaperSheetActionTargets.select("C:\\wallpapers\\a.jpg"),
            ),
        )
        assertEquals(
            WallpaperSheetIntent.ConfirmRemove("/sdcard/w/a.jpg"),
            parseWallpaperSheetTarget(
                WallpaperSheetActionTargets.confirmDelete("/sdcard/w/a.jpg"),
            ),
        )
        assertEquals(
            WallpaperSheetIntent.UndoRemove("/sdcard/w/a.jpg"),
            parseWallpaperSheetTarget(
                WallpaperSheetActionTargets.undoRemove("/sdcard/w/a.jpg"),
            ),
        )
    }

    @Test
    fun `自动换开关与取消删除也有接收方`() {
        assertEquals(
            WallpaperSheetIntent.ToggleAutoApply,
            parseWallpaperSheetTarget(WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE),
        )
        assertEquals(
            WallpaperSheetIntent.CancelRemove,
            parseWallpaperSheetTarget(WallpaperSheetActionTargets.ROW_CANCEL_DELETE),
        )
    }

    @Test
    fun `空后缀与陌生串不猜`() {
        assertNull(parseWallpaperSheetTarget(null))
        assertNull(parseWallpaperSheetTarget(""))
        assertNull(parseWallpaperSheetTarget("backdrop.recent.select:"))
        assertNull(parseWallpaperSheetTarget("backdrop.image.picked:"))
        assertNull(parseWallpaperSheetTarget("whatever.unknown"))
    }

    @Test
    fun `模型里每个带 target 的行都能被解析`() {
        val spec = SettingsBackdropFlowPage.selectionPage(
            BackdropFlowState(
                imagePath = "/w/now.jpg",
                history = listOf("/w/old.jpg"),
            ),
            SelectionPageState(
                backdrop = BackdropFlowState(
                    imagePath = "/w/now.jpg",
                    history = listOf("/w/old.jpg"),
                ),
                fileMissing = true,
                armedKey = "/w/old.jpg",
            ),
        )
        val targets = spec.rows().mapNotNull { it.actionTarget }
        assertTrue("选择页至少要发出好几条 target", targets.size >= 5)
        targets.forEach { target ->
            assertNotNull("target 没有接收方：$target", parseWallpaperSheetTarget(target))
        }
    }

    @Test
    fun `模型没给 target 的两行按 rowId 补稳定串`() {
        // 清除图片：模型 actionTarget = null，渲染层靠 rowId 认
        assertEquals(
            WallpaperSheetActionTargets.ROW_CLEAR,
            WallpaperSheetActionTargets.resolveTarget(
                WallpaperSheetActionTargets.ROW_CLEAR,
                explicitTarget = null,
            ),
        )
        // 自动换开关：同上，且开关渲染层丢掉了 checked 值，数据侧必须按台账现值取反
        assertEquals(
            WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE,
            WallpaperSheetActionTargets.resolveTarget(
                WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE,
                explicitTarget = null,
            ),
        )
        // 模型给了 target 就原样用模型的
        assertEquals(
            WallpaperSheetActionTargets.ROW_ADJUST,
            WallpaperSheetActionTargets.resolveTarget(
                WallpaperSheetActionTargets.ROW_ADJUST,
                explicitTarget = WallpaperSheetActionTargets.ROW_ADJUST,
            ),
        )
        // 其余行（随周次滑动 / 模糊滑杆）不替它们猜
        assertNull(
            WallpaperSheetActionTargets.resolveTarget("backdrop.followsWeekPager", null),
        )
    }
}
