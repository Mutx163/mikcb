package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.KeyValueStore

/**
 * 教务导入的**本机偏好**（8b 新增）：自定义登录地址 + 最近使用的学校。
 *
 * ## 键名逐字抄 Dart
 *
 * 来源 `lib/services/warehouse_import_preferences_service.dart`：
 * - `warehouse_custom_import_url_<adapterId>`（[CUSTOM_URL_PREFIX]）
 * - `warehouse_recent_school_ids`（[RECENT_SCHOOL_IDS_KEY]，`List<String>`）
 *
 * 用同一批键的理由与 `ImportRandomColorStore` / `CourseAutoRefreshStore` 一致：
 * 迁移期两个界面（Flutter 主入口与 Compose 开发壳）会读同一份存档，
 * **键名不一致就会写成两套互不相认的偏好**，用户改完切回去发现没生效。
 *
 * ## 没有做的（诚实边界）
 *
 * Dart 侧同一个服务还管：记住的账号密码（走 `FlutterSecureStorage`，**不是** prefs）、
 * 自定义调试记录（`warehouse_custom_debug_records`，JSON）、以及每个自定义地址的「来源」标记
 * （`warehouse_custom_import_url_source_<id>`，用于同步时区分「用户改的」与「备份带来的」）。
 * 这三块本刀都不碰——它们分别属于网页登录（8c）、自定义调试页（8c）与云同步，
 * 硬塞进来会让「改个地址」变成一次跨模块重构。
 */
class WarehouseImportPrefs(internal val store: KeyValueStore) {

    /** 用户为该适配器手填的登录地址；没填过回 `null`（`""` 也算没填）。 */
    fun customImportUrl(adapterId: String): String? =
        store.getString(CUSTOM_URL_PREFIX + adapterId)?.takeIf { it.isNotBlank() }

    /** 保存自定义地址；传空白 = 清除（与 Dart `setCustomImportUrl` 的 trim 口径一致）。 */
    fun putCustomImportUrl(adapterId: String, url: String) {
        val trimmed = url.trim()
        if (trimmed.isEmpty()) {
            store.remove(CUSTOM_URL_PREFIX + adapterId)
        } else {
            store.putString(CUSTOM_URL_PREFIX + adapterId, trimmed)
        }
    }

    fun clearCustomImportUrl(adapterId: String) {
        store.remove(CUSTOM_URL_PREFIX + adapterId)
    }

    /**
     * 最近使用过的学校 id，**最近的在前**；没记录过回空列表。
     *
     * 解码失败（值被写坏 / 类型不符）时**留档自愈**再回空表，不照抛：
     * 「最近使用」只是便利数据，为它炸掉整个选校页不成比例——坏值留档
     * （与 `TimetableStore` 同一口径），用户最多丢 ★ 列表，页面照常可用。
     */
    fun recentSchoolIds(): List<String> {
        val decoded = try {
            store.getStringList(RECENT_SCHOOL_IDS_KEY)
        } catch (_: Exception) {
            store.archiveCorruptAndRemove(RECENT_SCHOOL_IDS_KEY, nowMicros())
            null
        }
        return decoded.orEmpty()
    }

    /**
     * 记一次「最近使用」：去重、最近的排最前、最多留 [MAX_RECENT_SCHOOLS] 条。
     *
     * 上限存在是为了不让这个列表无限长——它只影响列表页顶部的 ★ 分组，
     * 长了既没用又会在同步时把档撑大。
     *
     * **写入时机由调用方保证**：发布版在网页登录页**导入落库成功后**才
     * `addRecentSchool`（`warehouse_adapter_web_login_screen.dart:2504`），
     * 不是「点一下学校」就记。点学校只写本条目的 `WarehouseShellState`，
     * 否则「最近使用」会退化成「最近点过」（2026-11-10 审核差异）。
     */
    fun recordRecentSchool(schoolId: String) {
        if (schoolId.isBlank()) {
            return
        }
        val next = buildList {
            add(schoolId)
            addAll(recentSchoolIds().filter { it != schoolId })
        }.take(MAX_RECENT_SCHOOLS)
        store.putStringList(RECENT_SCHOOL_IDS_KEY, next)
    }

    companion object {
        const val CUSTOM_URL_PREFIX = "warehouse_custom_import_url_"
        const val RECENT_SCHOOL_IDS_KEY = "warehouse_recent_school_ids"

        /**
         * 最近使用最多留几所。
         *
         * = 发布版 `WarehouseImportPreferencesService.addRecentSchool(limit: 6)`
         * （`warehouse_import_preferences_service.dart:379`）。原为 8，与发布版不一致，
         * 且 Flutter 主入口仍会按 6 写同一个键——两套上限会让「准星」在不同入口间跳。
         */
        const val MAX_RECENT_SCHOOLS = 6
    }
}

/** 留档时间戳口径与 Dart 一致：微秒。 */
private fun nowMicros(): Long = System.currentTimeMillis() * 1000L
