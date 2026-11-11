package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.app.TimetableHomeViewMode

/**
 * 首页三档（周 / 日 / 月）之间的**过渡几何判据**：哪一对可以播滑入、哪一对必须直达。
 *
 * ## 三档在屏幕上是并排的
 *
 * 日 / 月都是 `c1.week` 的页内态，各自读自己的进度做 `translateX`，于是三档在几何上被摆成
 * 一条横线：`日 | 周 | 月`。周内容的位置由「谁在过渡」决定——月过渡时按 `monthExpand` 左移
 * 淡出，日过渡时按 `dayExpand` 右移。
 *
 * 这带来一个只在**非相邻档**出现的副作用：点「日 ↔ 月」时两个进度**同时播**，日往左出、
 * 月从右入，中间那一截露出来的正是淡出中的周网格（360ms 内一直可见）。用户 2026-11-11
 * 真机反馈「底栏切月↔日，画面明显在周视图停了一下」就是这个。
 *
 * ## 基准：直达
 *
 * 发布版 `v2.1.4.1`（2026-10-19）里**还没有月视图**（tag 的 `lib/` 下没有任何 month 文件），
 * 所以「月↔日」的发布版基准只能取去 Flutter 前的最后一版 Dart（`pre-deflutter-stage2`）：
 * 月视图在那里是首页内的整屏内嵌页，覆盖 / 揭开是**即时的**，源码注释原文
 * 「与旧『设置 Tab』一致：点底栏闪现直切，无滑动转场」。本判据对齐的正是这条。
 *
 * ## 只管「跨过周」的那一对
 *
 * * `周 ↔ 日`、`周 ↔ 月`：相邻档，横滑（translateX）是对的，**继续播**；
 * * `日 ↔ 月`：中间隔着周，播滑入必然把周露出来 ⇒ `animate` 收成 false，两档当帧 snap 落定；
 * * 同档（重复点）：不换档，判 false（调用方本来就会提前 return）。
 *
 * 收口点在 [com.mutx163.qingyu.pages.ShellWiring.switchHomeViewMode]，不动任何调用点：
 * 底栏那几处的 `animate = true, horizontal = true` 语义（「两格互点 = 横滑」）原样保留。
 */
object HomeViewSwitchMotion {

    /**
     * 这一对切换是否**跨过了周档**（`日 ↔ 月`）：是 ⇒ 不许播滑入，直接落定。
     *
     * @param from 切换前的档（`ShellWiring.homeViewMode`）。
     * @param to 切换后的档。
     */
    fun directAcrossWeek(
        from: TimetableHomeViewMode,
        to: TimetableHomeViewMode,
    ): Boolean = (from == TimetableHomeViewMode.DAY && to == TimetableHomeViewMode.MONTH) ||
        (from == TimetableHomeViewMode.MONTH && to == TimetableHomeViewMode.DAY)
}
