package com.mutx163.qingyu.transfer.lan

import com.mutx163.qingyu.app.TimetableRepository
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

/**
 * [LanTransferSettingsStore] 的仓储版实现。
 *
 * 2026-11-03：从「直接持有 [TimetableStore]」改为「注入 [TimetableRepository]」，
 * 读走 `readRawSettings()`、写走 `writeRawSettingsPatch(patch)`——两者都在仓储的
 * **同一把对象锁**内完成「读 → 合并 → 写 → 刷新内存 → 锁外通知」，
 * 消除了旧实现「`loadSettingsJson` 与 `saveSettingsPatch` 两次跨调用之间被 UI
 * 设置编辑插队」的丢更新窗口。
 *
 * 语义不变：整份替换由 [LanTransferLogic.settingsReplacePatch] 负责（缺失键写 null），
 * 设备信任锚点仍在补丁构造时保留；撤销「删新增键」依旧走同一个 patch 入口。
 * `writeRawSettingsPatch` 返回 false（底层写失败）时抛异常，交给
 * [LanTransferApplier] 的统一 catch 走回滚 + `transfer_import_failed`。
 */
class TimetableStoreLanSettings(private val repository: TimetableRepository) : LanTransferSettingsStore {

    override fun readSettingsJson(): Map<String, Any?> =
        // 盘上可能留着合并写产生的显式 null；Dart `toJson()` 的口径是「null 即省略」，
        // 读出来先归一，否则差异比对会把「同义」的缺键/空键判成不同。
        repository.readRawSettings().filterValues { it != null }

    override fun writeSettingsPatch(patch: Map<String, Any?>) {
        if (!repository.writeRawSettingsPatch(patch)) {
            throw IllegalStateException("lan_settings_write_failed")
        }
    }
}
