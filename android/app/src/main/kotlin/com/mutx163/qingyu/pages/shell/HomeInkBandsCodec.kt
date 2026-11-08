package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.pages.shell.HomeBackgroundModel.InkBands

/**
 * 壁纸亮度带的持久化编码（2026-11-07 冷启动修复）。
 *
 * ## 为什么需要落盘
 *
 * 亮度带之前只有进程内 `LruCache`：冷启动首帧一定是 null。底栏在「有壁纸但亮度未知」时
 * 按保守白字兜底（`GlassDockNavigationBar` 的第二分支），亮壁纸下就是白底白字。
 * 落盘后，同一张壁纸、同一视口 / 取景的测量结果在下次启动首帧就能读到。
 *
 * ## 格式
 *
 * `top,weekday,body,dock`，某项未知写空串；**解析失败返回 null**（不拿半份数据猜）。
 * 键由 `wallpaperInkBandsCacheKey` 生成（路径 + 解码宽 + 视口 + 取景），编解码不掺键。
 */
object HomeInkBandsCodec {

    fun encode(bands: InkBands): String =
        listOf(bands.top, bands.weekday, bands.body, bands.dock)
            // 非有限 / 越界值一律写成空：坏值不落盘，免得下次启动被当成「已知真值」。
            .joinToString(",") { it.normalizedBandValue()?.toString().orEmpty() }

    fun decode(raw: String?): InkBands? {
        val parts = raw?.split(',') ?: return null
        if (parts.size != 4) return null
        // 带空白的段一律当坏数据：`toDoubleOrNull` 会静默接受前后空格，
        // 留着它会让「写进去什么」与「读出来什么」不可预期。
        if (parts.any { it != it.trim() }) return null
        val values = parts.map { it.toDoubleOrNull() }
        // 非有限值（NaN / Infinity）或越界值：整条作废，不回退到「部分可信」。
        // 否则 NaN 会穿透到 DockInkRule：`NaN < 0.45` 为 false ⇒ 永远近黑字，且磁盘不会自愈。
        if (values.any { value -> value != null && value.normalizedBandValue() == null }) {
            return null
        }
        // 四项全空 = 没有可用数据，按未命中处理，别拿一份全 null 的带子去判墨。
        if (values.all { it == null }) return null
        return InkBands(
            top = values[0],
            weekday = values[1],
            body = values[2],
            dock = values[3],
        )
    }

    /** 亮度带只接受 [0, 1] 的有限值；其余（含 NaN / ±Infinity）当没有。 */
    private fun Double?.normalizedBandValue(): Double? =
        this?.takeIf { it.isFinite() && it >= 0.0 && it <= 1.0 }
}
