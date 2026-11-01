package com.mutx163.qingyu.pages.settings

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
 * `TimetableSettingsModelStore.save` 每次落盘都会把壁纸键合并写进 **active 档案**
 * （`app/TimetableSettingsModel.kt:1143-1147` → `TimetableStore.kt:272-318`）。
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
     * 从盘上原始 JSON 文本扫描。
     *
     * null / 空串 = 还没有档案（可确认的空集，`readable = true`）；
     * 解析失败 = 读不懂（`readable = false`）。
     */
    fun scanProfileBackdrops(profilesJson: String?): ProfileBackdropScan {
        if (profilesJson.isNullOrEmpty()) {
            return ProfileBackdropScan(emptyList(), readable = true)
        }
        val decoded = MiniJson.tryParse(profilesJson)
            ?: return ProfileBackdropScan(emptyList(), readable = false)
        return scanProfileBackdrops(decoded)
    }

    /** 内部：解析后的 JSON 树。对外只暴露文本入口，避免调用方各拼一棵树。 */
    private fun scanProfileBackdrops(profiles: Any?): ProfileBackdropScan {
        if (profiles !is List<*>) {
            return ProfileBackdropScan(emptyList(), readable = false)
        }
        val paths = LinkedHashSet<String>()
        var readable = true
        for (profile in profiles) {
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
            effectiveBackdropPath(settings)?.let { paths.add(it) }
        }
        return ProfileBackdropScan(paths.toList(), readable)
    }

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
        val whitelist = WallpaperHistoryLedger.evictionWhitelist(
            allProfilesCurrentPaths = scan.backdropPaths + listOfNotNull(currentPath),
            draftPath = draftPath,
            galleryLedgerPaths = galleryLedgerPaths,
        )
        return EvictionPlan(
            deletable = WallpaperHistoryLedger.deletable(evictedPaths, whitelist),
            profilesUnreadable = false,
        )
    }

    /**
     * 一份档案内嵌 settings 的「当前有效背景图」。
     *
     * 壁纸优先；壁纸缺失、空串或已下线的 `builtin:` 键时回退旧版背景图字段。
     * 返回 null 表示这份档案没有可用的背景图文件。
     */
    private fun effectiveBackdropPath(settings: Map<*, *>): String? {
        val wallpaper = settings["homePageWallpaperPath"] as? String
        if (wallpaper != null && WallpaperHistoryLedger.isAvailableKey(wallpaper)) {
            return wallpaper
        }
        val legacy = settings["homePageBackgroundImagePath"] as? String
        return legacy?.takeIf { WallpaperHistoryLedger.isAvailableKey(it) }
    }
}
