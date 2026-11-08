package com.mutx163.qingyu.pages.shell

/**
 * 底栏切换的**页映射 / 方向 / 降级**纯逻辑（2026-11-03 左右滑转场）。
 *
 * ## 背景与形态
 *
 * 底栏切页从「替换 miuix-nav 栈底路由」（瞬时直切）改成官方 demo 的主屏形态：
 * 栈底固定一条主屏路由，内容区用 `HorizontalPager` 承载主屏条目，点底栏 =
 * `springAnimateToPage`（miuix 官方工具）滑到目标页。三个原因写在这里，供改这块的人对账：
 *
 * 1. miuix-nav 对 `NavChange.Replace` **没有转场**：新条目与被替换条目在栈里同占一个
 *    index，驱动 float 当前值与目标值相等根本不动，旧条目由渲染层的
 *    `finishedLeaving`（index < 当前栈长）在第一帧就地卸载 —— 库的官方语义就是「替换即瞬切」，
 *    没有任何进度信号可给转场用。官方 demo 对 tab 切换给的标准形态就是 Pager
 *    （`AppContent.kt` 的 `MainPagerState.animateToPage`），miuix-nav 只管推页。
 * 2. Pager 的滑动几何天然「方向跟索引」：目标页在右侧就从右滑入，在左侧反之 ——
 *    需求的方向规则由组件保证，这里只把「条目 id → 页下标 → 方向」的映射做成纯函数钉住。
 * 3. 周课表与日课表是**同一个宿主的两种展开态**（页内窗口动画，另一套机制），
 *    在 Pager 里必须是同一页，否则底栏「日」「周」两格会渲染出两个课表实例。
 *    [normalizePageKey] 把这对 id 归一到同一页。
 *
 * 全部函数无 Android / Compose 依赖，JVM 单测直接钉（`DockPagerMotionTest`）。
 */
object DockPagerMotion {

    /**
     * 视图动作归一：`day` / `monthView` 与 `week` 是**同一个课表宿主**的三种页内态，
     * Pager 里必须是同一页。
     *
     * 高亮仍按原始 id 区分（`dockSelectedIdOf` 会把课表宿主的路由按 `homeViewMode`
     * 折到 `day` / `week` / `monthView` 格上），这里只影响「几页、点哪格滑到哪页」。
     */
    fun normalizePageKey(itemId: String): String = when (itemId) {
        HomeDockNavModel.ACTION_DAY,
        "monthView" -> HomeDockNavModel.ACTION_WEEK

        else -> itemId
    }

    /**
     * Pager 页列表：底栏排列里「主屏内渲染」的条目，按 [normalizePageKey] 去重保序。
     *
     * - 推页型条目（外观编辑器、加课表单等，`rendersAsRoot` 为 false）不占 Pager 页：
     *   点它们仍是推一层页面、底栏让位，与改造前一致；
     * - [ensureItemId]（冷启动恢复的条目，来自存档的 `timetableHomeViewMode`）可能不在
     *   用户当前的底栏排列里（例如存档停在月视图、底栏没排月视图格）：补到末尾，
     *   保证恢复的那个主屏真的有页可停 —— 与改造前「栈底直接渲染该条目」等价。
     */
    fun pageItemIds(dockIds: List<String>, ensureItemId: String): List<String> {
        val items = ArrayList<String>(dockIds.size + 1)
        for (id in dockIds) {
            if (!HomeDockNavModel.rendersAsRoot(id)) continue
            val key = normalizePageKey(id)
            if (items.contains(key)) continue
            items.add(key)
        }
        if (HomeDockNavModel.rendersAsRoot(ensureItemId) &&
            !items.contains(normalizePageKey(ensureItemId))
        ) {
            items.add(normalizePageKey(ensureItemId))
        }
        return items
    }

    /**
     * 条目 id 在 Pager 页列表里的下标；不在列表时返回 null（调用方不动，不猜）。
     */
    fun indexOfPage(items: List<String>, itemId: String): Int? {
        val key = normalizePageKey(itemId)
        return items.indexOfFirst { normalizePageKey(it) == key }.takeIf { it >= 0 }
    }

    /**
     * 方向判据：目标条目相对当前条目隔了几页、在哪一侧。
     *
     * `+n` = 目标在右 n 页（新页从右滑入、旧页向左退）；`-n` = 目标在左（反向）；
     * `0` = 同一页（含 `week` 与 `day` 互点 —— 那是宿主内的展开态切换，不走 Pager 滑动），
     * 也覆盖目标条目不在页列表里的情况（调用方走别的分支，不滑动、不猜）。
     *
     * 壳在 `selectRoot` 里消费它做「重复点同页 / 同宿主无动作」守卫；数值本身同时是
     * 单测的方向契约（`DockPagerMotionTest`）：Pager 沿索引方向滑动，正值必然表现为
     * 新页从右进入。
     */
    fun slideStep(fromItemId: String, toItemId: String, items: List<String>): Int {
        val from = indexOfPage(items, fromItemId) ?: return 0
        val to = indexOfPage(items, toItemId) ?: return 0
        return to - from
    }

    /**
     * 降级判据：系统「动画时长缩放」归零（开发者选项里把三个动画缩放都关掉）时，
     * 底栏切换不播滑动 —— 直接落定到目标页，零中间帧。
     *
     * 判据写法与 `homeViewExpandReducedMotion`（首页展开动画那条，`pages/timetable/`）
     * 同一口径：纯函数收缩放值，渲染层读 `Settings.Global.ANIMATOR_DURATION_SCALE` 喂进来，
     * 两边互不复用文件但语义逐字一致。另外 Compose 的 MotionDurationScale 本身也挂这同一个
     * 系统值，spring 动画在缩放为 0 时会被压成零时长 —— 显式判据是双保险，且让单测可钉。
     */
    fun reducedMotion(animatorDurationScale: Float): Boolean = animatorDurationScale <= 0f

    /**
     * 该主屏条目是否把壁纸铺在自己底下（周 / 日 / 月三个视图）。
     *
     * 只有这三个视图是「照片在上、内容浮在玻璃上」；其余内嵌页（任务、设置、取件码…）
     * 是不透明的主题面，坞压在它们上面时墨色必须按主题判 —— Dart 旧版对应
     * `isInlinePage`（`timetable_glass_dock.dart:85-86` 把它算成「壁纸亮度 = null」）。
     */
    fun showsWallpaper(itemId: String): Boolean = HomeDockNavModel.isViewAction(itemId)
}
