package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.share.camera.BarcodeScanResult
import com.mutx163.qingyu.share.camera.DedupDecision
import com.mutx163.qingyu.share.camera.PermissionAction
import com.mutx163.qingyu.share.camera.PermissionState
import com.mutx163.qingyu.share.camera.ScanPipeline

/**
 * 二维码扫码会话协调器（Phase 3.5 · P35-B6）。
 *
 * ## 它解决的是「异步解码」与「同步管线」之间的缝
 *
 * B5 交付的 [ScanPipeline.onFrame] 要求一个**同步**的 `decoder`：进去一帧、立刻给出结果。
 * 真实解码器（MLKit barcode-scanning）是异步 `Task` —— 一帧交出去，
 * 回调要过几十毫秒才回来。硬把等待塞进 `onFrame` 会占住相机分析线程，
 * 正好是 B5 的「忙碌丢帧」要防的那件事。
 *
 * 所以这里把同一份 [ScanPipeline] 拆成两段调用：
 *
 * 1. [beginFrame] —— 帧一到就问「权限有吗、这一帧值不值得解」，false 就直接 `close()`
 *    丢给相机，**解码器根本不会被叫到**（省电就省在这里）；
 * 2. [deliverDecoded] —— 解码回调回来再问「这个码该不该交给业务」，去重与跨码防抖都在这一步。
 *
 * 两段共用同一个 `pipeline` 实例，因此节流状态、去重状态、权限状态是同一份，
 * 不存在「两套状态机各说各的」。
 *
 * ## 为什么这个类不带一行 `android.*`
 *
 * 相机、MLKit、Compose 全在宿主适配器（`QrCameraHost.kt`）里；这一层只做决策，
 * 用虚拟时钟就能在 JVM 单测里把「连扫 30 帧同一个码」压缩成几微秒，不碰真机、不睡觉。
 */
class QrScanSessionCoordinator(
    val pipeline: ScanPipeline = ScanPipeline(),
) {

    /** 已经交给业务层的条码次数（被去重/防抖挡下的不计）。 */
    var deliveredCount: Int = 0
        private set

    // ── 权限：全部透传给 B5 的状态机，适配器不许自己造一套 ──

    /** 当前权限状态。 */
    val permissionState: PermissionState
        get() = pipeline.permissionMachine.state

    /** 是否已获授权（决定预览能不能起）。 */
    val isPermissionGranted: Boolean
        get() = pipeline.permissionMachine.isGranted

    /** 权限被拒时该说给用户的那句话（B5 状态机自带，避免各处另写文案）。 */
    val rationaleMessage: String
        get() = pipeline.permissionMachine.rationaleMessage

    /**
     * 进页面 / 用户点「重新授权」时调用：问状态机下一步该做什么，
     * 适配器照着 [PermissionAction] 执行（弹系统框 / 显示理由 / 跳设置）。
     */
    fun onPermissionRequested(): PermissionAction = pipeline.permissionMachine.onRequestPermission()

    /** 系统权限弹窗的结果回传。 */
    fun onPermissionResult(granted: Boolean, shouldShowRationale: Boolean): PermissionState =
        pipeline.permissionMachine.onPermissionResult(granted, shouldShowRationale)

    /** 宿主回到前台（例如用户从系统设置里改完权限回来）时探测真实权限。 */
    fun onHostResumed(hasSystemPermission: Boolean): PermissionState =
        pipeline.permissionMachine.onAppResume(hasSystemPermission)

    // ── 帧闸门 ──

    /**
     * 帧到达：权限 + 节流两道闸。
     *
     * @return true = 值得送去解码，**调用方处理完必须回调 [endFrame]**（否则忙碌标记卡住，
     *         后续帧会被当成「上一帧还没解完」全部丢掉）。
     */
    fun beginFrame(timestampMs: Long = pipeline.clock.currentTimeMillis()): Boolean {
        if (!pipeline.permissionMachine.isGranted) {
            return false
        }
        return pipeline.throttler.beginFrame(timestampMs)
    }

    /** 一帧处理结束：无论解码成功、失败、还是图像为空，都必须调。 */
    fun endFrame(timestampMs: Long = pipeline.clock.currentTimeMillis()) {
        pipeline.throttler.endFrame(timestampMs)
    }

    // ── 结果闸门 ──

    /**
     * 解码结果该不该交给业务层。
     *
     * 过三关：空结果、空白内容、去重（同一码冷却窗口内重复命中 / 跨码全局防抖）。
     *
     * @return 放行时原样返回该结果（方便调用方链式 `?.let(onBarcode)`），否则 null。
     */
    fun deliverDecoded(result: BarcodeScanResult?): BarcodeScanResult? {
        if (result == null) return null
        if (result.rawValue.isBlank()) return null
        if (pipeline.deduplicator.evaluate(result) != DedupDecision.ACCEPT) return null
        deliveredCount++
        return result
    }

    /** 重新扫码 / 离开页面时清空节流与去重状态（默认保留权限结论）。 */
    fun reset(preservePermission: Boolean = true) {
        pipeline.reset(preservePermission)
        deliveredCount = 0
    }
}
