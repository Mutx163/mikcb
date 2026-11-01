package com.mutx163.qingyu.pages.sync

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.CircularProgressIndicator
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.ChevronForward
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
) {
    val dark = isSystemInDarkTheme()

    QingyuPageScaffold(title = viewState.title, onBack = onBack, smallTopBar = true) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {

            when {
                viewState.isLoading -> Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    CircularProgressIndicator()
                }

                viewState.isEmpty -> Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(24.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = viewState.emptyText,
                        style = MiuixTheme.textStyles.body1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                }

                else -> QingyuPageList(
                    innerPadding = PaddingValues(0.dp),
                    horizontalPadding = 16.dp,
                    contentPadding = PaddingValues(top = 4.dp, bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
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
                                    CircularProgressIndicator(size = 16.dp, strokeWidth = 2.dp)
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
            Text(text = SyncStrings.cloudBackupRestoreAction.zh)
        }
        if (detail.canDelete) {
            TextButton(
                text = SyncStrings.deleteAction.zh,
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
