package com.mutx163.qingyu.pages.timetable

/**
 * 顶栏玻璃带「底边折射」的作用范围与位移夹具（2026-11-03）。
 *
 * ## 为什么需要它
 *
 * `TimetableChromeBandGlass` 那条带在壁纸上叠「二次模糊 + 染色 + 底边折射
 * `lens(作用带, 位移, 色散)`」。折射的位移会把**带子与内容交界处**的画面几何搬位：
 * 作用带一宽（默认 11dp、滑杆最大 24dp），大半条带都在弯，风景照的横线在带内外
 * 上下对不上——用户读作「星期栏那块壁纸错位」。
 *
 * 收窄规则（本文件是唯一出口，渲染层不许另写公式）：
 *
 * 1. **位移量 0 ⇒ 严格零位移**：输出 (0, 0)，渲染层连 `lens` 都不挂；
 * 2. **作用带硬上限 [MAX_BAND_DP]（8dp）**：位移本身 ≤ 8dp 时，8dp 的作用带刚好
 *    容纳一个完整位移周期——交界以外（带内其余部分）的画面逐像素与下方内容连续；
 * 3. **作用带不得超出带盒高度**：带子比夹具还窄时按带盒算，不让折射溢出；
 * 4. **位移量硬上限 [MAX_AMOUNT_DP]（8dp）**：材质滑杆拖到多大都被压住。
 *
 * 入参出参全部是**逻辑 dp**；px 换算在渲染层（`LocalDensity`）。
 */
data class TimetableBandRefraction(
    /** 折射作用带高度（dp，从交界边起算）。0 = 不折射。 */
    val bandDp: Float,
    /** 最大位移量（dp）。0 = 不折射。 */
    val amountDp: Float,
)

/** 作用带硬上限（dp）：紧贴交界的一小条，其余部分零位移。 */
const val TIMETABLE_BAND_REFRACTION_MAX_BAND_DP = 8f

/** 位移量硬上限（dp）：材质滑杆拖到多大都被压到这个值。 */
const val TIMETABLE_BAND_REFRACTION_MAX_AMOUNT_DP = 8f

/**
 * 把用户调的「作用带 / 位移量」夹进交界窄带。
 *
 * @param bandBoxHeightDp 带盒自身高度（dp）；夹具不许让作用带超出带盒。
 * @param requestedBandDp 用户/出厂的作用带值（材质面板滑杆）。
 * @param requestedAmountDp 用户/出厂的位移量值（材质面板滑杆）。
 */
fun timetableBandRefraction(
    bandBoxHeightDp: Float,
    requestedBandDp: Float,
    requestedAmountDp: Float,
): TimetableBandRefraction {
    val amount = requestedAmountDp.coerceIn(0f, TIMETABLE_BAND_REFRACTION_MAX_AMOUNT_DP)
    if (amount <= 0f) {
        // 零位移 ⇒ 严格零偏移：作用带也归零，渲染层不挂折射。
        return TimetableBandRefraction(bandDp = 0f, amountDp = 0f)
    }
    val band = requestedBandDp.coerceIn(0f, minOf(TIMETABLE_BAND_REFRACTION_MAX_BAND_DP, bandBoxHeightDp))
    if (band <= 0f) {
        return TimetableBandRefraction(bandDp = 0f, amountDp = 0f)
    }
    return TimetableBandRefraction(bandDp = band, amountDp = amount)
}
