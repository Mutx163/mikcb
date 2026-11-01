package com.mutx163.qingyu.pages

import top.yukonga.miuix.kmp.nav.core.NavKey

/**
 * 壳页面层的路由 —— miuix-nav 返回栈里的「键」。
 *
 * - [Dock]：栈底那一层，主屏；[itemId] 是当前停在哪个**底栏条目**
 *   （`week` / `day` / `tasks` / `settings` / `monthView` …，取值来自用户的
 *   `glassDockActions` 存档）。切条目 = 替换这条路由，转场交给 NavDisplay，
 *   不自己写动画。
 * - [Page]：从索引点开的、或页面内部推开的任意一页；[id] 即 [ShellPageContent]
 *   认识的目录 id（`a.about` / `b.general` / `c1.week` …）。
 *
 * 用 `data class`：miuix-nav 用每条路由的 `toString()` 当 contentKey，按值唯一 ⇒
 * 两个路由不同、状态不会串；同一页重复压栈会被运行时判为重复 key（push 已先幂等）。
 *
 * 不标 `@Serializable`：配 `navBackStackOf` 用内存栈（进程被杀后从主屏重来可接受），
 * 免得为壳在共享 build 上再接一套序列化编译器插件。
 */
sealed interface ShellRoute : NavKey {

    /**
     * 栈底的主屏，[itemId] 指当前停的底栏条目。
     *
     * 2026-10-31 之前这里叫 `slotId`、只认四个写死的槽位（timetable/schedule/task/
     * settings）；底栏改为读用户存档后条目集合是可变的，「槽位」这个词不再成立。
     */
    data class Dock(val itemId: String) : ShellRoute

    /** 页面层的一页，[id] 即目录 id。 */
    data class Page(val id: String) : ShellRoute

    /**
     * 页面层的一页，但入场走**「首页缩放」档**：[id] 同 [Page.id]。
     *
     * 目前只有外观编辑页用它，与 Dart 的 `HomeMenuEntry.zoomTransition`
     * （`lib/widgets/home_menu_catalog.dart:456-490`：`zoom` 参数目前仅外观编辑开启）
     * 逐条对应。这一页**自己**就会把「整个首页」从整屏缩进预览卡
     * （`AppearanceEditorScreen` 的入场），所以壳**不再叠一层侧滑** ——
     * 叠上去正是用户 2026-11-01 报的「从右边滑进来，而不是首页缩放」。
     *
     * 转场用官方 `NavTransitions.None`（瞬时切换、零位移），不是自研动画：
     * 位置变化全部来自页面自己的缩放入场，壳只负责「别插一脚」。
     */
    data class ZoomPage(val id: String) : ShellRoute
}
