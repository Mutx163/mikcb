package com.mutx163.qingyu.pages.transfer

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.preference.SwitchPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 局域网编辑页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/lan_edit_screen.dart`（489 行）：
 * - 顶栏：返回 + "局域网编辑"；
 * - 说明段（`lanEditIntro`：数据不上云、关闭即停）；
 * - 主按钮（开启 / 停止）+「离开后保持开启」开关；
 * - 会话块（只在跑起来且拿到地址时出现）：状态、访问地址（可复制）、PIN、端口、
 *   已连接台数、最近活动、二维码提示、热点提示；
 * - 启动失败时一行错误。
 *
 * 不持业务状态、不做业务计算：地址拼法、客户端计数文案、空值隐藏全在
 * [LanEditModel] 里算好（有 18 例单测钉住），这里只画。
 *
 * 二维码本身不在这里画：官方 Miuix 无二维码组件，页面只给提示行（`lanEditQrHint`），
 * 由宿主决定用哪个二维码实现。这一条写在认领文件「差异与风险」里。
 */
@Composable
fun LanEditPage(
    model: LanEditModel,
    onBack: () -> Unit,
    onToggleRunning: () -> Unit,
    onCopyAddress: () -> Unit,
    onKeepAliveChange: (Boolean) -> Unit,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            topBar = {
                TopAppBar(
                    title = model.title,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = model.title,
                                tint = Color(QingyuTheme.actionIcon(dark)),
                            )
                        }
                    },
                )
            },
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // ── 说明段 ──
                Text(
                    text = model.intro,
                    fontSize = 13.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(horizontal = 4.dp, vertical = 4.dp),
                )

                // ── 主按钮 ──
                Button(
                    onClick = onToggleRunning,
                    modifier = Modifier.fillMaxWidth(),
                    colors = if (model.running) {
                        ButtonDefaults.buttonColors(
                            color = MiuixTheme.colorScheme.surfaceVariant,
                            contentColor = MiuixTheme.colorScheme.onSurfaceVariantActions,
                        )
                    } else {
                        ButtonDefaults.buttonColors()
                    },
                    content = { Text(text = model.primaryActionLabel) },
                )

                // ── 离开后保持开启 ──
                Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(vertical = 2.dp)) {
                    SwitchPreference(
                        checked = model.keepAliveWhenLeaving,
                        onCheckedChange = onKeepAliveChange,
                        title = model.keepAliveTitle,
                        summary = model.keepAliveSubtitle,
                    )
                }

                // ── 启动失败 ──
                val failed = model.startFailedText
                if (failed != null) {
                    Text(
                        text = failed,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.error(dark)),
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                }

                // ── 会话块 ──
                if (model.showSessionBlock) {
                    Text(
                        text = model.runningLabel,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.sectionLabel(dark)),
                        modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 4.dp),
                    )
                    Card(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(vertical = 2.dp)) {
                        // 访问地址（可复制）
                        ArrowPreference(
                            title = model.addressLabel,
                            summary = model.addressText,
                            onClick = onCopyAddress,
                        )
                        val pin = model.pinText
                        if (pin.isNotEmpty()) {
                            HorizontalDivider(
                                modifier = Modifier.padding(start = 16.dp),
                                color = Color(QingyuTheme.dividerLine(dark)),
                            )
                            InfoRow(label = model.pinLabel, value = pin)
                        }
                        val port = model.portText
                        if (port.isNotEmpty()) {
                            HorizontalDivider(
                                modifier = Modifier.padding(start = 16.dp),
                                color = Color(QingyuTheme.dividerLine(dark)),
                            )
                            InfoRow(label = model.portLabel, value = port)
                        }
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 16.dp),
                            color = Color(QingyuTheme.dividerLine(dark)),
                        )
                        InfoRow(label = model.clientsLabel, value = model.clientsText)
                        val lastActivity = model.lastActivityLine
                        if (lastActivity != null) {
                            HorizontalDivider(
                                modifier = Modifier.padding(start = 16.dp),
                                color = Color(QingyuTheme.dividerLine(dark)),
                            )
                            InfoRow(label = model.lastActivityLabel, value = lastActivity)
                        }
                    }

                    // 二维码提示与热点提示（都是整宽说明，允许折行）
                    Text(
                        text = model.qrHint,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                    Text(
                        text = model.hotspotHint,
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.secondaryText(dark)),
                        modifier = Modifier.padding(horizontal = 4.dp),
                    )
                }
            }
        }
    }
}

/** 只读信息行：左标签 + 右取值（Dart `_InfoRow`）。 */
@Composable
private fun InfoRow(label: String, value: String) {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text = label, fontSize = 15.sp, color = Color(QingyuTheme.primaryText(dark)))
        Spacer(Modifier.height(0.dp))
        Text(
            text = value,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}
