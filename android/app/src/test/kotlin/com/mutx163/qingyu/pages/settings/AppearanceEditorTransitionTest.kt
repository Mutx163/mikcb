package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 外观编辑页转场 / 几何契约测试。
 *
 * 被测对象是纯 Kotlin 的 [AppearanceEditorTransitionSpec]、
 * [leadingCornerNotch]、[appearanceEditorCardBox]、[zoomSnapshotFrame]。
 * 期望值全部来自 Dart 原件（行号见各常量注释），不是实现里的同类算式复述。
 *
 * ⚠️ 改洞的几何参数（半径 / 角点 / 是否补色 / 可见判据）或缩放时间线时，先跑本文件：
 * 咬合探针见报告「改坏半径 → `洞的半径恒定` 红」。
 */
class AppearanceEditorTransitionTest {

    // ───────────────────────────────────────────── 时间线（zoom）

    @Test
    fun `缩放时间线端点精确`() {
        // hyperos_zoom_route.dart:55-59 / :101-105 / :119-126
        assertEquals(0f, AppearanceEditorTransitionSpec.progress(0f), 0f)
        assertEquals(1f, AppearanceEditorTransitionSpec.progress(1f), 0f)
        assertEquals(0f, AppearanceEditorTransitionSpec.linearT(0f), 0f)
        assertEquals("chromeT(1) 必须精确是 1", 1f, AppearanceEditorTransitionSpec.chromeT(1f), 0f)
        assertEquals(0f, AppearanceEditorTransitionSpec.shrinkT(0f), 0f)
        assertEquals(1f, AppearanceEditorTransitionSpec.shrinkT(1f), 0f)
    }

    @Test
    fun `总进度单调递增`() {
        var last = -1f
        for (i in 0..100) {
            val p = i / 100f
            val v = AppearanceEditorTransitionSpec.progress(p)
            assertTrue("progress 必须单调：p=$p", v >= last)
            last = v
        }
    }

    @Test
    fun `linearT 是 progress 的逆`() {
        for (i in 1..99) {
            val p = i / 100f
            val roundTrip = AppearanceEditorTransitionSpec.progress(
                AppearanceEditorTransitionSpec.linearT(p),
            )
            assertEquals("linearT 反解误差 p=$p", p, roundTrip, 0.002f)
        }
    }

    @Test
    fun `缩小段结束才轮到编辑页出场`() {
        // growT 在 swapPoint 之前恒 0（hyperos_zoom_route.dart:105）
        assertEquals(0f, AppearanceEditorTransitionSpec.growT(0f), 0f)
        assertEquals(0f, AppearanceEditorTransitionSpec.growT(AppearanceEditorTransitionSpec.SWAP_POINT), 0f)
        assertTrue(AppearanceEditorTransitionSpec.growT(0.46f) > 0f)
        assertEquals(1f, AppearanceEditorTransitionSpec.growT(1f), 0f)
    }

    @Test
    fun `chrome 比暗底更晚出场且按线性时间起势`() {
        // hyperos_zoom_route.dart:107-126：chromeT 经 linearT 反解，起点在 0.55 线性时间
        val pBefore = AppearanceEditorTransitionSpec.progress(0.5f)
        assertEquals("缩放结束前 chrome 必须完全不可见", 0f, AppearanceEditorTransitionSpec.chromeT(pBefore), 0f)
        val pAfter = AppearanceEditorTransitionSpec.progress(0.6f)
        assertTrue("0.6 线性时间后 chrome 应开始出现", AppearanceEditorTransitionSpec.chromeT(pAfter) > 0f)
        // 且它比暗底晚：同一进度下 chromeT <= growT
        for (i in 55..99) {
            val p = i / 100f
            val grow = AppearanceEditorTransitionSpec.growT(p)
            val chrome = AppearanceEditorTransitionSpec.chromeT(p)
            assertTrue("chrome 不应早于暗底 p=$p", chrome <= grow + 1e-3f)
        }
    }

    @Test
    fun `卡片阶跃与浮影跟随暗底`() {
        // settings_appearance_editor.dart:1738（阶跃）与 :1834-1841（浮影）
        assertFalse(AppearanceEditorTransitionSpec.cardVisible(AppearanceEditorTransitionSpec.SWAP_POINT))
        assertTrue(AppearanceEditorTransitionSpec.cardVisible(0.46f))
        assertEquals(0f, AppearanceEditorTransitionSpec.cardShadowAlpha(0f), 0f)
        assertEquals(
            AppearanceEditorTransitionSpec.CARD_SHADOW_ALPHA,
            AppearanceEditorTransitionSpec.cardShadowAlpha(1f),
            1e-6f,
        )
    }

    @Test
    fun `退场源只在预览视图与首页一致时可用`() {
        // settings_appearance_editor.dart:751-762
        assertTrue(AppearanceEditorTransitionSpec.exitSourceEligible(true, true, true))
        assertTrue(AppearanceEditorTransitionSpec.exitSourceEligible(true, false, false))
        assertFalse("没烤出图就不能发布", AppearanceEditorTransitionSpec.exitSourceEligible(false, true, true))
        assertFalse("切过日周就不发布", AppearanceEditorTransitionSpec.exitSourceEligible(true, true, false))
    }

    // ───────────────────────────────────────────── 洞（前缘圆角）

    @Test
    fun `Dart 出货态不挖洞`() {
        // hyperos_miuix_spec.dart:813：clipLeadingCornersWhileMoving = false
        assertFalse(AppearanceEditorTransitionSpec.NOTCH_SHIPPED_ENABLED)
        val notch = leadingCornerNotch(
            enterProgress = 0.5f,
            screenWidthDp = 400f,
            screenHeightDp = 800f,
            deviceCornerRadiusDp = 28f,
            mode = NotchMode.Disabled,
        )
        assertFalse(notch.enabled)
        assertFalse(notch.visible)
        assertEquals(0f, notch.radiusDp, 0f)
        assertEquals(0f, notch.topLeftRadiusDp, 0f)
        assertEquals(0f, notch.bottomLeftRadiusDp, 0f)
    }

    @Test
    fun `LTR 洞只挖前缘左两角`() {
        // hyperos_navigation.dart:700-724：只裁正在滑入的栈顶页，前缘两角
        val notch = leadingCornerNotch(
            enterProgress = 0.5f,
            screenWidthDp = 400f,
            screenHeightDp = 800f,
            deviceCornerRadiusDp = 28f,
            isRtl = false,
            mode = NotchMode.LeadingCorners,
        )
        assertTrue(notch.enabled)
        assertTrue(notch.visible)
        assertEquals(28f, notch.radiusDp, 0f)
        assertEquals(28f, notch.topLeftRadiusDp, 0f)
        assertEquals(28f, notch.bottomLeftRadiusDp, 0f)
        assertEquals(0f, notch.topRightRadiusDp, 0f)
        assertEquals(0f, notch.bottomRightRadiusDp, 0f)
        // 页面滑到一半：前缘在 x=200，洞就开在那一侧
        assertEquals(200f, notch.leadingEdgeXDp, 0f)
        assertEquals(200f, notch.holeLeftDp, 0f)
        assertEquals(228f, notch.holeRightDp, 0f)
        assertEquals(0f, notch.holeTopDp, 0f)
        assertEquals(800f, notch.holeBottomDp, 0f)
    }

    @Test
    fun `RTL 洞镜像到右两角`() {
        val notch = leadingCornerNotch(
            enterProgress = 0.5f,
            screenWidthDp = 400f,
            screenHeightDp = 800f,
            deviceCornerRadiusDp = 28f,
            isRtl = true,
            mode = NotchMode.LeadingCorners,
        )
        assertEquals(28f, notch.topRightRadiusDp, 0f)
        assertEquals(28f, notch.bottomRightRadiusDp, 0f)
        assertEquals(0f, notch.topLeftRadiusDp, 0f)
        assertEquals(0f, notch.bottomLeftRadiusDp, 0f)
        assertEquals(200f, notch.leadingEdgeXDp, 0f)
        assertEquals(172f, notch.holeLeftDp, 0f)
        assertEquals(200f, notch.holeRightDp, 0f)
    }

    @Test
    fun `洞的半径恒定 不随进度收窄`() {
        // hyperos_miuix_spec.dart:815-820：2026-10-18 起半径全程恒定，不再末段收束
        val radii = listOf(0.1f, 0.25f, 0.5f, 0.75f, 0.9f).map { t ->
            leadingCornerNotch(
                enterProgress = t,
                screenWidthDp = 400f,
                screenHeightDp = 800f,
                deviceCornerRadiusDp = 28f,
                mode = NotchMode.LeadingCorners,
            ).radiusDp
        }
        radii.forEach { assertEquals("半径必须全程恒定为 28", 28f, it, 0f) }
    }

    @Test
    fun `停稳后洞消失 设备报 0 时也不挖洞`() {
        // 官方 NavDisplayEffects 判据 -1 < d < 0：停稳的栈顶不裁
        val settled = leadingCornerNotch(
            enterProgress = 1f,
            screenWidthDp = 400f,
            screenHeightDp = 800f,
            deviceCornerRadiusDp = 28f,
            mode = NotchMode.LeadingCorners,
        )
        assertFalse("停稳后不应再裁", settled.visible)
        // 半径字段仍是设备读数（几何不变），只是不生效
        assertEquals(28f, settled.radiusDp, 0f)

        val noCornerDevice = leadingCornerNotch(
            enterProgress = 0.5f,
            screenWidthDp = 400f,
            screenHeightDp = 800f,
            deviceCornerRadiusDp = 0f,
            mode = NotchMode.LeadingCorners,
        )
        assertEquals("平台报 0 时不挖洞", 0f, noCornerDevice.radiusDp, 0f)
    }

    @Test
    fun `洞永不补色也永不描边`() {
        // hyperos_miuix_spec.dart:776-802：两轮补色 + 前缘细线全部被否
        val notch = leadingCornerNotch(
            enterProgress = 0.5f,
            screenWidthDp = 400f,
            screenHeightDp = 800f,
            deviceCornerRadiusDp = 28f,
            mode = NotchMode.LeadingCorners,
        )
        assertEquals(NotchFill.None, notch.fill)
        assertNull("洞不补色", notch.fillArgb)
        assertEquals("洞不描边", 0f, notch.strokeDp, 0f)
        assertEquals(28f, notch.holeWidthDp, 0f)
    }

    @Test
    fun `预览洞半径按缩尺比收小`() {
        assertEquals(14f, AppearanceEditorTransitionSpec.previewNotchRadiusDp(28f, 0.5f), 0f)
        assertEquals(0f, AppearanceEditorTransitionSpec.previewNotchRadiusDp(0f, 0.5f), 0f)
        assertEquals(0f, AppearanceEditorTransitionSpec.previewNotchRadiusDp(28f, 0f), 0f)
    }

    // ───────────────────────────────────────────── 卡片几何（B3 / B4）

    private fun sampleCardBox() = appearanceEditorCardBox(
        areaWidthDp = 400f,
        areaHeightDp = 800f,
        screenWidthDp = 393f,
        screenHeightDp = 852f,
        topInsetDp = 24f,
        bottomInsetDp = 24f,
        screenCornerRadiusDp = 28f,
    )

    @Test
    fun `卡片几何逐数对 Dart`() {
        // settings_appearance_editor.dart:1624-1650
        val box = sampleCardBox()
        assertEquals(98f, box.topReserveDp, 0.001f)   // 24 + 16 + 40 + 18
        assertEquals(130f, box.bottomReserveDp, 0.001f) // 24 + 24 + 56 + 8 + 18
        assertEquals(572f, box.availableHeightDp, 0.001f)
        // 高度是限制项（竖屏），卡片高正好吃满上下净空之间的带子
        assertEquals(572f, box.cardHeightDp, 0.001f)
        assertEquals(box.topReserveDp, box.cardTopDp, 0.001f)
        // 等比：宽高比与整屏一致
        assertEquals(393f / 852f, box.cardWidthDp / box.cardHeightDp, 1e-4f)
        // 横向居中
        assertEquals((400f - box.cardWidthDp) / 2f, box.cardLeftDp, 0.001f)
        // 圆角 = 屏幕圆角 × scale
        assertEquals(28f * box.scale, box.radiusDp, 0.001f)
    }

    @Test
    fun `宽窗口时宽度成为限制项且圆角夹到半高`() {
        val box = appearanceEditorCardBox(
            areaWidthDp = 300f,
            areaHeightDp = 2000f,
            screenWidthDp = 400f,
            screenHeightDp = 800f,
            topInsetDp = 0f,
            bottomInsetDp = 0f,
            screenCornerRadiusDp = 500f,
        )
        assertEquals(300f * 0.86f, box.cardWidthDp, 0.001f)
        assertEquals(300f * 0.86f / 400f, box.scale, 1e-5f)
        assertEquals(box.cardHeightDp / 2f, box.radiusDp, 0.001f)
    }

    @Test
    fun `可用高度不足时钳到下限 120`() {
        val box = appearanceEditorCardBox(
            areaWidthDp = 400f,
            areaHeightDp = 100f,
            screenWidthDp = 400f,
            screenHeightDp = 800f,
            topInsetDp = 24f,
            bottomInsetDp = 24f,
        )
        assertEquals(120f, box.availableHeightDp, 0.001f)
    }

    // ───────────────────────────────────────────── 首页快照帧（退出长回全屏）

    @Test
    fun `快照起点是整屏且圆角取屏幕圆角`() {
        val landing = sampleCardBox()
        val frame = zoomSnapshotFrame(
            progress = 0f,
            screenWidthDp = 393f,
            screenHeightDp = 852f,
            landing = landing,
            deviceCornerRadiusDp = 28f,
        )
        assertEquals(0f, frame.leftDp, 0.001f)
        assertEquals(0f, frame.topDp, 0.001f)
        assertEquals(393f, frame.widthDp, 0.001f)
        assertEquals(852f, frame.heightDp, 0.001f)
        // 起点圆角 = min(28, 393/2)，不是 0（hyperos_zoom_route.dart:462-481）
        assertEquals(28f, frame.radiusDp, 0.001f)
        // 整屏时 sx = 1，变换前半径 = 显示半径
        assertEquals(28f, frame.clipRadiusBeforeScaleDp, 0.001f)
    }

    @Test
    fun `快照终点与卡片落到同一矩形与圆角`() {
        // 硬要求：landT=1 时快照四边与卡片逐像素重合（hyperos_zoom_route.dart:457-461）
        val landing = sampleCardBox()
        val frame = zoomSnapshotFrame(
            progress = 1f,
            screenWidthDp = 393f,
            screenHeightDp = 852f,
            landing = landing,
            deviceCornerRadiusDp = 28f,
        )
        assertEquals(landing.cardLeftDp, frame.leftDp, 0.001f)
        assertEquals(landing.cardTopDp, frame.topDp, 0.001f)
        assertEquals(landing.cardWidthDp, frame.widthDp, 0.001f)
        assertEquals(landing.cardHeightDp, frame.heightDp, 0.001f)
        assertEquals(landing.radiusDp, frame.radiusDp, 0.001f)
    }

    @Test
    fun `快照矩形随进度单调收缩`() {
        val landing = sampleCardBox()
        var last = Float.MAX_VALUE
        for (i in 0..100) {
            val frame = zoomSnapshotFrame(
                progress = i / 100f,
                screenWidthDp = 393f,
                screenHeightDp = 852f,
                landing = landing,
                deviceCornerRadiusDp = 28f,
            )
            assertTrue("宽度必须单调不减地缩小", frame.widthDp <= last + 1e-4f)
            last = frame.widthDp
        }
    }
}
