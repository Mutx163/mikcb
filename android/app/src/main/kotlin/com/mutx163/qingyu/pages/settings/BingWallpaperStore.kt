package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.weather.BingWallpaperLedger
import com.mutx163.qingyu.weather.BingWallpaperRecordResult
import com.mutx163.qingyu.weather.BingWallpaperResolution
import com.mutx163.qingyu.weather.LEDGER_PREFS_KEY
import com.mutx163.qingyu.weather.WallpaperTargetSize

/**
 * Bing 每日壁纸的**设备级**存储（Dart `lib/services/bing_wallpaper_store.dart` 的
 * 读写壳；纯记账在 [BingWallpaperLedger]）。
 *
 * ## 为什么是设备级，而不是进 `TimetableSettings`
 *
 * 壁纸本身仍「每个课表各自一张」（`homePageWallpaperPath` 在设置模型里），但这两样
 * 都不是某份课表的属性，而是**这台设备怎么取图**的偏好：
 *
 * * 「自动换」问的是 App 的行为，不是「这份课表长什么样」；
 * * 下载台账记的是本机文件路径与哪天哪档下过，换设备时那些路径根本不存在。
 *
 * 因此它们不参与备份 / 云同步（Dart 同口径），单独落在两个 prefs 键上。
 *
 * ## 键名与 Dart 逐字一致
 *
 * * 开关：[PREF_AUTO_APPLY]（`bing_wallpaper_auto_apply_v1`）；
 * * 台账：[PREF_LEDGER]（`bing_wallpaper_v1`，JSON 数组）。
 *
 * `flutter.` 前缀由 [KeyValueStore] 的实现加（[com.mutx163.qingyu.platform.PrefsKeyValueStore]），
 * 本类只写**契约键**，与仓内其它存储同一条规矩。
 *
 * ## 为什么不抛错
 *
 * 台账整串坏掉时 [BingWallpaperLedger.fromJsonText] 当没有台账（最坏多下一次图），
 * 开关读失败回落 `false`。设置页是高频入口，任何一条脏数据都不该把页面带崩。
 *
 * ## 变更通知
 *
 * Dart 用 `ValueNotifier<int>` 让面板那颗开关重建；Kotlin 侧这里用一组回调，
 * 由宿主在自己的 `DisposableEffect` 里订阅后转成 Compose 状态。**不在这里 import
 * Compose**：本目录（`pages/settings`）必须保持纯 JVM 才能在 L0 里被直测。
 */
class BingWallpaperStore(private val prefs: KeyValueStore) {

    private val listeners = LinkedHashSet<() -> Unit>()

    /** 自动换开关（缺省关：新功能不该在用户没选择时就联网换壁纸）。 */
    fun autoApplyEnabled(): Boolean = prefs.getBool(PREF_AUTO_APPLY, false)

    /** 下载台账；坏数据当空表，不抛。 */
    fun ledger(): BingWallpaperLedger =
        BingWallpaperLedger.fromJsonText(prefs.getString(PREF_LEDGER))

    /** 面板与自动换执行体读的同一份快照（开关 + 台账）。 */
    fun snapshot(): WallpaperAutoApplySnapshot = WallpaperAutoApplySnapshot(
        enabled = autoApplyEnabled(),
        ledger = ledger(),
    )

    /** 写开关（Dart `setAutoApplyEnabled`：先让本进程可见，再落盘，再通知）。 */
    fun setAutoApplyEnabled(enabled: Boolean) {
        prefs.putBool(PREF_AUTO_APPLY, enabled)
        notifyListeners()
    }

    /**
     * 记一次「这张 / 这个档位 / 这个尺寸已经下到 [path]」，并返回应当删除的溢出路径。
     *
     * 只记账、不碰磁盘：调用方知道「还有谁在用这张图」（别的课表 / 历史 / 图库缓存），
     * 所以删除必须走 [WallpaperHistoryLedger.evictionWhitelist] + `deletable` 那一套。
     */
    fun recordApplied(
        dateKey: String,
        resolution: BingWallpaperResolution,
        path: String,
        autoApplied: Boolean = true,
        targetSize: WallpaperTargetSize? = null,
    ): BingWallpaperRecordResult {
        val result = ledger().recordApplied(
            dateKey = dateKey,
            resolution = resolution,
            path = path,
            autoApplied = autoApplied,
            targetSize = targetSize,
        )
        prefs.putString(PREF_LEDGER, encodeLedger(result.ledger))
        notifyListeners()
        return result
    }

    /** 订阅台账变更（开关写入 / 记账各一次）；宿主负责在离开时 [removeListener]。 */
    fun addListener(listener: () -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: () -> Unit) {
        listeners.remove(listener)
    }

    private fun notifyListeners() {
        // 先复制：监听器里若顺手增删订阅，不能破坏本次遍历。
        for (listener in listeners.toList()) listener()
    }

    companion object {
        /** 自动换开关（Dart `bing_wallpaper_store.dart:39`；字面量在共享 `weather/BingWallpaperPrefs`）。 */
        const val PREF_AUTO_APPLY = com.mutx163.qingyu.weather.BingWallpaperPrefs.AUTO_APPLY

        /**
         * 下载台账 JSON 数组（Dart 同文件 `:36`）。
         *
         * 2026-11-03 起委托共享层 [LEDGER_PREFS_KEY]：这是跨域契约 key（课表域
         * 删档案回收独占用图读同一份台账），真源随契约逻辑放在共享层。
         */
        const val PREF_LEDGER = LEDGER_PREFS_KEY

        /**
         * 台账落盘形状：**JSON 数组**（Dart `jsonEncode([...])`），不是包一层对象。
         *
         * 与 [BingWallpaperLedger.fromJsonText] 的读取口径配对；两者都写在测试里，
         * 键名逐条对齐 Dart 的 `_DownloadedEntry.toJson`。
         */
        fun encodeLedger(ledger: BingWallpaperLedger): String =
            MiniJson.encode(ledger.entries.map { it.toJson() })
    }
}
