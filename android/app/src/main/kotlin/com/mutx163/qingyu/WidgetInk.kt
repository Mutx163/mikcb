package com.mutx163.qingyu

import android.content.Context
import android.os.Build
import android.widget.RemoteViews

/**
 * 桌面卡片「中性字色」的角色。
 *
 * 四个角色与 `values/attrs.xml` 里的四个主题属性一一对应；主题定义在
 * `values/styles.xml` 的 `QingyuWidgetTheme`，颜色值本身在
 * `values/colors.xml` 与 `values-night/colors.xml` 的 `widget_ink_*`。
 *
 * 走主题属性的理由见 [applyInk]：卡片的**底色**是 `drawable/` + `drawable-night/`
 * 两套资源，由桌面在画的时候按它当时的深浅档现挑；字色若在 App 渲染时就算成固定值，
 * 两条通道各听一个时钟，系统换档后就会「底换了、字没换」，出现深底深字这类看不清的卡片。
 */
enum class WidgetInk(val attrId: Int) {
    PRIMARY(R.attr.widgetInkPrimary),
    SECONDARY(R.attr.widgetInkSecondary),
    CHIP_STRONG(R.attr.widgetInkChipStrong),
    CHIP_DIM(R.attr.widgetInkChipDim),
}

/** 状态芯片该用哪一档：strong 状态（上课中 / 即将上课 / 假期）与其余状态在白天分档，夜间同色。 */
internal fun chipInkRole(state: String): WidgetInk =
    if (TodayWidgetSupport.isStrongChipState(state)) WidgetInk.CHIP_STRONG else WidgetInk.CHIP_DIM

/**
 * 这次上色要不要交给宿主（桌面）在应用 RemoteViews 的那一刻按主题解析。
 *
 * - 渐变风格（`gradient`）是日夜同底的亮色卡，字色与深浅档无关（芯片恒深、正文恒白），
 *   继续下发渲染时算好的固定值即可，走属性反而会跟着系统档变错；
 * - Android 12 以下没有 `RemoteViews.setColorAttr`。
 *
 * ⚠️ 2026-10-10 真机证伪，属性通道**停用**（恒 false）：HyperOS 桌面解析这四个属性时
 * 拿到的是**白天档**——同一渲染里，课程色固定值（App 侧按夜间算）是亮的，而走
 * setColorAttr 的主字/次字/芯片字全部是深色（用户截图 2026-10-10 20:06：2×4 概览的
 * 「16:00 - 17:40 / 未知地点 / 默认课表·明日1节」与迷你列表「第5周 / 16:00·未知地点」，
 * 恰好全是属性路径；课程名/色条/芯片文字全是课程色路径）。即宿主解析属性所用
 * 的资源/主题在 day-night 选择上没有跟桌面当前的夜间档走（成因在宿主侧，App 无法控制）。
 * 字色回到渲染时算的固定值（[TodayWidgetSupport.inkFallback]），见
 * .agents/notes/rejected/bug-fix/2026-10-10-widget-ink-host-theme-attr.md。
 */
@Suppress("UNUSED_PARAMETER")
internal fun shouldResolveInkFromTheme(style: String, sdkInt: Int): Boolean = false

/**
 * 给卡片上的中性文字上色。
 *
 * - [accent] 非空：课程色贯穿，课程名/状态字跟随课程色（每门课各不相同，没法写成主题属性）；
 * - 否则非渐变 + Android 12+：下发**主题属性**动作，桌面在应用时按它**当下的**深浅档解析，
 *   与底色同一个时钟，换档时两边一起变；
 * - 其余情况（渐变 / Android 12 以下）：下发 [fallback]（默认按当下深浅档现算）。
 */
fun RemoteViews.applyInk(
    viewId: Int,
    role: WidgetInk,
    style: String,
    context: Context? = null,
    accent: Int? = null,
    fallback: Int = TodayWidgetSupport.inkFallback(role, style, context),
) {
    if (accent != null) {
        setTextColor(viewId, accent)
        return
    }
    if (shouldResolveInkFromTheme(style, Build.VERSION.SDK_INT)) {
        setColorAttr(viewId, "setTextColor", role.attrId)
        return
    }
    setTextColor(viewId, fallback)
}
