package com.mutx163.qingyu.app

import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.calendar.ScheduleDateRuleLogic
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeAction
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeDeleteCheck
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeEditorModel
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeManagementModel
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeManagementStrings
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeMenuState
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeNameSheet
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeDeleteBlockedSheet
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeDeleteSheet
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeEditorPage
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeMenuSheet
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeQuickGenerateSheet
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeServiceMessages
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeSheet
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeUsageIndexFactory
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeUsageSheet
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeUsageView
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeSectionEdit
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeShareSheet
import com.mutx163.qingyu.pages.time_scheme.TimeSchemeShareSheetDialog
import com.mutx163.qingyu.pages.transfer.DataTransferPackageLogic
import com.mutx163.qingyu.pages.transfer.QrTransferSendSession
import com.mutx163.qingyu.pages.transfer.TransferPackageRequest
import com.mutx163.qingyu.pages.transfer.TransferPackageResult
import com.mutx163.qingyu.pages.transfer.TransferServiceMessages
import com.mutx163.qingyu.pages.transfer.TransferShellBridge
import com.mutx163.qingyu.platform.AndroidTransferShareAdapter
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferEnvelope
import com.mutx163.qingyu.share.TransferScope
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.NumberPicker
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.theme.MiuixTheme
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 「时间模板」族（`d3.timeSchemes` 列表页 + `d3.timeSchemeEditor` 编辑节次页）的**真宿主**。
 *
 * ## 为什么要有这个文件（审核缺口 P0-①）
 *
 * 壳里原来的写法是 `TimeSchemeManagementPage(model = TimeSchemeManagementModel(), 七个空回调)`：
 * 模型空构造 ⇒ **永远空列表**；回调全是 `{}` ⇒ 新建、更多菜单、应用、编辑一个都不通。
 * 用户打开这一页看到的是「请先创建一套时间模板」，而且**永远**是这句（`timeSchemeManagementScreen.dart`
 * 1 888 行的功能，实际连一个动作都执行不了）。
 *
 * 本宿主补上三件事：
 *
 * 1. **真数据**：订阅 [TimetableRepository] 快照，喂模板清单 / 当前模板 / 地点分组数 /
 *    日期规则数与「今天是否落在某条日期规则里」；引用关系用 [TimeSchemeUsageIndexFactory]
 *    从同一份快照现算（快照不可变，所以不存在 Dart `_syncUsageSnapshot` 那套缓存失效问题）。
 * 2. **真动作**：新建 / 重命名 / 复制 / 删除 / 应用 / 查看使用情况 / 编辑节次，全部落到
 *    [TimetableRepository] 的写入口（写入口语义逐条对 `timetable_time_scheme_service.dart`：
 *    先落盘、成功才改内存并在失败时上抛，因此宿主只需 catch 后提示，不自己写回滚）。
 * 3. **真弹层**：新建/重命名（文本输入）、删除确认、删除被拦（占用清单）、使用情况详情——
 *    由本文件的 `TimeSchemeDialog` 状态机驱动，渲染层只负责摆像素。
 *
 * ## 与 Dart 的三处**有意差异**（诚实清单，别当漏抄）
 *
 * | 差异 | Dart | 本层 | 原因 |
 * |---|---|---|---|
 * | 分享（系统文件 / 二维码） | 打包成只含该模板的 `.mikcb` 再走 `SharePlus` / `QrTransferSendScreen` | **已接上**（2026-11-10）：打包复用 `pages/transfer/DataTransferPackageLogic` 的 `TIME_TEMPLATE` 分支（只带被点名的模板），系统分享复用 `platform/AndroidTransferShareAdapter`（写缓存 → FileProvider → 选择器），二维码复用 `TransferShellBridge` + 现成的 `g3.qrSend`。壳没给 `onRequestQrSend` 时**二维码那一项不显示**——宁可少一项，也不摆一个点了没反应的按钮 |
 * | 地点作息匹配 / 日期作息规则两页 | 各自是完整实现 | **只保证入口点得动**（跳 `d3.locationMatch` / `d2.dateRule`） | 那两页属 `P35-B2` 与 `ScheduleDateRuleHost` 各自的批次 |
 * | 编辑节次的「是否有未保存改动」 | 无（返回即丢弃） | 同样无 | 与 Dart 一致，不新增行为 |
 *
 * ## 时间选择为什么在宿主里
 *
 * 渲染层是纯函数（`onPickSectionTime(index)` 只上报「点了第几节」），两个滚轮弹层与
 * 「开始 → 结束」两跳的串联都在本文件：这一段是有状态的流程（中间要暂存已选开始时间），
 * 放进页面会让渲染层持有业务时序。
 */

/**
 * 列表页宿主（`d3.timeSchemes`）。
 *
 * @param repository 课表仓储（与设置页、首页同一个实例）。
 * @param onBack 返回。
 * @param onOpenEditor 打开某套模板的编辑节次页（壳负责推 `d3.timeSchemeEditor` 并带上 id）。
 * @param onOpenLocationEntry 进「地点作息匹配」。
 * @param onOpenDateRules 进「日期作息规则」。
 * @param onRequestQrSend 打开壳的二维码发送页（`g3.qrSend`）。载荷由本宿主先写进
 *   [TransferShellBridge] 再调它；**为 null 表示壳还没接这条路**（路由表那一行归 Lead），
 *   此时分享弹层里不显示「二维码分享」，避免点上去没反应。
 */
@Composable
fun TimeSchemeManagementHost(
    repository: TimetableRepository,
    onBack: () -> Unit,
    onOpenEditor: (schemeId: String) -> Unit,
    onOpenLocationEntry: () -> Unit,
    onOpenDateRules: () -> Unit,
    onRequestQrSend: (() -> Unit)? = null,
) {
    var snapshot by remember(repository) { mutableStateOf<TimetableSnapshot?>(null) }
    var model by remember(repository) { mutableStateOf<TimeSchemeManagementModel?>(null) }
    DisposableEffect(repository) {
        val subscription = repository.observe { updated -> snapshot = updated }
        onDispose { subscription.close() }
    }

    // 首装载全部挪到后台线程：旧实现把 `repository.snapshot` 读、引用索引
    // (`TimeSchemeUsageIndexFactory.build`) 与模型构造全塞在**组合期**同步执行——
    // 课程/档案一多就把主线程按住数秒，首帧画不出来，用户看到的是「空页干等，数据回来猛一下弹出」。
    LaunchedEffect(repository) {
        // 后台读一次；读回来的途中若仓储已经推了新快照（`observe` 回调先到），
        // 不要把新的盖成这次读到的旧值 —— 只在仍然为空时落盘。
        val loaded = withContext(Dispatchers.IO) { repository.snapshot }
        if (snapshot == null) snapshot = loaded
    }
    LaunchedEffect(snapshot) {
        val current = snapshot ?: return@LaunchedEffect
        val next = withContext(Dispatchers.Default) {
            val usage = TimeSchemeUsageIndexFactory.build(
                schemes = current.timeSchemes,
                profiles = current.profiles,
                locationGroups = current.locationTimeGroups,
                dateRules = current.scheduleDateRules,
            )
            // Dart 每次 build 都拿 `DateTime.now()` 去 match（`:127-128`），这里也现算，
            // 「今天在区间内」那句话本来就该随日期变。
            TimeSchemeManagementModel(
                schemes = current.timeSchemes,
                usage = usage,
                activeSchemeId = current.activeTimeSchemeId,
                locationGroupCount = current.locationTimeGroups.size,
                dateRuleCount = current.scheduleDateRules.size,
                hasActiveDateRule = ScheduleDateRuleLogic.match(
                    LocalDateTime.now(),
                    current.scheduleDateRules.map { it.toCalendarRule() },
                ) != null,
            )
        }
        model = next
    }

    val context = LocalContext.current
    val currentModel = model ?: TimeSchemeManagementModel()
    val coroutineScope = rememberCoroutineScope()
    val shareAdapter = remember(context) { AndroidTransferShareAdapter(context) }
    // 分享是「打包 + 写缓存 + 拉面板」一整串，连点两次会各拉一次面板；一个进行中的标记就够。
    var isSharing by remember { mutableStateOf(false) }

    var dialog by remember { mutableStateOf<TimeSchemeDialog>(TimeSchemeDialog.None) }
    // 新建成功后要直接进编辑器（Dart `_createScheme` 末尾 `_openEditor(scheme.id)`），
    // 但编辑器是**另一条壳路由**，所以用一次性意图把 id 带过去。
    fun toast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    /** 打包 / 分享失败 → 提示。码经 [TransferServiceMessages] 翻成人话（与数据备份页同口径）。 */
    fun showShareFailure(code: String) {
        toast(
            currentModel.sendFailedMessage(
                TransferServiceMessages.localize("transfer_send_${code.lowercase()}"),
            ),
        )
    }

    /** 单套模板的打包请求：scope 固定 TIME_TEMPLATE + 只点名这一套（Dart 同名参数）。 */
    fun shareRequest(schemeId: String, channel: TransferChannel): TransferPackageRequest =
        TransferPackageRequest(
            scope = TransferScope.TIME_TEMPLATE,
            channel = channel,
            packageId = TransferEnvelope.newPackageId(),
            now = LocalDateTime.now(),
            selectedTimeSchemeIds = setOf(schemeId),
        )

    /**
     * 系统分享单套模板（Dart `_shareTimeSchemeAsFile:896-940`）。
     *
     * 分享正文/主题取**本页自己的** ARB（`timeSchemeShareText(name)` /
     * `timeSchemeShareSubject`），不是数据备份页那两句：发布版这里就是模板页的文案，
     * 拼包结果 [TransferPackageResult.Success.shareText] 只服务备份页。
     */
    fun shareAsFile(schemeId: String) {
        val sheet = currentModel.shareSheet(schemeId) ?: return
        if (isSharing) return
        isSharing = true
        val snap = snapshot ?: repository.snapshot
        coroutineScope.launch {
            val failure = withContext(Dispatchers.IO) {
                when (
                    val built = DataTransferPackageLogic.build(
                        snapshot = snap,
                        request = shareRequest(schemeId, TransferChannel.FILE),
                    )
                ) {
                    is TransferPackageResult.Failure -> built.code
                    is TransferPackageResult.Success -> when (
                        val outcome = shareAdapter.share(
                            fileName = built.fileName,
                            content = built.json,
                            shareText = sheet.shareText,
                            shareSubject = sheet.shareSubject,
                        )
                    ) {
                        is AndroidTransferShareAdapter.Outcome.Launched -> null
                        is AndroidTransferShareAdapter.Outcome.Failed -> outcome.failure.name
                    }
                }
            }
            isSharing = false
            failure?.let(::showShareFailure)
        }
    }

    /**
     * 二维码分享单套模板（Dart `_shareTimeSchemeAsQr:943-989`）。
     *
     * 与数据备份页的二维码发送同一条路：打包 → `QrTransferSendSession.prepare` 预检资源上限
     * → 字节与标题写进 [TransferShellBridge] → 让壳跳 `g3.qrSend`。超限时**不跳页**，
     * 原地提示（Dart 同样是 preflight 抛 `QrTransferLimitException` 后只弹 toast）。
     */
    fun shareAsQr(schemeId: String) {
        val sheet = currentModel.shareSheet(schemeId) ?: return
        val requestQr = onRequestQrSend ?: return
        if (isSharing) return
        isSharing = true
        val snap = snapshot ?: repository.snapshot
        coroutineScope.launch {
            val result = withContext(Dispatchers.IO) {
                when (
                    val built = DataTransferPackageLogic.build(
                        snapshot = snap,
                        request = shareRequest(schemeId, TransferChannel.QR),
                    )
                ) {
                    is TransferPackageResult.Failure -> QrShareResult.Failure(built.code)
                    is TransferPackageResult.Success -> {
                        val bytes = built.json.toByteArray(Charsets.UTF_8)
                        if (QrTransferSendSession.prepare(bytes).overResourceLimit) {
                            QrShareResult.OverLimit
                        } else {
                            QrShareResult.Ready(bytes)
                        }
                    }
                }
            }
            isSharing = false
            when (result) {
                is QrShareResult.Failure -> showShareFailure(result.code)
                QrShareResult.OverLimit -> toast(currentModel.qrResourceLimitMessage)
                is QrShareResult.Ready -> {
                    TransferShellBridge.publishOutbound(result.bytes, sheet.title)
                    requestQr()
                }
            }
        }
    }

    fun openMenu(schemeId: String) {
        // 2026-11-10：分享项不再被过滤掉（打包器与分享适配器都已就绪，见文件头差异表）。
        val items = currentModel.menu(schemeId)
        if (items.isEmpty()) return
        val name = currentModel.row(schemeId)?.title.orEmpty()
        dialog = TimeSchemeDialog.Menu(TimeSchemeMenuState(schemeId = schemeId, schemeName = name, items = items))
    }

    fun dispatch(schemeId: String, action: TimeSchemeAction) {
        dialog = TimeSchemeDialog.None
        when (action) {
            TimeSchemeAction.VIEW_USAGE -> {
                currentModel.usageView(schemeId)?.let { dialog = TimeSchemeDialog.Usage(it) }
            }

            TimeSchemeAction.EDIT_SECTIONS -> onOpenEditor(schemeId)

            TimeSchemeAction.RENAME ->
                currentModel.renameSheet(schemeId)?.let {
                    dialog = TimeSchemeDialog.Name(
                        sheet = it,
                        mode = TimeSchemeNameMode.RENAME,
                        schemeId = schemeId,
                    )
                }

            TimeSchemeAction.DUPLICATE -> {
                val name = currentModel.copyName(currentModel.row(schemeId)?.title.orEmpty())
                val result = runCatching { repository.duplicateTimeScheme(schemeId, name) }
                result.onSuccess { copied ->
                    if (copied == null) {
                        toast(TimeSchemeManagementStrings.saveFailed.text)
                    } else {
                        toast(TimeSchemeManagementStrings.copiedTimeSchemeMessage.text)
                    }
                }.onFailure { toast(TimeSchemeManagementStrings.saveFailed.text) }
            }

            TimeSchemeAction.APPLY_TO_CURRENT -> {
                val result = runCatching { repository.applyTimeScheme(schemeId) }
                result.onSuccess { error ->
                    if (error == null) {
                        toast(currentModel.appliedMessage(schemeId))
                    } else {
                        toast(TimeSchemeServiceMessages.localize(error))
                    }
                }.onFailure { toast(TimeSchemeManagementStrings.saveFailed.text) }
            }

            TimeSchemeAction.DELETE -> {
                val check = currentModel.deleteCheck(schemeId) ?: return
                dialog = if (check.canDelete) {
                    TimeSchemeDialog.Delete(check)
                } else {
                    TimeSchemeDialog.DeleteBlocked(check)
                }
            }

            // 分享：先弹三选一（取消 / 二维码 / 系统文件），选定后才真打包
            // （Dart `_shareTimeScheme:851-893`；2026-11-10 接上，之前菜单里把这项剪掉了）。
            TimeSchemeAction.SHARE -> {
                currentModel.shareSheet(schemeId)?.let { sheet ->
                    dialog = TimeSchemeDialog.Share(sheet)
                }
            }
        }
    }

    TimeSchemeManagementPageHost(
        model = currentModel,
        isLoading = model == null,
        onBack = onBack,
        onCreate = {
            dialog = TimeSchemeDialog.Name(
                sheet = currentModel.createSheet,
                mode = TimeSchemeNameMode.CREATE,
                schemeId = null,
            )
        },
        onOpenMenu = { schemeId -> openMenu(schemeId) },
        onApply = { schemeId -> dispatch(schemeId, TimeSchemeAction.APPLY_TO_CURRENT) },
        onEditSections = { schemeId -> onOpenEditor(schemeId) },
        onOpenLocationEntry = onOpenLocationEntry,
        onOpenDateRules = onOpenDateRules,
    )

    // ---- 五个弹层全部常驻组合（2026-11-02 弹层债 #1）：原来的 `when (dialog)` 条件挂载，
    // 父级一翻 false 整棵弹层就离开组合，官方 260ms 退场动画一次都播不出来。
    // 可见性只交给各弹层内部的 `show`；退场期间的标题/正文由各弹层用 remember 保留的
    // 最后一份非空状态渲染，不会闪成空板（同 settings 弹窗常驻组合配方）。----
    val menuDialog = dialog as? TimeSchemeDialog.Menu
    TimeSchemeMenuSheet(
        state = menuDialog?.state,
        onDismiss = { dialog = TimeSchemeDialog.None },
        onAction = { action ->
            menuDialog?.let { dispatch(it.state.schemeId, action) }
        },
    )

    val nameDialog = dialog as? TimeSchemeDialog.Name
    TimeSchemeNameSheet(
        sheet = nameDialog?.sheet,
        onDismiss = { dialog = TimeSchemeDialog.None },
        onConfirm = { raw ->
            val state = nameDialog ?: return@TimeSchemeNameSheet
            dialog = TimeSchemeDialog.None
            val name = raw.trim()
            val error = currentModel.validateName(name)
            if (error != null) {
                toast(error)
                return@TimeSchemeNameSheet
            }
            if (state.mode == TimeSchemeNameMode.CREATE) {
                val result = runCatching { repository.createTimeScheme(name) }
                result.onSuccess { created ->
                    // Dart：新建后立刻进编辑器，把「建完什么都没发生」变成「建完就能填节次」。
                    onOpenEditor(created.id)
                }.onFailure {
                    toast(TimeSchemeManagementStrings.saveFailed.text)
                }
            } else {
                val schemeId = state.schemeId ?: return@TimeSchemeNameSheet
                if (name == state.sheet.initialName) return@TimeSchemeNameSheet
                val result = runCatching { repository.renameTimeScheme(schemeId, name) }
                result.onSuccess { renamed ->
                    if (renamed == null) {
                        toast(TimeSchemeManagementStrings.saveFailed.text)
                    } else {
                        toast(TimeSchemeManagementStrings.renamedToMessage.filled("name", name))
                    }
                }.onFailure { toast(TimeSchemeManagementStrings.saveFailed.text) }
            }
        },
    )

    val deleteDialog = dialog as? TimeSchemeDialog.Delete
    TimeSchemeDeleteSheet(
        check = deleteDialog?.check,
        onCancel = { dialog = TimeSchemeDialog.None },
        onConfirm = {
            val check = deleteDialog?.check ?: return@TimeSchemeDeleteSheet
            dialog = TimeSchemeDialog.None
            val result = runCatching { repository.deleteTimeScheme(check.schemeId) }
            result.onSuccess { deleted ->
                val name = currentModel.row(check.schemeId)?.title.orEmpty()
                toast(
                    if (deleted) {
                        TimeSchemeManagementStrings.deletedTimeSchemeMessage.filled("name", name)
                    } else {
                        TimeSchemeManagementStrings.timeSchemeInUseMessage.text
                    },
                )
            }.onFailure { toast(TimeSchemeManagementStrings.deleteFailed.text) }
        },
        onViewUsage = {
            deleteDialog?.check?.let { chk ->
                currentModel.usageView(chk.schemeId)?.let { dialog = TimeSchemeDialog.Usage(it) }
            }
        },
    )

    val blockedDialog = dialog as? TimeSchemeDialog.DeleteBlocked
    TimeSchemeDeleteBlockedSheet(
        check = blockedDialog?.check,
        onCancel = { dialog = TimeSchemeDialog.None },
        onViewUsage = {
            blockedDialog?.check?.let { chk ->
                currentModel.usageView(chk.schemeId)?.let { dialog = TimeSchemeDialog.Usage(it) }
            }
        },
    )

    val usageDialog = dialog as? TimeSchemeDialog.Usage
    TimeSchemeUsageSheet(
        view = usageDialog?.view,
        onClose = { dialog = TimeSchemeDialog.None },
    )

    val shareDialog = dialog as? TimeSchemeDialog.Share
    TimeSchemeShareSheetDialog(
        sheet = shareDialog?.sheet,
        // 壳没给 `onRequestQrSend`（路由表那一行属 Lead）时，二维码入口不出现；
        // 系统分享那条走本文件 + 现成适配器，壳零改动就能用。
        qrEnabled = onRequestQrSend != null,
        onDismiss = { dialog = TimeSchemeDialog.None },
        onShareSystem = {
            val schemeId = shareDialog?.sheet?.schemeId ?: return@TimeSchemeShareSheetDialog
            dialog = TimeSchemeDialog.None
            shareAsFile(schemeId)
        },
        onShareQr = {
            val schemeId = shareDialog?.sheet?.schemeId ?: return@TimeSchemeShareSheetDialog
            dialog = TimeSchemeDialog.None
            shareAsQr(schemeId)
        },
    )
}

/** 列表页宿主的渲染转接：把 `TimeSchemeManagementPage` 的入参一次性摊开，避免宿主里出现长参数块。 */
@Composable
private fun TimeSchemeManagementPageHost(
    model: TimeSchemeManagementModel,
    isLoading: Boolean,
    onBack: () -> Unit,
    onCreate: () -> Unit,
    onOpenMenu: (String) -> Unit,
    onApply: (String) -> Unit,
    onEditSections: (String) -> Unit,
    onOpenLocationEntry: () -> Unit,
    onOpenDateRules: () -> Unit,
) {
    com.mutx163.qingyu.pages.time_scheme.TimeSchemeManagementPage(
        model = model,
        isLoading = isLoading,
        onBack = onBack,
        onCreate = onCreate,
        onOpenMenu = onOpenMenu,
        onApply = onApply,
        onEditSections = onEditSections,
        onOpenLocationEntry = onOpenLocationEntry,
        onOpenDateRules = onOpenDateRules,
    )
}

/** 列表页当前打开的弹层。`None` 与「弹层自己关掉」区分开，避免渲染层拿 null 猜语义。 */
private sealed interface TimeSchemeDialog {
    data object None : TimeSchemeDialog
    data class Menu(val state: TimeSchemeMenuState) : TimeSchemeDialog
    data class Name(
        val sheet: TimeSchemeSheet,
        val mode: TimeSchemeNameMode,
        val schemeId: String?,
    ) : TimeSchemeDialog

    data class Delete(val check: TimeSchemeDeleteCheck) : TimeSchemeDialog
    data class DeleteBlocked(val check: TimeSchemeDeleteCheck) : TimeSchemeDialog
    data class Usage(val view: TimeSchemeUsageView) : TimeSchemeDialog

    /** 分享三选一（取消 / 二维码 / 系统文件）。 */
    data class Share(val sheet: TimeSchemeShareSheet) : TimeSchemeDialog
}

/** 二维码分享的预检结果（超限时不动页面，原地提示）。 */
private sealed interface QrShareResult {
    data class Ready(val bytes: ByteArray) : QrShareResult
    data object OverLimit : QrShareResult
    data class Failure(val code: String) : QrShareResult
}

/** 输入弹层的两个用途：新建（提交后进编辑器）与重命名（提交后只提示）。 */
private enum class TimeSchemeNameMode { CREATE, RENAME }

// ────────────────────────────── 编辑节次页 ──────────────────────────────

/**
 * 编辑节次页宿主（`d3.timeSchemeEditor`）。
 *
 * ## 状态分两层，别合并
 *
 * - **name / sections** 是用户在页面上正在编辑的东西，属于本页局部状态（Dart 同样是
 *   `TextEditingController` + `_sections` 两个 State 字段）⇒ 用 `remember` 持有；
 * - **usage / 当前是否生效 / 模板清单** 是仓储派生的东西（Dart 每次 build 从 provider 现算）
 *   ⇒ 快照一变就 `withUsage` 刷进来，**不覆盖**用户正在改的节次。
 *
 * 这两层混在一起会出现「改了一半的节次被一次仓储通知冲掉」或「改完保存后影响提示不更新」，
 * 两种都很难查。
 *
 * @param schemeId 要编辑哪一套（由 `ShellWiring.pendingTimeSchemeEditId` 带过来）。
 */
@Composable
fun TimeSchemeEditorHost(
    repository: TimetableRepository,
    schemeId: String,
    onBack: () -> Unit,
) {
    var snapshot by remember(repository) { mutableStateOf(repository.snapshot) }
    DisposableEffect(repository) {
        val subscription = repository.observe { updated -> snapshot = updated }
        onDispose { subscription.close() }
    }

    val context = LocalContext.current
    val usage = remember(snapshot) {
        TimeSchemeUsageIndexFactory.build(
            schemes = snapshot.timeSchemes,
            profiles = snapshot.profiles,
            locationGroups = snapshot.locationTimeGroups,
            dateRules = snapshot.scheduleDateRules,
        )
    }

    // 只初始化一次：`schemeId` 变了（换一套模板）才重建，仓储通知不重建。
    var model by remember(schemeId) {
        mutableStateOf(
            TimeSchemeEditorModel.from(
                schemes = repository.snapshot.timeSchemes,
                activeSchemeId = repository.snapshot.activeTimeSchemeId,
                usage = usage,
                schemeId = schemeId,
            ),
        )
    }

    // 派生输入刷新（不动 name/sections）。
    LaunchedEffect(usage, snapshot.activeTimeSchemeId, snapshot.timeSchemes) {
        model = model?.withUsage(usage, snapshot.timeSchemes, snapshot.activeTimeSchemeId)
    }

    val current = model
    if (current == null) {
        // 打开时这套模板已经不在了（别处删掉 / 备份恢复换了一份）：没有可编辑对象就退回，
        // 不要渲染一个空壳页面。用 effect 里回调，避免在组合期直接触发导航。
        LaunchedEffect(schemeId) { onBack() }
        return
    }

    fun toast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    var pickPhase by remember { mutableStateOf<SectionPickPhase>(SectionPickPhase.None) }
    var quickGenerateVisible by remember { mutableStateOf(false) }

    TimeSchemeEditorPage(
        model = current,
        onBack = onBack,
        onNameChange = { value -> model = model?.withName(value) },
        onSave = {
            val validation = current.validateForSave()
            if (validation != null) {
                toast(validation)
            } else {
                val result = runCatching {
                    repository.updateTimeScheme(
                        schemeId = schemeId,
                        name = current.name.trim(),
                        sections = current.sections,
                    )
                }
                result.onSuccess { code ->
                    if (code == null) {
                        onBack()
                    } else {
                        toast(TimeSchemeServiceMessages.localize(code))
                    }
                }.onFailure { toast(TimeSchemeManagementStrings.saveFailed.text) }
            }
        },
        onPickSectionTime = { index ->
            val stored = current.sections.getOrNull(index) ?: return@TimeSchemeEditorPage
            pickPhase = SectionPickPhase.Start(index, stored)
        },
        onAddSection = { model = model?.addSection() },
        onRemoveLastSection = { model = model?.removeLastSection() },
        onResetSections = { model = model?.resetSections() },
        onOpenQuickGenerate = { quickGenerateVisible = true },
    )

    TimeSchemeQuickGenerateSheet(
        visible = quickGenerateVisible,
        initialPreset = current.lastQuickGeneratePreset,
        onDismiss = { quickGenerateVisible = false },
        onConfirm = { preset ->
            quickGenerateVisible = false
            runCatching { preset.toSections() }
                .onSuccess { sections -> model = model?.withSections(sections) }
                .onFailure { error ->
                    // `buildQuickSectionTimes` 抛的是 DartFormatException（消息就是服务消息码）。
                    toast(TimeSchemeServiceMessages.localize(error.message))
                }
        },
    )

    // ── 单节时间：开始 → 结束 两跳（Dart `_editSectionTime:1400-1450`） ──
    // 两个选择器也常驻组合（2026-11-02 弹层债 #2）：`when (pickPhase)` 条件挂载同样杀退场
    // 动画。`show` 由相位驱动；`initial` 用 [rememberLastNonNull] 钉住最后一份非空相位，
    // 退场期间滚轮不会被重铺成空值。
    val startPick = pickPhase as? SectionPickPhase.Start
    val endPick = pickPhase as? SectionPickPhase.End

    SchemeTimePickerSheet(
        show = startPick != null,
        title = TimeSchemeManagementStrings.selectStartTimeTitle.text,
        initial = rememberLastNonNull(startPick)?.section?.startTime.orEmpty(),
        onDismiss = { pickPhase = SectionPickPhase.None },
        onConfirm = { start ->
            val phase = startPick ?: return@SchemeTimePickerSheet
            pickPhase = SectionPickPhase.End(phase.index, phase.section, start)
        },
    )

    SchemeTimePickerSheet(
        show = endPick != null,
        title = TimeSchemeManagementStrings.selectEndTimeTitle.text,
        initial = rememberLastNonNull(endPick)?.section?.endTime.orEmpty(),
        onDismiss = { pickPhase = SectionPickPhase.None },
        onConfirm = { pickedEnd ->
            val phase = endPick ?: return@SchemeTimePickerSheet
            pickPhase = SectionPickPhase.None
            // Dart `resolveSectionEndTimeEdit`：选择器小时上限 23 表达不了 24:00，
            // 用户没动结束时间时要把这个哨兵认回来，否则「只想改开始时间」会顺手把 24:00 改成 00:00。
            val end = TimeSchemeSectionEdit.resolveEndTimeEdit(
                storedEndTime = phase.section.endTime,
                pickedEndTime = pickedEnd,
            )
            val outcome = model?.withSectionTime(phase.index, phase.start, end)
            if (outcome != null) {
                model = outcome.model
                outcome.message?.let { toast(it) }
            }
        },
    )
}

/** 单节时间选择的两跳状态。`End` 里要带着已经选好的开始时间。 */
private sealed interface SectionPickPhase {
    data object None : SectionPickPhase
    data class Start(val index: Int, val section: SectionTime) : SectionPickPhase
    data class End(val index: Int, val section: SectionTime, val start: String) : SectionPickPhase
}

/**
 * 时间选择弹层：时 0-23 / 分 0-59（步长 5），官方 `NumberPicker` 两列。
 *
 * 与 Flutter `showMiuixTimePickerSheet` 同口径：**小时上限 23**（表达不了 24:00，
 * 那个哨兵由调用点的 `resolveEndTimeEdit` 认回来）。分钟按 5 分钟一档，与 Dart 同款，
 * 免得用户在一小时的 60 个格子里滚。
 */
@Composable
private fun SchemeTimePickerSheet(
    show: Boolean,
    title: String,
    initial: String,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    val parsed = remember(initial) { parseClockOrDefault(initial) }
    var hour by remember(show, initial) { mutableIntStateOf(parsed.first) }
    var minuteIndex by remember(show, initial) { mutableIntStateOf(parsed.second / MINUTE_STEP) }

    QingyuSheet(
        show = show,
        title = title,
        onDismissRequest = onDismiss,
        // 横向内边距由框架侧统一给 16dp，与标题行落在同一条竖线上。原来的写法是
        // 「内容自带 16 + 框架侧归零」，标题行跟着归零、长标题会顶到面板边（弹层债 #5 同款）。
        contentPadsHorizontally = false,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(220.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                NumberPicker(
                    value = hour,
                    onValueChange = { hour = it },
                    range = 0..23,
                    wrapAround = true,
                    // Dart `miuix_time_picker_sheet.dart:91/102` 的 label 就是 `_twoDigits`：
                    // 只显示两位数字，不带「时 / 分」后缀（那两个字在 ARB 里没有键，屏上也不该出现）。
                    label = { it.toString().padStart(2, '0') },
                    // 220dp + title3 SEMIBOLD 与 SettingsHost 的「每天更新时刻」滚轮同款
                    // （Dart 同弹层就是 title3 + w600）；走 shiftWeight 才不会被用户字重盖掉。
                    textStyle = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    modifier = Modifier.weight(1f),
                )
                NumberPicker(
                    value = minuteIndex,
                    onValueChange = { minuteIndex = it },
                    range = 0 until (60 / MINUTE_STEP),
                    wrapAround = true,
                    label = { (it * MINUTE_STEP).toString().padStart(2, '0') },
                    textStyle = MiuixTheme.textStyles.title3.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    modifier = Modifier.weight(1f),
                )
            }
            Spacer(modifier = Modifier.height(16.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                TextButton(
                    modifier = Modifier.weight(1f),
                    text = TimeSchemeManagementStrings.cancelAction.text,
                    onClick = onDismiss,
                )
                Button(
                    modifier = Modifier.weight(1f),
                    onClick = {
                        val minute = (minuteIndex * MINUTE_STEP).toString().padStart(2, '0')
                        onConfirm("${hour.toString().padStart(2, '0')}:$minute")
                    },
                    // 弹层的主出口（不是取消）⇒ 强调色；默认 `buttonColors()` 是灰的
                    // `secondaryVariant`，读起来像禁用（Dart 用 primary 变体）。
                    colors = ButtonDefaults.buttonColorsPrimary(),
                ) {
                    // Dart 同位置（`miuix_time_picker_sheet.dart:124`）用的是 confirmAction
                    //（「确认」），不是 saveAction（「保存」）——弹层债 #4，这里对齐。
                    Text(text = TimeSchemeManagementStrings.confirmAction.text)
                }
            }
        }
    }
}

private const val MINUTE_STEP = 5

/**
 * 退场期保留最后一份非空状态：[current] 变 null 后仍返回上一次的非空值。
 *
 * 弹层常驻组合后，`show` 归 false 的退场动画期间内容还会被组合——直接读可空相位
 * 会把滚轮初值重铺成空。这里用 remember 钉住最后一份非空状态（与 settings 弹窗
 * 「常驻组合」笔记同配方）。
 */
@Composable
private fun <T : Any> rememberLastNonNull(current: T?): T? {
    var shown by remember { mutableStateOf(current) }
    if (current != null) {
        shown = current
    }
    return shown
}

/**
 * 容错解析 `HH:MM`。
 *
 * 坏值退回 00:00 而不是抛：`SectionTime.fromJson` 只要求"非空字符串"，外来备份里的
 * `"08.30"` / `"上午8点"` 都能进库（Dart `_parseTimeOfDay` 的注释记着这个坑：
 * 裸 `int.parse` 一抛，被 async 吞掉后表现为「点某一节的时间没反应」）。
 */
private fun parseClockOrDefault(value: String): Pair<Int, Int> {
    val parts = value.split(":")
    if (parts.size != 2) return 0 to 0
    val hour = parts[0].toIntOrNull() ?: return 0 to 0
    val minute = parts[1].toIntOrNull() ?: return 0 to 0
    if (hour !in 0..24 || minute !in 0..59) return 0 to 0
    // 24:00 是「当天结束」哨兵，选择器表达不了 → 显示 00:00（与 Dart 同口径）。
    if (hour == 24) return 0 to 0
    return hour to (minute / MINUTE_STEP) * MINUTE_STEP
}

/**
 * 把仓储里的 `core.ScheduleDateRule` 桥成 `calendar.ScheduleDateRule`。
 *
 * 本仓有两份同形模型：`core/` 那份是落盘真源（`TimetableSnapshot.scheduleDateRules`），
 * `calendar/` 那份是日期规则页与 `ScheduleDateRuleLogic` 的入参，目前**没有现成转换函数**。
 * 这里只做字段搬运，**不复制判据**——「今天落在哪条规则里」仍然只有
 * `ScheduleDateRuleLogic.match` 这一份实现（复制一套的话，两处早晚会漂）。
 */
private fun com.mutx163.qingyu.core.ScheduleDateRule.toCalendarRule(): com.mutx163.qingyu.calendar.ScheduleDateRule =
    com.mutx163.qingyu.calendar.ScheduleDateRule(
        id = id,
        name = name,
        timeSchemeId = timeSchemeId,
        enabled = enabled,
        startDate = startDate,
        endDate = endDate,
    )
