package com.mutx163.qingyu.pages.settings

/**
 * 设置页（上方预览 + 下方列表的分栏页）的列表要不要挂**顶栏折叠连接器**。
 *
 * ## 为什么必须按顶栏形态分流（2026-11-03 用户实报「下面的设置区滚不动」）
 *
 * `QingyuPageScaffold` 每页都建一个 `MiuixScrollBehavior()`。大顶栏页里官方
 * `TopAppBar` 会把大标题的实测高度写进 `heightOffsetLimit`，折叠连接器只吃
 * 「收起大标题」那一截滚动，剩下的全给列表——联动正常。
 *
 * 小顶栏页（`collapsibleLargeTitle = false`：课程卡片 / 课表页面两页）里
 * `SmallTopAppBar` **不接**这个 behavior，`heightOffsetLimit` 就停在
 * `rememberTopAppBarState` 的默认值 `-Float.MAX_VALUE`（miuix `TopAppBar.kt:276`）。
 * 此时连接器的 `onPreScroll` 里 `state.heightOffset += available.y` 的 coerced
 * 区间是 `[-Float.MAX_VALUE, 0]` ⇒ **任何向上滚动都产生有效差值、被整个吞掉**，
 * 且这个「幻影折叠」永远到不了头——列表一格都滚不动；向下滚则要先喂饱幻影展开。
 *
 * 判据收敛在这一个函数：小顶栏页一律不挂（列表独占滚动），大顶栏页照常挂。
 */
fun settingsListAttachesTopBarSync(collapsibleLargeTitle: Boolean): Boolean = collapsibleLargeTitle
