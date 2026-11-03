package com.mutx163.qingyu.pages.schedule

import android.Manifest
import android.content.Context
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.core.permission.PermissionFlow
import com.mutx163.qingyu.core.permission.PermissionStep
import com.mutx163.qingyu.platform.permission.PermissionSystemActions

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

    // ── 通知权限（对齐旧版 add_schedule_item_screen.dart:552-597）──
    //
    // 旧版：选中提醒档位时查一次通知权限（初始乐观视为已授予，`:65`）；不可用时在
    // 提醒卡片下显示「检查通知权限」行动作 + 缺失说明；点行动作弹系统框，被拒后
    // 直接送系统通知设置页（`:586-592`），回来再查一次并刷新显示。
    // 状态机只用它管「还能不能弹框」：永久拒绝后点行动作不再空弹一次、直达设置页
    // （旧版是先空弹一次被系统秒拒再跳，终点相同）。
    var reminderPermissionMissing by remember { mutableStateOf(false) }
    val activity = remember(context) { PermissionSystemActions.findHostActivity(context) }
    val notificationFlow = remember {
        PermissionFlow(initiallyGranted = PermissionSystemActions.notificationsGranted(context))
    }

    fun refreshPermissionMissing() {
        reminderPermissionMissing = !PermissionSystemActions.notificationsGranted(context)
    }

    val notificationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        val canAskAgain = activity?.let {
            PermissionSystemActions.canAskAgain(it, Manifest.permission.POST_NOTIFICATIONS)
        } ?: false
        notificationFlow.onSystemResult(granted, canAskAgain)
        if (!granted) {
            // 与旧版同出口：被拒就送系统通知设置页（永久拒绝时系统框本来就不再弹）。
            PermissionSystemActions.openNotificationSettings(context)
        }
        refreshPermissionMissing()
    }

    fun requestNotificationPermission() {
        when (notificationFlow.onTrigger()) {
            PermissionStep.Proceed -> refreshPermissionMissing()
            PermissionStep.LaunchRequest ->
                notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            PermissionStep.OpenSettings -> {
                PermissionSystemActions.openNotificationSettings(context)
                refreshPermissionMissing()
            }
        }
    }

    AddScheduleItemPage(
        scheduleItem = scheduleItem,
        initialDate = initialDate,
        occurrenceDate = occurrenceDate,
        onBack = onFinish,
        reminderPermissionMissing = reminderPermissionMissing,
        onRequestNotificationPermission = { requestNotificationPermission() },
        onReminderSelected = { minutes ->
            // 选了具体档位才关心权限（对齐旧版 :547-549 选择时刷新；「关」不查）。
            if (minutes != null) refreshPermissionMissing()
        },
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
