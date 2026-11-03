package com.mutx163.qingyu.weather

import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.MiniJson

/**
 * 删壁纸文件前，「其它档案正在用的图」从哪来（纯函数）。
 *
 * ## 为什么内存快照不够
 *
 * 仓储快照里的 [com.mutx163.qingyu.core.TimetableProfile.settings] 是
 * [com.mutx163.qingyu.core.TimetableSettings]——只解析时间/周次四个键
 * （`core/TimetableSettings.kt:22-27`），**拿不到壁纸路径**。上一批因此只能护住
 * 当前课表。
 *
 * 但盘上不是这个形状：每份档案内嵌的 `settings` 是**整份设置对象**。
 * `TimetableStore.saveProfiles` 的注释写得很清楚（`app/TimetableStore.kt:111-115`：
 * 「盘上每份档案的 `settings` 是完整的 250+ 键对象」），而
 * `TimetableSettingsModelStore.save` 每次落盘都会把壁纸键合并写进 **active 档案**。
 * Dart 侧同样把整份 settings 写回档案（`lib/providers/timetable_provider.dart:1499-1511`）。
 *
 * 所以覆盖所有档案的唯一完整来源是 **`timetable_profiles` 的原始 JSON**，
 * 不是仓储快照。IO（读 prefs）留在宿主，本层保持纯函数、可直接单测。
 *
 * ## 白名单口径（与 Dart 一致）
 *
 * 每份档案取 `resolveHomePageBackdropImagePath` 的有效路径：壁纸优先，旧版背景图
 * 字段只在壁纸缺失/为空时兜底（`lib/utils/home_page_background.dart:346-356`，
 * Dart 的 `inUseWallpaperPaths` 也是这么收的，`lib/utils/wallpaper_history.dart:250-252`）。
 * 空串与已下线的 `builtin:` 键不是文件，一律不进白名单。
 *
 * ## 保守策略
 *
 * 档案 JSON 读不懂（不是数组、或某份档案的 `settings` 不是对象）时，
 * [ProfileBackdropScan.readable] 为 false，[planEviction] **一张都不删**。
 * 「读不到」不能当成「没人用」——宁可留一张垃圾图，也不能删掉别的课表正在用的壁纸。
 *
 * ## 为什么住在共享 weather/（2026-11-03 自 `pages/settings` 下沉）
 *
 * 它的两个调用方分属两域：设置域（Bing 图库应用壁纸时的淘汰，`BingGalleryApply`）
 * 与课表域（删课表档案后的独占用图回收，`TimetableProfilesController`）。留在设置域
 * 会让课表域反向 import 设置域，`pages/timetable` 的 L0 编不过。`pages/settings`
 * 留了同名 typealias，设置域与 composeP1 宿主的一行都不用改。
 */
object WallpaperEvictionSources {

    /** 契约 key：课表全量档案数组（与 [TimetableStore.KEY_PROFILES] 同源，不另起字面量）。 */
    const val PROFILES_KEY: String = TimetableStore.KEY_PROFILES

    /**
     * 一次档案扫描的结果。
     *
     * [readable] = false 表示盘上这份 JSON 无法完整确认所有档案的壁纸；
     * 此时任何删除都必须放弃（见 [planEviction]）。
     */
    data class ProfileBackdropScan(
        val backdropPaths: List<String>,
        val readable: Boolean,
    )

    /**
     * 每份档案 id → 有效背景图路径（[scanProfileBackdrops] 的按 id 版本）。
     *
     * [readable] = false 表示有条目读不懂（`settings` 不是对象），此时不能据此
     * 判定「谁在用 / 谁没人用」。回收独占用图必须按 id 取「被删那份」的图，
     * 所以单独保留这一份映射；两条入口共用同一个解析核心，不另写一套。
     */
    data class ProfileBackdropIndex(
        val byId: Map<String, String>,
        val readable: Boolean,
    )

    /** 一次「删档案后回收独占用图」的判定结果。 */
    data class ProfileReclaimPlan(
        /** 被删档案实际引用过的图（通常 0 或 1 张）。 */
        val candidatePaths: List<String>,
        /** 确认不再被任何来源引用、可以删的图。 */
        val deletablePaths: List<String>,
        /**
         * false = 有引用来源读不到 / 读不懂（档案 JSON、设置、图库台账任一）。
         * 此时 [deletablePaths] 必为空：宁可留一张垃圾图，也不能删别人的在用图。
         */
        val referencesKnown: Boolean,
    ) {
        companion object {
            /** 引用来源读不懂时的唯一形状：候选照记（给日志用），可删清单一律为空。 */
            fun unknown(candidates: List<String> = emptyList()): ProfileReclaimPlan =
                ProfileReclaimPlan(candidates, emptyList(), referencesKnown = false)
        }
    }

    /**
     * 从盘上原始 JSON 文本扫描。
     *
     * null / 空串 = 还没有档案（可确认的空集，`readable = true`）；
     * 解析失败 = 读不懂（`readable = false`）。
     */
    fun scanProfileBackdrops(profilesJson: String?): ProfileBackdropScan {
        val index = scanProfileBackdropIndex(profilesJson)
        return ProfileBackdropScan(
            backdropPaths = index.byId.values.toList().distinct(),
            readable = index.readable,
        )
    }

    /**
     * 按档案 id 取有效背景图（回收独占用图用）。
     *
     * 与 [scanProfileBackdrops] 同一条解析规则：壁纸优先、旧版背景图字段兜底，
     * 空串与 `builtin:` 键不算引用；`settings` 存在却不是对象 ⇒ `readable = false`。
     */
    fun scanProfileBackdropIndex(profilesJson: String?): ProfileBackdropIndex {
        if (profilesJson.isNullOrEmpty()) {
            return ProfileBackdropIndex(emptyMap(), readable = true)
        }
        val decoded = MiniJson.tryParse(profilesJson)
            ?: return ProfileBackdropIndex(emptyMap(), readable = false)
        if (decoded !is List<*>) {
            return ProfileBackdropIndex(emptyMap(), readable = false)
        }
        val byId = LinkedHashMap<String, String>()
        var readable = true
        for (profile in decoded) {
            // 非对象条目不是档案，也不可能带 settings；仓储的宽松解析同样丢弃它们。
            if (profile !is Map<*, *>) continue
            val settings = profile["settings"] ?: continue
            // 没有 `settings` 的条目按模型口径等价于默认设置（`TimetableProfile.fromJson`
            // 也是取值失败回落 defaults），即从未写过壁纸，不构成在用图。
            if (settings !is Map<*, *>) {
                // 有条目的 settings 存在却读不懂 ⇒ 无法确认这份档案的壁纸。
                readable = false
                continue
            }
            val path = effectiveBackdropPath(settings) ?: continue
            // 没有 id 的档案无法和「被删的那份」对应；它不构成可读性失败，只是进不了映射。
            val id = (profile["id"] as? String)?.takeIf { it.isNotBlank() } ?: continue
            byId[id] = path
        }
        return ProfileBackdropIndex(byId, readable)
    }

    /**
     * 一次「待删清单」的判定结果。
     *
     * [profilesUnreadable] 为 true 时 [deletable] 必为空——这是给宿主的显式信号，
     * 用来记一条「为什么没删」的日志，而不是静默跳过。
     */
    data class EvictionPlan(
        val deletable: List<String>,
        val profilesUnreadable: Boolean,
    )

    /**
     * 判一次待删清单：返回真正可以删的路径。
     *
     * 白名单四路并集 = 所有档案的有效背景图 + 当前（草稿）路径 + 图库台账。
     * 档案 JSON 读不懂时**一张都不删**（[EvictionPlan.profilesUnreadable] = true）。
     *
     * @param currentPath 内存里当前生效的壁纸；可能比盘上新（本页草稿尚未落盘）。
     * @param draftPath 草稿里刚选中的那张（与 `currentPath` 同值时也不重复计入）。
     */
    fun planEviction(
        evictedPaths: List<String>,
        profilesJson: String?,
        currentPath: String?,
        draftPath: String?,
        galleryLedgerPaths: Iterable<String> = emptyList(),
    ): EvictionPlan {
        val scan = scanProfileBackdrops(profilesJson)
        if (!scan.readable) {
            return EvictionPlan(deletable = emptyList(), profilesUnreadable = true)
        }
        val whitelist = WallpaperEvictionRules.evictionWhitelist(
            allProfilesCurrentPaths = scan.backdropPaths + listOfNotNull(currentPath),
            // 走到这里 scan 一定可读；空列表是「所有档案都没设壁纸」的合法结果，
            // 不能因此把淘汰文件判成「引用未知」而永不回收（P2-18）。
            profilesReadable = scan.readable,
            draftPath = draftPath,
            galleryLedgerPaths = galleryLedgerPaths,
        )
        return EvictionPlan(
            deletable = WallpaperEvictionRules.deletable(evictedPaths, whitelist),
            profilesUnreadable = false,
        )
    }

    /**
     * 判一次「删档案后回收独占用图」（**只在删除档案那条流程里**调用）。
     *
     * 取被删档案实际引用过的那张图；它若不再被以下任一来源引用，就可以删：
     *
     * 1. 删除后盘上的**其余档案**（壁纸字段 + 旧版 `homePageBackgroundImagePath` 兜底）；
     * 2. 当前设置里的背景图（`timetable_settings` 原始 JSON，壁纸优先、旧字段兜底）；
     * 3. 本流程的草稿（档案管理页没有草稿，参数留给同一模型的其它调用方）；
     * 4. 图库下载台账（`bing_wallpaper_v1` 原始 JSON 数组）。
     *
     * ## fail-safe
     *
     * 任一来源读不到 / 读不懂（档案 JSON 不是数组、某份 settings 不是对象、
     * 设置 JSON 不是对象、台账不是数组或有一条解析不出）⇒
     * [ProfileReclaimPlan.referencesKnown] = false 且**一张都不删**。
     * 「读不懂」绝不能当成「没人用」：那会把别的课表正在用的壁纸删掉、切过去首页裂图。
     *
     * ## 不做的事
     *
     * 这里只判**该怎么删**，不碰磁盘；真删与失败日志由调用方负责。也不做开机 /
     * 定时扫描——候选只来自「刚被删掉的那份档案」。
     */
    fun planProfileDeletionReclaim(
        deletedProfileId: String,
        profilesJsonBefore: String?,
        profilesJsonAfter: String?,
        settingsJson: String?,
        ledgerJson: String?,
        draftPath: String? = null,
    ): ProfileReclaimPlan {
        val before = scanProfileBackdropIndex(profilesJsonBefore)
        if (!before.readable) return ProfileReclaimPlan.unknown()
        val candidates = listOfNotNull(before.byId[deletedProfileId])
            .filter { it.isNotBlank() }
            .distinct()
        // 被删的那份本来就没壁纸：没有可回收的候选，这是一次可确认的空集。
        if (candidates.isEmpty()) {
            return ProfileReclaimPlan(candidates, emptyList(), referencesKnown = true)
        }

        val after = scanProfileBackdropIndex(profilesJsonAfter)
        if (!after.readable) return ProfileReclaimPlan.unknown(candidates)
        val current = currentBackdropPaths(settingsJson)
            ?: return ProfileReclaimPlan.unknown(candidates)
        val ledger = ledgerPaths(ledgerJson)
            ?: return ProfileReclaimPlan.unknown(candidates)

        val references = HashSet<String>(after.byId.values)
        references.addAll(current)
        references.addAll(ledger)
        draftPath?.takeIf { it.isNotBlank() }?.let { references.add(it) }

        return ProfileReclaimPlan(
            candidatePaths = candidates,
            deletablePaths = deletableWallpaperPaths(candidates, inUsePaths = references),
            referencesKnown = true,
        )
    }

    /**
     * `timetable_settings` 原始 JSON 里的当前背景图（壁纸优先、旧字段兜底）。
     *
     * null = JSON 读不懂；空集 = 确实没设背景图。
     */
    private fun currentBackdropPaths(settingsJson: String?): Set<String>? {
        if (settingsJson.isNullOrEmpty()) return emptySet()
        val decoded = MiniJson.tryParse(settingsJson) ?: return null
        if (decoded !is Map<*, *>) return null
        val path = effectiveBackdropPath(decoded) ?: return emptySet()
        return setOf(path)
    }

    /**
     * 图库台账里记着的本地路径。
     *
     * null = 读不懂（不是数组、或任意一条解析不出）；空集 = 真没有台账。
     * 解析必须**逐条严格**：宽松丢弃一条就等于「那张图没人引用」，
     * 而它可能正是用户刚下好、还没应用的那张。
     */
    private fun ledgerPaths(ledgerJson: String?): Set<String>? {
        if (ledgerJson.isNullOrEmpty()) return emptySet()
        val decoded = MiniJson.tryParse(ledgerJson) ?: return null
        if (decoded !is List<*>) return null
        val paths = LinkedHashSet<String>()
        for (raw in decoded) {
            val entry = BingWallpaperLedgerEntry.fromJson(raw) ?: return null
            paths.add(entry.path)
        }
        return paths
    }

    /**
     * 一份档案内嵌 settings 的「当前有效背景图」。
     *
     * 壁纸优先；壁纸缺失、空串或已下线的 `builtin:` 键时回退旧版背景图字段。
     * 返回 null 表示这份档案没有可用的背景图文件。
     */
    private fun effectiveBackdropPath(settings: Map<*, *>): String? {
        val wallpaper = settings["homePageWallpaperPath"] as? String
        if (wallpaper != null && WallpaperEvictionRules.isAvailableKey(wallpaper)) {
            return wallpaper
        }
        val legacy = settings["homePageBackgroundImagePath"] as? String
        return legacy?.takeIf { WallpaperEvictionRules.isAvailableKey(it) }
    }
}
