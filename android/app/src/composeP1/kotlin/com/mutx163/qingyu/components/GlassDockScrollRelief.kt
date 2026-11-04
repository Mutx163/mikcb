package com.mutx163.qingyu.components

import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * 首页**根页**（壳 `entry<ShellRoute.Dock>` 栈底主屏，`LocalQingyuPageIsRootEntry == true`）
 * 可滚动内容需要的**底部坞避让**（dp，从屏幕底端起算，已含系统底安全区）。
 *
 * ## 它解决什么
 *
 * 玻璃坞是壳叠在首页内容之上的**满屏半透明 overlay**：页面滚动体要能一直滚到药丸下方、
 * 末尾内容从半透明坞下方**穿过**，而不是被坞硬生生盖住看不到。Flutter 发布版用
 * `GlassDockScrollReliefScope(inset = _glassDockContentScrollInset)` 注入同一个量、
 * 由 `HyperosListView` 统一消费（新增内嵌页无须逐页适配）。Compose 侧用本 CompositionLocal
 * 复刻这条：壳在 `entry<ShellRoute.Dock>` 注入，[QingyuPageList] 自动消费。
 *
 * ## 默认值与不影响的页面
 *
 * 默认 [DefaultGlassDockScrollRelief] = `0.dp`。推入页（引导 / 版本更新 / 关于……壳注入
 * `LocalQingyuPageIsRootEntry provides false`）与无壳环境（缩尺预览卡）拿到的就是 0，
 * 底部行为与改动前逐像素一致——**独立流程不受本改造影响**。
 *
 * 取值口径与 [com.mutx163.qingyu.pages.shell.HomeFloatingMetrics.contentBottomDp] 同源
 * （药丸占用 + 系统底安全区），壳侧用 `rememberHomeFloatingInsets(settingsModel).contentBottom`
 * 拿到再注入，避免两处各算一遍。
 */
val LocalGlassDockScrollRelief = staticCompositionLocalOf<Dp> { DefaultGlassDockScrollRelief }

/** [LocalGlassDockScrollRelief] 的默认值：无坞 / 非首页根页时为 0。 */
val DefaultGlassDockScrollRelief: Dp = 0.dp
