package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 首页「更多」容器变换的几何插值。
 *
 * 这些数是**屏上真实几何**的唯一来源（渲染层不重复推导），所以逐数钉死：
 * 收起态必须与触发按钮严丝合缝（否则点开第一帧会跳一下），展开态必须等于
 * 面板宽度（否则菜单内容会被拉宽或缩窄）。
 */
class HomeMenuMorphModelTest {

    private val eps = 0.001f

    @Test
    fun `收起态宽度等于触发按钮直径`() {
        assertEquals(40f, HomeMenuMorphModel.widthDp(0f), eps)
    }

    @Test
    fun `展开态宽度等于面板宽度`() {
        assertEquals(200f, HomeMenuMorphModel.widthDp(1f), eps)
    }

    @Test
    fun `半程宽度取中点`() {
        assertEquals(120f, HomeMenuMorphModel.widthDp(0.5f), eps)
    }

    @Test
    fun `宽度保留弹簧过冲但不接受离谱值`() {
        // 过冲 10% ⇒ 略超面板宽（"长过头再收回"的观感来源）
        assertEquals(216f, HomeMenuMorphModel.widthDp(1.1f), eps)
        // 过冲上限 1.2 ⇒ 232；再大也只到 232
        assertEquals(232f, HomeMenuMorphModel.widthDp(5f), eps)
        // 反向过冲下限 -0.2 ⇒ 8dp，不会出现负尺寸
        assertEquals(8f, HomeMenuMorphModel.widthDp(-9f), eps)
    }

    @Test
    fun `收起态高度恒等于按钮直径 与菜单有几行无关`() {
        assertEquals(40f, HomeMenuMorphModel.heightPx(0f, triggerPx = 40f, contentHeightPx = 900f), eps)
    }

    @Test
    fun `展开态高度等于内容自然高度`() {
        assertEquals(900f, HomeMenuMorphModel.heightPx(1f, triggerPx = 40f, contentHeightPx = 900f), eps)
    }

    @Test
    fun `内容缩放按当前宽占面板宽的比例`() {
        assertEquals(0.2f, HomeMenuMorphModel.contentScale(40f), eps)
        assertEquals(1f, HomeMenuMorphModel.contentScale(200f), eps)
        assertEquals(0.6f, HomeMenuMorphModel.contentScale(120f), eps)
    }

    @Test
    fun `内容缩放异常输入不除零`() {
        assertEquals(1f, HomeMenuMorphModel.contentScale(120f, panelWidth = 0f), eps)
    }

    @Test
    fun `内容在 0点3 到 0点7 之间淡入`() {
        assertEquals(0f, HomeMenuMorphModel.contentAlpha(0f), eps)
        assertEquals(0f, HomeMenuMorphModel.contentAlpha(0.3f), eps)
        assertEquals(0.5f, HomeMenuMorphModel.contentAlpha(0.5f), eps)
        assertEquals(1f, HomeMenuMorphModel.contentAlpha(0.7f), eps)
        assertEquals(1f, HomeMenuMorphModel.contentAlpha(1f), eps)
    }

    @Test
    fun `过冲时内容不会超出缩放上限`() {
        // 过冲 10% 时内容最多回到 1.0（不放大到 1.1 把文字糊出面板）
        assertEquals(1f, HomeMenuMorphModel.contentScale(HomeMenuMorphModel.widthDp(1.1f)), eps)
    }
}
