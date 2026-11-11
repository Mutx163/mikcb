package com.mutx163.qingyu.pages.time_scheme

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.SourceSlice
import org.junit.Test

/**
 * **时间模板行内「三个点」必须是锚点菜单**（2026-11-10 用户报「整版直接列动作、难看」）。
 *
 * ## 它钉住的四件事
 *
 * 1. 卡片上的 ⋮ 必须**实测自己的窗口矩形并上报**（发布版 `HyperosAnchorMenuPopup` 就锚在它下面）；
 * 2. 菜单必须走 `OverlayListPopup + ListPopupColumn + DropdownImpl` 这条官方配方；
 * 3. 旧的底部动作表 `TimeSchemeMenuSheet` 不许回来（那是用户点名难看的形态）；
 * 4. 面板里不许再出现「取消」条目/文字钮（发布版菜单没有取消项，点空白/返回键收起）。
 */
class TimeSchemeMenuAnchorGuardTest {

    private val page by lazy { readKotlinSourceNoStrings(PAGE_PATH) }
    private val dialogs by lazy { readKotlinSourceNoStrings(DIALOGS_PATH) }

    @Test
    fun `卡片上的三个点必须上报自己的窗口矩形`() {
        assertTrue(
            "SchemeCard 的 ⋮ 没有 `onGloballyPositioned { … boundsInWindow() }`——" +
                "菜单就拿不到锚点，只能退回底部弹层",
            page.contains("onGloballyPositioned") && page.contains("boundsInWindow()"),
        )
        assertTrue(
            "页面必须把 anchor 交给宿主（`onOpenMenu: (schemeId, anchor: Rect?)`）",
            page.contains("onOpenMenu: (schemeId: String, anchor: Rect?) -> Unit"),
        )
        assertTrue(
            "⋮ 的点击必须带出锚点（`onClick = { onOpenMenu(menuAnchor) }`）",
            page.contains("onOpenMenu(menuAnchor)"),
        )
    }

    @Test
    fun `菜单必须走官方锚点菜单配方`() {
        assertTrue("找不到 OverlayListPopup(", dialogs.contains("OverlayListPopup("))
        assertTrue("找不到 ListPopupColumn(", dialogs.contains("ListPopupColumn"))
        assertTrue("找不到 DropdownImpl(", dialogs.contains("DropdownImpl("))
        assertTrue(
            "菜单必须自己算位置（PopupPositionProvider），否则弹不到 ⋮ 下面",
            dialogs.contains("PopupPositionProvider"),
        )
        assertTrue(
            "删除项必须用 error 色（发布版 destructive 红字）",
            dialogs.contains("QingyuTheme.error(dark)"),
        )
    }

    @Test
    fun `旧的底部动作表不许回来`() {
        assertFalse(
            "dialogs 里又出现 `fun TimeSchemeMenuSheet(`——那是用户点名难看的底部动作表",
            dialogs.contains("fun TimeSchemeMenuSheet("),
        )
        assertFalse(
            "宿主又在用 TimeSchemeMenuSheet——菜单必须换成锚点弹层",
            hostSource.contains("TimeSchemeMenuSheet("),
        )
        // 菜单里不该再有「取消」：发布版锚点菜单没有这一项（点空白/返回键收起）。
        val popupBody = SourceSlice.functionBody(dialogs, "fun TimeSchemeMenuPopup(")
        assertFalse(
            "锚点菜单里出现 cancelAction 了——发布版菜单没有取消项",
            popupBody.contains("cancelAction"),
        )
    }

    @Test
    fun `点条目先收菜单再动作（发布版 240ms）`() {
        assertTrue(
            "宿主没有 `delay(240)`——发布版 `_kCollapseBudget=240ms`：点条目立即推页/弹框" +
                "会把退场动画切在中间",
            hostSource.contains("delay(240)"),
        )
    }

    // ------------------------------------------------------------------ 工具

    private val hostSource: String by lazy { readKotlinSourceNoStrings(HOST_PATH) }

    private companion object {
        const val PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeManagementPage.kt"
        const val DIALOGS_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeManagementDialogs.kt"
        const val HOST_PATH = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/TimeSchemeHost.kt"
    }
}
