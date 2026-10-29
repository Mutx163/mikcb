package com.mutx163.qingyu.pages

import top.yukonga.miuix.kmp.nav.core.NavKey

/**
 * 壳页面层的路由 —— miuix-nav 返回栈里的「键」。
 *
 * - [Dock]：栈底那一层，底部四槽的主屏；[slotId] 记录当前是哪个槽
 *   （`timetable` / `schedule` / `task` / `settings`）。切槽 = 替换这条路由，
 *   转场交给 NavDisplay，不自己写动画。
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

    /** 栈底的主屏（底部四槽），[slotId] 指当前槽。 */
    data class Dock(val slotId: String) : ShellRoute

    /** 页面层的一页，[id] 即目录 id。 */
    data class Page(val id: String) : ShellRoute
}
