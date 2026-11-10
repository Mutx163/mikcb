package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.DartTime
import kotlin.math.roundToInt

/**
 * 支持作者页的纯结构模型（移植 `lib/screens/support_creator_screen.dart` +
 * `lib/services/support_creator_service.dart` 的数据部分，2026-10-26 快照）。
 *
 * ## 分层
 *
 * 与开源许可页同一套约定：本文件在 main 源集、**零 Compose/Miuix 依赖**
 * （main 对全变体编译，import miuix 会让 Flutter 的 prod 包编不过），
 * 只承载「JSON 解析 / 排序」；文案在 `SupportCreatorStrings.kt`，渲染在 composeP1 源集。
 */

/** 一位支持者（Dart `SupportDonorEntry`）。 */
data class SupportDonorEntry(
    val name: String,
    val amount: String? = null,
    val date: String? = null,
    val message: String? = null,
)

/** 鸣谢名单整体（Dart `SupportDonorData`）。 */
data class SupportDonorData(
    val title: String? = null,
    val subtitle: String? = null,
    val subtitleNote: String? = null,
    val updatedAt: String? = null,
    val donors: List<SupportDonorEntry> = emptyList(),
)

/**
 * Dart `SupportDonorData.fromJson` 的纯逻辑部分（去掉网络 IO）：
 *
 * 1. `donors` 只收 Map 元素（Dart `whereType<Map<String,dynamic>>()`）；
 * 2. 每个条目四个字段各自 `trim`，`name` 缺省空串；
 * 3. **name 为空的条目被丢弃**（Dart :59）；
 * 4. 按 [compareDonorDateDesc] 排序（Dart :62）；
 * 5. title/subtitle/subtitleNote/updatedAt 各自 `trim`（可为 null）。
 *
 * ⚠️ 已知口径差：Dart 用 `List.sort`（非稳定排序），Kotlin 的 `sortedWith` 是稳定排序。
 * 两条记录**排序键完全相等**时，Dart 侧的相对顺序本来就不保证，这里以稳定排序为准。
 * 有日期可比的真实数据不受影响（见测试）。
 */
fun parseSupportDonorData(json: Map<String, Any?>): SupportDonorData {
    val donors = (json["donors"] as? List<*>)
        .orEmpty()
        .filterIsInstance<Map<*, *>>()
        .map { raw ->
            @Suppress("UNCHECKED_CAST")
            val map = raw as Map<String, Any?>
            SupportDonorEntry(
                name = (map["name"] as? String)?.trim() ?: "",
                amount = (map["amount"] as? String)?.trim(),
                date = (map["date"] as? String)?.trim(),
                message = (map["message"] as? String)?.trim(),
            )
        }
        .filter { it.name.isNotEmpty() }
        .sortedWith { a, b -> compareDonorDateDesc(a, b) }

    return SupportDonorData(
        title = (json["title"] as? String)?.trim(),
        subtitle = (json["subtitle"] as? String)?.trim(),
        subtitleNote = (json["subtitleNote"] as? String)?.trim(),
        updatedAt = (json["updatedAt"] as? String)?.trim(),
        donors = donors,
    )
}

/**
 * Dart `_compareDonorDateDesc`：**新的在前**。
 *
 * 分三段（顺序即优先级）：
 * 1. 两个日期都能解析 → 按时刻倒序；
 * 2. 只有一个能解析 → 能解析的在前（`-1`/`1`）；
 * 3. 都不能解析 → 拿**原始字符串**倒序比较；只有一个非空则它在前；都空则相等。
 */
fun compareDonorDateDesc(a: SupportDonorEntry, b: SupportDonorEntry): Int {
    val dateA = parseDonorDate(a.date)
    val dateB = parseDonorDate(b.date)
    if (dateA != null && dateB != null) {
        val cmp = dateB.compareTo(dateA)
        if (cmp != 0) return cmp
    } else if (dateA != null) {
        return -1
    } else if (dateB != null) {
        return 1
    } else {
        val rawA = a.date?.trim() ?: ""
        val rawB = b.date?.trim() ?: ""
        if (rawA.isNotEmpty() && rawB.isNotEmpty()) {
            val cmp = rawB.compareTo(rawA)
            if (cmp != 0) return cmp
        } else if (rawA.isNotEmpty()) {
            return -1
        } else if (rawB.isNotEmpty()) {
            return 1
        }
    }
    return 0
}

/** Dart `DateTime.tryParse`：解析不出返回 null（空白串同 null）。 */
private fun parseDonorDate(raw: String?): java.time.LocalDateTime? {
    if (raw == null) return null
    val trimmed = raw.trim()
    if (trimmed.isEmpty()) return null
    return DartTime.tryParseIso(trimmed)
}

/** 支持方式（Dart `_SupportMethod`）。 */
enum class SupportMethod { WECHAT, ALIPAY }

// ─────────────────────────────────────────────────────────────────────────────
// 鸣谢名单行的观感派生（2026-11-10）
//
// 发布版 `lib/widgets/support_donor_tile.dart:22-31 / :129-145` 给每行画一个
// **首字圆形头像**，颜色按昵称哈希从 12 个精选色相里取；不含 alpha（玻璃卡上半透明
// 水洗会透出壁纸发黑，Dart 侧注释就是这么写的）。这里把「哈希 → HSL → ARGB」抽成
// 纯函数放在 main 层：可 JVM 单测、渲染层只负责画。
// ─────────────────────────────────────────────────────────────────────────────

/** 精选色相（发布版 12 档，分布参照课程色板）。顺序即索引，别改顺序。 */
internal val DonorAvatarHues: List<Double> = listOf(
    4.0, 25.0, 40.0, 95.0, 145.0, 172.0,
    197.0, 217.0, 243.0, 262.0, 292.0, 330.0,
)

/** 一头像的两色（都是**不透明** ARGB，见文件头「不用 alpha」的理由）。 */
data class DonorAvatarColors(val backgroundArgb: Int, val inkArgb: Int)

/**
 * 昵称 → 头像底色/字色（发布版 `_avatarColors`）。
 *
 * 哈希用 JVM 的 [String.hashCode] 而不是复刻 Dart 的实现：发布版只要求「同一个名字
 * 永远同一色、不同名字尽量分散」，具体落在哪个色相没有语义；复刻 Dart 哈希反而要
 * 背一份平台差异。
 */
fun donorAvatarColors(name: String, dark: Boolean): DonorAvatarColors {
    val index = ((name.hashCode() % DonorAvatarHues.size) + DonorAvatarHues.size) % DonorAvatarHues.size
    val hue = DonorAvatarHues[index]
    return DonorAvatarColors(
        backgroundArgb = hslToArgb(
            hue = hue,
            saturation = if (dark) 0.42 else 0.68,
            lightness = if (dark) 0.26 else 0.90,
        ),
        inkArgb = hslToArgb(
            hue = hue,
            saturation = if (dark) 0.60 else 0.55,
            lightness = if (dark) 0.82 else 0.36,
        ),
    )
}

/**
 * 头像里的字：昵称首字（拉丁字母转大写）；昵称为空时回落到 `♥`（发布版同口径）。
 *
 * 有意偏差：先 `trim()` 再取——发布版直接取原始字符串首字符，名单里带前导空格时会画成
 * 空白头像；这里取到真正的第一个字（见页面头 KDoc「有意偏差 2」）。
 */
fun donorAvatarInitial(name: String): String {
    val first = name.trim().firstOrNull() ?: return "♥"
    return first.uppercaseChar().toString()
}

/**
 * 右栏日期：只保留 `yyyy-MM-dd` 那一段（发布版 `support_donor_tile.dart:42-43`）。
 *
 * 名单里的 `date` 常带时分秒（`2026-08-30 14:42:22`），整串塞进右栏会把金额挤走；
 * 截断只影响**显示**，[SupportDonorEntry.date] 原值不动。
 */
fun donorDateLabel(raw: String?): String {
    val trimmed = raw?.trim().orEmpty()
    return if (trimmed.length >= 10) trimmed.substring(0, 10) else trimmed
}

/** HSL（色相 0-360 / 饱和度 0-1 / 亮度 0-1）→ 不透明 ARGB。 */
private fun hslToArgb(hue: Double, saturation: Double, lightness: Double): Int {
    val chroma = (1.0 - kotlin.math.abs(2.0 * lightness - 1.0)) * saturation
    val hp = (((hue % 360.0) + 360.0) % 360.0) / 60.0
    val second = chroma * (1.0 - kotlin.math.abs(hp % 2.0 - 1.0))
    val (r1, g1, b1) = when (hp.toInt().coerceIn(0, 5)) {
        0 -> Triple(chroma, second, 0.0)
        1 -> Triple(second, chroma, 0.0)
        2 -> Triple(0.0, chroma, second)
        3 -> Triple(0.0, second, chroma)
        4 -> Triple(second, 0.0, chroma)
        else -> Triple(chroma, 0.0, second)
    }
    val match = lightness - chroma / 2.0
    fun channel(value: Double): Int =
        ((value + match) * 255.0).roundToInt().coerceIn(0, 255)
    return (0xFF shl 24) or (channel(r1) shl 16) or (channel(g1) shl 8) or channel(b1)
}

