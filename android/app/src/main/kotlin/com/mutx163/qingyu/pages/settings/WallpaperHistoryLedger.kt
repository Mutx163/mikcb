package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.WallpaperHistoryRowModel
import com.mutx163.qingyu.weather.WallpaperEvictionPolicy
import com.mutx163.qingyu.weather.WallpaperHistoryEntry
import com.mutx163.qingyu.weather.pushWallpaperHistory
import com.mutx163.qingyu.weather.rememberWallpaperHistoryBatch

/**
 * 淘汰白名单判定结果——真源已下沉到 `weather/WallpaperEvictionPolicy.kt`
 *（设置页与 timetable 共用同一份「谁在用这张图」的口径）。这里只做转名。
 */
typealias EvictionWhitelist = com.mutx163.qingyu.weather.EvictionWhitelist

/**
 * 壁纸「最近使用」台账的纯运算层（Dart `lib/utils/wallpaper_history.dart`
 * `lib/screens/settings/settings_home_backdrop_flow.dart:234-417`）。
 *
 * ## 为什么再包一层（weather 里已有 `pushWallpaperHistory`）
 *
 * [com.mutx163.qingyu.weather.WallpaperHistoryLogic] 只搬运了**列表运算**，而且用的是
 * 天气/存储层的 `WallpaperHistoryEntry`；本页状态用的却是
 * [WallpaperHistoryRow]（渲染层）与 [WallpaperHistoryRowModel]（设置模型）。
 * 这里把两边接起来，只补 Dart 里真正属于**壁纸流程**的那四条契约：
 *
 * 1. **10 条上限**：记一次就置顶，第 11 条被挤出并进待删清单；
 * 2. **当前这张补最前**：历史里没有当前壁纸时，用当前取景造一条补在队首
 *    （`settings_home_backdrop_flow.dart:805-815`）；
 * 3. **切回连取景一起还原**：alignX / alignY / scale 三件一起回写，漏 scale
 *    等于「取景被还原了一半」（`wallpaper_history.dart:145-152`）；
 * 4. **淘汰白名单三路并集**：所有课表当前壁纸 + 本页草稿那张 + 图库台账
 *    （`settings_home_backdrop_flow.dart:265-274`、`:1105-1118`）。
 *
 * ## 不在这里做的事
 *
 * - 摸盘判「文件还在不在」：Dart 的 `availableWallpaperHistory` 会查文件，
 *   那是 IO；本层只过滤空 key 与已下线的 `builtin:` 条目，文件存在性由宿主判；
 * - 真删文件：由宿主拿 [deletable] 的结果去调受管删除（还要先失效缓存）；
 * - 2.5s 反悔窗口：宿主计时，本层只提供「删除凭据 = 删之前整份历史」
 *   （[Removal.previousHistory]），撤销就是把它原样放回（[undo]）。
 */
object WallpaperHistoryLedger {

    /** 历史保留条数（ARB `homePageWallpaperRecentSubtitle` 写死了这个数）。 */
    const val MAX_ENTRIES = 10

    /** 一次记入的结果：裁剪后的历史 + 被挤出上限、可以删文件的路径。 */
    data class RememberResult(
        val history: List<WallpaperHistoryRow>,
        val evictedPaths: List<String>,
    )

    /** 切回一条历史后的结果：要落盘的设置 + 淘汰文件（尚未过白名单）。 */
    data class ApplyResult(
        val settings: TimetableSettingsModel,
        val evictedPaths: List<String>,
    )

    /** 相册选图收进受管目录后的结果：要落盘的设置 + 淘汰文件（尚未过白名单）。 */
    data class PickedResult(
        val settings: TimetableSettingsModel,
        val evictedPaths: List<String>,
    )

    /**
     * 一次「确认删除」的结果。
     *
     * [previousHistory] 就是撤销凭据：存整份旧列表而不是「那一条 + 下标」，
     * 撤销时天然把顺序、时间、取景值全还原（Dart `:31-39`）。
     */
    data class Removal(
        val settings: TimetableSettingsModel,
        val removedPath: String,
        val previousHistory: List<WallpaperHistoryRowModel>,
    )

    /**
     * 记一次壁纸使用：同一 key 去重后置顶，超出 [MAX_ENTRIES] 的旧条目挤出。
     *
     * 纯列表运算，不落盘；[evictedPaths] 交给宿主过 [deletable] 后再删。
     * [usedAt] 缺省取当前时间，单测注入固定值。
     */
    fun remember(
        history: List<WallpaperHistoryRow>,
        key: String,
        alignX: Double = 0.0,
        alignY: Double = 0.0,
        scale: Double = 1.0,
        usedAt: Long = System.currentTimeMillis(),
    ): RememberResult {
        val pushed = pushWallpaperHistory(
            history = history.map { it.toWeatherEntry() },
            key = key,
            alignX = alignX,
            alignY = alignY,
            scale = scale,
            usedAt = usedAt,
        )
        return RememberResult(
            history = pushed.history.map { it.toRow() },
            evictedPaths = pushed.evictedPaths,
        )
    }

    /**
     * 「最近使用」缩略图条实际展示的条目（Dart `buildRecentWallpaperTile` `:800-818`）。
     *
     * 当前生效但历史里没有的那张补在**最前**，并用当前取景造条目；历史里已有时
     * 不重复补。只过滤空 key 与 `builtin:`（无文件的旧内置壁纸）——文件存在性
     * 属于 IO，由宿主先过滤。
     *
     * ⚠️ 展示列表可能比 [MAX_ENTRIES] 多一条：存储上限管的是「历史」，
     * 当前那张是从设置里补出来的，Dart 也是 11 条。
     */
    fun visibleEntries(
        history: List<WallpaperHistoryRow>,
        currentPath: String?,
        currentFraming: WallpaperFraming = WallpaperFraming.DEFAULT,
    ): List<WallpaperHistoryRow> {
        val out = ArrayList<WallpaperHistoryRow>(history.size + 1)
        val seen = HashSet<String>()
        val current = currentPath?.takeIf { it.isNotBlank() }
        if (current != null && history.none { it.key == current }) {
            out.add(
                WallpaperHistoryRow(
                    key = current,
                    label = SettingsBackdropFlowPage.fileNameOf(current),
                    alignX = currentFraming.alignX,
                    alignY = currentFraming.alignY,
                    scale = currentFraming.scale,
                ),
            )
            seen.add(current)
        }
        for (entry in history) {
            if (!WallpaperEvictionPolicy.isAvailableKey(entry.key)) continue
            if (!seen.add(entry.key)) continue
            out.add(entry)
        }
        return out
    }

    /**
     * 一条历史对应的取景。
     *
     * **三件一起还原**：Dart `settingsWithWallpaperHistoryEntry` 同时写
     * `homePageWallpaperAlignX/Y` 与 `homePageWallpaperScale`
     * （`wallpaper_history.dart:145-152`）。只还原位置不还原缩放，用户放大过的那张
     * 切回来会被静默缩回 1。
     */
    fun framingOf(entry: WallpaperHistoryRow): WallpaperFraming = WallpaperFraming(
        alignX = entry.alignX,
        alignY = entry.alignY,
        scale = entry.scale,
    )

    /**
     * 切回一条历史（Dart `_selectBackdropEntry` `:294-316`）：
     * 写路径 + 三件取景 + 把「刚被换下的那张」与「切回的这张」按旧→新补进历史。
     *
     * 返回 null 的两种情形与 Dart 一致：key 为空、或条目来自已下线的内置壁纸
     * （没有文件，切过去只会得到死路径）。
     */
    fun applySelection(
        current: TimetableSettingsModel,
        entry: WallpaperHistoryRow,
        usedAt: Long = System.currentTimeMillis(),
    ): ApplyResult? {
        if (!WallpaperEvictionPolicy.isAvailableKey(entry.key)) return null
        val previousPath = current.homePageWallpaperPath?.takeIf { it.isNotBlank() }
        val batch = ArrayList<WallpaperHistoryEntry>(2)
        if (previousPath != null) {
            batch.add(
                WallpaperHistoryEntry(
                    key = previousPath,
                    alignX = current.homePageWallpaperAlignX,
                    alignY = current.homePageWallpaperAlignY,
                    scale = current.homePageWallpaperScale,
                ),
            )
        }
        batch.add(entry.toWeatherEntry())
        val result = rememberWallpaperHistoryBatch(
            history = current.wallpaperHistory.map { it.toWeatherEntry() },
            entries = batch,
        )
        val framing = framingOf(entry)
        return ApplyResult(
            settings = current.copy(
                homePageWallpaperPath = entry.key,
                homePageWallpaperAlignX = framing.alignX,
                homePageWallpaperAlignY = framing.alignY,
                homePageWallpaperScale = framing.scale,
                wallpaperHistory = result.history.map { it.toRowModel() },
            ),
            evictedPaths = result.evictedPaths,
        )
    }

    /**
     * 相册选图落进受管目录后的写入（Dart `:1007-1019` / `:1070-1091`）：
     * 记一条「最近使用」并写路径 + 居中取景。
     *
     * 与 [applySelection] 的差别只有入口：那条是「切回已有历史」，这条是「新图第一次进来」。
     * 两者共用同一份 [remember]，10 条上限与淘汰清单因此只有一处实现。
     */
    fun applyPicked(
        current: TimetableSettingsModel,
        path: String,
        alignX: Double = 0.0,
        alignY: Double = 0.0,
        scale: Double = 1.0,
        usedAt: Long = System.currentTimeMillis(),
    ): PickedResult? {
        if (!WallpaperEvictionPolicy.isAvailableKey(path)) return null
        val pushed = pushWallpaperHistory(
            history = current.wallpaperHistory.map { it.toWeatherEntry() },
            key = path,
            alignX = alignX,
            alignY = alignY,
            scale = scale,
            usedAt = usedAt,
        )
        return PickedResult(
            settings = current.copy(
                homePageWallpaperPath = path,
                homePageWallpaperAlignX = alignX,
                homePageWallpaperAlignY = alignY,
                homePageWallpaperScale = scale,
                wallpaperHistory = pushed.history.map { it.toRowModel() },
            ),
            evictedPaths = pushed.evictedPaths,
        )
    }

    /**
     * 按 key 切回一条历史（Dart `:294-316`）：找不到（或已下线的内置壁纸）返回 null。
     *
     * 存在的理由只是把「从设置模型里找条目」收归一处，取景三件与补记顺序仍走
     * [applySelection] —— 宿主不该在 UI 层自己拼 [WallpaperHistoryRow]。
     */
    fun select(
        current: TimetableSettingsModel,
        key: String,
        usedAt: Long = System.currentTimeMillis(),
    ): ApplyResult? {
        val entry = current.wallpaperHistory.firstOrNull { it.key == key } ?: return null
        return applySelection(
            current = current,
            entry = WallpaperHistoryRow(
                key = entry.key,
                label = SettingsBackdropFlowPage.fileNameOf(entry.key),
                alignX = entry.alignX,
                alignY = entry.alignY,
                scale = entry.scale,
                usedAt = entry.usedAt,
            ),
            usedAt = usedAt,
        )
    }

    /**
     * 确认删除一条历史（Dart `_removeBackdropHistoryEntry` `:325-354`）：
     * 摘条目 + 镜进设置，并把**删之前那份整历史**当撤销凭据返回。
     *
     * 正在用的那张不给删（Dart 在 UI 层挡，本层再兜一次：两处都判不会漏，
     * 但这里是数据入口，绕过 UI 也不能删掉当前壁纸）。条目不存在时返回 null，
     * 调用方可以无脑先算再落盘。
     */
    fun remove(current: TimetableSettingsModel, key: String): Removal? {
        val trimmed = key.trim()
        if (!WallpaperEvictionPolicy.isAvailableKey(trimmed)) return null
        if (!isRemovable(trimmed, current.homePageWallpaperPath)) return null
        val previous = current.wallpaperHistory
        val next = previous.filter { it.key != trimmed }
        if (next.size == previous.size) return null
        return Removal(
            settings = current.copy(wallpaperHistory = next),
            removedPath = trimmed,
            previousHistory = previous,
        )
    }

    /**
     * 撤销最近一次删除：**整份旧历史原样放回**（Dart `_undoRemoveBackdropHistoryEntry` `:356-378`）。
     *
     * 撤销窗口内历史不会变（没有别的入口改它），所以直接替换即可；
     * 文件删除排期也要在同一刻取消，那属于宿主的计时器。
     */
    fun undo(
        current: TimetableSettingsModel,
        previousHistory: List<WallpaperHistoryRowModel>,
    ): TimetableSettingsModel = current.copy(wallpaperHistory = previousHistory.toList())

    /** 当前正在用的那张不给移除（`settings_recent_wallpaper.dart:128-137`）。 */
    fun isRemovable(key: String, currentPath: String?): Boolean =
        currentPath != null && key != currentPath
}

private fun WallpaperHistoryRow.toWeatherEntry(): WallpaperHistoryEntry = WallpaperHistoryEntry(
    key = key,
    alignX = alignX,
    alignY = alignY,
    scale = scale,
    usedAt = usedAt,
)

private fun WallpaperHistoryEntry.toRow(): WallpaperHistoryRow = WallpaperHistoryRow(
    key = key,
    label = SettingsBackdropFlowPage.fileNameOf(key),
    alignX = alignX,
    alignY = alignY,
    scale = scale,
    usedAt = usedAt,
)

private fun WallpaperHistoryRowModel.toWeatherEntry(): WallpaperHistoryEntry = WallpaperHistoryEntry(
    key = key,
    alignX = alignX,
    alignY = alignY,
    scale = scale,
    usedAt = usedAt,
)

private fun WallpaperHistoryEntry.toRowModel(): WallpaperHistoryRowModel = WallpaperHistoryRowModel(
    key = key,
    alignX = alignX,
    alignY = alignY,
    scale = scale,
    usedAt = usedAt,
)
