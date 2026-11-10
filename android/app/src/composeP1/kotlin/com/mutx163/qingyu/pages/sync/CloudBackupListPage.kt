package com.mutx163.qingyu.pages.sync

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuEmptyState
import com.mutx163.qingyu.components.QingyuLoadingCenter
import com.mutx163.qingyu.components.QingyuLoadingInButton
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Backup
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 云备份列表页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/cloud_backup_list_screen.dart`：
 * - 顶栏：返回 + 「备份版本」
 * - 加载中：居中进度圈
 * - 空列表：居中「还没有备份版本」
 * - 非空：「立即备份」按钮卡 + 每条备份一行（标题 / 副标题 / 当前徽标 / 右箭头）
 *
 * 页内**不做业务判断**：显隐、排序、标题、副标题、徽标全部来自
 * [CloudBackupListViewState]（模型层 [CloudBackupListLogic] 组装）。
 */
@Composable
fun CloudBackupListPage(
    viewState: CloudBackupListViewState,
    onBack: () -> Unit,
    onCreateBackup: () -> Unit,
    onOpenBackup: (entryId: String) -> Unit,
    onUndoRestore: () -> Unit,
    // 刷新失败重试（成员八复核④；2026-11-06 第三轮返工①改语义）：errorText 在
    // **两个状态**都可能有值（模型层 errorCode 有值即透出）——空态分支用失败原因
    // 替代「为什么空」+ 重试；非空分支顶部出轻量错误条 + 重试（列表照常展示缓存）。
    onRetryRefresh: () -> Unit = {},
) {
    val dark = isSystemInDarkTheme()

    QingyuPageScaffold(title = viewState.title, onBack = onBack, smallTopBar = true) {
        // 2026-11-10 顶栏渐变模糊修正：内容统一进 QingyuPageList 并吃 innerPadding，才能滚进顶栏带、
        // 让模糊采样到真实像素（此前 innerPadding 吃在外层 Column 上，列表视口整体落在栏下方，
        // 顶栏带只剩一片纯背景 —— 用户真机日报「云同步页顶栏和其他页不一样」）。
        //
        // 撤销恢复卡改列表首项：发布版它本来就在列表流里（`cloud_sync_screen.dart` 备份组同区），
        // 空态 / 加载中同样能看到（不再像旧的列表外常驻条那样挡住顶栏采样）。
        QingyuPageList(
            innerPadding = innerPadding,
            horizontalPadding = 16.dp,
            contentPadding = PaddingValues(top = 4.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (viewState.canUndoRestore) {
                item(key = "undo_restore") {
                    CloudRestoreUndoCard(
                        title = viewState.undoRestoreTitle,
                        summary = viewState.undoRestoreSummary,
                        actionLabel = viewState.undoRestoreActionLabel,
                        onUndo = onUndoRestore,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            when {
                viewState.isLoading -> item(key = "loading") {
                    // 档 A2：块内居中转圈（列表里不能 fillMaxSize）。
                    QingyuLoadingCenter(fillPage = false)
                }

                viewState.isEmpty -> item(key = "empty") {
                    if (viewState.errorText != null) {
                        // 拉取失败时换成「为什么空」（断网 / 密码失效），不把失败说成「还没有备份」。
                        // 2026-11-06 第三轮返工①后的模型口径：errorText **有 errorCode 即透出**、
                        // 不再按「列表是否为空」过滤——空态与非空列表都要有可见出口。空态分支
                        // 的出口 = 失败原因 + 显式「重试」（cloudBackupRetryAction）；纯空态
                        // 仍是静态文字；非空列表的出口见下方错误条窗口。
                        val error = viewState.errorText
                        QingyuEmptyState(
                            icon = MiuixIcons.Info,
                            title = error,
                            action = {
                                Button(
                                    onClick = onRetryRefresh,
                                    colors = ButtonDefaults.buttonColors(),
                                ) {
                                    Text(text = SyncStrings.cloudBackupRetryAction.text)
                                }
                            },
                        )
                    } else {
                        QingyuEmptyState(
                            icon = MiuixIcons.Backup,
                            title = viewState.emptyText,
                        )
                    }
                }

                else -> {
                    // 刷新失败可见（2026-11-06 第三轮返工①）：errorText 有值 = 本次刷新
                    // 失败，列表是**上次拉到的缓存**——顶部轻量错误条 + 重试，列表照常
                    // 展示。「有缓存就静默用缓存」被 hy1 推翻：那正是最初审核的 S2 原病
                    // （刷新失败完全静默），失败必须有可见出口。
                    viewState.errorText?.let { error ->
                        item(key = "refresh_error_bar") {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(Color(QingyuTheme.error(dark)).copy(alpha = 0.12f))
                                    .clickable(onClick = onRetryRefresh)
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(
                                    text = error,
                                    style = MiuixTheme.textStyles.footnote1,
                                    color = Color(QingyuTheme.error(dark)),
                                    modifier = Modifier.weight(1f),
                                )
                                Text(
                                    text = SyncStrings.cloudBackupRetryAction.text,
                                    style = MiuixTheme.textStyles.footnote1
                                        .shiftWeight(QingyuWeightDelta.SEMIBOLD),
                                    color = Color(QingyuTheme.error(dark)),
                                )
                                Icon(
                                    imageVector = MiuixIcons.Refresh,
                                    contentDescription = null,
                                    tint = Color(QingyuTheme.error(dark)),
                                    modifier = Modifier.size(18.dp),
                                )
                            }
                        }
                    }

                    item(key = "create_backup") {
                        QingyuCard(
                            modifier = Modifier.fillMaxWidth(),
                            insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
                        ) {
                            Button(
                                onClick = onCreateBackup,
                                enabled = !viewState.isCreatingBackup,
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                if (viewState.isCreatingBackup) {
                                    QingyuLoadingInButton()
                                    Spacer(modifier = Modifier.width(8.dp))
                                }
                                Text(text = viewState.createLabel)
                            }
                        }
                    }

                    items(viewState.rows, key = { it.entryId }) { row ->
                        CloudBackupRowCard(row = row, dark = dark, onClick = { onOpenBackup(row.entryId) })
                    }
                }
            }
        }
    }
}

@Composable
private fun CloudBackupRowCard(
    row: CloudBackupRowView,
    dark: Boolean,
    onClick: () -> Unit,
) {
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = row.title,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = row.subtitle,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }

            // 「当前」徽标：只有当前版本才有（模型层给 null 时整块不渲染）。
            row.details?.let { badge ->
                Text(
                    text = badge,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primary(dark = dark)),
                    modifier = Modifier
                        .clip(RoundedCornerShape(4.dp))
                        .padding(horizontal = 6.dp, vertical = 2.dp),
                )
            }

            Icon(
                imageVector = MiuixIcons.ChevronForward,
                contentDescription = null,
                tint = Color(QingyuTheme.actionIcon(dark)),
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

/**
 * 「撤销上一次恢复」卡片（云同步页与备份列表页共用）。
 *
 * 显隐判据由调用方的 viewState `canUndoRestore` 给，渲染层不自己判断
 * 「有没有撤销点」；没有撤销点时整块不组合。
 */
@Composable
fun CloudRestoreUndoCard(
    title: String,
    summary: String,
    actionLabel: String,
    onUndo: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        insideMargin = PaddingValues(horizontal = 14.dp, vertical = 12.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = Color(QingyuTheme.primaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = summary,
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            TextButton(
                text = actionLabel,
                onClick = onUndo,
            )
        }
    }
}

/** 详情弹框里「恢复 / 删除」两个动作的按钮组（宿主用 bottom sheet 承载）。 */
@Composable
fun CloudBackupDetailActions(
    detail: CloudBackupDetailView,
    onRestore: () -> Unit,
    onDelete: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Button(onClick = onRestore, modifier = Modifier.fillMaxWidth()) {
            Text(text = SyncStrings.cloudBackupRestoreAction.text)
        }
        if (detail.canDelete) {
            TextButton(
                text = SyncStrings.deleteAction.text,
                onClick = onDelete,
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

/** 详情弹框正文（当前版本 / 时间 + 设备 + 来源 + 内容）。 */
@Composable
fun CloudBackupDetailBody(detail: CloudBackupDetailView, dark: Boolean) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = detail.title,
            style = MiuixTheme.textStyles.title4.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = Color(QingyuTheme.primaryText(dark)),
        )
        Spacer(modifier = Modifier.height(10.dp))
        DetailLine(detail.deviceLine, dark)
        Spacer(modifier = Modifier.height(6.dp))
        DetailLine(detail.sourceLine, dark)
        detail.summaryLine?.let { line ->
            Spacer(modifier = Modifier.height(6.dp))
            DetailLine(line, dark)
        }
    }
}

@Composable
private fun DetailLine(text: String, dark: Boolean) {
    Text(
        text = text,
        style = MiuixTheme.textStyles.footnote1,
        color = Color(QingyuTheme.secondaryText(dark)),
    )
}

// ─────────────────────────────────────────────────────────────────────────────
// IDE 预览（2026-11-08）
//
// 只给实现阶段看效果，不进业务路径。覆盖两个维度：
//
//   数据状态 4 档：有备份（可撤销恢复）/ 空列表 / 加载中 / 刷新失败（列表留着缓存）；
//   外观 3 档：亮色、暗色、大字号 1.3。
//
// 为什么偏偏是这几档：
//   · 空列表 —— 只有「还没有备份版本」一句，没有按钮，最容易被改错成不可操作；
//   · 刷新失败 —— errorText 在两个分支都要有出口：空态顶替空文案 + 重试，
//     非空列表顶部出轻量错误条 + 重试（列表照常画缓存）；
//   · 可撤销恢复 —— 撤销卡在列表**外面**，空态 / 加载中也要能看见；
//   · 暗色 / 大字号 —— 页面取色走 isSystemInDarkTheme()，只有 QingyuPageTheme 会把
//     LocalConfiguration 的 uiMode 一起改写；行内文案的折行点只在字放大后才暴露。
//
// 固定写法：主题一律 QingyuPageTheme(isDark = …)、字号走 textScale 参数
//（@Preview(fontScale = …) 绕过了应用的 appTextScale 口径）；宽度按 400dp（本仓折行实测口径）。
//
// 数据一律走 `CloudBackupListLogic.buildListViewState`，不手工拼 viewState：
// 排序、当前版本徽标、副标题都在模型层算，手工拼等于绕过被测代码。
// ─────────────────────────────────────────────────────────────────────────────

/** 预览用三份备份：当前版本 + 两台设备的旧备份，全用中文实义值。 */
private fun previewBackupEntries(): List<CloudBackupEntryModel> = listOf(
    CloudBackupEntryModel(
        id = "backup-current",
        fileName = "history/2026-11-08T09-12.mikcb",
        exportedAtIso = "2026-11-08T09:12:00",
        contentSha256 = "a1b2c3d4",
        deviceId = "device-demo-1",
        deviceLabel = "示例手机",
        appVersion = "1.0.0",
        isCurrent = true,
        source = CloudBackupSource.MANUAL,
        profileCount = 3,
        courseCount = 42,
    ),
    CloudBackupEntryModel(
        id = "backup-2",
        fileName = "history/2026-11-07T21-40.mikcb",
        exportedAtIso = "2026-11-07T21:40:00",
        contentSha256 = "e5f6a7b8",
        deviceId = "device-demo-2",
        deviceLabel = "示例平板",
        appVersion = "1.0.0",
        isCurrent = false,
        source = CloudBackupSource.AUTO,
        profileCount = 2,
        courseCount = 36,
    ),
    CloudBackupEntryModel(
        id = "backup-3",
        fileName = "history/2026-11-06T07-05.mikcb",
        exportedAtIso = "2026-11-06T07:05:00",
        contentSha256 = "c9d0e1f2",
        deviceId = "device-demo-1",
        deviceLabel = "示例手机",
        appVersion = "0.9.8",
        isCurrent = false,
        source = CloudBackupSource.AUTO,
        profileCount = 2,
        courseCount = 30,
    ),
)

/** 一档预览：模型层输入；[name] 只用来给预览命名，不参与渲染。 */
private data class PreviewBackupListState(
    val name: String,
    val entries: List<CloudBackupEntryModel>,
    val isLoading: Boolean = false,
    val isCreatingBackup: Boolean = false,
    val errorCode: String? = null,
    val canUndoRestore: Boolean = false,
)

private val previewBackupListStates: List<PreviewBackupListState> = listOf(
    PreviewBackupListState(
        name = "有备份·可撤销恢复",
        entries = previewBackupEntries(),
        canUndoRestore = true,
    ),
    PreviewBackupListState(
        name = "空列表",
        entries = emptyList(),
    ),
    PreviewBackupListState(
        name = "加载中",
        entries = emptyList(),
        isLoading = true,
    ),
    PreviewBackupListState(
        name = "刷新失败·留着缓存",
        entries = previewBackupEntries(),
        errorCode = "connection_timeout",
    ),
)

private fun previewBackupListState(name: String): PreviewBackupListState =
    previewBackupListStates.first { it.name == name }

/** 一档预览的公共身体：数据状态 + 外观档位。 */
@Composable
private fun PreviewCloudBackupListPage(
    state: PreviewBackupListState,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        CloudBackupListPage(
            viewState = CloudBackupListLogic.buildListViewState(
                entries = state.entries,
                isLoading = state.isLoading,
                isCreatingBackup = state.isCreatingBackup,
                errorCode = state.errorCode,
                canUndoRestore = state.canUndoRestore,
            ),
            onBack = {},
            onCreateBackup = {},
            onOpenBackup = {},
            onUndoRestore = {},
            onRetryRefresh = {},
        )
    }
}

// ── 单档：四态 × 亮色 ──────────────────────────────────────────────────────

@Suppress("unused")
@Preview(name = "1 有备份·可撤销恢复", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudBackupListPagePreviewData() {
    PreviewCloudBackupListPage(previewBackupListState("有备份·可撤销恢复"))
}

@Suppress("unused")
@Preview(name = "2 空列表", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudBackupListPagePreviewEmpty() {
    PreviewCloudBackupListPage(previewBackupListState("空列表"))
}

@Suppress("unused")
@Preview(name = "3 加载中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudBackupListPagePreviewLoading() {
    PreviewCloudBackupListPage(previewBackupListState("加载中"))
}

@Suppress("unused")
@Preview(name = "4 刷新失败·留着缓存", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudBackupListPagePreviewRefreshFailed() {
    PreviewCloudBackupListPage(previewBackupListState("刷新失败·留着缓存"))
}

// ── 单档：外观两档（以「有备份」为基准）─────────────────────────────────────

@Suppress("unused")
@Preview(name = "5 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudBackupListPagePreviewDark() {
    PreviewCloudBackupListPage(previewBackupListState("有备份·可撤销恢复"), dark = true)
}

@Suppress("unused")
@Preview(name = "6 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun CloudBackupListPagePreviewLargeText() {
    PreviewCloudBackupListPage(previewBackupListState("有备份·可撤销恢复"), textScale = 1.3f)
}

// ── 总览：四态并排，一屏看完 ────────────────────────────────────────────────

/**
 * 一屏总览：四种状态横向并排，用来一眼比结构差异（撤销卡 / 错误条 / 进度圈谁在）。
 *
 * 4 × 400dp + 3 × 16dp 间距 = 1648dp，所以画布给 1700dp。Studio 会等比缩小显示，
 * **缩放后字看不清是正常的**——要看细节点上面 1~6 的单档标签。
 */
@Suppress("unused")
@Preview(name = "0 总览·四态并排", showBackground = true, widthDp = 1700, heightDp = 900)
@Composable
private fun CloudBackupListPagePreviewOverview() {
    Row(
        modifier = Modifier.fillMaxSize(),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        for (state in previewBackupListStates) {
            Box(Modifier.width(400.dp).fillMaxHeight()) {
                PreviewCloudBackupListPage(state)
            }
        }
    }
}
