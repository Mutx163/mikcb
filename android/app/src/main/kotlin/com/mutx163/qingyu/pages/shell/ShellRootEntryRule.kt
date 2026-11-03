package com.mutx163.qingyu.pages.shell

/**
 * 顶栏返回键显隐的**唯一判据**（2026-11-03，从底栏进入的根页不显示返回箭头）。
 *
 * ## 判定规则（一句话）
 *
 * 从底栏进入的根页（取件码 / 任务 / 设置 / 月视图这类，页面栈的栈底主屏）没有上一级
 * 可回，返回箭头无用，不显示；从这些页面推入的二级及更深页面（设置 → 关于 → 更新、
 * 仓库 → 学校 → 适配器详情）保留返回箭头。
 *
 * ## 判据的输入从哪来
 *
 * 壳（`PagesShellActivity`）在 miuix-nav 的**两个 entry 分支**分别注入
 * `LocalQingyuPageIsRootEntry`：栈底主屏（`ShellRoute.Dock`）注入 `true`，
 * 推入页（`ShellRoute.Page` / `ZoomPage`）注入 `false` —— 这是页面栈的真实结构，
 * 页面自己不传「我是不是根」的布尔，箭头显隐由 [QingyuPageScaffold] 一处消费。
 * `null` = 无壳环境（外观编辑页的缩尺预览卡、独立预览），不注入，保持显示。
 *
 * 纯函数无 Android / Compose 依赖，JVM 单测钉住（`ShellRootEntryRuleTest`）。
 */
object ShellRootEntryRule {

    /**
     * 顶栏是否画返回键。
     *
     * @param isRootEntry 壳注入的根页标记；`true` = 根页（不画），`false` = 推入的
     *   二级/更深页（画），`null` = 无壳环境（保持画，行为与判据引入前一致）。
     */
    fun shouldShowBackButton(isRootEntry: Boolean?): Boolean = isRootEntry != true
}
