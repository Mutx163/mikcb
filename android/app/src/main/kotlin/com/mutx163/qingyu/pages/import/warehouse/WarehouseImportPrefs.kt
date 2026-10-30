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
class WarehouseImportPrefs(private val store: KeyValueStore) {

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

    /** 最近使用过的学校 id，**最近的在前**；没记录过回空列表。 */
    fun recentSchoolIds(): List<String> =
        store.getStringList(RECENT_SCHOOL_IDS_KEY).orEmpty()

    /**
     * 记一次「最近使用」：去重、最近的排最前、最多留 [MAX_RECENT_SCHOOLS] 条。
     *
     * 上限存在是为了不让这个列表无限长——它只影响列表页顶部的 ★ 分组，
     * 长了既没用又会在同步时把档撑大。
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
        const val MAX_RECENT_SCHOOLS = 8
    }
}
