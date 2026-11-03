package com.mutx163.qingyu.core

/**
 * 埋点出口抽象（2026-11-03 建立；此前 `TimetableRepository.logEvent` 是空实现，
 * 注释写「Phase 4 才接分析服务」）。
 *
 * ## 为什么不复用已有设施
 *
 * - `infra/AppAnalytics` 是 Dart 侧无操作桩的移植（契约就是「调了无事发生」），没有注入点；
 * - `platform/` 下的适配器全部依赖 Android `Context`，进不了纯 JVM 的 core 层；
 * - `UmengDiagnosticReporter` 是带隐私同意门 + 限流的本机诊断上报（Android 侧），
 *   属于「以后接真后端」的候选桥，不是默认管道。
 *
 * 所以这里是新的最小抽象：一个函数。可替换（构造参数注入），
 * 默认接 [EventSinks.shared]（本地内存环形缓冲，不联网、不落盘、无用户标识）。
 *
 * ## 职责边界
 *
 * Sink **不做**脱敏——隐私闸门（[EventPrivacy.sanitize]）在
 * `TimetableRepository.logEvent` 入口统一过，保证任何 sink 实现（含以后接的
 * 真分析后端）拿到的都已经是干净参数。
 */
fun interface EventSink {
    /** 记一条事件。[name] 应来自 [AnalyticsEvents] 常量表；参数应是已脱敏的。 */
    fun log(name: String, parameters: Map<String, Any>)
}

/** 一条已缓冲的事件（只读视图）。 */
data class EventRecord(
    val name: String,
    val parameters: Map<String, Any>,
    val atMillis: Long,
)

/**
 * 默认 sink：**内存环形缓冲**，容量 [capacity]，满了丢最旧——可观测但绝不无限增长。
 *
 * - 不落盘、不联网、不打用户标识；进程死即失（这正是「最小可用」的口径）；
 * - [onEmit] 是可选的纯 JVM 回调（每次事件入缓冲后触发），生产壳要转发到
 *   `android.util.Log` 时在这里传 `{ name, params -> Log.d(TAG, name) }`——
 *   本类保持零 Android 依赖，L0 可直接单测；
 * - 全程 `synchronized`：服务层可能在 LAN 编辑 worker 线程调 `logEvent`。
 */
class RingEventSink(
    private val capacity: Int = DEFAULT_CAPACITY,
    private val onEmit: ((name: String, parameters: Map<String, Any>) -> Unit)? = null,
) : EventSink {

    init {
        require(capacity > 0) { "capacity 必须为正，实际 $capacity" }
    }

    private val buffer = ArrayDeque<EventRecord>(capacity)

    @Synchronized
    override fun log(name: String, parameters: Map<String, Any>) {
        if (buffer.size >= capacity) buffer.removeFirst()
        buffer.addLast(EventRecord(name, parameters, System.currentTimeMillis()))
        onEmit?.invoke(name, parameters)
    }

    /** 缓冲快照（旧→新）。返回副本，调用方随便改。 */
    @Synchronized
    fun snapshot(): List<EventRecord> = buffer.toList()

    val size: Int @Synchronized get() = buffer.size

    /** 测试用：清空缓冲。 */
    @Synchronized
    fun clear() = buffer.clear()

    companion object {
        /** 环形上限：排障够用，又不至于在内存里攒出可观的用户行为档案。 */
        const val DEFAULT_CAPACITY = 128
    }
}

/**
 * 进程级共享 sink：所有 `TimetableRepository` 实例（主壳 / 测试替身之外的真实构造点）
 * 默认都汇到这里的一个缓冲里，便于以后统一取出或桥接后端。
 */
object EventSinks {

    val shared: RingEventSink = RingEventSink()

    /** 测试用：清空共享缓冲，免得上一条用例的事件漏到下一条。 */
    @Synchronized
    fun resetForTesting() = shared.clear()
}
