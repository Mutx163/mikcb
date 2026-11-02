package com.mutx163.qingyu.pages.sync

/**
 * 云端恢复的**撤销点**：一次恢复成功后留下的「恢复前的课表快照」。
 *
 * ## 为什么是进程级单例而不是页面控制器字段
 *
 * `f.cloudSync` 与 `f.backupList` 两条壳分支各自 `remember` 一个
 * [CloudSyncController]（控制器的可观察协议与监听器生命周期都绑在页面组合上，
 * 不能直接共享实例），撤销点原先挂在控制器字段里 ⇒ 在备份列表页恢复、进云同步页
 * 后撤销入口消失（进了「另一个控制器」）。现在撤销点提出来挂在
 * [Companion.shared] 上：两个入口各自 new 控制器，读写的却是同一份状态，
 * 「从备份列表恢复后进云同步页仍能撤销」。
 *
 * 与局域网的 [com.mutx163.qingyu.transfer.lan.LanTransferUndoStore] 同一套思路
 * （进程级、内存态、杀进程才失效），但**互不依赖**：云端撤销点只有单槽
 * （每次恢复成功重设、撤销成功消费），不需要容量队列。
 *
 * ## 线程
 *
 * 恢复/撤销动作跑在 IO 线程（页面 `Dispatchers.IO`），可见性判断在主线程；
 * 读写都走锁，与 LanTransferUndoStore 同一套约定。
 */
class CloudRestoreUndoPoint(
    /** 恢复**前**的本机课表快照（撤销要写回去的那份）。 */
    val beforeBytes: ByteArray,
    /** 撤销点创建时刻（毫秒），注入 clock 便于单测；仅用于诊断，不参与判据。 */
    val createdAtMillis: Long = 0L,
)

/**
 * 撤销点单槽索引：set 覆盖、take 消费、clear 失效。
 *
 * 单槽语义（与控制器原字段一致）：每次**成功**的恢复都重设撤销点——取不到本次
 * 恢复前的快照时必须清空而不是留着旧点，否则「撤销上一次恢复」撤的是更早的状态。
 */
class CloudSyncUndoStore {

    private val lock = Any()
    private var point: CloudRestoreUndoPoint? = null

    /** 记一个撤销点（覆盖旧点）。 */
    fun set(point: CloudRestoreUndoPoint): Unit = synchronized(lock) {
        this.point = point
    }

    /** 读当前撤销点（不消费）；null = 没有可撤销的恢复。 */
    fun peek(): CloudRestoreUndoPoint? = synchronized(lock) { point }

    /** 消费并清空撤销点（撤销成功后调用）。 */
    fun clear(): Unit = synchronized(lock) {
        point = null
    }

    companion object {
        /** 进程级共享：f.cloudSync 与 f.backupList 两个入口共用同一份撤销点。 */
        val shared = CloudSyncUndoStore()
    }
}
