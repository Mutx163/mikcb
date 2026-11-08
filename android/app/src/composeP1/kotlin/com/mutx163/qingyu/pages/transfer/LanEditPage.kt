package com.mutx163.qingyu.pages.transfer

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import com.mutx163.qingyu.components.rememberShellShouldShowBackButton
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.share.qr.QrEncoder
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.MiuixScrollBehavior
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.ChevronBackward
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
 * - 会话块（只在跑起来且拿到地址时出现）：状态、二维码、访问地址（可复制）、PIN、端口、
 *   已连接台数、最近活动、热点提示；
 * - 启动失败时一行错误。
 *
 * 不持业务状态、不做业务计算：地址拼法、客户端计数文案、空值隐藏全在
 * [LanEditModel] 里算好（有 18 例单测钉住），这里只画。
 *
 * ## 二维码画在这里（2026-11-05 补）
 *
 * 之前本页只画提示行、把码留给「宿主决定用哪个实现」，结果宿主一直没画——用户照着
 * 「电脑扫描二维码打开控制台」的提示找码，屏幕上没有码，这个入口实际不能用。
 * 现在直接用本域现成件：`QrEncoder.encode(地址)` 出矩阵、[QrMatrixCanvas] 画
 *（白底黑块、整数模块、四周静默区，不吃主题色），容器照发布版
 * `lan_edit_screen.dart:325-347`——居中、纯白圆角底、边长约半屏、内容 ≥160dp。
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
                        // 从底栏进入的根页没有上一级可回，不画返回键；推入的二级页照常画。
                        // 判据取法与全站骨架同一份（rememberShellShouldShowBackButton）。
                        if (rememberShellShouldShowBackButton()) {
                            IconButton(onClick = onBack) {
                                Icon(
                                    imageVector = MiuixIcons.ChevronBackward,
                                    contentDescription = model.title,
                                    tint = Color(QingyuTheme.actionIcon(dark)),
                                )
                            }
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
                                    color = MiuixTheme.colorScheme.secondary,
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
                                    InfoRow(label = model.pinLabel, value = pin)
                                }
                                val port = model.portText
                                if (port.isNotEmpty()) {
                                    InfoRow(label = model.portLabel, value = port)
                                }
                                InfoRow(label = model.clientsLabel, value = model.clientsText)
                                val lastActivity = model.lastActivityLine
                                if (lastActivity != null) {
                                    InfoRow(label = model.lastActivityLabel, value = lastActivity)
                                }
                            }

                            // ── 二维码 ──
                            // 发布版 `lan_edit_screen.dart:325-347`：居中、纯白圆角容器（内边距 12、
                            // 圆角 12），里面是边长约半屏的二维码；只有拿到地址时才出现。
                            // 白底是硬要求：深色主题下把码画成浅底深块，摄像头按「深色=1」判读，
                            // 对比度一反过来就扫不出（QrMatrixCanvas 也只画白底黑块）。
                            // 用 `hasAddress` 而不是「文本非空」：没有 IP/端口时 `addressText`
                            // 给的是「地址不可用」那句提示，把它编成二维码等于画一个假码。
                            if (model.hasAddress) {
                                val address = model.addressText
                                val matrix = remember(address) {
                                    // 地址是 http://ip:port，理论上编得出来；真编不出来就只显示
                                    // 白底容器（下方提示与地址行仍可手打），不让整页崩。
                                    runCatching { QrEncoder.encode(address) }.getOrNull()
                                }
                                BoxWithConstraints(
                                    modifier = Modifier.fillMaxWidth(),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    val side = (maxWidth * QR_SIDE_FRACTION).coerceAtLeast(QR_MIN_SIDE)
                                    Box(
                                        modifier = Modifier
                                            .size(side)
                                            .clip(RoundedCornerShape(QR_CORNER_RADIUS))
                                            .background(Color.White),
                                        contentAlignment = Alignment.Center,
                                    ) {
                                        if (matrix != null) {
                                            QrMatrixCanvas(
                                                matrix = matrix,
                                                modifier = Modifier
                                                    .fillMaxSize()
                                                    .padding(QR_CONTAINER_PADDING),
                                            )
                                        }
                                    }
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

/**
 * 二维码容器的边长占内容宽度的比例。
 *
 * 发布版是 `MediaQuery.of(context).size.width * 0.5`（整屏宽的一半，`lan_edit_screen.dart:336`）；
 * Compose 这层能拿到的是列表内容宽（≈屏宽 − 两侧外距），取同一比例即可，差的那点边距
 * 对「扫得出来」没有影响。
 */
private const val QR_SIDE_FRACTION = 0.5f

/** 容器最小边长：发布版没有下限，小屏能缩到 150dp 以下，扫起来就会吃力。 */
private val QR_MIN_SIDE = 160.dp

/** 白底容器内边距 / 圆角（发布版 `EdgeInsets.all(12)` + `BorderRadius.circular(12)`）。 */
private val QR_CONTAINER_PADDING = 12.dp
private val QR_CORNER_RADIUS = 12.dp

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
