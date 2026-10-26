package com.mutx163.qingyu.weather

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 壁纸亮度纯计算：WCAG 相对亮度 / 逐行剖面 / 采样键 / 墨色极性。
 *
 * 期望值来源：
 * - [Dart抄录] test/utils/home_page_background_luminance_test.dart（黑白图全 0 / 全 1、
 *   中灰 closeTo Color.computeLuminance、0.179 分界）；
 * - [Dart推演] lib/utils/wallpaper_luminance_profile.dart 的行范围与取整公式；
 * - [人推] WCAG 公式自算的期望值（与 Dart 测试「期望值按公式自己算，不复用被测实现」同款）。
 *
 * 不移植：图像解码与像素遍历（readEncodedImageSize / _rowLuminanceProfile 的
 * ui.Image 部分——IO/引擎边界）。本文件从**任意图的逐行亮度序列**出发，
 * 覆盖序列之后的全部分支。
 */
class WallpaperLuminanceLogicTest {

    // ---------- sRGB 线性化与相对亮度 ----------

    @Test
    fun `black reads zero white reads one`() { // [Dart抄录] all-black / all-white 两组
        assertEquals(0.0, relativeLuminanceOf(0, 0, 0), 1e-12)
        assertEquals(1.0, relativeLuminanceOf(255, 255, 255), 1e-12)
    }

    @Test
    fun `mid gray matches wcag luminance`() { // [Dart抄录] mid-tone closeTo Color.computeLuminance
        // Color(0xFF808080).computeLuminance() ≈ 0.2158608（按 WCAG 公式人推）。
        val expected = relativeLuminanceOf(128, 128, 128)
        assertEquals(0.2158608, expected, 1e-6)
    }

    @Test
    fun `linearize uses engine threshold 0_03928`() { // [Dart推演] _linearizeSrgbComponent 的阈值注释
        // 0.03928 * 255 ≈ 10.0164 → 值 10 及以下走线性段。
        val atThreshold = linearizeSrgbComponent(10.0 / 255.0)
        assertEquals((10.0 / 255.0) / 12.92, atThreshold, 1e-12)
        val justAbove = linearizeSrgbComponent(11.0 / 255.0)
        assertEquals(Math.pow((11.0 / 255.0 + 0.055) / 1.055, 2.4), justAbove, 1e-12)
    }

    @Test
    fun `green dominates luminance weighting`() { // [人推] 0.2126/0.7152/0.0722 权重
        assertEquals(0.7152, relativeLuminanceOf(0, 255, 0), 1e-12)
        assertEquals(0.2126, relativeLuminanceOf(255, 0, 0), 1e-12)
        assertEquals(0.0722, relativeLuminanceOf(0, 0, 255), 1e-12)
    }

    // ---------- WallpaperLuminanceProfile ----------

    @Test
    fun `empty profile returns null everywhere`() { // [Dart推演] empty 剖面：average/bands/luminanceForVerticalRange 全 null
        val profile = WallpaperLuminanceProfile.empty
        assertTrue(profile.isEmpty)
        assertNull(profile.averageValue)
        assertNull(profile.bands())
        assertNull(profile.luminanceForVerticalRange(0.0, 1.0))
    }

    @Test
    fun `average is the plain mean`() { // [Dart推演]
        val profile = WallpaperLuminanceProfile(listOf(0.1, 0.3, 0.5, 0.7))
        assertEquals(0.4, profile.averageValue!!, 1e-12)
    }

    @Test
    fun `vertical range matches band row math`() { // [Dart推演] 「按旧三带同一套 floor/ceil 取整」——0~0.09 与 bands.top 逐位一致
        // 100 行：第 0 行 0.0（黑），第 1..99 行 1.0（白）。
        val rows = List(100) { if (it == 0) 0.0 else 1.0 }
        val profile = WallpaperLuminanceProfile(rows)
        val top = profile.luminanceForVerticalRange(0.0, 0.09)!!
        // floor(100*0)=0 行起，ceil(100*0.09)=9 行止 → 9 行、1 行黑 8 行白。
        assertEquals(8.0 / 9.0, top, 1e-12)
        assertEquals(top, profile.bands()!!.top, 0.0)
    }

    @Test
    fun `vertical range clamps and swaps reversed input`() { // [Dart推演] 区间收口到 [0,1]，from>to 交换
        val rows = List(10) { 0.5 }
        val profile = WallpaperLuminanceProfile(rows)
        assertEquals(0.5, profile.luminanceForVerticalRange(-0.5, 0.25)!!, 1e-12)
        assertEquals(
            profile.luminanceForVerticalRange(0.25, 0.6)!!,
            profile.luminanceForVerticalRange(0.6, 0.25)!!,
            0.0,
        )
        assertEquals(0.5, profile.luminanceForVerticalRange(0.8, 1.5)!!, 1e-12)
    }

    @Test
    fun `three bands read their own rows`() { // [Dart推演] 行范围 0–0.09 / 0.07–0.20 / 0.22–0.72
        // 100 行：0..11 白（0.12 比例），其余黑。
        val rows = List(100) { if (it < 12) 1.0 else 0.0 }
        val bands = WallpaperLuminanceProfile(rows).bands()!!
        assertEquals(1.0, bands.top, 1e-12)
        // weekday 行 7..19：7..11 白（5 行）、12..19 黑（8 行）。
        assertEquals(5.0 / 13.0, bands.weekday, 1e-12)
        // body 行 22..71：全黑。
        assertEquals(0.0, bands.body, 1e-12)
        // 「top 全亮、weekday 半暗、body 暗」的极性序与 Dart 条纹用例一致。
        assertTrue(bands.top > bands.weekday)
        assertTrue(bands.weekday > bands.body)
    }

    @Test
    fun `sameValuesAs compares with epsilon`() { // [Dart推演] 1e-9 容差 + 长度不等直接 false
        val a = WallpaperLuminanceProfile(listOf(0.1, 0.2, 0.3))
        val same = WallpaperLuminanceProfile(listOf(0.1, 0.2, 0.3))
        val tiny = WallpaperLuminanceProfile(listOf(0.1, 0.2, 0.3 + 5e-10))
        val different = WallpaperLuminanceProfile(listOf(0.1, 0.2, 0.35))
        val otherLength = WallpaperLuminanceProfile(listOf(0.1, 0.2))
        assertTrue(a.sameValuesAs(same))
        assertTrue(a.sameValuesAs(tiny))
        assertFalse(a.sameValuesAs(different))
        assertFalse(a.sameValuesAs(otherLength))
        assertTrue(a.sameValuesAs(a))
    }

    @Test
    fun `profile json round trip`() { // [Dart推演] toJson/fromJson
        val profile = WallpaperLuminanceProfile(listOf(0.1, 0.25, 0.5, 0.75))
        val json = profile.toJson()
        assertEquals(listOf(0.1, 0.25, 0.5, 0.75), json)
        val restored = WallpaperLuminanceProfile.fromJson(json)!!
        assertEquals(4, restored.rowLuminances.size)
        assertEquals(0.25, restored.rowLuminances[1], 0.0)
    }

    @Test
    fun `profile fromJson rejects non numeric members`() { // [Dart推演] 任一项非 num → null
        assertNull(WallpaperLuminanceProfile.fromJson(null))
        assertNull(WallpaperLuminanceProfile.fromJson("not a list"))
        assertNull(WallpaperLuminanceProfile.fromJson(listOf<Any?>(0.1, "x")))
        assertNull(WallpaperLuminanceProfile.fromJson(listOf<Any?>(0.1, null)))
        // 空列表合法，回落 empty。
        val empty = WallpaperLuminanceProfile.fromJson(emptyList<Any?>())!!
        assertTrue(empty.isEmpty)
    }

    // ---------- 采样键 ----------

    @Test
    fun `sample key format is path viewport aligns scale`() { // [Dart推演] `路径|视口|alignX|alignY|scale`
        assertEquals(
            "/tmp/a.png|1080x2400|0.5|-0.25|1.5",
            homePageBackdropSampleKey(
                path = "/tmp/a.png",
                viewportKey = "1080x2400",
                alignX = 0.5,
                alignY = -0.25,
                scale = 1.5,
            ),
        )
    }

    @Test
    fun `sample key clamps all three freedoms`() { // [Dart推演] 三个入参按采样端口径钳制
        assertEquals(
            "/tmp/a.png|full-image|-1.0|-1.0|4.0",
            homePageBackdropSampleKey(
                path = "/tmp/a.png",
                viewportKey = "full-image",
                alignX = -5.0,
                alignY = -9.0,
                scale = 99.0,
            ),
        )
    }

    @Test
    fun `viewport key falls back to full image`() { // [Dart推演]
        assertEquals("full-image", homePageBackdropViewportKey(null))
        assertEquals("1080x2400", homePageBackdropViewportKey("1080x2400"))
    }

    // ---------- 墨色极性 ----------

    @Test
    fun `chrome ink flips at configured threshold`() { // [Dart抄录] home_page_background_luminance_test 的极性断言 + [Dart推演] 阈值 0.45
        assertEquals(ChromeInk.LIGHT, chromeInkForLuminance(null, fallback = ChromeInk.LIGHT))
        assertEquals(ChromeInk.DARK, chromeInkForLuminance(null, fallback = ChromeInk.DARK))
        // 暗壁纸 → 白墨（LIGHT），亮壁纸 → 黑墨（DARK）。
        assertEquals(ChromeInk.DARK, chromeInkForLuminance(1.0, fallback = ChromeInk.LIGHT))
        assertEquals(ChromeInk.LIGHT, chromeInkForLuminance(0.0, fallback = ChromeInk.DARK))
        // 0.45 邻域：0.44（暗）→ 白墨，0.46（亮）→ 黑墨。
        assertEquals(ChromeInk.LIGHT, chromeInkForLuminance(0.44, fallback = ChromeInk.LIGHT))
        assertEquals(ChromeInk.DARK, chromeInkForLuminance(0.46, fallback = ChromeInk.DARK))
    }

    @Test
    fun `contrast ratio math agrees with wcag`() { // [Dart抄录] 期望值按公式自己算
        // 黑墨(0.0) 对 0.356 背景：(0.356+0.05)/(0.0+0.05) = 8.12
        assertEquals(8.12, contrastRatio(0.0, 0.356), 1e-2)
        // 白墨(1.0) 对 0.356 背景：(1.05)/(0.406) = 2.586
        assertEquals(2.586, contrastRatio(1.0, 0.356), 1e-2)
        assertEquals(21.0, contrastRatio(1.0, 0.0), 1e-9)
        assertEquals(1.0, contrastRatio(0.3, 0.3), 1e-12)
    }

    @Test
    fun `status bar flip point is the equal contrast point`() { // [Dart抄录] 0.179：黑白对比度相等
        val flip = STATUS_BAR_ICON_FLIP_LUMINANCE
        val whiteContrast = contrastRatio(1.0, flip)
        val blackContrast = contrastRatio(0.0, flip)
        // 0.1791 是四舍五入到万分位的解析解（真值 0.17913…），两侧对比差 ≤ 0.005。
        assertEquals(whiteContrast, blackContrast, 5e-3)
        assertEquals(4.58, whiteContrast, 5e-3)
        // 0.356 的顶部带必须配黑图标（旧实现配白图标实测 2.59:1）。
        assertTrue("0.356 处必须黑图标对比更高", contrastRatio(1.0, 0.356) < contrastRatio(0.0, 0.356))
    }

    @Test
    fun `every sampled luminance picks the better polarity`() { // [Dart抄录] 每一个采样亮度下都选对比度更高的那一档
        for (luminance in listOf(0.05, 0.12, 0.18, 0.25, 0.36, 0.45, 0.55, 0.70)) {
            val picked = contrastRatio(0.0, luminance) >= contrastRatio(1.0, luminance)
            val ink = statusBarInkFor(luminance)
            assertEquals("亮度 $luminance 下选了对比度更差的那一档图标", picked, ink == StatusBarInk.Black)
        }
    }

    @Test
    fun `near the flip point both sides pass 4_5`() { // [Dart抄录] 分界点两侧都必须过 4.5:1
        for (luminance in listOf(0.17, 0.19)) {
            val ink = statusBarInkFor(luminance)
            val y = if (ink == StatusBarInk.Black) 0.0 else 1.0
            assertTrue(contrastRatio(y, luminance) >= 4.5)
        }
    }

    // ---------- 卡面玻璃有效亮度 ----------

    @Test
    fun `card glass surface blends fill and wallpaper`() { // [Dart推演] cardGlassSurfaceLuminance 的混合公式
        // 白卡(1.0) 以 0.32 压在 0.1 的壁纸上：1.0*0.32 + 0.1*0.68 = 0.388
        assertEquals(0.388, cardGlassSurfaceLuminance(cardFillLuminance = 1.0, washAlpha = 0.32, wallpaperLuminance = 0.1), 1e-12)
        // washAlpha 钳到 [0,1]。
        assertEquals(0.1, cardGlassSurfaceLuminance(1.0, -0.5, 0.1), 1e-12)
        assertEquals(1.0, cardGlassSurfaceLuminance(1.0, 1.5, 0.1), 1e-12)
    }

    @Test
    fun `card ink flips at 0_20 not 0_45`() { // [Dart推演] CARD_GLASS_INK_FLIP_LUMINANCE = 0.2（对比度相等点）
        assertEquals(0.2, CARD_GLASS_INK_FLIP_LUMINANCE, 0.0)
        // 0.21（亮卡面）→ 黑墨，0.19（暗卡面）→ 白墨。
        assertEquals(ChromeInk.DARK, cardGlassInkForLuminance(0.21))
        assertEquals(ChromeInk.LIGHT, cardGlassInkForLuminance(0.19))
    }

    // ---------- cover 取景几何（可见源矩形） ----------

    @Test
    fun `matching aspect samples the whole image`() { // [Dart推演]
        val rect = homePageWallpaperVisibleSourceRect(
            viewportSize = "100x100",
            imageSize = "100x100",
            alignX = 0.0,
            alignY = 0.0,
            zoom = 1.0,
        )
        assertEquals(0.0, rect.left, 0.0)
        assertEquals(0.0, rect.top, 0.0)
        assertEquals(1.0, rect.width, 0.0)
        assertEquals(1.0, rect.height, 0.0)
    }

    @Test
    fun `wide image crops horizontally by alignment`() { // [Dart推演] horizontal-split 用例的几何
        // 图 200x100（aspect 2.0）、视口 100x100（aspect 1.0）：可见宽 = 0.5。
        val left = homePageWallpaperVisibleSourceRect("100x100", "200x100", alignX = -1.0, alignY = 0.0, zoom = 1.0)
        assertEquals(0.0, left.left, 1e-12)
        assertEquals(0.5, left.width, 1e-12)
        val right = homePageWallpaperVisibleSourceRect("100x100", "200x100", alignX = 1.0, alignY = 0.0, zoom = 1.0)
        assertEquals(0.5, right.left, 1e-12)
        assertEquals(0.5, right.width, 1e-12)
    }

    @Test
    fun `tall image crops vertically by alignment`() { // [人推] 与横图对称
        val top = homePageWallpaperVisibleSourceRect("100x100", "100x200", alignX = 0.0, alignY = -1.0, zoom = 1.0)
        assertEquals(0.0, top.top, 1e-12)
        assertEquals(0.5, top.height, 1e-12)
        val bottom = homePageWallpaperVisibleSourceRect("100x100", "100x200", alignX = 0.0, alignY = 1.0, zoom = 1.0)
        assertEquals(0.5, bottom.top, 1e-12)
        assertEquals(0.5, bottom.height, 1e-12)
    }

    @Test
    fun `zoom shrinks the visible window around the anchor`() { // [Dart推演] zoom 后可见比例 ÷ 倍数
        val zoomed = homePageWallpaperVisibleSourceRect("100x100", "100x100", alignX = -1.0, alignY = -1.0, zoom = 2.0)
        assertEquals(0.0, zoomed.left, 1e-12)
        assertEquals(0.0, zoomed.top, 1e-12)
        assertEquals(0.5, zoomed.width, 1e-12)
        assertEquals(0.5, zoomed.height, 1e-12)
        // align = -1/0/+1 三处与不放大时同点不动：中心放大后仍以中心为锚。
        val center = homePageWallpaperVisibleSourceRect("100x100", "100x100", alignX = 0.0, alignY = 0.0, zoom = 2.0)
        assertEquals(0.25, center.left, 1e-12)
        assertEquals(0.5, center.width, 1e-12)
    }

    @Test
    fun `degenerate sizes fall back to full image`() { // [Dart推演] 非有限 / 非正尺寸 → 全图
        val rect = homePageWallpaperVisibleSourceRect("0x0", "100x100", 0.0, 0.0, 1.0)
        assertEquals(1.0, rect.width, 0.0)
        assertEquals(1.0, rect.height, 0.0)
    }

    @Test
    fun `zoom clamps to the wallpaper scale bounds`() { // [Dart推演] kWallpaperMinScale..kWallpaperMaxScale
        assertEquals(1.0, WALLPAPER_MIN_SCALE, 0.0)
        assertEquals(4.0, WALLPAPER_MAX_SCALE, 0.0)
        val clamped = homePageWallpaperVisibleSourceRect("100x100", "100x100", 0.0, 0.0, zoom = 99.0)
        assertEquals(0.25, clamped.width, 1e-12)
    }
}
