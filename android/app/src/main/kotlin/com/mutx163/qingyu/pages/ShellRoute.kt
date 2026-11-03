package com.mutx163.qingyu.pages

import top.yukonga.miuix.kmp.nav.core.NavKey

/**
 * 壳页面层的路由 —— miuix-nav 返回栈里的「键」。
 *
 * - [Dock]：栈底那一层，主屏（2026-11-03 起无参数：主屏停在第几个底栏条目由壳的
 *   `currentRootId` 状态持有，内容区用 `HorizontalPager` 承载、点底栏滑过去 ——
 *   miuix-nav 的 `NavChange.Replace` 官方就是瞬时直切（旧条目同帧卸载、驱动不动），
 *   根级切换的左右滑转场只能走官方 demo 的 Pager 形态；`itemId` 状态化之后栈底
 *   不再发生替换，返回栈语义不变）。
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
     * 栈底的主屏。**无参数** —— 停在第几个底栏条目由壳的状态持有
     * （`PagesShellActivity.currentRootId`），换条目不再动返回栈。
     *
     * 2026-10-31 之前这里叫 `slotId`、只认四个写死的槽位（timetable/schedule/task/
     * settings）；底栏改为读用户存档后条目集合是可变的，「槽位」这个词不再成立。
     * 2026-11-03 之前是 `data class Dock(val itemId: String)`：切底栏 = 替换栈底路由，
     * miuix-nav 按 Replace 瞬时直切（用户报「点底栏闪现」）——现改为 Pager 滑动。
     */
    data object Dock : ShellRoute

    /**
     * 页面层的一页，[id] 即目录 id。
     *
     * [pushToken] 由壳**每次推页时**分配一个递增序号，保证两条路由的值互不相等。
     * 原因（2026-11-01 真机事故）：miuix-nav 在「旧页正在退场（时长约 500ms）时又推入
     * key 相同的一页」这条路径上会**复用旧条目实例**（`NavPresentation.reconcile` 的
     * 「re-push of same key」分支），而旧实例的 composition 没被销毁 —— 页面自己的
     * 入场进度、`exiting` 守卫全都停在退场那一刻。外观编辑页就撞上了这个：
     * 退出后再点底栏进不来（页面停在退场末态、取消/完成也不响应）。
     * 每推一次给一个新 token ⇒ 新条目、新 composition，旧条目照常自己播完退场。
     */
    data class Page(val id: String, val pushToken: Long = 0L) : ShellRoute

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
     * [pushToken] 的作用同 [Page.pushToken]。
     */
    data class ZoomPage(val id: String, val pushToken: Long = 0L) : ShellRoute
}
