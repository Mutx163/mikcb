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
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
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

    // 顶栏折叠行为：一页一个实例，同时喂给 TopAppBar 与 QingyuPageList（组件内部已接 nestedScroll）。
    val scrollBehavior = MiuixScrollBehavior()

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            topBar = {
                TopAppBar(
                    title = model.title,
                    largeTitle = model.title,
                    scrollBehavior = scrollBehavior,
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
            // 官方页面骨架：LazyColumn + 滚动条 + 末端触感（见 QingyuPageList 注释）
            QingyuPageList(
                innerPadding = innerPadding,
                scrollBehavior = scrollBehavior,
                horizontalPadding = QingyuPageCardMargin,
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        // ── 说明段 ──
                        Text(
                            text = model.intro,
                            style = MiuixTheme.textStyles.footnote1,
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
                        // 只包 Preference：不传 insideMargin（官方 Preference 自带 16dp）
                        QingyuCard(modifier = Modifier.fillMaxWidth()) {
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
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.error(dark)),
                                modifier = Modifier.padding(horizontal = 4.dp),
                            )
                        }

                        // ── 会话块 ──
                        if (model.showSessionBlock) {
                            QingyuSectionTitle(text = model.runningLabel)
                            // 混装 Preference 与自绘信息行：不传 insideMargin（两者各自带 16dp）
                            QingyuCard(modifier = Modifier.fillMaxWidth()) {
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
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(horizontal = 4.dp),
                            )
                            Text(
                                text = model.hotspotHint,
                                style = MiuixTheme.textStyles.footnote1,
                                color = Color(QingyuTheme.secondaryText(dark)),
                                modifier = Modifier.padding(horizontal = 4.dp),
                            )
                        }

                    }
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
        Text(text = label, style = MiuixTheme.textStyles.body2, color = Color(QingyuTheme.primaryText(dark)))
        Spacer(Modifier.height(0.dp))
        Text(
            text = value,
            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}
