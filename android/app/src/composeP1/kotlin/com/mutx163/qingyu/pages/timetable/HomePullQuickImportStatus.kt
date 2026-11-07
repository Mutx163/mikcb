package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.pages.guide.GuideStrings
import com.mutx163.qingyu.pages.import.ImportStrings
import com.mutx163.qingyu.pages.import.warehouse.WarehouseStrings
import com.mutx163.qingyu.pages.settings.SettingsStringsExt3
import com.mutx163.qingyu.pages.transfer.TransferStrings
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Surface
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 首页下拉快捷导入的**原地状态药丸**（拿到事件 → 渲染，只此一件事）。
 *
 * ## 为什么是一个“视图状态”而不是直接吃引擎的事件
 *
 * 引擎（[com.mutx163.qingyu.pages.import.warehouse.WarehouseBackgroundImportEngine]，
 * 成员八交付）只对外发事件；事件里的失败原因是**契约枚举**，而上屏要的是**人话 + 能不能点**。
 * 把这层翻译收在这里，好处是：宿主接线只做「事件 → 状态」的一次 `when`，
 * 药丸本身不认识引擎、不认识路由、不认识 WebView，纯渲染，可单独看、单独改。
 *
 * ## 本轮刻意不引引擎类型
 *
 * 引擎文件还没落盘（成员八先改两条导入缺陷）。若这里直接 `import` 引擎的
 * `BackgroundWarehouseImportEvent` / `BackgroundWarehouseImportFailure`，整包会红在
 * “unresolved reference”上——那正是这轮冻结要避免的事故。所以这里用同名同义的
 * **本层枚举** [HomePullQuickImportFailureKind] 承接；引擎落地后接线层补一个 1:1 的
 * `when (engineReason)`（十行），两边的值一一对应，不做任何合并或推断。
 *
 * ## 文案纪律
 *
 * 药丸上的每一句话都来自已有 ARB 键（`ImportStrings` / `WarehouseStrings` /
 * `SettingsStringsExt3` / `GuideStrings` / `TransferStrings`），本文件**不新造文案**、
 * 也不写死中文字面量。两处说明见 [HomePullQuickImportFailureKind] 与 [applyingHeadline]。
 */
sealed interface HomePullQuickImportStatus {

    /** 什么都没发生（药丸不占位、不拦点击）。 */
    data object Idle : HomePullQuickImportStatus

    /** 引擎已接收请求，正在拉起后台网页。 */
    data object Starting : HomePullQuickImportStatus

    /** 回放到第 [index] / [total] 步；[label] 是引擎给的人话（`WarehouseReplayProgress.statusLabel`）。 */
    data class Step(val index: Int, val total: Int, val label: String) : HomePullQuickImportStatus

    /** 回放完了，正在把课写进课表。 */
    data class Applying(val courseCount: Int) : HomePullQuickImportStatus

    /** 写完了。 */
    data class Succeeded(val importedCount: Int) : HomePullQuickImportStatus

    /**
     * 没成。
     *
     * [headline] 是一句人话结论，[detail] 是可选的原因补充（引擎已本地化，原样显示），
     * [actionLabel] + [action] 是可点的出口（没有就是纯提示，不可点）。
     */
    data class Failed(
        val headline: String,
        val detail: String? = null,
        val actionLabel: String? = null,
        val action: HomePullQuickImportAction? = null,
    ) : HomePullQuickImportStatus
}

/** 药丸上唯一允许让用户点走的两件事（页面层不认识路由，只报意图）。 */
enum class HomePullQuickImportAction {
    /** 去「设置开学日期」（壳里 `b.semester`）。 */
    OPEN_SEMESTER_SETTINGS,

    /** 去教务导入页手动跑一次（壳里 `g2.webLogin`）——**唯一允许跳页**的出口。 */
    OPEN_WAREHOUSE_IMPORT,
}

/**
 * 失败原因（UI 口径）。十个值逐条对齐引擎契约的 `BackgroundWarehouseImportFailure`，
 * 顺序也一致，接线层的映射因此可以写成一眼能对号的 `when`。
 */
enum class HomePullQuickImportFailureKind {
    /** 一条已保存的快捷导入记录都没有。 */
    NO_SAVED_RECORD,

    /** 宏在，但自定义地址与默认地址都解析不出可用登录地址。 */
    NO_VALID_LOGIN_URL,

    /** 密码补不上 / 验证码 / 其它必须人来的步骤。 */
    LOGIN_REQUIRED,

    /** 回放某一步失败（`detail` 带第几步与原因的人话）。 */
    REPLAY_FAILED,

    /** 回放跑完了，但脚本没回传课程。 */
    NO_COURSES,

    /** 写课表失败（`detail` 带服务码人话）。 */
    WRITE_FAILED,

    /** 到点没回来（整次 120s / 写入 5min）。 */
    TIMEOUT,

    /** 用户取消。 */
    CANCELLED,

    /** 已经有一次在跑，这次直接拒（`start()` 返回 null）。 */
    ALREADY_RUNNING,

    /** 用户从没设过开学日：周次平移没有锚点，硬凑会改掉他的周次口径。 */
    SEMESTER_UNCONFIGURED,
}

/**
 * 失败原因 → 药丸状态。纯字符串拼装，不碰 Compose，方便将来单独加断言。
 *
 * 六条需要「能看懂 + 能点走」的出口：
 * - [HomePullQuickImportFailureKind.NO_SAVED_RECORD] / `NO_VALID_LOGIN_URL` → 去导入页；
 * - [HomePullQuickImportFailureKind.LOGIN_REQUIRED] → 去导入页（唯一允许跳页的情形）；
 * - [HomePullQuickImportFailureKind.SEMESTER_UNCONFIGURED] → 去设置开学日期；
 * - 其余（回放/写入/超时/取消/已在跑）→ 只有结论，不引导跳页。
 *
 * @param detail 引擎给的原因补充（已本地化）；null 时不显示第二行。
 */
fun homePullQuickImportFailureStatus(
    kind: HomePullQuickImportFailureKind,
    detail: String? = null,
): HomePullQuickImportStatus.Failed = when (kind) {
    HomePullQuickImportFailureKind.NO_SAVED_RECORD -> HomePullQuickImportStatus.Failed(
        headline = ImportStrings.noSavedQuickImportRecords.text,
        detail = detail,
        actionLabel = WarehouseStrings.webLoginImport.text,
        action = HomePullQuickImportAction.OPEN_WAREHOUSE_IMPORT,
    )

    HomePullQuickImportFailureKind.NO_VALID_LOGIN_URL -> HomePullQuickImportStatus.Failed(
        headline = ImportStrings.noValidWarehouseLoginUrl.text,
        detail = detail,
        actionLabel = WarehouseStrings.webLoginImport.text,
        action = HomePullQuickImportAction.OPEN_WAREHOUSE_IMPORT,
    )

    // 「需要手动操作」+ 去登录：引擎能自动补密码时根本不会走到这里；
    // 走到这里就是验证码/账号密码得本人来。这是唯一允许跳页的失败出口。
    HomePullQuickImportFailureKind.LOGIN_REQUIRED -> HomePullQuickImportStatus.Failed(
        headline = WarehouseStrings.quickImportManualInputTitle.text,
        detail = detail,
        actionLabel = WarehouseStrings.webLoginImport.text,
        action = HomePullQuickImportAction.OPEN_WAREHOUSE_IMPORT,
    )

    // 没设开学日：**不硬凑周次**，直接把用户送到设置页。
    HomePullQuickImportFailureKind.SEMESTER_UNCONFIGURED -> HomePullQuickImportStatus.Failed(
        headline = SettingsStringsExt3.pleaseSetSemesterStartDate.text,
        detail = detail,
        actionLabel = GuideStrings.setSemesterStartDateAction.text,
        action = HomePullQuickImportAction.OPEN_SEMESTER_SETTINGS,
    )

    HomePullQuickImportFailureKind.ALREADY_RUNNING -> HomePullQuickImportStatus.Failed(
        headline = ImportStrings.homePullQuickImportFetchingCourses.text,
        detail = detail,
    )

    HomePullQuickImportFailureKind.CANCELLED -> HomePullQuickImportStatus.Failed(
        headline = WarehouseStrings.importCancelledStatus.text,
        detail = detail,
    )

    // 回放失败 / 没拿到课 / 写不进去 / 超时：结论统一是「导入失败」，原因在第二行。
    HomePullQuickImportFailureKind.REPLAY_FAILED,
    HomePullQuickImportFailureKind.NO_COURSES,
    HomePullQuickImportFailureKind.WRITE_FAILED,
    HomePullQuickImportFailureKind.TIMEOUT,
    -> HomePullQuickImportStatus.Failed(
        headline = WarehouseStrings.importFailedStatus.text,
        detail = detail,
    )
}

/**
 * 原地状态药丸。
 *
 * 只用官方件：miuix `Surface`（药丸底）+ `CircularProgressIndicator`（转圈）+
 * `Text` / `TextButton`（文案与出口）。**不写任何自制动效**：跑/停的交替就是
 * 转圈出现与消失本身，没有缩放、没有位移、没有逐帧动画。
 *
 * @param onAction 用户点了药丸上的出口；只有 [HomePullQuickImportStatus.Failed] 会带出口。
 */
@Composable
fun HomePullQuickImportStatusPill(
    status: HomePullQuickImportStatus,
    onAction: (HomePullQuickImportAction) -> Unit,
    modifier: Modifier = Modifier,
) {
    if (status is HomePullQuickImportStatus.Idle) return

    val failed = status is HomePullQuickImportStatus.Failed
    val busy = status is HomePullQuickImportStatus.Starting ||
        status is HomePullQuickImportStatus.Step ||
        status is HomePullQuickImportStatus.Applying

    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(percent = 50),
        color = MiuixTheme.colorScheme.surfaceContainer,
        shadowElevation = 6.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (busy) {
                CircularProgressIndicator(size = 16.dp, strokeWidth = 1.9.dp)
            }
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = statusHeadline(status),
                    style = MiuixTheme.textStyles.body2,
                    color = if (failed) {
                        MiuixTheme.colorScheme.error
                    } else {
                        MiuixTheme.colorScheme.onSurface
                    },
                    maxLines = 1,
                )
                val detail = statusDetail(status)
                if (detail != null) {
                    Text(
                        text = detail,
                        style = MiuixTheme.textStyles.body2,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                        maxLines = 2,
                    )
                }
            }
            // 出口只可能挂在 Failed 上（其余状态没有可点的东西）。
            if (status is HomePullQuickImportStatus.Failed &&
                status.action != null &&
                status.actionLabel != null
            ) {
                TextButton(
                    text = status.actionLabel,
                    onClick = { onAction(status.action) },
                )
            }
        }
    }
}

/** 药丸第一行：一句结论。 */
private fun statusHeadline(status: HomePullQuickImportStatus): String = when (status) {
    HomePullQuickImportStatus.Idle -> ""
    HomePullQuickImportStatus.Starting -> WarehouseStrings.importingAction.text
    is HomePullQuickImportStatus.Step -> WarehouseStrings.quickImportPlaybackStepProgress.filled(
        "current" to status.index.toString(),
        "total" to status.total.toString(),
    )
    is HomePullQuickImportStatus.Applying -> applyingHeadline()
    is HomePullQuickImportStatus.Succeeded -> WarehouseStrings.importUpdatedCount.filled(
        "count" to status.importedCount.toString(),
    )
    is HomePullQuickImportStatus.Failed -> status.headline
}

/** 药丸第二行：可选的原因 / 具体那一步。 */
private fun statusDetail(status: HomePullQuickImportStatus): String? = when (status) {
    is HomePullQuickImportStatus.Step -> status.label.takeIf { it.isNotBlank() }
    is HomePullQuickImportStatus.Failed -> status.detail
    else -> null
}

/**
 * 「正在写入课表」这一拍没有专属 ARB 键：本文件不许新造文案，所以取 ARB 里语义相同的那句
 * 「数据接收完成，正在导入……」（`qrTransferReceiveComplete`，导入/传输同一套用词）。
 * 要精确到「正在写入课表」得先有一条新 ARB 键，届时应换掉这一行。
 */
private fun applyingHeadline(): String = TransferStrings.qrTransferReceiveComplete.text
