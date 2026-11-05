package com.mutx163.qingyu.pages.import.warehouse

/**
 * 跨路由交接「这一下点进去的是哪所学校 / 哪个适配器」。
 *
 * ## 为什么必须有它（2026-11-03 用户实报）
 *
 * 用户：**「课程导入的时候点击网页导入，就会回答学校列表页面」**——点「网页登录导入」
 * 没进登录页，反而被打回选校页。
 *
 * 壳里 `warehouseState` 是 `ShellPageContent` 内的 `remember { WarehouseShellState() }`，
 * 而 `ShellPageContent` 由 `entry<ShellRoute.Page>` **每个路由条目各组合一次**
 * （miuix-nav 用 `key(contentKey)` 把条目分成独立组合作用域）。所以从适配器列表
 * 推 `g2.webLogin` / `g2.adapterDetail` 时，新页拿到的是**全新实例**，学校与适配器
 * 都是 null；登录页旧兜底 `onOpenPage(IMPORT_PICKER)` 于是把用户**静默打回选校页**。
 *
 * ## 用法
 *
 * 来源页在 `onOpenPage(...)` **之前** [publish]；目标页首次组合 [take] 取走（取走即清）。
 * 交接件是**一次性**的，不会把这一趟的选择泄漏到下一次进入导入流程。
 *
 * ## 2026-11-05 补第三跳：选校页 → 适配器列表
 *
 * 前两跳（→ 登录页 / → 详情页）当初修好了，**选校页这一跳漏了**：点学校只写进本条目
 * 的 `WarehouseShellState` 就 `onOpenPage("schoolAdapters")`，而壳给新条目一个全新
 * state（school=null）⇒ 新条目又渲染一遍选校页，用户得把同一所学校**点两遍**，
 * 「最近使用」也跟着记两次。现在这一跳同样 `publish(school)`（没有适配器，`adapter` 可空），
 * 壳的 `WarehouseImportBranch` 用 [peek] 只读判断该画哪一页。
 *
 * 只读判据与消耗权**分开**：`peek` 不消耗，`take` 消耗——否则壳一判断就把交接件拿走，
 * 里面的适配器宿主 `take()` 到 null，又回落到诚实空态。
 *
 * ## 为什么放 main 而不是 composeP1
 *
 * 它是纯 Kotlin 数据交接（不含 Compose 类型），放这里才能被 JVM 单测直接构造与断言；
 * composeP1 里的宿主只负责「把 state 里的值传进来 / 把取到的值写回去」。
 * 壳（`ShellPageIndex.kt` / `ShellWiring.kt`）是 Lead 写作用域，本件不改壳。
 */
internal object WarehouseImportHandoff {

    /** 交接载荷：目标页需要的四件东西。 */
    data class Payload(
        val school: WarehouseSchoolEntry,
        /**
         * 选中的适配器。
         *
         * **可空**：选校页 → 适配器列表这一跳还没有适配器（学校刚选中、适配器清单还没拉），
         * 而那一跳同样要跨条目带学校（见下面 2026-11-05 那段）。需要适配器的目标页
         * （登录页 / 详情页）本来就有 `adapter == null` 的诚实空态分支，不受影响。
         */
        val adapter: WarehouseAdapterEntry? = null,
        /** 进登录页是否自动开始录制（「录制导入」恒 true，普通导入按有无已存宏判断）。 */
        val autoRecordMacro: Boolean = false,
        /** 快捷导入带来的待回放宏；普通导入为 null。 */
        val playbackMacro: WarehouseMacroRecord? = null,
    )

    private var pending: Payload? = null

    /** 来源页跳转前调用一次；同样的目标重复发布时以最后一次为准。 */
    fun publish(
        school: WarehouseSchoolEntry,
        adapter: WarehouseAdapterEntry? = null,
        autoRecordMacro: Boolean = false,
        playbackMacro: WarehouseMacroRecord? = null,
    ) {
        pending = Payload(school, adapter, autoRecordMacro, playbackMacro)
    }

    /** 目标页首次组合调用一次，取走即清。 */
    fun take(): Payload? = pending.also { pending = null }

    /**
     * **只读**看一眼（不消耗），给「分流要判断、但消耗权归目标页」的场合用。
     *
     * 唯一调用点是壳的 `WarehouseImportBranch`：它要在**不把交接件拿走**的前提下判断
     * 「这一条目该画选校页还是适配器列表」——拿走了，里面的适配器宿主就 `take()` 不到、
     * 又回落到空态（2026-11-05 用户实报「同一所学校要点两遍」的下一层坑）。
     */
    fun peek(): Payload? = pending

    /** 测试用：避免交接件在用例之间串味。 */
    fun clear() {
        pending = null
    }
}
