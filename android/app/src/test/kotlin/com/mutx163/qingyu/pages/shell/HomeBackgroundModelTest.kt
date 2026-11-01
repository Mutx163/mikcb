package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.app.TimetableSettingsModel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 首页壁纸背景模型（[HomeBackgroundModel]）的**契约测试**。
 *
 * ## 期望值从哪来
 *
 * 全部手推自 Dart 源码，**不是**从 Kotlin 实现里抄的：
 *
 * * 绘制几何：`lib/utils/home_page_background.dart:531-580`——`Image(fit: cover)` 外套
 *   `Transform.scale(scale:, alignment:)`；「绕对齐点缩放」展开后等价于
 *   `left = -(放大的宽 - 视口宽) × (alignX+1)/2`，因为
 *   `Transform.scale` 的缩放中心在 `视口宽 × (alignX+1)/2`，把 `left = -(cover宽-视口宽)×k`
 *   代进去化简会得到「按放大**之后**的溢出量」而不是「基础溢出 × 倍数」。
 * * 解码：`:192-213`（按宽 720…2160、兜底 1440、`ResizeImage(width:)` 只缩不放）。
 * * 模糊：`timetable_settings.dart:353-354`（0…24）；`RenderEffect` 的半径↔sigma
 *   换算见 `HomeBackgroundModel.BLUR_SIGMA_PER_RADIUS` 的注释。
 * * 墨色：`:715-727`（0.45）、`:801-807`（0.20）、`:310`（0.1791，方向相反）、
 *   `:730-733`（0.72 / 0.62）、`:863-878`（3:1）。
 * * 区域位标志：`lib/models/settings/timetable_settings_enums.dart:111-125`。
 * * 路径 / 页底色：`home_page_background.dart:273-285`、`:346-392`、`lib/utils/hex_color.dart:3-21`。
 *
 * 所以「实现改错了」这些用例会红；反过来「用例跟着实现改」应当被 review 拦下。
 * 反向验证（故意改坏常量 → 必须红 → 还原 → 绿）的记录写在交付报告里。
 */
class HomeBackgroundModelTest {

    // ───────────────────────── 绘制几何 ─────────────────────────

    @Test
    fun `coverScale 取两维里更大的那个比例`() {
        // 正方形图塞进 500×1000：宽要 0.5、高要 1.0 ⇒ 1.0。
        assertEquals(1.0, HomeBackgroundModel.coverScale(1000, 1000, 500, 1000), 1e-9)
        // 竖长图 1000×4000 塞进 500×1000：宽 0.5、高 0.25 ⇒ 0.5。
        assertEquals(0.5, HomeBackgroundModel.coverScale(1000, 4000, 500, 1000), 1e-9)
        // 4000×3000 塞进 1080×2400：宽 0.27、高 0.8 ⇒ 0.8。
        assertEquals(0.8, HomeBackgroundModel.coverScale(4000, 3000, 1080, 2400), 1e-9)
    }

    @Test
    fun `coverScale 遇到非正尺寸返回 0 表示画不了`() {
        assertEquals(0.0, HomeBackgroundModel.coverScale(0, 3000, 1080, 2400), 1e-9)
        assertEquals(0.0, HomeBackgroundModel.coverScale(4000, 3000, 0, 2400), 1e-9)
    }

    @Test
    fun `drawRect 比例刚好相等时零偏移`() {
        // 1080×2400 图塞进 1080×2400 视口：cover = 1，溢出 0，左上都 0。
        val rect = HomeBackgroundModel.drawRect(1080, 2400, 1080, 2400, 1.0, 0.0, 0.0)!!
        assertEquals(0.0, rect.left, 1e-9)
        assertEquals(0.0, rect.top, 1e-9)
        assertEquals(1080.0, rect.width, 1e-9)
        assertEquals(2400.0, rect.height, 1e-9)
    }

    @Test
    fun `drawRect 水平溢出按对齐比例摊开`() {
        // 1000×1000 图塞进 500×1000：cover=1 ⇒ 画 1000 宽，水平溢出 500。
        val rect = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 1.0, 0.0, 0.0)!!
        assertEquals(1000.0, rect.width, 1e-9)
        assertEquals(-250.0, rect.left, 1e-9) // -(1000-500) × 0.5
        assertEquals(0.0, rect.top, 1e-9) // 竖直方向没有溢出
        // 靠左对齐：溢出全丢在右边，左边贴 0。
        val left = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 1.0, -1.0, 0.0)!!
        assertEquals(0.0, left.left, 1e-9)
        // 靠右对齐：溢出全丢在左边。
        val right = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 1.0, 1.0, 0.0)!!
        assertEquals(-500.0, right.left, 1e-9)
        // 竖直方向溢出的那一例：2000×1000 塞进 500×1000 时水平溢出 1500、竖直 0。
        val wide = HomeBackgroundModel.drawRect(2000, 1000, 500, 1000, 1.0, 0.0, 0.0)!!
        assertEquals(-750.0, wide.left, 1e-9)
        assertEquals(0.0, wide.top, 1e-9)
    }

    @Test
    fun `drawRect 放大后按放大后的溢出量折算`() {
        // 同一张 1000×1000 塞进 500×1000，放大 2 倍 ⇒ 画 2000×2000。
        // 水平溢出 2000-500=1500 ⇒ left = -1500×0.5 = -750（不是 -250×2 = -500）。
        // 竖直溢出 2000-1000=1000 ⇒ top = -1000×0.5 = -500。
        val rect = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 2.0, 0.0, 0.0)!!
        assertEquals(2000.0, rect.width, 1e-9)
        assertEquals(2000.0, rect.height, 1e-9)
        assertEquals(-750.0, rect.left, 1e-9)
        assertEquals(-500.0, rect.top, 1e-9)
        assertTrue("按基础溢出乘倍数会得到 -500，这里必须是 -750", rect.left != -500.0)
    }

    @Test
    fun `drawRect 的倍数被夹进 1 到 4`() {
        val one = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 1.0, 0.0, 0.0)!!
        val tooSmall = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 0.3, 0.0, 0.0)!!
        assertEquals(one.width, tooSmall.width, 1e-9)
        assertEquals(one.left, tooSmall.left, 1e-9)

        val four = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 4.0, 0.0, 0.0)!!
        val tooBig = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 9.0, 0.0, 0.0)!!
        assertEquals(4000.0, four.width, 1e-9)
        assertEquals(-1750.0, four.left, 1e-9) // -(4000-500)×0.5
        assertEquals(-1500.0, four.top, 1e-9) // -(4000-1000)×0.5
        assertEquals(four.width, tooBig.width, 1e-9)
        assertEquals(four.left, tooBig.left, 1e-9)
    }

    @Test
    fun `drawRect 的对齐值被夹进 -1 到 1，NaN 按居中`() {
        val right = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 1.0, 1.0, 0.0)!!
        val overRight = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 1.0, 7.0, 0.0)!!
        assertEquals(right.left, overRight.left, 1e-9)

        val left = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 1.0, -1.0, 0.0)!!
        val overLeft = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 1.0, -7.0, 0.0)!!
        assertEquals(left.left, overLeft.left, 1e-9)

        val center = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 1.0, 0.0, 0.0)!!
        val nanAlign = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, 1.0, Double.NaN, Double.NaN)!!
        assertEquals(center.left, nanAlign.left, 1e-9)
        assertEquals(center.top, nanAlign.top, 1e-9)

        val nanScale = HomeBackgroundModel.drawRect(1000, 1000, 500, 1000, Double.NaN, 0.0, 0.0)!!
        assertEquals(center.width, nanScale.width, 1e-9)
    }

    @Test
    fun `drawRect 画不了时返回 null 而不是零尺寸矩形`() {
        assertNull(HomeBackgroundModel.drawRect(1000, 1000, 0, 1000, 1.0, 0.0, 0.0))
        assertNull(HomeBackgroundModel.drawRect(1000, 1000, 500, 0, 1.0, 0.0, 0.0))
        assertNull(HomeBackgroundModel.drawRect(0, 1000, 500, 1000, 1.0, 0.0, 0.0))
    }

    // ───────────────────────── 解码 ─────────────────────────

    @Test
    fun `decodeWidthPx 无视口兜底 1440，否则夹进 720 到 2160`() {
        assertEquals(1440, HomeBackgroundModel.decodeWidthPx(null))
        assertEquals(720, HomeBackgroundModel.decodeWidthPx(0)) // 0 也算「太小」，夹到下限
        assertEquals(720, HomeBackgroundModel.decodeWidthPx(300))
        assertEquals(1080, HomeBackgroundModel.decodeWidthPx(1080))
        assertEquals(2160, HomeBackgroundModel.decodeWidthPx(5000))
    }

    @Test
    fun `decodePlan 按宽下采样，采样值是 2 的幂且不低于目标`() {
        // 4000×3000 解到 1080 宽：目标高 = 3000×1080/4000 = 810。
        // 采样 2 ⇒ 2000×1500 都还 ≥ 1080×810；采样 4 ⇒ 1000 < 1080 ⇒ 只能取 2。
        val plan = HomeBackgroundModel.decodePlan(4000, 3000, 1080)!!
        assertEquals(1080, plan.targetWidthPx)
        assertEquals(810, plan.targetHeightPx)
        assertEquals(2, plan.inSampleSize)
    }

    @Test
    fun `decodePlan 源图比目标还小时不放大`() {
        // 800×600 解到 1440 宽：BitmapFactory 不做放大采样 ⇒ 1。
        val plan = HomeBackgroundModel.decodePlan(800, 600, 1440)!!
        assertEquals(1440, plan.targetWidthPx)
        assertEquals(1080, plan.targetHeightPx) // 600×1440/800
        assertEquals(1, plan.inSampleSize)
    }

    @Test
    fun `decodePlan 目标宽同样被夹住，源图非法返回 null`() {
        val plan = HomeBackgroundModel.decodePlan(4000, 3000, 300)!!
        assertEquals(720, plan.targetWidthPx)
        assertEquals(540, plan.targetHeightPx) // 3000×720/4000
        assertNull(HomeBackgroundModel.decodePlan(0, 3000, 1080))
        assertNull(HomeBackgroundModel.decodePlan(4000, 3000, 0))
    }

    // ───────────────────────── 模糊 ─────────────────────────

    @Test
    fun `blurRadiusPxForSigma 按 miuix-blur 的半径口径换算`() {
        // miuix 内部 sigma = radius × 0.45 ⇒ radius = sigma / 0.45，再乘屏幕密度才是 px。
        // 手挑的数：sigma 0.9 / 0.45 = 半径 2.0；密度 2 ⇒ 4.0 px。
        assertEquals(4.0, HomeBackgroundModel.blurRadiusPxForSigma(0.9, 2.0f), 1e-9)
        assertEquals(2.0, HomeBackgroundModel.blurRadiusPxForSigma(0.9, 1.0f), 1e-9)
        // sigma ≤ 0.5 一律 0：走原图，不让 miuix 白跑一遍采样。
        assertEquals(0.0, HomeBackgroundModel.blurRadiusPxForSigma(0.0, 3.0f), 1e-9)
        assertEquals(0.0, HomeBackgroundModel.blurRadiusPxForSigma(0.5, 3.0f), 1e-9)
        // 上限 24、密度 3.5 ⇒ 24 / 0.45 × 3.5 ≈ 186.6667 px。
        assertEquals(186.6667, HomeBackgroundModel.blurRadiusPxForSigma(24.0, 3.5f), 1e-3)
        // 越界值先夹到 24，再换算 ⇒ 与 24 完全相同。
        assertEquals(
            HomeBackgroundModel.blurRadiusPxForSigma(24.0, 3.0f),
            HomeBackgroundModel.blurRadiusPxForSigma(99.0, 3.0f),
            1e-9,
        )
        // 咬合探针：密度这一步漏掉（或乘成 dp）时，下面这条会红。
        assertEquals(
            HomeBackgroundModel.blurRadiusPxForSigma(0.9, 1.0f) * 2,
            HomeBackgroundModel.blurRadiusPxForSigma(0.9, 2.0f),
            1e-9,
        )
    }

    // ───────────────────────── EXIF ─────────────────────────

    @Test
    fun `exifRotationDegrees 只认三种旋转档`() {
        assertEquals(0, HomeBackgroundModel.exifRotationDegrees(1)) // NORMAL
        assertEquals(180, HomeBackgroundModel.exifRotationDegrees(3))
        assertEquals(90, HomeBackgroundModel.exifRotationDegrees(6))
        assertEquals(270, HomeBackgroundModel.exifRotationDegrees(8))
        assertEquals(0, HomeBackgroundModel.exifRotationDegrees(0)) // 坏值按不旋转
        assertEquals(0, HomeBackgroundModel.exifRotationDegrees(2)) // 镜像档暂不处理
    }

    @Test
    fun `orientedSize 在 90 和 270 度时对调宽高`() {
        assertEquals(HomeBackdropSize(200, 100), HomeBackgroundModel.orientedSize(100, 200, 90))
        assertEquals(HomeBackdropSize(200, 100), HomeBackgroundModel.orientedSize(100, 200, 270))
        assertEquals(HomeBackdropSize(100, 200), HomeBackgroundModel.orientedSize(100, 200, 180))
        assertEquals(HomeBackdropSize(100, 200), HomeBackgroundModel.orientedSize(100, 200, 0))
    }

    // ───────────────────────── 跟周页滑动 ─────────────────────────

    @Test
    fun `stripPageOffsets 静止时只画一份，滑动时补相邻页`() {
        assertEquals(listOf(0f), HomeBackgroundModel.stripPageOffsets(0f))
        assertEquals(listOf(0f), HomeBackgroundModel.stripPageOffsets(Float.NaN))
        assertEquals(listOf(-0.75f, 0.25f, 1.25f), HomeBackgroundModel.stripPageOffsets(0.25f))
    }

    // ───────────────────────── 墨色 ─────────────────────────

    @Test
    fun `chromeInkPolarity 用 0_45 分界，未知亮度按深墨`() {
        assertEquals(HomeInkPolarity.Light, HomeBackgroundModel.chromeInkPolarity(0.0))
        assertEquals(HomeInkPolarity.Light, HomeBackgroundModel.chromeInkPolarity(0.4499))
        assertEquals(HomeInkPolarity.Dark, HomeBackgroundModel.chromeInkPolarity(0.45)) // 严格小于才翻白
        assertEquals(HomeInkPolarity.Dark, HomeBackgroundModel.chromeInkPolarity(0.9))
        assertEquals(HomeInkPolarity.Dark, HomeBackgroundModel.chromeInkPolarity(null))
    }

    @Test
    fun `cardGlassInkPolarity 用 0_20 分界，不是顶栏那套 0_45`() {
        assertEquals(HomeInkPolarity.Light, HomeBackgroundModel.cardGlassInkPolarity(0.19))
        assertEquals(HomeInkPolarity.Dark, HomeBackgroundModel.cardGlassInkPolarity(0.2))
        // 0.3 这一档顶栏会判深墨、卡面也判深墨；但 0.25 顶栏仍是浅墨、卡面已是深墨。
        assertEquals(HomeInkPolarity.Light, HomeBackgroundModel.chromeInkPolarity(0.25))
        assertEquals(HomeInkPolarity.Dark, HomeBackgroundModel.cardGlassInkPolarity(0.25))
        assertEquals(HomeInkPolarity.Dark, HomeBackgroundModel.cardGlassInkPolarity(null))
    }

    @Test
    fun `statusBarInkPolarity 方向与墨色相反，正好等于阈值算浅色图标`() {
        // 亮度 > 0.1791 ⇒ 状态栏配白底 ⇒ 深色图标。
        assertEquals(HomeInkPolarity.Dark, HomeBackgroundModel.statusBarInkPolarity(0.1792))
        // 正好等于阈值 ⇐ 走「不大于」那一支 ⇒ 深底 + 浅色图标。
        assertEquals(HomeInkPolarity.Light, HomeBackgroundModel.statusBarInkPolarity(0.1791))
        assertEquals(HomeInkPolarity.Light, HomeBackgroundModel.statusBarInkPolarity(0.0))
        assertEquals(HomeInkPolarity.Light, HomeBackgroundModel.statusBarInkPolarity(null))
    }

    @Test
    fun `mutedInkAlpha 浅墨 0_72 深墨 0_62`() {
        assertEquals(0.72f, HomeBackgroundModel.mutedInkAlpha(HomeInkPolarity.Light), 1e-6f)
        assertEquals(0.62f, HomeBackgroundModel.mutedInkAlpha(HomeInkPolarity.Dark), 1e-6f)
    }

    @Test
    fun `cardGlassSurfaceLuminance 是卡底色与壁纸亮度的加权混合`() {
        // 纯白卡面（亮度 1.0）压 40% ⇒ 0.4×1.0 + 0.6×0.0 = 0.4。
        assertEquals(
            0.4,
            HomeBackgroundModel.cardGlassSurfaceLuminance(1.0, 0.4, 0.0),
            1e-9,
        )
        // 染色强度越界先夹：2.0 → 1.0 ⇒ 全是卡底色。
        assertEquals(
            1.0,
            HomeBackgroundModel.cardGlassSurfaceLuminance(1.0, 2.0, 0.0),
            1e-9,
        )
        // 0 → 全是壁纸亮度。
        assertEquals(
            0.3,
            HomeBackgroundModel.cardGlassSurfaceLuminance(1.0, 0.0, 0.3),
            1e-9,
        )
    }

    @Test
    fun `hasSufficientContrast 是 3 比 1`() {
        // 默认门槛就是 3:1（Dart `homePageInkHasSufficientContrast` 的 minContrastRatio）。
        assertEquals(3.0, HomeBackgroundModel.MIN_INK_CONTRAST_RATIO, 1e-9)
        // 黑字(0) 压 0.5 亮度背景：(0.55)/(0.05) = 11。
        assertTrue(HomeBackgroundModel.hasSufficientContrast(0.0, 0.5))
        // 黑字压 0.45：0.50/0.05 = 10，同样够。
        assertTrue(HomeBackgroundModel.hasSufficientContrast(0.0, 0.45))
        // 0.2 压 0.25：(0.30)/(0.25) = 1.2，不够。
        assertFalse(HomeBackgroundModel.hasSufficientContrast(0.2, 0.25))
        // 0.4 压 0.45：(0.50)/(0.45) ≈ 1.11，不够。
        assertFalse(HomeBackgroundModel.hasSufficientContrast(0.4, 0.45))
        // 同亮度：0.05/0.05 = 1，不够。
        assertFalse(HomeBackgroundModel.hasSufficientContrast(0.35, 0.35))
    }

    // ───────────────────────── 壁纸亮度采样 ─────────────────────────

    @Test
    fun `srgbChannelToLinear 走 WCAG 的两段曲线，不是除以 255`() {
        assertEquals(0.0, HomeBackgroundModel.srgbChannelToLinear(0), 1e-12)
        assertEquals(1.0, HomeBackgroundModel.srgbChannelToLinear(255), 1e-12)
        // 10/255 = 0.0392 ≤ 0.04045 ⇒ 线性段：0.0392/12.92 = 0.0030353。
        assertEquals(0.0030353, HomeBackgroundModel.srgbChannelToLinear(10), 1e-6)
        // 11/255 = 0.04314 > 0.04045 ⇒ 幂段：((0.04314+0.055)/1.055)^2.4 = 0.0033468。
        assertEquals(0.0033468, HomeBackgroundModel.srgbChannelToLinear(11), 1e-6)
        // 越界通道先夹：-5 → 0，300 → 255。
        assertEquals(0.0, HomeBackgroundModel.srgbChannelToLinear(-5), 1e-12)
        assertEquals(1.0, HomeBackgroundModel.srgbChannelToLinear(300), 1e-12)
    }

    @Test
    fun `relativeLuminance 是 WCAG 权重，且忽略 alpha`() {
        assertEquals(1.0, HomeBackgroundModel.relativeLuminance(0xFFFFFFFF.toInt()), 1e-9)
        assertEquals(0.0, HomeBackgroundModel.relativeLuminance(0xFF000000.toInt()), 1e-12)
        // 三原色各自的权重：0.2126 / 0.7152 / 0.0722。
        assertEquals(0.2126, HomeBackgroundModel.relativeLuminance(0xFFFF0000.toInt()), 1e-9)
        assertEquals(0.7152, HomeBackgroundModel.relativeLuminance(0xFF00FF00.toInt()), 1e-9)
        assertEquals(0.0722, HomeBackgroundModel.relativeLuminance(0xFF0000FF.toInt()), 1e-9)
        // 中灰 128：128/255 = 0.50196 ⇒ ((0.50196+0.055)/1.055)^2.4 ≈ 0.21586。
        // 直接取通道平均会得到 0.50196，差一倍多——这就是必须走曲线的理由。
        assertEquals(0.21586, HomeBackgroundModel.relativeLuminance(0xFF808080.toInt()), 1e-4)
        // alpha 不参与：全透明白仍按白算。
        assertEquals(1.0, HomeBackgroundModel.relativeLuminance(0x00FFFFFF), 1e-9)
    }

    @Test
    fun `bandRows 用 floor 与 ceil，顶栏带是顶部 9 个百分点`() {
        // 1000 高：0…0.09 ⇒ 行 [0, 90)。
        assertEquals(0 until 90, HomeBackgroundModel.bandRows(1000, 0.0, 0.09))
        // 277 高：0.09×277 = 24.93 ⇒ ceil = 25。
        assertEquals(0 until 25, HomeBackgroundModel.bandRows(277, 0.0, 0.09))
        // 星期条带 0.07…0.20：floor(7)=7、ceil(20)=20。
        assertEquals(7 until 20, HomeBackgroundModel.bandRows(100, 0.07, 0.20))
        // 上下限写反了也照样收口（Dart 会先换位）。
        assertEquals(7 until 20, HomeBackgroundModel.bandRows(100, 0.20, 0.07))
        // 极矮的图至少保留一行。
        assertEquals(0 until 1, HomeBackgroundModel.bandRows(2, 0.0, 0.09))
        // NaN 当 0：等价于从图片最顶端开始。
        assertEquals(0 until 90, HomeBackgroundModel.bandRows(1000, Double.NaN, 0.09))
        // 高度非正 ⇒ 空区间（调用方据此回 null，而不是猜 0 亮度）。
        assertTrue(HomeBackgroundModel.bandRows(0, 0.0, 0.09).isEmpty())
    }

    @Test
    fun `meanRelativeLuminance 按行区间求平均，参数不自洽回 null`() {
        // 2×2：上行两颗白、下行两颗黑，行优先排列。
        val pixels = intArrayOf(
            0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt(),
            0xFF000000.toInt(), 0xFF000000.toInt(),
        )
        assertEquals(1.0, HomeBackgroundModel.meanRelativeLuminance(pixels, 2, 0, 1)!!, 1e-9)
        assertEquals(0.0, HomeBackgroundModel.meanRelativeLuminance(pixels, 2, 1, 2)!!, 1e-12)
        assertEquals(0.5, HomeBackgroundModel.meanRelativeLuminance(pixels, 2, 0, 2)!!, 1e-9)
        // 一行一白一黑 ⇒ 0.5。
        val mixed = intArrayOf(0xFFFFFFFF.toInt(), 0xFF000000.toInt())
        assertEquals(0.5, HomeBackgroundModel.meanRelativeLuminance(mixed, 2, 0, 1)!!, 1e-9)
        // 参数不自洽：宽 0、空区间、像素不够铺满请求的行。
        assertNull(HomeBackgroundModel.meanRelativeLuminance(pixels, 0, 0, 1))
        assertNull(HomeBackgroundModel.meanRelativeLuminance(pixels, 2, 1, 1))
        assertNull(HomeBackgroundModel.meanRelativeLuminance(mixed, 2, 0, 2))
        assertNull(HomeBackgroundModel.meanRelativeLuminance(mixed, 2, -1, 1))
    }

    @Test
    fun `顶栏亮度带只吃顶部 9 个百分点，不是顶部 1 3`() {
        // 100 行 × 1 列：前 9 行白，其余黑。
        val pixels = IntArray(100) { row ->
            if (row < 9) 0xFFFFFFFF.toInt() else 0xFF000000.toInt()
        }
        // 顶栏带 = 行 [0,9) ⇒ 全是白 ⇒ 1.0。
        assertEquals(
            1.0,
            HomeBackgroundModel.meanRelativeLuminanceForVerticalRange(
                pixels, 1, 100,
                HomeBackgroundModel.CHROME_TOP_BAND_FROM,
                HomeBackgroundModel.CHROME_TOP_BAND_TO,
            )!!,
            1e-9,
        )
        // 若误取顶部 1/3（行 [0,34)）：9 白 + 25 黑 = 9/34 ≈ 0.2647，会被判成「浅色底」。
        assertEquals(
            9.0 / 34.0,
            HomeBackgroundModel.meanRelativeLuminanceForVerticalRange(pixels, 1, 100, 0.0, 1.0 / 3.0)!!,
            1e-9,
        )
        // 整幅平均 = 0.09。
        assertEquals(
            0.09,
            HomeBackgroundModel.meanRelativeLuminanceForVerticalRange(pixels, 1, 100, 0.0, 1.0)!!,
            1e-9,
        )
        // 高度 0 ⇒ null（未知，不猜）。
        assertNull(
            HomeBackgroundModel.meanRelativeLuminanceForVerticalRange(pixels, 1, 0, 0.0, 0.09),
        )
    }

    // ───────────────────────── 路径与页底色 ─────────────────────────

    @Test
    fun `parseHexArgb 只认恰好 6 位十六进制`() {
        assertEquals(0xFF102030.toInt(), HomeBackgroundModel.parseHexArgb("#102030"))
        assertEquals(0xFF102030.toInt(), HomeBackgroundModel.parseHexArgb("102030"))
        assertEquals(0xFF102030.toInt(), HomeBackgroundModel.parseHexArgb("  #102030  "))
        assertEquals(0xFFABCDEF.toInt(), HomeBackgroundModel.parseHexArgb("#ABCDEF"))
        assertNull(HomeBackgroundModel.parseHexArgb("#fff")) // 3 位缩写 Dart 不收
        assertNull(HomeBackgroundModel.parseHexArgb("#1020304")) // 7 位
        assertNull(HomeBackgroundModel.parseHexArgb("GGGGGG"))
        assertNull(HomeBackgroundModel.parseHexArgb("-12345")) // 6 字符但含非法字符
        assertNull(HomeBackgroundModel.parseHexArgb(""))
        assertNull(HomeBackgroundModel.parseHexArgb(null))
    }

    @Test
    fun `resolvePageColorArgb 深色永远用主题兜底色`() {
        val fallback = 0xFF112233.toInt()
        // 浅色 + 合法自定义色 ⇒ 用自定义色。
        assertEquals(0xFF00FF00.toInt(), HomeBackgroundModel.resolvePageColorArgb("#00FF00", false, fallback))
        // 浅色 + 没设 / 非法 ⇒ 主题兜底。
        assertEquals(fallback, HomeBackgroundModel.resolvePageColorArgb(null, false, fallback))
        assertEquals(fallback, HomeBackgroundModel.resolvePageColorArgb("#xyz", false, fallback))
        // 深色 + 合法自定义色 ⇒ **仍然**主题兜底（Dart `:278-280`）。
        assertEquals(fallback, HomeBackgroundModel.resolvePageColorArgb("#00FF00", true, fallback))
    }

    @Test
    fun `resolveBackdropImagePath 壁纸优先，老背景图兜底`() {
        assertEquals("C:/a.jpg", HomeBackgroundModel.resolveBackdropImagePath("C:/a.jpg", "C:/b.jpg"))
        assertEquals("C:/b.jpg", HomeBackgroundModel.resolveBackdropImagePath(null, "C:/b.jpg"))
        assertEquals("C:/b.jpg", HomeBackgroundModel.resolveBackdropImagePath("", "C:/b.jpg"))
        assertNull(HomeBackgroundModel.resolveBackdropImagePath(null, null))
        assertNull(HomeBackgroundModel.resolveBackdropImagePath("", ""))
    }

    @Test
    fun `backdropKey 只有文件真的存在才算有壁纸`() {
        val exists = { path: String -> path == "C:/a.jpg" || path == "C:/b.jpg" }
        assertEquals("C:/a.jpg", HomeBackgroundModel.backdropKey("C:/a.jpg", null, exists))
        // 壁纸字段为空时，老背景图字段兜底（Dart `resolveHomePageBackdropImagePath` 的第二段）。
        assertEquals("C:/b.jpg", HomeBackgroundModel.backdropKey("", "C:/b.jpg", exists))
        // ⚠️ 壁纸字段**非空但文件丢了**时，Dart 不会退回去用老背景图：`homePageBackdropKey`
        // 直接对「壁纸优先」的那条路径判存在性，不在就 null（重装 / 清数据后完全无背景）。
        // 这里钉住这个「看起来反直觉」的口径，免得后来者"好心"补一条兜底把行为改掉。
        assertNull(HomeBackgroundModel.backdropKey("C:/gone.jpg", "C:/b.jpg", exists))
        // 两个都失效 ⇒ null = 视为无壁纸，回退纯色底。
        assertNull(HomeBackgroundModel.backdropKey("C:/x.jpg", "C:/y.jpg", exists))
        assertNull(HomeBackgroundModel.backdropKey(null, null, exists))
    }

    // ───────────────────────── 快照与区域 ─────────────────────────

    @Test
    fun `区域铺图由位标志决定，无壁纸时全部回落纯色`() {
        val pageColor = 0xFFEEEEEE.toInt()
        val snapshot = HomeBackdropSnapshot(
            wallpaperPath = "C:/a.jpg",
            alignX = 0.0,
            alignY = 0.0,
            scale = 1.0,
            blurSigma = 0.0,
            decodeWidthPx = 1440,
            scope = HomeBackdropScope.DEFAULT,
            pageColorArgb = pageColor,
            followsWeekPager = false,
        )
        assertTrue(snapshot.hasWallpaper)
        assertTrue(snapshot.showsBackdrop(HomeBackdropRegion.StatusBar))
        assertTrue(snapshot.showsBackdrop(HomeBackdropRegion.Timetable))
        assertTrue(snapshot.regionPaint(HomeBackdropRegion.Header).isTransparent)

        // 只允许课表区铺纸 ⇒ 顶栏 / 状态栏回落纯色。
        val timetableOnly = snapshot.copy(scope = HomeBackdropScope.TIMETABLE)
        assertTrue(timetableOnly.showsBackdrop(HomeBackdropRegion.Timetable))
        assertFalse(timetableOnly.showsBackdrop(HomeBackdropRegion.Header))
        val headerPaint = timetableOnly.regionPaint(HomeBackdropRegion.Header)
        assertFalse(headerPaint.isTransparent)
        assertEquals(pageColor, headerPaint.colorArgb)

        // 没有壁纸：哪个区域都不透。
        val noWallpaper = snapshot.copy(wallpaperPath = null)
        assertFalse(noWallpaper.hasWallpaper)
        for (region in HomeBackdropRegion.values()) {
            assertFalse(noWallpaper.showsBackdrop(region))
            assertEquals(pageColor, noWallpaper.regionPaint(region).colorArgb)
        }
    }

    @Test
    fun `快照只有在跟周页滑动时才铺相邻页`() {
        val base = HomeBackdropSnapshot(
            wallpaperPath = "C:/a.jpg",
            alignX = 0.0,
            alignY = 0.0,
            scale = 1.0,
            blurSigma = 0.0,
            decodeWidthPx = 1440,
            scope = HomeBackdropScope.DEFAULT,
            pageColorArgb = 0,
            followsWeekPager = false,
        )
        assertEquals(listOf(0f), base.stripPageOffsets(0.5f))
        assertEquals(listOf(-0.5f, 0.5f, 1.5f), base.copy(followsWeekPager = true).stripPageOffsets(0.5f))
    }

    @Test
    fun `snapshotOf 从设置建快照并把越界值收口`() {
        val settings = TimetableSettingsModel(
            homePageWallpaperPath = "C:/a.jpg",
            homePageWallpaperAlignX = 5.0,
            homePageWallpaperAlignY = -9.0,
            homePageWallpaperScale = 0.2,
            homePageWallpaperBlurSigma = 40.0,
            homePageBackdropFollowsWeekPager = true,
        )
        val snapshot = HomeBackgroundModel.snapshotOf(
            settings = settings,
            isDark = false,
            viewportWidthPx = 1080,
            themeFallbackArgb = 0xFFF8F8F8.toInt(),
            exists = { it == "C:/a.jpg" },
        )
        assertEquals("C:/a.jpg", snapshot.wallpaperPath)
        assertEquals(1.0, snapshot.alignX, 1e-9)
        assertEquals(-1.0, snapshot.alignY, 1e-9)
        assertEquals(1.0, snapshot.scale, 1e-9) // 0.2 → 下限 1
        assertEquals(24.0, snapshot.blurSigma, 1e-9) // 40 → 上限 24
        assertEquals(1080, snapshot.decodeWidthPx)
        assertEquals(HomeBackdropScope.DEFAULT, snapshot.scope)
        assertEquals(0xFFF8F8F8.toInt(), snapshot.pageColorArgb)
        assertTrue(snapshot.followsWeekPager)
        assertTrue(snapshot.hasWallpaper)

        // 文件不在 ⇒ 无壁纸；视口拿不到 ⇒ 1440；深色 ⇒ 主题兜底色。
        val missing = HomeBackgroundModel.snapshotOf(
            settings = settings.copy(homePageWallpaperPath = "C:/gone.jpg"),
            isDark = true,
            viewportWidthPx = null,
            themeFallbackArgb = 0xFF101010.toInt(),
            pageColorHex = "#00FF00",
            exists = { it == "C:/a.jpg" },
        )
        assertNull(missing.wallpaperPath)
        assertFalse(missing.hasWallpaper)
        assertEquals(1440, missing.decodeWidthPx)
        assertEquals(0xFF101010.toInt(), missing.pageColorArgb)
    }

    @Test
    fun `snapshotOf 没配壁纸时也给出可用快照`() {
        val snapshot = HomeBackgroundModel.snapshotOf(
            settings = TimetableSettingsModel(),
            isDark = false,
            viewportWidthPx = 4000,
            themeFallbackArgb = 0xFFFAFAFA.toInt(),
        )
        assertNull(snapshot.wallpaperPath)
        assertFalse(snapshot.hasWallpaper)
        assertEquals(2160, snapshot.decodeWidthPx) // 4000 → 上限
        assertEquals(1.0, snapshot.scale, 1e-9) // 出厂档
        assertEquals(0.0, snapshot.blurSigma, 1e-9)
        assertFalse(snapshot.followsWeekPager)
        // 没壁纸时每个区域都是纯色，内容照常画在上面。
        assertEquals(
            0xFFFAFAFA.toInt(),
            snapshot.regionPaint(HomeBackdropRegion.Timetable).colorArgb,
        )
    }

    // ───────────── 压在壁纸上的墨色（Dart homePageOverWallpaperInk 同口径） ─────────────

    @Test
    fun `没有壁纸时墨色用配置色 没有配置才用主题兜底`() {
        val fallback = 0xFF202020.toInt()
        assertEquals(fallback, HomeBackgroundModel.inkOverWallpaperArgb(null, fallback, null))
        val configured = 0xFF3377CC.toInt()
        assertEquals(
            configured,
            HomeBackgroundModel.inkOverWallpaperArgb(configured, fallback, null),
        )
    }

    @Test
    fun `深壁纸用浅墨 浅壁纸用深墨`() {
        val fallback = 0xFF202020.toInt()
        val darkWallpaper = HomeBackgroundModel.inkOverWallpaperArgb(null, fallback, 0.05)
        val lightWallpaper = HomeBackgroundModel.inkOverWallpaperArgb(null, fallback, 0.95)
        // 深壁纸 ⇒ 墨色被推到看得见（≥3:1）；浅壁纸 ⇒ 深墨原样就够。
        val darkInkLuminance = HomeBackgroundModel.relativeLuminance(darkWallpaper)
        assertTrue(
            "深壁纸上的兜底墨色对比度不足：$darkInkLuminance",
            HomeBackgroundModel.hasSufficientContrast(darkInkLuminance, 0.05),
        )
        assertTrue(
            "深壁纸上的兜底墨色没有变浅",
            darkInkLuminance > HomeBackgroundModel.relativeLuminance(fallback),
        )
        assertTrue(
            "浅壁纸上的兜底墨色没有被判成可读的深墨",
            HomeBackgroundModel.hasSufficientContrast(
                HomeBackgroundModel.relativeLuminance(lightWallpaper),
                0.95,
            ),
        )
    }

    @Test
    fun `用户挑的墨色对比度够时原样保留`() {
        // 亮蓝压在深壁纸上，对比度够 ⇒ 不该被改成黑/白。
        val configured = 0xFF66CCFF.toInt()
        assertEquals(
            configured,
            HomeBackgroundModel.inkOverWallpaperArgb(configured, 0xFF202020.toInt(), 0.05),
        )
    }

    @Test
    fun `对比度不够时朝两侧推 中灰壁纸也能到 3 比 1`() {
        // 浅灰墨（亮度约 0.52）压在 0.40 的中灰壁纸上：朝白最多只有 2.33:1，
        // 必须改朝黑推才到得了 3:1（2026-11-01 审计：只朝一侧推会永远失败）。
        val lightGrey = 0xFFC0C0C0.toInt()
        val pushed = HomeBackgroundModel.inkOverWallpaperArgb(
            configuredArgb = lightGrey,
            fallbackArgb = lightGrey,
            wallpaperLuminance = 0.40,
        )
        assertTrue(
            "中灰壁纸上的浅灰墨没有被推到 3:1：$pushed",
            HomeBackgroundModel.hasSufficientContrast(
                HomeBackgroundModel.relativeLuminance(pushed),
                0.40,
            ),
        )
        // 不能退化成纯白（那正是只朝白推的旧实现会给出的结果，对比度只有 2.33）。
        assertTrue("结果不应是纯白：$pushed", pushed != 0xFFFFFFFF.toInt())
    }

    @Test
    fun `内置默认墨色按亮度直接翻黑或白 而不是推成中灰`() {
        val black = 0xFF000000.toInt()
        val white = 0xFFFFFFFF.toInt()
        assertEquals(
            white,
            HomeBackgroundModel.inkOverWallpaperArgb(
                configuredArgb = black,
                fallbackArgb = black,
                wallpaperLuminance = 0.02,
                builtInDefaultArgb = black,
            ),
        )
        assertEquals(
            HomeBackgroundModel.ON_LIGHT_INK_ARGB,
            HomeBackgroundModel.inkOverWallpaperArgb(
                configuredArgb = white,
                fallbackArgb = white,
                wallpaperLuminance = 0.95,
                builtInDefaultArgb = white,
            ),
        )
    }

    @Test
    fun `墨色解析接受六位与八位两种写法`() {
        assertEquals(0xFF112233.toInt(), HomeBackgroundModel.parseInkArgb("#112233"))
        assertEquals(0xFF112233.toInt(), HomeBackgroundModel.parseInkArgb("112233"))
        // 设置页的规范化允许 #AARRGGBB：丢掉 alpha、保留 RGB。
        assertEquals(0xFF112233.toInt(), HomeBackgroundModel.parseInkArgb("#FF112233"))
        assertNull(HomeBackgroundModel.parseInkArgb("#12345"))
        assertNull(HomeBackgroundModel.parseInkArgb(null))
    }

    @Test
    fun `可见取景矩形按 cover 与缩放对齐折算`() {
        val full = HomeBackgroundModel.visibleSourceRect(
            imageWidth = 1000, imageHeight = 2000,
            viewportWidth = 1000, viewportHeight = 2000,
            scale = 1.0, alignX = 0.0, alignY = 0.0,
        )!!
        assertEquals(0.0, full.leftFraction, 1e-9)
        assertEquals(0.0, full.topFraction, 1e-9)
        assertEquals(1.0, full.widthFraction, 1e-9)
        assertEquals(1.0, full.heightFraction, 1e-9)

        // 放大 2 倍、居中：屏幕上只看到原图中部的一半。
        val zoomed = HomeBackgroundModel.visibleSourceRect(
            imageWidth = 1000, imageHeight = 2000,
            viewportWidth = 1000, viewportHeight = 2000,
            scale = 2.0, alignX = 0.0, alignY = 0.0,
        )!!
        assertEquals(0.25, zoomed.leftFraction, 1e-9)
        assertEquals(0.25, zoomed.topFraction, 1e-9)
        assertEquals(0.5, zoomed.widthFraction, 1e-9)
        assertEquals(0.5, zoomed.heightFraction, 1e-9)
    }

    @Test
    fun `次级墨色按墨色亮度选 0_72 与 0_70`() {
        val light = HomeBackgroundModel.mutedInkOverWallpaperArgb(0xFFFFFFFF.toInt())
        val dark = HomeBackgroundModel.mutedInkOverWallpaperArgb(0xFF101010.toInt())
        // 四舍五入，与 Flutter `withValues().toARGB32()` 一致：0.72→184(0xB8)、0.70→179(0xB3)。
        assertEquals(0xB8, (light ushr 24) and 0xFF)
        assertEquals(0xB3, (dark ushr 24) and 0xFF)
    }

}
