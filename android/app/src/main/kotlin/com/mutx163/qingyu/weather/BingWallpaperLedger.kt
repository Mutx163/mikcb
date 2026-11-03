package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.MiniJson

/**
 * Dart `lib/services/bing_wallpaper_store.dart` 的移植（**纯记账**部分）。
 *
 * Dart 的 BingWallpaperStore 是「SharedPreferences + 单例 + 台账记账」的混合体；
 * Kotlin 侧只把纯记账抽成 [BingWallpaperLedger]：键构造、去重置顶、封顶、
 * 溢出清单、JSON 契约（`_DownloadedEntry`）。prefs 读写与文件存在性检查
 * （findExisting 的 `existsSync`）属 IO，留给宿主层接线——这里提供
 * [findExistingPath]（不做存在性检查）供其复用。
 */

/** 台账保留的条数（图库一次展示 8 天 + 最近挑过几张；封顶的唯一理由是磁盘）。 */
const val MAX_DOWNLOADED_ENTRIES = 12

/**
 * 下载台账的 prefs 契约 key（`bing_wallpaper_v1`，JSON 数组）。
 *
 * 2026-11-03 从 `pages.settings.BingWallpaperStore.PREF_LEDGER` 提到共享层：
 * 键是**跨域契约**——课表域删档案回收独占用图时要读同一份台账
 * （`TimetableProfilesController` → `WallpaperEvictionSources.planProfileDeletionReclaim`），
 * 契约 key 放在契约逻辑（本文件）旁边，设置域的 [com.mutx163.qingyu.pages.settings.BingWallpaperStore]
 * 委托到这里的同一个常量，两边永不漂移。
 */
const val LEDGER_PREFS_KEY = "bing_wallpaper_v1"

/** 台账里的一条：`dateKey@档位@尺寸` → 本地路径。 */
data class BingWallpaperLedgerEntry(
    val dateKey: String,
    /** 档位（旧存档的陌生字符串回退 standard：别把已下的图当成没下过）。 */
    val resolution: BingWallpaperResolution,
    /**
     * 实际下载时用的像素尺寸（2026-10-07 起进键）。旧存档没有这个字段 → 回退到
     * **该档默认尺寸**，绝不回退到当前屏幕：那条目是按写死尺寸下的，用屏幕尺寸
     * 去找它必然找不到。
     */
    val targetSize: WallpaperTargetSize,
    val path: String,
    /**
     * 是不是「自动换」写下的。lastAutoAppliedDate 只认自动换来的那一条：
     * 用户手动从图库挑一张也算用上了今天那张，但若把它算进「今天已换过」，
     * 自动换就会误以为已完成而跳过。
     */
    val autoApplied: Boolean,
) {
    val key: String get() = makeKey(dateKey, resolution, targetSize)

    /** JSON 键序与 Dart 一致（`dateKey/resolution/targetWidth/targetHeight/path/autoApplied`）。 */
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "dateKey" to dateKey,
        "resolution" to resolution.storageKey,
        "targetWidth" to targetSize.width.toLong(),
        "targetHeight" to targetSize.height.toLong(),
        "path" to path,
        "autoApplied" to autoApplied,
    )

    companion object {
        fun makeKey(
            dateKey: String,
            resolution: BingWallpaperResolution,
            size: WallpaperTargetSize,
        ): String = "$dateKey@${resolution.storageKey}@${size.width}x${size.height}"

        /** 脏条目逐条丢弃（与 WallpaperHistoryEntry.listFromJson 同一口径）。 */
        fun fromJson(raw: Any?): BingWallpaperLedgerEntry? {
            if (raw !is Map<*, *>) return null
            val dateKey = raw["dateKey"] as? String ?: return null
            val path = raw["path"] as? String ?: return null
            if (dateKey.trim().isEmpty() || path.trim().isEmpty()) return null
            val resolutionKey = raw["resolution"] as? String
            val resolution = BingWallpaperResolution.fromStorageKey(resolutionKey)
            val defaultSize = WallpaperTargetSize(resolution.width, resolution.height)
            val tw = (raw["targetWidth"] as? Number)?.toLong()
            val th = (raw["targetHeight"] as? Number)?.toLong()
            val hasSize = tw != null && th != null && tw > 0 && th > 0
            return BingWallpaperLedgerEntry(
                dateKey = dateKey.trim(),
                resolution = resolution,
                targetSize = if (hasSize) WallpaperTargetSize(tw.toInt(), th.toInt()) else defaultSize,
                path = path.trim(),
                autoApplied = (raw["autoApplied"] as? Boolean) ?: true,
            )
        }
    }
}

/** 一次记账的结果：新台账 + 应当删除的溢出路径（对应 Dart recordApplied 的返回值）。 */
data class BingWallpaperRecordResult(
    val ledger: BingWallpaperLedger,
    val evictedPaths: List<String>,
)

/**
 * 下载台账的纯记账器：**只记账，不碰磁盘**。
 *
 * 与 `pushWallpaperHistory` 同一分工：调用方知道「还有谁在用这张图」
 * （别的课表可能正拿它当壁纸），所以删除必须走白名单（[deletableWallpaperPaths]）。
 */
data class BingWallpaperLedger(
    val entries: List<BingWallpaperLedgerEntry> = emptyList(),
) {
    /** 台账里记着的本地文件路径（最新在前）。 */
    val downloadedPaths: List<String> get() = entries.map { it.path }

    /**
     * 最近一次自动换用掉的那天的 `dateKey`；没换过为 null。
     * 只认 autoApplied 的条目（手动挑的不算「自动换已完成」）。
     */
    val lastAutoAppliedDate: String?
        get() = entries.firstOrNull { it.autoApplied }?.dateKey

    /**
     * 记一次「这张 / 这个档位（/ 这个实际尺寸）已经下到 [path]」。
     *
     * 同键去重后置顶（最新在前），超出 [MAX_DOWNLOADED_ENTRIES] 的溢出路径随结果
     * 返回给调用方去真删（Dart `recordApplied` 返回 `List<String>` 的不可变对应物）。
     */
    fun recordApplied(
        dateKey: String,
        resolution: BingWallpaperResolution,
        path: String,
        autoApplied: Boolean = true,
        targetSize: WallpaperTargetSize? = null,
    ): BingWallpaperRecordResult {
        val size = targetSize ?: WallpaperTargetSize(resolution.width, resolution.height)
        val key = BingWallpaperLedgerEntry.makeKey(dateKey, resolution, size)
        val next = ArrayList<BingWallpaperLedgerEntry>(entries.size + 1)
        next.add(
            BingWallpaperLedgerEntry(
                dateKey = dateKey,
                resolution = resolution,
                targetSize = size,
                path = path,
                autoApplied = autoApplied,
            ),
        )
        for (entry in entries) {
            if (entry.key != key) next.add(entry)
        }
        val kept = next.take(MAX_DOWNLOADED_ENTRIES)
        val evicted = next.drop(MAX_DOWNLOADED_ENTRIES).map { it.path }
        return BingWallpaperRecordResult(ledger = BingWallpaperLedger(entries = kept), evictedPaths = evicted)
    }

    /**
     * 找一张已下过的图（同一张 + 同一档位 + 同一实际尺寸）的记账路径。
     *
     * ⚠️ 与 Dart `findExisting` 的差异：Dart 在这里做 `File.existsSync()` 存在性
     * 检查（文件可能已被历史淘汰删掉）。本函数**不做**存在性检查（IO），只回
     * 记账路径；调用方接上磁盘检查即为完整语义。
     */
    fun findExistingPath(
        dateKey: String,
        resolution: BingWallpaperResolution,
        targetSize: WallpaperTargetSize? = null,
    ): String? {
        val size = targetSize ?: WallpaperTargetSize(resolution.width, resolution.height)
        val key = BingWallpaperLedgerEntry.makeKey(dateKey, resolution, size)
        return entries.firstOrNull { it.key == key }?.path
    }

    companion object {
        /** 从持久化 JSON 载入；脏条目逐条丢弃、整串坏掉当没有台账（绝不抛错）。 */
        fun fromJsonList(raw: Any?): BingWallpaperLedger {
            if (raw !is List<*>) return BingWallpaperLedger()
            return BingWallpaperLedger(entries = raw.mapNotNull { BingWallpaperLedgerEntry.fromJson(it) })
        }

        fun fromJsonText(text: String?): BingWallpaperLedger =
            fromJsonList(MiniJson.tryParse(text))
    }
}
