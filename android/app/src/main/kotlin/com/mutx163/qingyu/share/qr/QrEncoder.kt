package com.mutx163.qingyu.share.qr

/**
 * 纠错等级。数值对齐 `qr` 包的 `QrErrorCorrectLevel`：L=1 / M=0 / Q=3 / H=2。
 *
 * 保留这层映射只为了不改变调用方与旧数据语义；ZXing 侧有自己的枚举，映射在
 * `platform/ZxingTransferQrEncoder` 里做。
 */
enum class QrErrorCorrectionLevel(val wire: Int) {
    L(1),
    M(0),
    Q(3),
    H(2),
}

/**
 * 编好的二维码矩阵。
 *
 * @property size 边长（模块数），版本 V 时为 `17 + 4 * V`
 * @property dark `dark[y][x]`，`true` = 黑块；第 0 行在最上面（与屏幕坐标一致）
 */
class QrMatrix(
    val size: Int,
    val dark: Array<BooleanArray>,
) {
    init {
        require(dark.size == size) { "dark.size=${dark.size} 与 size=$size 不符" }
        dark.forEach { row -> require(row.size == size) { "行宽 ${row.size} 与 size=$size 不符" } }
    }

    fun isDark(x: Int, y: Int): Boolean = dark[y][x]

    /** 黑块个数（单测断言用）。 */
    val darkCount: Int get() = dark.sumOf { row -> row.count { it } }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is QrMatrix) return false
        if (size != other.size) return false
        for (y in 0 until size) if (!dark[y].contentEquals(other.dark[y])) return false
        return true
    }

    override fun hashCode(): Int = 31 * size + dark.fold(0) { acc, row -> 31 * acc + row.contentHashCode() }
}

/**
 * 二维码编码实现接口（纯 Kotlin，L0 可测；实现见 `platform/ZxingTransferQrEncoder`）。
 *
 * 2026-11-14 用户决定：自研编码换 ZXing。`share` 是 L0 共享面（classpath 没有 zxing jar），
 * 所以按 `QrEncodeModel` / `AboutHttp` 同一套切法：**接口留域内，实现放 `platform/`，
 * 安装只在组合根**。
 */
fun interface ShareQrEncoderPort {
    /**
     * @param version `null` = 自动选最小可用版本；1–40 = 显式版本
     * @throws IllegalArgumentException 内容放不进该版本（或版本 40 也放不下）
     */
    fun encode(text: String, ec: QrErrorCorrectionLevel, version: Int?): QrMatrix
}

/**
 * 二维码编码入口（`pages/transfer` 的两处调用方只认这里，换库后一行未改）。
 *
 * 组合根（`ShellWiring.init`）启动时调用一次 [install]；未安装就调 [encode] 会立刻报错——
 * 宁可当场红，也不要静默画一张空白码。
 */
object QrEncoder {

    @Volatile
    private var installed: ShareQrEncoderPort? = null

    /** 组合根安装实现（幂等）。 */
    fun install(port: ShareQrEncoderPort) {
        installed = port
    }

    /** 是否已安装实现（诊断 / 测试用）。 */
    val isInstalled: Boolean get() = installed != null

    /**
     * 把 [text]（UTF-8）编成二维码，自动选最小可用版本。
     *
     * @throws IllegalArgumentException 文本长到版本 40 也放不下
     * @throws IllegalStateException 组合根还没安装实现
     */
    fun encode(text: String, ec: QrErrorCorrectionLevel = QrErrorCorrectionLevel.L): QrMatrix =
        port().encode(text, ec, null)

    /**
     * 用**显式版本**（1–40）编码。
     *
     * @throws IllegalArgumentException 版本越界，或文本放不进该版本
     */
    fun encode(text: String, ec: QrErrorCorrectionLevel, version: Int): QrMatrix {
        require(version in 1..40) { "版本必须在 1..40，收到 $version" }
        return port().encode(text, ec, version)
    }

    private fun port(): ShareQrEncoderPort = installed ?: error(
        "二维码编码器未安装：组合根应先调用 QrEncoder.install(ZxingTransferQrEncoder)",
    )
}
