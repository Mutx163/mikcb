package com.mutx163.qingyu.platform

/**
 * 异步结果回投的**唯一契约**（去 Flutter 化阶段 1，2026-11-07）。
 *
 * 形状与 `MethodChannel.Result` 逐项对应（`success` / `error` / `notImplemented`），
 * 但**不带任何 `io.flutter.*` 依赖**：`CalendarSync` / `LocationFix` 这类平台能力因此
 * 可以在「无 Flutter 构型」（`-PwithFlutter=false`）下照常编译。
 *
 * 调用方适配：
 * - Flutter 通道仍在的时候，由 `MainActivity` 里的 `ChannelResultSink` 把
 *   `MethodChannel.Result` 包一层（行为逐字等价：`error` 三个参数原样透传）；
 * - 纯 Kotlin 调用方（如 `composeP1` 的 ICS 导出宿主）直接实现本接口。
 *
 * 语义不变式（与官方的通道结果一致）：**每个实例只回投一次**——重复回投属于调用方
 * 违约，这里不额外拦截（与 `MethodChannel.Result` 相同，保持行为逐字等价）。
 */
interface ResultSink {
    fun success(value: Any?)

    fun error(code: String, message: String?, details: Any?)

    fun notImplemented()
}
