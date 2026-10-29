package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.app.KeyValueStore

/**
 * 随机配色的三项偏好（Dart `ImportRandomColorPreferences` 的三个键）。
 *
 * 默认值照 Dart 抄：**开关默认开**（新导入的课默认配色不同，这是产品行为不是笔误）、
 * 颜色组默认「全部颜色」、卡片文字色默认关（opt-in）。
 */
data class ImportRandomColorPrefs(
    val enabled: Boolean = ImportRandomColorStore.DEFAULT_ENABLED,
    val groupId: String = ImportRandomColorStore.DEFAULT_GROUP_ID,
    val textColorEnabled: Boolean = ImportRandomColorStore.DEFAULT_TEXT_COLOR_ENABLED,
)

/**
 * 导入页「随机配色」偏好的**落盘 store**（纯 Kotlin，无 Android / Compose 依赖）。
 *
 * 移植 `lib/services/import_random_color_preferences.dart`，键名逐字对齐（不然正式包
 * 换成 Compose 后读不到用户已有设置）：
 *
 * | 契约 key | 盘上类型 | 默认 |
 * |---|---|---|
 * | [KEY_ENABLED] | Bool | `true` |
 * | [KEY_GROUP] | String | `all` |
 * | [KEY_TEXT_COLOR_ENABLED] | Bool | `false` |
 *
 * `flutter.` 前缀由 [KeyValueStore] 的实现负责，本层只说契约 key。
 *
 * 三个 setter 都**写完回读**再返回布尔：`KeyValueStore.putX` 是 `Unit`，不认账也看不出来；
 * 回读不一致就说明这次没落盘，界面据此提示/回滚，而不是假装保存成功
 * （与 [CourseAutoRefreshStore.saveSchedule] 同一套口径）。
 */
class ImportRandomColorStore(private val store: KeyValueStore) {

    /** 一次读三项（页面首帧用，避免三处各自读盘）。 */
    fun snapshot(): ImportRandomColorPrefs = ImportRandomColorPrefs(
        enabled = isEnabled(),
        groupId = groupId(),
        textColorEnabled = isTextColorEnabled(),
    )

    fun isEnabled(): Boolean = store.getBool(KEY_ENABLED, DEFAULT_ENABLED)

    fun setEnabled(enabled: Boolean): Boolean {
        store.putBool(KEY_ENABLED, enabled)
        return store.getBool(KEY_ENABLED, !enabled) == enabled
    }

    /**
     * 当前颜色组 id。盘上是历史残留值（组被改名/删除）时**原样返回**，
     * 由 [ImportSharedModel.courseColorGroupPalette] 兜底成全量色板——
     * 读的时候就改写成 `all` 会把用户原来的选择悄悄抹掉。
     */
    fun groupId(): String = store.getString(KEY_GROUP) ?: DEFAULT_GROUP_ID

    fun setGroupId(groupId: String): Boolean {
        store.putString(KEY_GROUP, groupId)
        return store.getString(KEY_GROUP) == groupId
    }

    fun isTextColorEnabled(): Boolean = store.getBool(KEY_TEXT_COLOR_ENABLED, DEFAULT_TEXT_COLOR_ENABLED)

    fun setTextColorEnabled(enabled: Boolean): Boolean {
        store.putBool(KEY_TEXT_COLOR_ENABLED, enabled)
        return store.getBool(KEY_TEXT_COLOR_ENABLED, !enabled) == enabled
    }

    companion object {

        const val KEY_ENABLED = "import_random_course_colors_enabled"
        const val KEY_GROUP = "import_random_course_color_group"
        const val KEY_TEXT_COLOR_ENABLED = "import_random_course_text_color_enabled"

        const val DEFAULT_ENABLED = true
        const val DEFAULT_GROUP_ID = ImportSharedModel.COURSE_COLOR_GROUP_ALL_ID
        const val DEFAULT_TEXT_COLOR_ENABLED = false

        /**
         * 配色组选择弹层的选项顺序 = 「全部颜色」+ [ImportSharedModel.COURSE_COLOR_GROUPS] 的声明顺序。
         * Dart `course_recolor_sheet.dart` 的选项顺序与色板表一致，这里不另排序。
         */
        val GROUP_OPTIONS: List<String> =
            listOf(ImportSharedModel.COURSE_COLOR_GROUP_ALL_ID) +
                ImportSharedModel.COURSE_COLOR_GROUPS.map { it.first }

        /** 组 id → 屏上名字（唯一出处是 [ImportSharedModel.colorGroupDisplayName]）。 */
        fun groupLabel(groupId: String): String = ImportSharedModel.colorGroupDisplayName(groupId)
    }
}
