package com.mutx163.qingyu.pages.import.warehouse

/**
 * 壳层跨路由「桥」的**纯逻辑**部分（2026-11-10 第二波）。
 *
 * 桥的宿主是 composeP1 里的进程级 object（`ImportShellBridge` / `TransferShellBridge`），
 * 但那里带 Compose 状态、进不了 JVM 单测。本文件只放**语义**，让 L0 能真正测到行为：
 *
 * - [ImportCompletionCounter]：导入方式页只认「本页挂载之后」增长的成功代数。
 *   发布版靠 `Navigator.pop(true)` 的返回值把「子页导成功」交给入口页，天然不会把上一次
 *   外部「打开方式」导入的成功带给下一次进入的入口页；进程级单例没有返回值，所以用代数。
 * - [ShellOutboundSlot]：数据备份页写入的 (传输包字节, 发送范围标题) 由二维码发送页读取。
 *   两个路由共享同一个进程级槽（发布版是 Navigator 的构造参数）。
 *
 * 为什么放在 `pages/import/warehouse`：本仓 L0 只编这个模块目录，放这里才能被 JVM 直测。
 */

/**
 * 「子页导入成功」的代数计数器。
 *
 * 入口页挂载时记下 [snapshot]；子页成功后 [markImported]。入口页只认
 * `snapshot() > 挂载时的值`——于是：
 * - 正常流程：入口页（被一个子页盖住但仍在组合中）看到代数增长 ⇒ 自关；
 * - 外部「打开方式」直接进 ICS/表格导入：没有入口页在等，代数增长只留在计数器里，
 *   下一次进入导入方式页时挂载值就是新值 ⇒ **不会**秒关。
 */
class ImportCompletionCounter {
    private var generation = 0

    fun markImported() {
        generation += 1
    }

    fun snapshot(): Int = generation
}

/** 一次待发送的传输包：字节 + 发送范围标题（Dart 按 scope 取「当前课表 / 全部数据」）。 */
data class ShellOutboundTransfer(val payload: ByteArray, val title: String?)

/**
 * 发送包的进程级槽（后一次 publish 覆盖前一次，与发布版每次 push 带一份新参数同义）。
 */
class ShellOutboundSlot {
    private var value: ShellOutboundTransfer? = null

    fun publish(payload: ByteArray, title: String?) {
        value = ShellOutboundTransfer(payload, title)
    }

    fun current(): ShellOutboundTransfer? = value
}
