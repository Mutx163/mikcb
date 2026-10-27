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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import top.yukonga.miuix.kmp.basic.Card
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Scaffold
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TopAppBar
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Back
import top.yukonga.miuix.kmp.icon.extended.Import
import top.yukonga.miuix.kmp.icon.extended.Scan

/**
 * 取件码页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/pickup_codes_screen.dart`（466 行）：
 * - 顶栏：返回 + "取件码"；
 * - 两个分组：「出示身份码」（3 个）/「查待取快递」（4 个）；
 * - 每个入口一行：图标 + 标题 + 说明（说明是「跳过去具体到哪」，不重复分组标题）；
 * - 点一行 → 宿主调 `PickupCodeLauncher`，失败时按模型层给的话术提示。
 *
 * 不持业务状态：入口表、分组、失败原因文案、语义标签全在 [PickupCodesModel] 里
 * （有 17 例单测钉住顺序与兜底），这里只画。
 *
 * 图标名（`qrCode` / `parcel`）到矢量图的映射在本文件内完成：官方 Miuix 扩展图标里
 * 没有二维码与包裹图形，用最接近的两个（Scan / Import）代替，并在认领文件「差异与风险」
 * 里记了一笔；要 1:1 还原需引入自绘图标资源，属下一批。
 */
@Composable
fun PickupCodesPage(
    onBack: () -> Unit,
    onEntryClick: (PickupCodesModel.Preset) -> Unit,
    installedOf: (PickupCodesModel.Preset) -> Boolean = { true },
) {
    val dark = isSystemInDarkTheme()

    QingyuPageTheme {
        Scaffold(
            containerColor = Color(QingyuTheme.scaffoldBackground(dark)),
            topBar = {
                TopAppBar(
                    title = PickupCodesModel.title,
                    navigationIcon = {
                        IconButton(onClick = onBack) {
                            Icon(
                                imageVector = MiuixIcons.Back,
                                contentDescription = PickupCodesModel.title,
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
                for (group in PickupCodesModel.groups) {
                    Text(
                        text = PickupCodesModel.groupTitle(group),
                        fontSize = 13.sp,
                        color = Color(QingyuTheme.sectionLabel(dark)),
                        modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 4.dp),
                    )
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        insideMargin = PaddingValues(vertical = 2.dp),
                    ) {
                        val entries = PickupCodesModel.presetsOf(group)
                        for ((index, preset) in entries.withIndex()) {
                            EntryRow(
                                preset = preset,
                                installed = installedOf(preset),
                                onClick = { onEntryClick(preset) },
                            )
                            if (index < entries.lastIndex) {
                                HorizontalDivider(
                                    modifier = Modifier.padding(start = 56.dp),
                                    color = Color(QingyuTheme.dividerLine(dark)),
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

/** 一个入口：图标 + 标题 + 说明（Dart `_PickupCodeRow`）。 */
@Composable
private fun EntryRow(
    preset: PickupCodesModel.Preset,
    installed: Boolean,
    onClick: () -> Unit,
) {
    val dark = isSystemInDarkTheme()

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = if (preset.icon == "qrCode") MiuixIcons.Scan else MiuixIcons.Import,
            contentDescription = null,
            tint = Color(QingyuTheme.actionIcon(dark)),
            modifier = Modifier.size(22.dp),
        )
        Spacer(Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = preset.title,
                fontSize = 16.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = preset.hint,
                fontSize = 13.sp,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
            // 未安装时补一行提示（Dart 侧是灰字 + 语义标签，视觉上也给一行）
            if (!installed) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = TransferExtStrings.pickupCodeSemanticsNotInstalled.zh,
                    fontSize = 12.sp,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
    }
}
