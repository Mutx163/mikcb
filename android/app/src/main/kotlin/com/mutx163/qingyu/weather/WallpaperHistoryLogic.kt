package com.mutx163.qingyu.weather

/**
 * Dart `lib/models/wallpaper_history.dart` + `lib/utils/wallpaper_history.dart`
 * 的移植（**纯列表运算**部分）。
 *
 * 不移植（IO 清单，见交付说明）：
 * - `wallpaperHistoryEntryAvailable` / `availableWallpaperHistory`（文件存在性摸盘）；
 * - `settingsWithWallpaperHistoryEntry`（依赖 TimetableSettings + 摸盘）；
 * - `deleteEvictedWallpaperFiles`（真删文件 + 缓存失效）。
 */

/** 「最近使用」保留的壁纸条数上限。 */
const val MAX_WALLPAPER_HISTORY_ENTRIES = 10

/** 已下线的「内置壁纸」预设在历史里的键前缀（`builtin:<预设>`）：无文件、不可用。 */
const val LEGACY_BUILTIN_WALLPAPER_KEY_PREFIX = "builtin:"

/** 条目是否来自已下线的内置壁纸（无文件、不可用）。 */
fun isLegacyBuiltInWallpaperEntry(entry: WallpaperHistoryEntry): Boolean =
    entry.key.startsWith(LEGACY_BUILTIN_WALLPAPER_KEY_PREFIX)

/** 一次历史写入的结果。 */
data class WallpaperHistoryPushResult(
    /** 去重置顶并按上限裁剪后的新历史（最新在前）。 */
    val history: List<WallpaperHistoryEntry>,
    /** 被挤出上限、需要顺手删除文件的图片路径；遗留的内置壁纸条目无文件，不入表。 */
    val evictedPaths: List<String>,
)

/** 首页壁纸「最近使用」历史条目（JSON 契约与 Dart 逐字一致）。 */
data class WallpaperHistoryEntry(
    /** 背景身份键：背景图片的文件绝对路径。 */
    val key: String,
    /** 使用该壁纸时的水平对齐（-1..1）。 */
    val alignX: Double = 0.0,
    /** 使用该壁纸时的垂直对齐（-1..1）。 */
    val alignY: Double = 0.0,
    /** 使用该壁纸时的放大倍数（1 = 刚好铺满）。 */
    val scale: Double = 1.0,
    /** 最近一次使用时间（epoch 毫秒）；旧数据缺失回退 0。 */
    val usedAt: Long = 0L,
) {
    /** 空 key 是无意义条目，直接视为脏数据。 */
    val isValid: Boolean get() = key.trim().isNotEmpty()

    /** JSON 键序与 Dart 一致。 */
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "key" to key,
        "alignX" to alignX,
        "alignY" to alignY,
        "scale" to scale,
        "usedAt" to usedAt,
    )

    companion object {
        /**
         * 非法输入返回 null 而不是抛错：设置 JSON 可能来自旧版本或手改备份。
         *
         * ⚠️ 必须用类型判断（`as?`），坏类型一律回退默认值——单个坏值绝不能
         * 放大成整份设置丢失（Dart 侧 `as num?` 会抛 TypeError 的教训）。
         */
        fun fromJson(raw: Any?): WallpaperHistoryEntry? {
            if (raw !is Map<*, *>) return null
            val key = raw["key"] as? String ?: return null
            val entry = WallpaperHistoryEntry(
                key = key,
                alignX = numOrNullOrDouble(raw["alignX"]) ?: 0.0,
                alignY = numOrNullOrDouble(raw["alignY"]) ?: 0.0,
                // 存量存档没有 scale：缺省 1（刚好铺满）。
                scale = numOrNullOrDouble(raw["scale"]) ?: 1.0,
                usedAt = numOrNullOrLong(raw["usedAt"]) ?: 0L,
            )
            return if (entry.isValid) entry else null
        }

        /** 只放行 num；其余类型（含字符串数字）一律视为缺失。 */
        private fun numOrNull(value: Any?): Number? = value as? Number

        private fun numOrNullOrDouble(value: Any?): Double? = numOrNull(value)?.toDouble()

        private fun numOrNullOrLong(value: Any?): Long? = numOrNull(value)?.toLong()

        fun listFromJson(raw: Any?): List<WallpaperHistoryEntry> {
            if (raw !is List<*>) return emptyList()
            return raw.mapNotNull { fromJson(it) }
        }
    }
}

/**
 * 记录一次壁纸使用：同一 key 去重后置顶，超出上限的旧条目挤出。
 *
 * 返回新历史与需删除的淘汰文件路径，函数本身不碰磁盘——这样它可以在任何
 * 回调里同步调用，也便于单测（与 Dart 同一分工：调用方知道「还有谁在用」）。
 */
fun pushWallpaperHistory(
    history: List<WallpaperHistoryEntry>,
    key: String,
    alignX: Double = 0.0,
    alignY: Double = 0.0,
    scale: Double = 1.0,
    usedAt: Long? = null,
): WallpaperHistoryPushResult {
    val trimmedKey = key.trim()
    if (trimmedKey.isEmpty()) {
        return WallpaperHistoryPushResult(history = history.toList(), evictedPaths = emptyList())
    }
    val next = ArrayList<WallpaperHistoryEntry>(history.size + 1)
    next.add(
        WallpaperHistoryEntry(
            key = trimmedKey,
            alignX = alignX,
            alignY = alignY,
            scale = scale,
            usedAt = usedAt ?: System.currentTimeMillis(),
        ),
    )
    for (entry in history) {
        if (entry.isValid && entry.key != trimmedKey) next.add(entry)
    }
    val kept = next.take(MAX_WALLPAPER_HISTORY_ENTRIES)
    val evictedPaths = next.drop(MAX_WALLPAPER_HISTORY_ENTRIES)
        .filter { !isLegacyBuiltInWallpaperEntry(it) }
        .map { it.key }
    return WallpaperHistoryPushResult(history = kept, evictedPaths = evictedPaths)
}

/**
 * 从「最近使用」里移除一条，返回新历史（其余条目保持原有先后顺序）。
 *
 * 键为空、或历史里本来就没有这一条时**原样返回同一实例**（幂等）。只动列表，
 * 不碰磁盘；键只做首尾空白裁剪，不做路径归一化（分隔符/大小写不同的同名路径
 * 不是同一张图——误删一条别人的历史，比多留一条严重得多）。
 */
fun removeWallpaperHistoryEntry(
    history: List<WallpaperHistoryEntry>,
    key: String,
): List<WallpaperHistoryEntry> {
    val trimmedKey = key.trim()
    if (trimmedKey.isEmpty()) return history
    if (history.none { it.key == trimmedKey }) return history
    return history.filter { it.key != trimmedKey }
}

/**
 * 批量记录：把 [entries] 按「旧 → 新」顺序依次 [pushWallpaperHistory]，
 * 返回最终历史与累计的待删文件路径。
 *
 * 淘汰清单必须按**最终历史**再过滤一遍：同一批里后一条可能把前一条挤出的那张图
 * 重新加回队首（历史已满时点「最近使用」里最旧的一条），照单删除就会删掉
 * 正在使用的壁纸文件。
 */
fun rememberWallpaperHistoryBatch(
    history: List<WallpaperHistoryEntry>,
    entries: List<WallpaperHistoryEntry>,
): WallpaperHistoryPushResult {
    var current = history
    val evicted = ArrayList<String>()
    for (entry in entries) {
        if (!entry.isValid) continue
        val result = pushWallpaperHistory(
            history = current,
            key = entry.key,
            alignX = entry.alignX,
            alignY = entry.alignY,
            // 缩放也是「当时那个取景」的一部分：漏传会让条目落库永远是 1。
            scale = entry.scale,
            usedAt = if (entry.usedAt == 0L) null else entry.usedAt,
        )
        current = result.history
        evicted.addAll(result.evictedPaths)
    }
    val keptKeys = current.map { it.key }.toSet()
    return WallpaperHistoryPushResult(
        history = current,
        evictedPaths = evicted.filter { !keptKeys.contains(it) },
    )
}

/**
 * 把多份历史并成一份：按 key 去重、同 key 取「更新」的那条，最新在前，按上限截断。
 *
 * [histories] 必须按「由旧到新」给：两条都缺 usedAt（老数据回退 0）时，取后看到的
 * 那条，顺序才符合直觉。
 */
fun mergeWallpaperHistories(
    histories: List<List<WallpaperHistoryEntry>>,
): List<WallpaperHistoryEntry> {
    val merged = LinkedHashMap<String, WallpaperHistoryEntry>()
    val seenOrder = HashMap<String, Int>()
    var sequence = 0
    for (history in histories) {
        for (entry in history) {
            sequence++
            if (!entry.isValid) continue
            val current = merged[entry.key]
            if (current == null) {
                merged[entry.key] = entry
                seenOrder[entry.key] = sequence
                continue
            }
            val newer = if (entry.usedAt != current.usedAt) {
                entry.usedAt > current.usedAt
            } else {
                sequence > (seenOrder[entry.key] ?: 0)
            }
            if (newer) {
                merged[entry.key] = entry
                seenOrder[entry.key] = sequence
            }
        }
    }
    val ordered = merged.values.sortedWith(
        compareByDescending<WallpaperHistoryEntry> { it.usedAt }
            .thenByDescending { seenOrder[it.key] ?: 0 },
    )
    return ordered.take(MAX_WALLPAPER_HISTORY_ENTRIES)
}

/**
 * 从「待删清单」里筛掉不该删的路径，返回真正可以删的那些。
 *
 * 三条豁免：空串、遗留的内置壁纸键（不是文件路径）、以及 [inUsePaths]
 * （还有人在用的图——全局历史下别的课表可能正拿它当壁纸）。纯函数，便于单测。
 */
fun deletableWallpaperPaths(
    paths: List<String>,
    inUsePaths: Set<String> = emptySet(),
): List<String> = paths.filter { path ->
    path.isNotEmpty() &&
        !path.startsWith(LEGACY_BUILTIN_WALLPAPER_KEY_PREFIX) &&
        !inUsePaths.contains(path)
}
