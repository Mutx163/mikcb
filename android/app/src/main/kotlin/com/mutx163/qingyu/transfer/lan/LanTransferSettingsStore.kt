package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.TimetableStore

/**
 * 局域网传输包的**完整设置读写缝**。
 *
 * Dart 侧 `TimetableSettings` 是 250+ 键的整份 JSON，`applyToProvider` 与导出都按整份处理；
 * Kotlin 的 [com.mutx163.qingyu.core.TimetableSettings] 只移植了时间/周次核心子集。
 * 要让局域网导入“设置”与 Dart 对齐，传输层必须能读到/写回**盘上的整份设置 JSON**，
 * 而不是核心子集。
 *
 * 读写语义与 [TimetableStore.saveSettingsPatch]
 * （`saveSettingsPatchToActiveProfile` 同步活动档案内嵌设置）一致：按键合并，
 * 显式 null 才删键——见 [LanTransferLogic.settingsReplacePatch] 如何用 null
 * 表达 Dart「整体覆盖」时缺失键回落默认。
 */
interface LanTransferSettingsStore {
    /** 盘上当前整份设置（原样键集，不做模型裁剪）。 */
    fun readSettingsJson(): Map<String, Any?>

    /** 按键合并写回（值 null = 删除该键）。 */
    fun writeSettingsPatch(patch: Map<String, Any?>)
}

/** [LanTransferSettingsStore] 的仓储版实现：底层就是与 [TimetableStore] 同一份存储。 */
class TimetableStoreLanSettings(private val store: TimetableStore) : LanTransferSettingsStore {

    override fun readSettingsJson(): Map<String, Any?> =
        // 盘上可能留着合并写产生的显式 null；Dart `toJson()` 的口径是「null 即省略」，
        // 读出来先归一，否则差异比对会把「同义」的缺键/空键判成不同。
        store.loadSettingsJson().filterValues { it != null }

    override fun writeSettingsPatch(patch: Map<String, Any?>) {
        store.saveSettingsPatch(patch)
        store.saveSettingsPatchToActiveProfile(patch)
    }
}
