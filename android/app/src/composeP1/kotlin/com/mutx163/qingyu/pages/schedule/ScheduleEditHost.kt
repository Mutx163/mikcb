package com.mutx163.qingyu.pages.schedule

import android.content.Context
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

/**
 * 日程「新建 / 编辑」页的**宿主层（反馈部分）**。
 *
 * ## 这个文件补的是什么口子
 *
 * 审核 `docs/plans/2026-10-29-quality-audit/misc-wiring.md` P1-5：
 * 壳里原来是
 *
 * ```
 * onSave = { draft, applyToAll -> if (wiring.saveScheduleItem(draft, applyToAll)) { …; onBack() } }
 * ```
 *
 * `saveScheduleItem` 落盘失败时 `catch { false }`（`ShellWiring.kt`），壳里**没有 else 分支**
 * ⇒ 用户点保存，页面不动、零提示；保存成功也只是静默关页。删除同理。
 *
 * Dart 原件两侧都有反馈（`lib/screens/add_schedule_item_screen.dart`）：
 *
 * | 场景 | Dart 出处 | 文案键 |
 * |---|---|---|
 * | 保存失败 | `:906-911` | `saveFailed` |
 * | 新建成功 | `:919-924` | `scheduleSavedHint` |
 * | 编辑成功 | `:919-924` | `scheduleUpdatedHint` |
 * | 删除失败 | `:1024-1032`（整条）/ `:986-994`（只这一次） | `deleteFailed` |
 * | 删除成功 | `:1036-1040` / `:999-1003` | `scheduleDeletedHint` |
 *
 * Dart 源码在两条失败路径上还各留了一段注释，说的就是「provider 落盘失败会回滚并 rethrow，
 * 不接就是零提示 + 未处理异步错误，而这里还会照常关页并报『已保存 / 已删除』」——
 * Compose 侧此前正是它警告的那种形态（静默），本类把这条补上。
 *
 * ## 为什么不直接把 Toast 塞进渲染层页面
 *
 * `AddScheduleItemPage` 的 `onSave` 返回 `Unit`：页面**不知道**落盘成败，硬塞 Toast 只能
 * 猜「大概成功了」——那正是 rubric 判 P0 的「假成功」。所以成败判据留在宿主：
 * 宿主拿到 `Boolean`，成功才关页 + 弹成功提示，失败留在页面上 + 弹失败提示。
 *
 * ## 接线方式
 *
 * 壳把 `wiring.saveScheduleItem` / `wiring.deleteScheduleItem`（都是 `Boolean`）传进来即可，
 * 见审核报告里的「壳接线请求」。本类不 import `ShellWiring`（方向反了），只收函数类型。
 *
 * @param scheduleItem 正在编辑的日程；`null` = 新建（决定成功提示用「已添加」还是「已更新」）。
 * @param onSave 落盘：`true` = 已写入仓储。**实现方不许把异常吞成 `true`。**
 * @param onDelete 删除：`true` = 已删除。
 * @param onFinish 关闭本页（壳在这里顺带清一次性意图 `clearScheduleIntent()`）。
 */
@Composable
fun ScheduleEditHost(
    scheduleItem: ScheduleItemData?,
    initialDate: String,
    occurrenceDate: String?,
    onSave: (ScheduleItemData, Boolean?) -> Boolean,
    onDelete: (ScheduleItemData, Boolean?) -> Boolean,
    onFinish: () -> Unit,
) {
    val context = LocalContext.current
    AddScheduleItemPage(
        scheduleItem = scheduleItem,
        initialDate = initialDate,
        occurrenceDate = occurrenceDate,
        onBack = onFinish,
        onSave = { draft, applyToAll ->
            if (onSave(draft, applyToAll)) {
                // 先关页再弹提示：Dart 也是 `pop(true)` 之后 showAppToast
                // （`:919-925`），保证提示挂在上一层的 context 上而不是被销毁的页面上。
                onFinish()
                toast(
                    context,
                    if (scheduleItem == null) {
                        ScheduleStrings.scheduleSavedHint.zh
                    } else {
                        ScheduleStrings.scheduleUpdatedHint.zh
                    },
                )
            } else {
                // 失败**不关页**：用户填的内容还在，改完可以再点保存。
                toast(context, ScheduleStrings.saveFailed.zh)
            }
        },
        onDelete = { item, applyToAll ->
            if (onDelete(item, applyToAll)) {
                onFinish()
                toast(context, ScheduleStrings.scheduleDeletedHint.zh)
            } else {
                toast(context, ScheduleStrings.deleteFailed.zh)
            }
        },
    )
}

/**
 * 一条短提示。
 *
 * 本仓 Compose 侧既有的同类反馈（`ShellPageIndex` 的任务族、日程域）都用 `Toast`，
 * 这里保持一致；`showAppToast` 是 Dart 侧的名字，Kotlin 侧没有同名封装。
 */
private fun toast(context: Context, message: String) {
    Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
}
