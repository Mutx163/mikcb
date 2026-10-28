package com.mutx163.qingyu.share.camera

/**
 * 时钟抽象，用于在单测中提供 100% 确定性的虚拟时间，
 * 避免在单测中使用 Thread.sleep 造成脆弱性与性能浪费。
 */
interface ScanClock {
    fun currentTimeMillis(): Long
}

/** 生产环境默认时钟：直接取系统当前时间戳。 */
object SystemScanClock : ScanClock {
    override fun currentTimeMillis(): Long = System.currentTimeMillis()
}

/**
 * 相机生命周期与运行状态。
 */
enum class CameraState {
    /** 未初始化：控制器已实例化，未绑定宿主与相机生命周期。 */
    UNINITIALIZED,

    /** 正在启动：请求硬件资源、绑定生命周期、配置预览与分析流。 */
    STARTING,

    /** 正在预览与分析：相机工作正常，图像分析管道畅通。 */
    STREAMING,

    /** 已暂停分析：预览流可能保持（或冻结），但暂停向算法管道投递帧。 */
    PAUSED,

    /** 已停止：相机硬件已关闭，释放资源。 */
    STOPPED,

    /** 出错态：硬件被占用、权限缺失或初始化失败。 */
    ERROR,
}

/**
 * 手电筒/闪光灯状态。
 */
enum class TorchState {
    OFF,
    ON,
    UNAVAILABLE,
}

/**
 * 镜头朝向。
 */
enum class LensFacing {
    BACK,
    FRONT,
}

/**
 * 条码几何顶点（归一化坐标或像素坐标）。
 */
data class BarcodePoint(
    val x: Float,
    val y: Float,
)

/**
 * 条码类型。
 */
enum class BarcodeFormat {
    QR_CODE,
    CODE_128,
    CODE_39,
    EAN_13,
    EAN_8,
    DATA_MATRIX,
    UNKNOWN,
}

/**
 * 条形码/二维码解码结果。
 *
 * 纯逻辑值对象，不依赖特定第三方库（如 MLKit 的 Barcode 或 ZXing 的 Result），
 * 供宿主层适配器（CameraX / MLKit / ZXing）与页面层进行解耦契约交互。
 */
data class BarcodeScanResult(
    val rawValue: String,
    val format: BarcodeFormat = BarcodeFormat.QR_CODE,
    val rawBytes: ByteArray? = null,
    val cornerPoints: List<BarcodePoint> = emptyList(),
    val timestampEpochMs: Long = 0L,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is BarcodeScanResult) return false
        if (rawValue != other.rawValue) return false
        if (format != other.format) return false
        if (rawBytes != null) {
            if (other.rawBytes == null) return false
            if (!rawBytes.contentEquals(other.rawBytes)) return false
        } else if (other.rawBytes != null) return false
        if (cornerPoints != other.cornerPoints) return false
        if (timestampEpochMs != other.timestampEpochMs) return false
        return true
    }

    override fun hashCode(): Int {
        var result = rawValue.hashCode()
        result = 31 * result + format.hashCode()
        result = 31 * result + (rawBytes?.contentHashCode() ?: 0)
        result = 31 * result + cornerPoints.hashCode()
        result = 31 * result + timestampEpochMs.hashCode()
        return result
    }
}

/**
 * 相机控制器契约接口。
 *
 * 宿主层（如 Activity/Fragment 或 Compose AndroidView）实现此契约，
 * 供业务页面、传输流程与状态控制器调用。
 */
interface CameraScanController {
    /** 当前相机运行状态。 */
    val cameraState: CameraState

    /** 当前闪光灯状态。 */
    val torchState: TorchState

    /** 当前镜头朝向。 */
    val lensFacing: LensFacing

    /** 启动预览与分析。 */
    fun startPreview()

    /** 停止预览并释放相机。 */
    fun stopPreview()

    /** 暂停帧分析。 */
    fun pauseAnalysis()

    /** 恢复帧分析。 */
    fun resumeAnalysis()

    /** 开关手电筒；成功返回 true，不可用返回 false。 */
    fun setTorch(enabled: Boolean): Boolean

    /** 设置/监听解码出的条形码。 */
    fun setScanResultListener(listener: ((BarcodeScanResult) -> Unit)?)
}
