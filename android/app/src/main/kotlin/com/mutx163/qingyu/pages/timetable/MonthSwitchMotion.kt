package com.mutx163.qingyu.pages.timetable

/**
 * 月视图页内态（`c1.week` 的第三种态）**自身过渡**的两处时序判据（2026-11-12）。
 *
 * ## 这是「取舍冲突」的收口点，不是又一个动画开关
 *
 * 用户的两条反馈互相拉扯，`4bd6b1fe4`（2026-11-11「底栏月↔日直达，不再路过周视图」）
 * 已经把其中一半定死了：
 *
 * * **日 ↔ 月跨过周档**时不许播滑入 —— 两个进度同帧起跑会把淡出中的**周网格**露在中间
 *   （`HomeViewSwitchMotion.directAcrossWeek`，`ShellWiring.kt` 里收成 `animate = false`
 *   ⇒ 本页直接 `snapTo`）。**那条不是缺陷，是修掉真问题**，本轮不 revert、不动它的判据；
 * * 剩下的两处是**月页自身过渡**的毛病，与本文件有关：
 *   1. **起步空 1~2 帧**：月层是「换档下一帧才首次组合」（`monthMounted` 先置真、月层
 *      才挂树），而 360ms tween 同帧起跑 ⇒ 首组合 / 首测量和动画第一帧挤在一帧里，
 *      观感是月内容到位前先空一下。日视图早就有「先挂树 → 等首组合 → 再开播」两步门，
 *      月层一直没有。
 *   2. **外层 spring 与内层 tween 真叠加**：只看 `daySwitchAnimate` 不够 —— 连点底栏时
 *      外层底栏 Pager 还在 spring 滑行，页内再播 360ms tween —— 这是**已知的一条真叠加路径**
 *      （**是否在叠加帧生效未验**：effect 的键变化要等一次重组，重进之前可能已播 1~2 帧 tween；
 *      两者各动一半，画面像被拽了两次）。判据应是「外层还在滑 ⇒ 本页别播，跟着走」。
 *
 * ## 为什么单独成文件
 *
 * 两个判据都是**纯函数**：没有 Compose、没有 Android、没有状态。放在 main 源集是为了让
 * JVM 单测（[MonthSwitchMotionTest]）直接钉真值表，而不是靠渲染层文本守卫猜意图；
 * 渲染侧只剩「取哪个布尔」的薄适配（`TimetableWeekPage` 的
 * `LaunchedEffect(monthMode, monthContentComposed, homePagerScrolling)`）。
 *
 * ⚠️ 本文件**不改**「月 ↔ 日直达」那条决定，也不负责外层 Pager 的几何；壳侧要不要把
 * `pagerState.isScrollInProgress` 接进来由 `PagesShellActivity` / `ShellWiring` 的所有者决定。
 * 未接线时 `TimetableWeekPage(homePagerScrolling = false)` 是默认值 ⇒ 行为与今天完全一致。
 */
object MonthSwitchMotion {

    /**
     * 是否**直接落定**（`snapTo`，不播逐帧形变）：减少动画 / 调用方要求不播 / 外层 pager 仍在滑行。
     *
     * 三个输入都是「任一条成立就该立刻到终点」，所以是**或**关系而不是优先级表：
     *
     * 1. 系统「减少动画」（`animatorDurationScale <= 0`）——与日视图同一口径，
     *    降级时一律不补形变；
     * 2. 调用方要求不播（`monthMode` 来源是「跨过周档的直达」，见 `HomeViewSwitchMotion`）；
     * 3. **外层底栏 Pager 仍在 spring 滑行**——此时页内再播 360ms tween 会与外层位移
     *    叠成一帧两动，是**已知的一条真叠加路径**（**是否在叠加帧生效未验**：effect 的键变化
     *    要等一次重组，重进之前可能已播 1~2 帧 tween）。判据应是「外层还在滑 ⇒ 本页别播，
     *    跟着走」；真机观感未验，别把这条当已验结论。
     *
     * @param reducedMotion 系统「减少动画」是否生效（`homeViewExpandReducedMotion`）。
     * @param animate 调用方本次是否允许播动画（`TimetableWeekPage.daySwitchAnimate`）。
     * @param outerPagerScrolling 外层底栏 Pager 当前是否仍在滑行
     *   （壳侧 `pagerState.isScrollInProgress`）；未接线时恒 `false`。
     */
    fun shouldSnap(reducedMotion: Boolean, animate: Boolean, outerPagerScrolling: Boolean): Boolean =
        reducedMotion || !animate || outerPagerScrolling

    /**
     * 打开方向是否要**等首组合信号**：仅在「已进月、要播动画、还没组好、且有内容可挂」时等。
     *
     * 与 `TimetableWeekPage` 里日视图那套两步门同构：本帧只把月层挂上树（`monthMounted = true`），
     * 什么都不播；月层里的 `MonthContentMountSignal` 在组合落地后把「已组合」置真，effect 因键
     * 变化重进一次，才走到 `animateTo`。中间那一帧用于测量 / 放置 / 绘制，动画因此从**已经画好的
     * 树**上起步，不再空 1~2 帧。
     *
     * ⚠️ `hasContent == false`（宿主没给 `monthContent`）时**必须不等**：没有东西可挂就永远等不到
     * 信号，`monthExpand` 会停在 0，而 `monthVisible` 已为真 ⇒ 命中层一直吃事件，页面点不动。
     * `monthMode == false`（收起方向）同样必须不等 —— 那一支没人再把状态翻回来，收起动画会永久挂起。
     * 两条都被真值表钉着（`MonthSwitchMotionTest` 的 `needsMountWait` 用例）。
     *
     * @param monthMode 当前是不是月视图页内态（收起方向一律不等）。
     * @param contentComposed 月层子树是否已完成至少一次组合（`monthContentComposed`）。
     * @param hasContent 宿主是否真的注入了月视图正文（`monthContent != null`）。
     */
    fun needsMountWait(monthMode: Boolean, contentComposed: Boolean, hasContent: Boolean): Boolean =
        monthMode && !contentComposed && hasContent
}
