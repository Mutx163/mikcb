package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.pages.timetable.day.dayAgendaPageFallbackLuminance
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 日视图议程卡「压在壁纸上的墨色」判据（[CourseCardInk.resolveCardInkOverWallpaper]）。
 *
 * ## 为什么这份测试存在
 *
 * 2026-11-07 用户实机截图：森林壁纸下「机械控制工程」卡深底深字、日期摘要卡浅底白字。
 * 根因是卡面墨色与实际压住的壁纸亮度**脱钩** —— 旧实现只看不透明卡色（`calculateCardInk`
 * 的 gamma 0.55 阈值）、或干脆写死白字（考试卡）、或用主题前景（待办带）。
 *
 * 现在的判据（用户 2026-11-07 口径，不看发布版怎么实现）：
 *
 * ```
 * 卡面有效亮度 = L(卡色) × α + L(背后壁纸) × (1 − α)
 * 墨色 = 白 / 近黑里与卡面有效亮度**对比度更高**的一档（相等点在 0.2017，不是写死阈值）
 * ```
 *
 * 这份测试钉的是**判据本身**，不是「源码里出现了某个调用」：
 * 把条件改回「亮度 < 0.45 → 白」、把 α 写死成 0.5、或把自定义色无条件保留，这里都会红。
 */
class DayAgendaCardInkTest {

    /** 自动墨两档（与 [CourseCardInk] 内部同一对颜色）。 */
    private val lightInk = 0xFFFFFFFF.toInt()
    private val darkInk = 0xFF1A1A1A.toInt()

    /** 一组能代表截图场景的卡色：中性浅灰（摘要卡 / 待办带的中性底）。 */
    private val neutralCardFill = 0xFFB0B8C0.toInt()

    @Test
    fun `分界点是黑白对比度相等点 不是顶栏的 0_45`() {
        // 白（1.0）与近黑 #1A1A1A（0.0103）对比度相等的背景亮度 ≈ 0.2017。
        assertEquals("亮度 0.19 应拿白墨", lightInk, CourseCardInk.bestContrastInkForLuminance(0.19))
        assertEquals("亮度 0.21 应拿近黑墨", darkInk, CourseCardInk.bestContrastInkForLuminance(0.21))

        // 关键：0.30 早就该是近黑墨了。若谁把判据改回「亮度 < 0.45 → 白」（顶栏那套），
        // 这条会变红 —— 那正是分界点附近只剩 ~2:1 的老账。
        assertEquals("亮度 0.30 已越过相等点，应拿近黑墨", darkInk, CourseCardInk.bestContrastInkForLuminance(0.30))

        // 两侧最差也要有 ~4:1（相等点两侧是对称的）。
        assertTrue("0.21 的近黑墨对比度应 ≥ 4:1", contrastAgainst(darkInk, 0.21) >= 4.0)
        assertTrue("0.19 的白墨对比度应 ≥ 4:1", contrastAgainst(lightInk, 0.19) >= 4.0)
    }

    @Test
    fun `实心档按卡色真实亮度择优 —— 中灰卡该用近黑 不是白`() {
        // #808080：gamma 加权是 0.502（旧 `calculateCardInk` 的 0.55 阈值 ⇒ 白字，3.95:1），
        // 但它的 WCAG 亮度是 0.2159，近黑字有 4.41:1 —— 实心卡上黑字更清楚。
        assertEquals(
            "#808080 实心卡应拿近黑墨",
            darkInk,
            CourseCardInk.bestContrastInk(0xFF808080.toInt()),
        )
        // 深色卡仍是白字（#1A1A1A 自身）。
        assertEquals(
            "#1A1A1A 实心卡应拿白墨",
            lightInk,
            CourseCardInk.bestContrastInk(darkInk),
        )
    }

    @Test
    fun `深壁纸上的近透明浅卡必须拿白墨 —— 截图那张深底深字的回归`() {
        // 液态档染色拉到最低 0.08：卡面基本就是背后壁纸。卡色本身是浅灰
        //（旧实现按不透明卡色判 ⇒ 深墨），壁纸是近黑的树影 ⇒ 真实卡面很暗。
        val ink = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = neutralCardFill,
            fillAlpha = 0.08f,
            wallpaperLuminance = 0.10,
            showsWallpaper = true,
            fallbackArgb = darkInk,
        )
        assertEquals("近透明浅卡压在近黑壁纸上应拿白墨", lightInk, ink)
    }

    @Test
    fun `浅壁纸上的近透明卡必须拿近黑墨`() {
        val ink = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = neutralCardFill,
            fillAlpha = 0.10f,
            wallpaperLuminance = 0.85,
            showsWallpaper = true,
            fallbackArgb = lightInk,
        )
        assertEquals("近透明卡压在亮壁纸上应拿近黑墨", darkInk, ink)
    }

    @Test
    fun `染色强度按真实 alpha 混合而不是写死 0_5`() {
        // 同一个卡色、同一张壁纸，只改染色强度：
        //   alpha 0.08 ⇒ 卡面 ≈ 壁纸（0.12 附近，暗）⇒ 白墨；
        //   alpha 1.00 ⇒ 卡面 = 卡色本身（浅灰，亮）⇒ 近黑墨。
        val translucent = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = neutralCardFill,
            fillAlpha = 0.08f,
            wallpaperLuminance = 0.12,
            showsWallpaper = true,
            fallbackArgb = darkInk,
        )
        val opaque = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = neutralCardFill,
            fillAlpha = 1f,
            wallpaperLuminance = 0.12,
            showsWallpaper = true,
            fallbackArgb = lightInk,
        )
        assertEquals(lightInk, translucent)
        assertEquals(darkInk, opaque)

        // 写死 0.5 的混合会把这个浅灰卡（L≈0.47）与暗壁纸（0.12）混成 ≈0.295 ⇒ 近黑墨，
        // 与真实观感（近透明）相反。这条断言守住「必须用真实 alpha」。
        assertTrue(
            "真实 alpha 混合出的亮度应低于 0.20（暗卡面）",
            CourseCardInk.compositeLuminanceOverWallpaper(neutralCardFill, 0.08f, 0.12) < 0.20,
        )
        // 测试侧独立复算必须与实现同值（两边一起错就没意义了）。
        assertEquals(
            "测试侧复算与实现不一致",
            compositeLuminance(neutralCardFill, 0.42f, 0.30),
            CourseCardInk.compositeLuminanceOverWallpaper(neutralCardFill, 0.42f, 0.30),
            1e-12,
        )
    }

    @Test
    fun `自定义墨色对比度够就保留 不够才回自动黑白`() {
        // 橙色（L≈0.4404）压在近黑卡面（0.08）上：对比度 3.7:1，够 ⇒ 保留用户色。
        val orange = 0xFFFF9900.toInt()
        assertEquals(
            "对比度够时不该改用户挑的颜色",
            orange,
            CourseCardInk.resolveCardInkOverWallpaper(
                fillArgb = 0xFF000000.toInt(),
                fillAlpha = 0.2f,
                wallpaperLuminance = 0.10,
                showsWallpaper = true,
                fallbackArgb = lightInk,
                preferredArgb = orange,
            ),
        )
        // 蓝色（L≈0.1743）压在浅卡面（0.3825）上：对比度只有 1.93:1 ⇒ 丢掉用户色，取近黑。
        assertEquals(
            "对比度不够时必须回自动黑白",
            darkInk,
            CourseCardInk.resolveCardInkOverWallpaper(
                fillArgb = 0xFFFFFFFF.toInt(),
                fillAlpha = 0.35f,
                wallpaperLuminance = 0.05,
                showsWallpaper = true,
                fallbackArgb = lightInk,
                preferredArgb = 0xFF3366FF.toInt(),
            ),
        )
    }

    @Test
    fun `实色卡与亮度未知时保持各自原来的墨色`() {
        // 不露壁纸（实色卡）：壁纸与它无关，原样回 fallback。
        assertEquals(
            darkInk,
            CourseCardInk.resolveCardInkOverWallpaper(
                fillArgb = neutralCardFill,
                fillAlpha = 1f,
                wallpaperLuminance = 0.05,
                showsWallpaper = false,
                fallbackArgb = darkInk,
            ),
        )
        // 壁纸亮度还没采到（首帧）：不猜，回 fallback。
        assertEquals(
            lightInk,
            CourseCardInk.resolveCardInkOverWallpaper(
                fillArgb = neutralCardFill,
                fillAlpha = 0.08f,
                wallpaperLuminance = null,
                showsWallpaper = true,
                fallbackArgb = lightInk,
            ),
        )
    }

    @Test
    fun `染色强度越界时夹回 0 到 1`() {
        // > 1 当作实色：卡面亮度 = 卡色亮度。
        assertEquals(
            CourseCardInk.bestContrastInkForLuminance(CourseCardInk.relativeLuminance(neutralCardFill)),
            CourseCardInk.resolveCardInkOverWallpaper(
                fillArgb = neutralCardFill,
                fillAlpha = 3f,
                wallpaperLuminance = 0.05,
                showsWallpaper = true,
                fallbackArgb = darkInk,
            ),
        )
        // < 0 当作全透明：卡面亮度 = 壁纸亮度。
        assertEquals(
            CourseCardInk.bestContrastInkForLuminance(0.90),
            CourseCardInk.resolveCardInkOverWallpaper(
                fillArgb = neutralCardFill,
                fillAlpha = -1f,
                wallpaperLuminance = 0.90,
                showsWallpaper = true,
                fallbackArgb = darkInk,
            ),
        )
    }

    @Test
    fun `自定义字色门槛是 3 比 1 —— 不到就回黑白`() {
        // 与 HomeBackgroundModel.MIN_INK_CONTRAST_RATIO 同一条达标线（故意写死成 3.0，
        // 谁把它降回 2.0（课卡标题色那道旧守卫）这里就红）。
        assertEquals("自定义字色门槛应与 MIN_INK_CONTRAST_RATIO 一致", 3.0, CourseCardInk.PREFERRED_INK_MIN_CONTRAST, 0.0)

        // 卡面有效亮度 0.08（黑底 α=0.2 压在 0.10 壁纸上）。
        val surface = 0.08
        val belowThree = 0xFF989898.toInt() // L≈0.3141 ⇒ 2.80:1，不到 3:1
        val aboveThree = 0xFF9E9E9E.toInt() // L≈0.3420 ⇒ 3.02:1，刚过线

        assertEquals("不到 3:1 必须丢掉自定义色", lightInk, resolveWith(preferred = belowThree))
        assertEquals("刚好过 3:1 应保留自定义色", aboveThree, resolveWith(preferred = aboveThree))

        // 等于门槛的边界：用实测对比度当门槛，`>=` 比较必须保留（不是 `>`）。
        val measured = contrastAgainst(aboveThree, surface)
        assertEquals(
            "对比度正好等于门槛时应保留",
            aboveThree,
            resolveWith(preferred = aboveThree, minContrast = measured),
        )
        assertEquals(
            "门槛比实测高一点就必须丢",
            lightInk,
            resolveWith(preferred = aboveThree, minContrast = measured * 1.0001),
        )
    }

    // ───────────── 无壁纸（亮度 null）：按页底 + 卡色真实 α 合成 ─────────────

    @Test
    fun `无壁纸时按页底与 0_55 卡面合成 —— 中调卡压在深页底要白字`() {
        // #808080 的不透明卡色亮度≈0.216 ⇒ 实色档选近黑；但磨砂档 0.55α 压在
        // 亮度 0.10 的页底上，卡面只剩 0.164 ⇒ 白字才是高对比那档。
        val midCard = 0xFF808080.toInt()
        assertEquals("前提：实色档 #808080 选近黑墨", darkInk, CourseCardInk.bestContrastInk(midCard))
        val ink = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = midCard,
            fillAlpha = 0.55f,
            wallpaperLuminance = null,
            showsWallpaper = true,
            fallbackArgb = CourseCardInk.bestContrastInk(midCard),
            pageBackgroundLuminance = 0.10,
        )
        assertEquals("中调卡 0.55α 压在深页底上，卡面≈0.164 ⇒ 白墨", lightInk, ink)
        assertEquals(
            "合成必须用真实 α（0.55），不是写死的卡色亮度",
            0.164,
            CourseCardInk.compositeLuminanceOverWallpaper(midCard, 0.55f, 0.10),
            0.001,
        )
    }

    @Test
    fun `无壁纸时按页底与 0_55 卡面合成 —— 深卡压在亮页底要近黑字`() {
        // #37474F 的不透明卡色亮度≈0.059 ⇒ 实色档选白；0.55α 压亮度 0.95 的页底
        // 后卡面≈0.46 ⇒ 近黑字。
        val deepCard = 0xFF37474F.toInt()
        assertEquals("前提：实色档深蓝灰卡选白墨", lightInk, CourseCardInk.bestContrastInk(deepCard))
        val ink = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = deepCard,
            fillAlpha = 0.55f,
            wallpaperLuminance = null,
            showsWallpaper = true,
            fallbackArgb = CourseCardInk.bestContrastInk(deepCard),
            pageBackgroundLuminance = 0.95,
        )
        assertEquals("深卡 0.55α 压在亮页底上，卡面≈0.46 ⇒ 近黑墨", darkInk, ink)
    }

    @Test
    fun `壁纸亮度已知时优先用壁纸 页底不参与`() {
        val ink = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = 0xFF808080.toInt(),
            fillAlpha = 0.55f,
            wallpaperLuminance = 0.08,
            showsWallpaper = true,
            fallbackArgb = darkInk,
            // 页底 0.95 单独会给出近黑墨；壁纸 0.08 必须赢。
            pageBackgroundLuminance = 0.95,
        )
        assertEquals("壁纸亮度已知时必须优先用壁纸", lightInk, ink)
    }

    @Test
    fun `页底也未知时保持旧回退`() {
        val fallback = 0xFF00FF00.toInt()
        val ink = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = 0xFF808080.toInt(),
            fillAlpha = 0.55f,
            wallpaperLuminance = null,
            showsWallpaper = true,
            fallbackArgb = fallback,
            pageBackgroundLuminance = null,
        )
        assertEquals("壁纸与页底都不知道 ⇒ 原样回退，既有调用零影响", fallback, ink)
    }

    @Test
    fun `实色档不看页底`() {
        val fallback = 0xFF00FF00.toInt()
        val ink = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = 0xFF808080.toInt(),
            fillAlpha = 0.55f,
            wallpaperLuminance = null,
            showsWallpaper = false,
            fallbackArgb = fallback,
            pageBackgroundLuminance = 0.05,
        )
        assertEquals("不露壁纸/页底的实色档直接回退", fallback, ink)
    }

    @Test
    fun `有壁纸但亮度未就绪时按旧回退 不许用页底反判`() {
        // 浅色主题页底 0.95、真实壁纸约 0.05，深蓝灰卡 0.55α：
        // 按页底合成 0.46 ⇒ 近黑字；屏幕上实际是深壁纸（合成 0.055）⇒ 应白字。
        val deepCard = 0xFF37474F.toInt()
        val fallback = CourseCardInk.bestContrastInk(deepCard)
        val gated = dayAgendaPageFallbackLuminance(hasWallpaper = true, pageLuminance = 0.95)
        assertNull("有壁纸时门控必须把页底亮度置空", gated)

        val ink = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = deepCard,
            fillAlpha = 0.55f,
            wallpaperLuminance = null,
            showsWallpaper = true,
            fallbackArgb = fallback,
            pageBackgroundLuminance = gated,
        )
        assertEquals("亮度未就绪时保持旧回退（白字），不许按页底反判", lightInk, ink)

        // 反证：不门控、把页底直接传进去就会选近黑 —— 这正是瞬态要避免的那一帧。
        val ungated = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = deepCard,
            fillAlpha = 0.55f,
            wallpaperLuminance = null,
            showsWallpaper = true,
            fallbackArgb = fallback,
            pageBackgroundLuminance = 0.95,
        )
        assertEquals("反证：页底 0.95 会选近黑（与真实壁纸相反）", darkInk, ungated)

        // 亮度测出来后按真壁纸判，仍是白字：门控不改变正常结果。
        val measured = CourseCardInk.resolveCardInkOverWallpaper(
            fillArgb = deepCard,
            fillAlpha = 0.55f,
            wallpaperLuminance = 0.05,
            showsWallpaper = true,
            fallbackArgb = fallback,
        )
        assertEquals("壁纸亮度 0.05 应白字", lightInk, measured)
    }

    /** 在固定的黑底卡（α=0.2、壁纸亮度 0.10 ⇒ 卡面 0.08）上解一次自定义字色。 */
    private fun resolveWith(preferred: Int, minContrast: Double? = null): Int =
        if (minContrast == null) {
            CourseCardInk.resolveCardInkOverWallpaper(
                fillArgb = 0xFF000000.toInt(),
                fillAlpha = 0.2f,
                wallpaperLuminance = 0.10,
                showsWallpaper = true,
                fallbackArgb = lightInk,
                preferredArgb = preferred,
            )
        } else {
            CourseCardInk.resolveCardInkOverWallpaper(
                fillArgb = 0xFF000000.toInt(),
                fillAlpha = 0.2f,
                wallpaperLuminance = 0.10,
                showsWallpaper = true,
                fallbackArgb = lightInk,
                preferredArgb = preferred,
                preferredMinContrast = minContrast,
            )
        }

    /** [CourseCardInk.resolveCardInkOverWallpaper] 的混合公式（测试侧独立复算，别调用实现）。 */
    private fun compositeLuminance(fillArgb: Int, fillAlpha: Float, wallpaperLuminance: Double): Double {
        val t = fillAlpha.toDouble().coerceIn(0.0, 1.0)
        return CourseCardInk.relativeLuminance(fillArgb) * t + wallpaperLuminance * (1.0 - t)
    }

    private fun contrastAgainst(inkArgb: Int, backgroundLuminance: Double): Double {
        val inkLuminance = CourseCardInk.relativeLuminance(inkArgb)
        val lighter = if (inkLuminance > backgroundLuminance) inkLuminance else backgroundLuminance
        val darker = if (inkLuminance > backgroundLuminance) backgroundLuminance else inkLuminance
        return (lighter + 0.05) / (darker + 0.05)
    }
}
