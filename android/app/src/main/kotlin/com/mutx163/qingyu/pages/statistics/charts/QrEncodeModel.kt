package com.mutx163.qingyu.pages.statistics.charts

/**
 * 导出长图品牌条右下角的二维码矩阵（`dark[y][x]`，true = 黑块）。
 *
 * 纯数据，不含任何编码逻辑——编码实现在 `platform/ZxingQrEncoder`。
 */
data class QrMatrix(
    val size: Int,
    /** `dark[y][x]`，true = 黑块；第 0 行在最上面（与屏幕坐标一致）。 */
    val dark: Array<BooleanArray>,
) {
    fun isDark(x: Int, y: Int): Boolean = dark[y][x]

    /** 黑块个数（单测断言与覆盖率用）。 */
    val darkCount: Int get() = dark.sumOf { row -> row.count { it } }
}

/**
 * 二维码编码接口（纯 Kotlin，L0 可测；实现见 `platform/ZxingQrEncoder`）。
 *
 * 为什么是接口：`pages/statistics` 在 L0 共享面里，classpath 没有 `com.google.zxing:core`；
 * 把 `QRCodeWriter` 写在本目录，24 个模块的 L0 会一起 `Unresolved reference`。所以按
 * `AboutHttp` / `HolidayHttp` 同一套切法：**接口留域内，实现放 `platform/`，构造只在组合根**。
 */
fun interface QrEncoder {
    fun encode(text: String): QrMatrix
}

/**
 * 品牌条二维码的**对外入口**（调用方只认这里：`QrEncodeModel.encode(text)`）。
 *
 * 2026-11-14 用户拍板：编码从手写换 ZXing，不再自己写 GF(256) / Reed-Solomon / 掩码罚分。
 * 对外契约不变：
 * - 矩阵仍是**版本 2、25×25**、纠错等级 **L**（`qr_flutter` 给这个网址挑的规格）；
 * - 超过 [MAX_BYTES] 字节抛 `IllegalArgumentException`，不悄悄降级成半张图。
 *
 * 组合根（`ShellWiring`）启动时调用一次 [install] 装上 `ZxingQrEncoder`；未安装就调 [encode]
 * 会立刻报错——宁可当场红，也不要静默画一张空白码。
 */
object QrEncodeModel {

    /** 固定版本 2（品牌条按 25×25 排的版）。 */
    const val VERSION = 2

    /** 版本 2 = 17 + 4 × 2 = 25 个模块。 */
    const val SIZE = 17 + 4 * VERSION

    /** 版本 2-L 的字节模式容量：272 位数据减去 4 位模式 + 8 位长度 = 260 位 → 32 字节。 */
    const val MAX_BYTES = 32

    @Volatile
    private var installed: QrEncoder? = null

    /** 组合根安装实现（幂等；重复安装只覆盖引用，不报错）。 */
    fun install(encoder: QrEncoder) {
        installed = encoder
    }

    /** 是否已安装实现（诊断 / 测试用）。 */
    val isInstalled: Boolean get() = installed != null

    /**
     * 编成二维码矩阵。
     *
     * @throws IllegalArgumentException 文本超过 [MAX_BYTES] 字节（UTF-8 计算）
     * @throws IllegalStateException 组合根还没安装实现
     */
    fun encode(text: String): QrMatrix {
        val bytes = text.toByteArray(Charsets.UTF_8)
        require(bytes.size <= MAX_BYTES) {
            "固定版本 2-L 最多 $MAX_BYTES 字节，实际 ${bytes.size} 字节"
        }
        val encoder = installed ?: error(
            "二维码编码器未安装：组合根应先调用 QrEncodeModel.install(ZxingQrEncoder)",
        )
        return encoder.encode(text)
    }
}
