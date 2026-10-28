package com.mutx163.qingyu.app.imagecache

/**
 * 尺寸选择（纯逻辑，JVM 可测，禁 android 导入）。
 *
 * 计算 `BitmapFactory.Options.inSampleSize` 的 2 的幂采样值（BitmapFactory 语义）：
 * 取**最大的 2 的幂** `s`，使得解码后宽高 `src/s` **都不小于**目标宽高 `target`。
 * 即「只缩到够用为止，绝不低于目标」，避免糊图。
 *
 * - `src` 或 `target` 非正（含 0 / 负数）→ 返回 1（不采样，交给 BitmapFactory 自行处理）；
 * - 源比目标还小（放大场景）→ 返回 1（BitmapFactory 不做放大采样）；
 * - 源恰好等于目标 → 返回 1。
 *
 * 返回恒 >= 1。
 */
object ImageSizeSelector {

    fun inSampleSize(srcWidth: Int, srcHeight: Int, targetWidth: Int, targetHeight: Int): Int {
        if (srcWidth <= 0 || srcHeight <= 0 || targetWidth <= 0 || targetHeight <= 0) return 1
        var sample = 1
        // 尝试再翻倍：只有「翻倍后解码宽 AND 高仍都 >= 目标」时才接受。
        while (srcWidth / (sample * 2) >= targetWidth && srcHeight / (sample * 2) >= targetHeight) {
            sample *= 2
        }
        return sample
    }
}
