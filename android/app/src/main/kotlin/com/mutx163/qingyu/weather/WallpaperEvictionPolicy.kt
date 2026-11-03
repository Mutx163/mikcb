package com.mutx163.qingyu.weather

/**
 * 一次淘汰白名单的判定结果。
 *
 * [profileReferencesKnown] = false 表示**没拿到档案引用**（调用方没读成功、或档案
 * JSON 读不懂）。此时 [WallpaperEvictionPolicy.deletable] 一律返回空表：
 * 「白名单为空」在语义上是「谁都没在用」，那是最危险的结论；宁可多留一张垃圾图，
 * 也不能删掉别的课表正在用的壁纸（与 [WallpaperEvictionSources.planEviction] 的
 * 保守口径同一条）。
 *
 * ⚠️ 这个信号**只表示「读没读成功」**，与路径列表是否为空无关：
 * 「所有档案都没设壁纸」是一份**合法且可确认**的引用快照（空集），
 * 此时淘汰文件必须能删；拿「路径非空」推断可读性会造成纯磁盘泄漏（P2-18）。
 */
data class EvictionWhitelist(
    val paths: Set<String>,
    val profileReferencesKnown: Boolean,
)

/**
 * 壁纸文件淘汰的**纯判定**（`settings_home_backdrop_flow.dart:265-274`、`:1105-1118`）。
 *
 * 原实现在 `pages/settings/WallpaperHistoryLedger` 里。2026-11-03 下沉到共享
 * `weather/`：timetable 的档案删除流程（`TimetableProfilesController`）要判「删掉这份
 * 课表后那张独占用图还能不能删」，却因此反向依赖整个设置页族，L0 编译闭包跑到
 * `pages/settings` 的 Compose 页面。这里只留纯函数，设置页与 timetable 都依赖它。
 */
object WallpaperEvictionPolicy {

    /**
     * 删淘汰文件的白名单：**三路并集**。
     *
     * 历史是设备级共享的，而壁纸仍每个课表各一张 —— 少算任何一路都会删掉别人的在用图：
     *
     * 1. 所有课表当前壁纸（自动换写下的那张**不在历史里**）；
     * 2. 本页草稿里刚选中的那张（还没落盘）；
     * 3. Bing 图库台账里下过的每一张（= 下载缓存，删了下次要重下）。
     *
     * ## 可读性与「路径是否为空」是两个独立信号（P2-18）
     *
     * 原先 `allProfilesCurrentPaths` 缺省 `emptyList()`，并用「至少有一个非空路径」
     * 推断档案引用可读。这会把「所有课表都没设壁纸」误判成「引用未知」，淘汰文件
     * 从此永不删（纯磁盘泄漏）。现在由调用方显式交代 [profilesReadable]：
     *
     * * `true` + 空列表 = 读到了，确实谁都没在用 ⇒ 该删就删；
     * * `false`（读不到 / JSON 读不懂）= 引用未知 ⇒ [deletable] 一律返回空表。
     *
     * @param profilesReadable 调用方是否**成功读到了**全部档案的壁纸字段。
     *   不能用「路径非空」代替：空列表是合法结果，不等于读取失败。
     */
    fun evictionWhitelist(
        allProfilesCurrentPaths: Iterable<String?>?,
        profilesReadable: Boolean,
        draftPath: String? = null,
        galleryLedgerPaths: Iterable<String> = emptyList(),
    ): EvictionWhitelist {
        val out = LinkedHashSet<String>()
        if (allProfilesCurrentPaths != null) {
            for (path in allProfilesCurrentPaths) {
                if (path != null && path.isNotBlank()) out.add(path)
            }
        }
        if (draftPath != null && draftPath.isNotBlank()) out.add(draftPath)
        for (path in galleryLedgerPaths) {
            if (path.isNotBlank()) out.add(path)
        }
        return EvictionWhitelist(paths = out, profileReferencesKnown = profilesReadable)
    }

    /**
     * 从「待删清单」里筛掉不该删的，返回真正可以删的那些。
     *
     * 三条豁免（由本层同一实现保证）：空串、已下线的 `builtin:` 键、
     * 以及 [whitelist] 里还在用的图。
     *
     * 第四条是 fail-safe：**档案引用没拿到时一张都不删**（见 [EvictionWhitelist]）。
     */
    fun deletable(evictedPaths: List<String>, whitelist: EvictionWhitelist): List<String> =
        if (!whitelist.profileReferencesKnown) {
            emptyList()
        } else {
            deletableWallpaperPaths(evictedPaths, inUsePaths = whitelist.paths)
        }

    /** 空 key 与已下线的内置壁纸键都不可用；文件存在性不在这里判（IO）。 */
    fun isAvailableKey(key: String): Boolean =
        key.isNotBlank() && !key.startsWith(LEGACY_BUILTIN_WALLPAPER_KEY_PREFIX)
}
