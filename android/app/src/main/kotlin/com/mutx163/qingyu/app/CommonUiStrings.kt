package com.mutx163.qingyu.app

/**
 * 全站共享 UI 组件的文案（目前只有一条：返回键的无障碍描述）。
 *
 * ## 为什么这条文案必须放在这里、而不是写在 `components/` 里
 *
 * 本仓的约定是**渲染层（`composeP1/`）不写中文字面量**，文案统一放在
 * `*Strings.kt`（在 `main/`）里由渲染层引用。守卫 `CjkLiteralGateTest`
 * 只扫 `composeP1/kotlin`，正是为了强制这条约定。
 *
 * `QingyuBackIconButton` 的 `contentDescription` 默认值原先是写死在
 * `components/QingyuPageScaffold.kt` 里的 `"返回"`，因此被门禁判为漏项。
 *
 * ## 与 ARB 的关系（诚实说明）
 *
 * `lib/l10n/app_zh.arb` 目前**没有**「返回」这个键（已 grep 确认），所以这里
 * 没法像 `CourseActionStrings` 那样做 ARB 逐字对拍。等 ARB 补上公共返回键后，
 * 应把本值换成对拍并加 parity 测试。在那之前，本文件是**唯一登记处**：
 * 要改「返回」的读法，改这里，不要改渲染层。
 *
 * ## 为什么不用 `contentDescription = null`
 *
 * 返回键不是装饰性图标，读屏（TalkBack）要靠它说清「这是什么按钮」。
 * 置 null 会让这个按钮在读屏下变成无名称控件，属可访问性倒退，故保留文案。
 */
object CommonUiStrings {
    /** 返回键的无障碍描述。ARB 暂无公共返回键，见类注释。 */
    const val back: String = "返回"
}
