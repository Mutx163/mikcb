package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel

/**
 * 外观编辑页**回到页顶**时，草稿要不要对齐盘上真值（纯判据，JVM 可测）。
 *
 * ## 为什么需要这一步（2026-11-03 用户实报「Bing 壁纸点应用，预览要点完成才变」）
 *
 * Bing 图库 / 调整位置这类**被本页推开的整页**，应用结果直接 `store.save()` 写盘、
 * 不经过本页草稿；而本页被覆盖期间仍组合着（miuix `NavDisplay` 可见窗口
 * `opaqueDepth = 1`，depth=1 的被覆盖页不销毁），返回时草稿还是旧内存值——
 * 预览（读草稿）就停在旧壁纸上，直到「完成」退出本页、首页按
 * `settingsRevision` 重读盘才看到。修法 = 宿主在 NavDisplay 条目生命周期
 * `ON_RESUME`（重新成为页顶）时调这个判据：盘上与本页不同就对齐草稿，预览当场跟上。
 *
 * 判据本身只有三条：正在退场不对齐（退场只回滚 / 提交，不掺外部变更）；
 * 盘上与草稿相同不对齐（省一次无谓重组）；其余返回盘上真值（`TimetableSettingsModel`
 * 是 data class，值相等判重安全）。
 *
 * @param disk 盘上刚读出的设置真值。
 * @param draft 本页当前草稿。
 * @param exiting 本页是否正在退场（取消 / 完成 / 系统返回已受理）。
 * @return 对齐后的草稿；`null` = 维持现草稿不动。
 */
fun appearanceEditorResyncOnResume(
    disk: TimetableSettingsModel,
    draft: TimetableSettingsModel,
    exiting: Boolean,
): TimetableSettingsModel? {
    if (exiting) return null
    if (disk == draft) return null
    return disk
}
