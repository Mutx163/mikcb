package com.mutx163.qingyu

import android.content.Context

/**
 * 桌面卡片 → 课表 绑定档案（appWidgetId 为身份证号）。
 *
 * - 与小组件快照同住在原生 `home_widget_prefs`；Flutter 不直接读这个文件，
 *   通过 home_widget 通道读写，两端不各自持副本，避免绑定更新/删除不一致。
 * - 未登记（返回 null）= 跟随当前课表：老用户升级后一切照旧，零迁移。
 * - 绑定值是 profile id（TA 课表为固定 id `partner-imported`）。课表被删或
 *   TA 解绑后该 id 不再存在，渲染侧按「跟随当前课表」回落；绑定记录保留，
 *   同名 id 重新出现（重新导入 TA）时自动恢复生效。
 * - 哨兵 id `couple-merged` = 情侣课表（我的+TA 合并视图）：不是真实课表，
 *   渲染/刷新按 [COUPLE_MERGED_BINDING_ID] 特判（TodayWidgetSupport 实时
 *   合并计算 + Flutter 推送的专属快照兜底）。与 Dart 侧
 *   kHomeWidgetCoupleMergedBindingId 必须保持一致。
 */
object WidgetBindingStore {

    /** TA 课表（partnerImported）在 profiles 里的固定 id，与 Dart 侧一致。 */
    const val PARTNER_PROFILE_ID = "partner-imported"

    /** 情侣课表（合并视图）绑定哨兵，与 Dart 侧 kHomeWidgetCoupleMergedBindingId 一致。 */
    const val COUPLE_MERGED_BINDING_ID = "couple-merged"
    private const val PREFS_NAME = "home_widget_prefs"
    private const val KEY_PREFIX = "widget_binding_"

    /** 卡片绑定的 profile id；null = 未登记（跟随当前课表）。 */
    fun getBoundProfileId(context: Context, appWidgetId: Int): String? {
        return prefs(context).getString(key(appWidgetId), null)?.takeIf { it.isNotBlank() }
    }

    /** profileId 传 null/空白 = 解除绑定，回落「跟随当前课表」。 */
    fun setBoundProfileId(context: Context, appWidgetId: Int, profileId: String?) {
        val editor = prefs(context).edit()
        if (profileId.isNullOrBlank()) {
            editor.remove(key(appWidgetId))
        } else {
            editor.putString(key(appWidgetId), profileId)
        }
        editor.apply()
    }

    /** 卡片被移除（APPWIDGET_DELETED）时清档案，防止越积越多。 */
    fun remove(context: Context, appWidgetId: Int) {
        prefs(context).edit().remove(key(appWidgetId)).apply()
    }

    /** 当前全部绑定：appWidgetId → profile id。 */
    fun allBindings(context: Context): Map<Int, String> {
        val all = prefs(context).all
        val result = mutableMapOf<Int, String>()
        for (entry in all.entries) {
            val key = entry.key
            if (!key.startsWith(KEY_PREFIX)) continue
            val appWidgetId = key.removePrefix(KEY_PREFIX).toIntOrNull() ?: continue
            val profileId = entry.value as? String ?: continue
            if (profileId.isNotBlank()) {
                result[appWidgetId] = profileId
            }
        }
        return result
    }

    private fun key(appWidgetId: Int) = "$KEY_PREFIX$appWidgetId"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
}
