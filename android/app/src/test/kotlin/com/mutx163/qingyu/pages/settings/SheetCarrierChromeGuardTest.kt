package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.testutil.SourceSlice
import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import org.junit.Test

/**
 * 弹层载体高度守卫（2026-11-14，「42 → 24」改库批次）。
 *
 * 改库 `ac1666750` 让 `TitleAndActionsRow` 在 `title` / `startAction` / `endAction`
 * 三空时整行不画（原先固定 6+12dp 的空标题行），载体头只剩 24dp 把手；
 * `1084e0f36` 把两块设置面板的限高常量从 42 收到 24。
 *
 * 判据全是代码结构（早退语句 / 尺寸 / 常量），统一走**中性化档**：KDoc 里
 * 「原先合计 42」是历史说明，剥注释后才不会假红；字符串内容同理不参与判断。
 */
class SheetCarrierChromeGuardTest {

    private companion object {
        const val MIUIX_SHEET_LAYOUT =
            "android/third_party/miuix-ui/src/main/kotlin/top/yukonga/miuix/kmp/layout/BottomSheetContentLayout.kt"
        const val MATERIAL_SHEET_BODY =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/MaterialSheetBody.kt"
        const val WALLPAPER_SHEET_BODY =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/settings/WallpaperSheetBody.kt"
    }

    /** 中性化档：判的是代码骨架，注释里的历史数字不算数。 */
    private val miuixCode by lazy { readKotlinSourceNoStrings(MIUIX_SHEET_LAYOUT) }
    private val materialCode by lazy { readKotlinSourceNoStrings(MATERIAL_SHEET_BODY) }
    private val wallpaperCode by lazy { readKotlinSourceNoStrings(WALLPAPER_SHEET_BODY) }

    /** ① 三空 ⇒ 整行不画：早退必须在 `TitleAndActionsRow` 函数体内。 */
    @Test
    fun `三空时标题行必须早退不画`() {
        val body = SourceSlice.functionBody(miuixCode, "private fun TitleAndActionsRow(")
        assertSourceContains(
            body,
            "if (title == null && startAction == null && endAction == null) return",
            "TitleAndActionsRow（三空早退）",
        )
    }

    /** ② 把手条高度仍是 24dp。 */
    @Test
    fun `把手条高度仍是 24dp`() {
        val body = SourceSlice.functionBody(miuixCode, "private fun DragHandleArea(")
        assertSourceContains(body, ".height(24.dp)", "DragHandleArea（把手 24dp）")
    }

    /** ③ 两块设置面板的载体高度常量都从 42 收到 24。 */
    @Test
    fun `两块设置面板的载体高度常量都是 24`() {
        assertSourceContains(
            materialCode,
            "private val MATERIAL_SHEET_CARRIER_CHROME = 24.dp",
            "MaterialSheetBody（载体常量）",
        )
        assertSourceContains(
            wallpaperCode,
            "private const val SHEET_CARRIER_CHROME_DP = 24f",
            "WallpaperSheetBody（载体常量）",
        )
    }

    /** ④ 载体高度不许写回 42（注释里的历史说明已被剥离，不算数）。 */
    @Test
    fun `两块设置面板的代码里不再出现 42`() {
        assertSourceLacks(materialCode, "42", "MaterialSheetBody（载体高度不许回 42）")
        assertSourceLacks(wallpaperCode, "42", "WallpaperSheetBody（载体高度不许回 42）")
    }
}
