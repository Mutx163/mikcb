package com.mutx163.qingyu.pages.import.warehouse

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import com.mutx163.qingyu.components.QingyuBackIconButton
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.SmallTopAppBar
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Refresh
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 教务网页登录与脚本执行容器页 · Compose 渲染层（P3-G2）。
 * 对应 Flutter `lib/screens/import/warehouse/warehouse_adapter_web_login_screen.dart`：
 * 1. 顶栏操作：刷新、桌面/移动版切换、更多（复制地址/浏览器打开）；
 * 2. 教务会话状态提示与已存账号自动填入浮条；
 * 3. 宏录制状态与底部动作栏（开始/结束录制、执行导入脚本）。
 */
@Composable
fun WarehouseWebLoginPage(
    title: String,
    sessionState: WarehouseWebLoginSessionState,
    onBack: () -> Unit = {},
    onReload: () -> Unit = {},
    onToggleDesktopMode: () -> Unit = {},
    onMoreOptions: () -> Unit = {},
    onAutofillLogin: () -> Unit = {},
    onDismissAutofill: () -> Unit = {},
    onSaveRememberedLogin: () -> Unit = {},
    onDismissSaveLogin: () -> Unit = {},
    onToggleMacroRecording: () -> Unit = {},
    onExecuteImport: () -> Unit = {},
) {
    Scaffold(
        topBar = {
            // 与 Dart 侧 warehouse_adapter_web_login_screen.dart:841-844 对齐
            // （title: SizedBox.shrink()、collapsibleLargeTitle: false）：这一页滚动发生在 WebView
            // 内部，大标题永远不会被收起，只会常驻占掉一行高度；用官方「无大标题」变体钉死，
            // 不会漏出大标题。
            SmallTopAppBar(
                title = title,
                navigationIcon = {
                    QingyuBackIconButton(
                        onBack = onBack,
                        contentDescription = WarehouseStrings.cancelAction.zh,
                    )
                },
                actions = {
                    IconButton(onClick = onReload) {
                        Icon(imageVector = MiuixIcons.Refresh, contentDescription = WarehouseStrings.reloadAction.zh)
                    }
                    IconButton(onClick = onMoreOptions) {
                        Icon(imageVector = MiuixIcons.More, contentDescription = WarehouseStrings.moreActionsTooltip.zh)
                    }
                }
            )
        },
        bottomBar = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MiuixTheme.colorScheme.surface)
                    .padding(horizontal = 16.dp, vertical = 12.dp)
            ) {
                // 账号自动填充提示
                if (sessionState.shouldPromptAutofill) {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 10.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = WarehouseStrings.rememberedAccountLabel.filled(
                                    "username",
                                    sessionState.rememberedAccount?.username.orEmpty()
                                ),
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Medium
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(
                                    onClick = onDismissAutofill,
                                    content = { Text(text = WarehouseStrings.notNowAction.zh) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.surfaceVariant,
                                        contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions
                                    )
                                )
                                Button(
                                    onClick = onAutofillLogin,
                                    content = { Text(text = WarehouseStrings.autofillAction.zh) }
                                )
                            }
                        }
                    }
                }

                // 凭据保存提示
                if (sessionState.shouldPromptSave) {
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 10.dp)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = WarehouseStrings.rememberPasswordTitle.zh,
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Medium
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(
                                    onClick = onDismissSaveLogin,
                                    content = { Text(text = WarehouseStrings.dontRememberAction.zh) },
                                    colors = ButtonDefaults.buttonColors(
                                        color = MiuixTheme.colorScheme.surfaceVariant,
                                        contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions
                                    )
                                )
                                Button(
                                    onClick = onSaveRememberedLogin,
                                    content = { Text(text = WarehouseStrings.rememberAndAutofillAction.zh) }
                                )
                            }
                        }
                    }
                }

                // 底部操作主按钮
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    val isRecording = sessionState.macroState == WarehouseMacroActionState.RECORDING
                    Button(
                        onClick = onToggleMacroRecording,
                        modifier = Modifier.weight(1f),
                        content = { Text(text = if (isRecording) {
                            "停止录制 (${sessionState.recordedStepsCount})"
                        } else {
                            WarehouseStrings.recordImportAction.zh
                        }) },
                        colors = ButtonDefaults.buttonColors(
                            color = if (isRecording) MiuixTheme.colorScheme.error else MiuixTheme.colorScheme.surfaceVariant,
                            contentColor = if (isRecording) MiuixTheme.colorScheme.surface else MiuixTheme.colorScheme.primary
                        )
                    )

                    Button(
                        onClick = onExecuteImport,
                        modifier = Modifier.weight(1.5f),
                        content = { Text(text = WarehouseStrings.executeImportScriptAction.zh) }
                    )
                }
            }
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            // 会话状态横幅
            if (sessionState.sessionActive) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MiuixTheme.colorScheme.primary.copy(alpha = 0.12f))
                        .padding(horizontal = 16.dp, vertical = 8.dp)
                ) {
                    Text(
                        text = WarehouseStrings.warehouseSessionAlreadyActive.zh,
                        fontSize = 13.sp,
                        color = MiuixTheme.colorScheme.primary,
                        fontWeight = FontWeight.Medium
                    )
                }
            }

            // WebView 视口占位与引导
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .background(MiuixTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = when (sessionState.stage) {
                            WarehouseWebLoginStage.LOADING -> "正在加载教务系统网页..."
                            WarehouseWebLoginStage.INJECTING_SCRIPT -> WarehouseStrings.injectingAdapterScript.zh
                            WarehouseWebLoginStage.EXECUTING -> WarehouseStrings.importingAction.zh
                            WarehouseWebLoginStage.SUCCESS -> "导入完成"
                            WarehouseWebLoginStage.ERROR -> sessionState.errorMessage ?: WarehouseStrings.saveFailed.zh
                            else -> "请在上方登录教务系统，随后点击下方【执行导入】"
                        },
                        fontSize = 14.sp,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = sessionState.currentUrl.ifEmpty { "https://..." },
                        fontSize = 12.sp,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary.copy(alpha = 0.7f)
                    )
                }
            }
        }
    }
}
