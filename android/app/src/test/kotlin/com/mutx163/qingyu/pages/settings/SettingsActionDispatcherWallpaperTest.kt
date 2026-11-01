package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.SettingsActionKind
import com.mutx163.qingyu.app.SettingsDispatch
import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 分派器的**壁纸数据 target 分支**（审计 F4 / F7 / J2「点了没反应」的接线面）。
 *
 * 判据只有一条：能碰文件 / 网络 / 设备级台账的 target 不许在分派器里被当成普通设置写入，
 * 必须原文交给宿主；而「清除图片」这类**纯设置写入**不能被误劫走。
 */
class SettingsActionDispatcherWallpaperTest {

    private val model = TimetableSettingsModel()

    private fun dispatch(target: String?, rowId: String): SettingsDispatch =
        SettingsActionDispatcher.dispatch(
            kind = SettingsActionKind.WRITE_SETTING,
            target = target,
            rowId = rowId,
            model = model,
        )

    private fun wallpaperTargetOf(target: String?, rowId: String): String? =
        (dispatch(target, rowId) as? SettingsDispatch.Write)?.wallpaperTarget

    @Test
    fun `收图 target 交给宿主执行`() {
        val target = WallpaperSheetActionTargets.picked("content://media/1")
        assertEquals(
            target,
            wallpaperTargetOf(target, WallpaperSheetActionTargets.ROW_PICK),
        )
    }

    @Test
    fun `切回 删除 撤销三种历史写入都交给宿主`() {
        val select = WallpaperSheetActionTargets.select("/w/a.png")
        assertEquals(select, wallpaperTargetOf(select, WallpaperSheetActionTargets.ROW_RECENT))

        val confirm = WallpaperSheetActionTargets.confirmDelete("/w/a.png")
        assertEquals(confirm, wallpaperTargetOf(confirm, WallpaperSheetActionTargets.ROW_RECENT))

        val undo = WallpaperSheetActionTargets.undoRemove("/w/a.png")
        assertEquals(undo, wallpaperTargetOf(undo, WallpaperSheetActionTargets.ROW_RECENT))
    }

    @Test
    fun `自动换开关带 target 与只带 rowId 都认`() {
        assertEquals(
            WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE,
            wallpaperTargetOf(
                WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE,
                WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE,
            ),
        )
        // 渲染层的开关不带新值 / target：rowId 兜底也必须认。
        assertEquals(
            WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE,
            wallpaperTargetOf(null, WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE),
        )
    }

    @Test
    fun `清除图片仍是普通设置写入 不被数据动作劫走`() {
        val result = dispatch(
            WallpaperSheetActionTargets.ROW_CLEAR,
            WallpaperSheetActionTargets.ROW_CLEAR,
        )
        assertTrue(result is SettingsDispatch.Write)
        result as SettingsDispatch.Write
        assertNull(result.wallpaperTarget)
        assertNull(result.model.homePageWallpaperPath)
    }

    @Test
    fun `分派器的壁纸前缀与唯一串表逐字一致`() {
        // 两边各写一份字面量是「模型发了、壳认不出」这类死按钮最常见的来源；
        // 这里逐条钉住，任何一侧改名都会红。
        assertEquals(
            WallpaperSheetActionTargets.PICKED_PREFIX,
            SettingsActionDispatcher.WALLPAPER_PICKED_PREFIX,
        )
        assertEquals(
            WallpaperSheetActionTargets.SELECT_PREFIX,
            SettingsActionDispatcher.WALLPAPER_SELECT_PREFIX,
        )
        assertEquals(
            WallpaperSheetActionTargets.CONFIRM_DELETE_PREFIX,
            SettingsActionDispatcher.WALLPAPER_CONFIRM_DELETE_PREFIX,
        )
        assertEquals(
            WallpaperSheetActionTargets.UNDO_REMOVE_PREFIX,
            SettingsActionDispatcher.WALLPAPER_UNDO_REMOVE_PREFIX,
        )
        assertEquals(
            WallpaperSheetActionTargets.AUTO_APPLY_TOGGLE,
            SettingsActionDispatcher.ROW_BACKDROP_AUTO_APPLY,
        )
    }
}
