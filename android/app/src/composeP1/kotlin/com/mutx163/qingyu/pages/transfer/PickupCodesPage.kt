package com.mutx163.qingyu.pages.transfer

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.role
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuLoadingAccentGlyph
import com.mutx163.qingyu.components.QingyuPageCardMargin
import com.mutx163.qingyu.components.QingyuPageList
import com.mutx163.qingyu.components.QingyuPageScaffold
import com.mutx163.qingyu.components.QingyuPageTheme
import com.mutx163.qingyu.components.QingyuSectionTitle
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.preference.ArrowPreference
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 取件码页 · Compose 渲染层（Phase 3）。
 *
 * 对应 Flutter `lib/screens/pickup_codes_screen.dart`（466 行）：
 * - 顶栏：返回 + "取件码"（大标题，与 `HyperosSubpage` 默认的 `collapsibleLargeTitle` 同口径）；
 * - 两个分组：「出示身份码」（3 个）/「查待取快递」（4 个）；
 * - 每个入口一行：品牌首字方块 + 标题 + 说明 + 右箭头，**整行可点**；
 * - 点一行 → 宿主调 `PickupCodeLauncher`，失败时按模型层给的话术提示。
 *
 * ## 状态全部由宿主喂进来
 *
 * 入口表、分组、品牌色、失败原因文案、无障碍标签全在 [PickupCodesModel]（有单测钉住）；
 * 「正在跳哪一条」「装没装」由 [PickupCodesHost] 持有。这里只画，不自己算。
 *
 * ## 为什么用官方 ArrowPreference 而不是手搓 Row
 *
 * 手搓 Row 时点击、按压指示、右箭头、按钮角色四件事都要自己接——2026-10 的重构
 * 就是漏了第一件：`onClick` 参数传进了 `EntryRow` 却没人消费，整页七行点了没反应。
 * `ArrowPreference`（官方 `BasicComponent` 的箭头版）把「整行热区 + 按压指示 + 行尾箭头 +
 * 按钮语义」一次给全，页面只负责内容与状态。
 *
 * ## 忙碌 / 未安装 / 无障碍（对齐 Dart，不是自创）
 *
 * - **忙碌**：被点的行用 22dp 进度圈换掉首字方块，其余行淡到 45%，整页暂时不可点
 *   （Dart `_busyEntryId` + `AnimatedOpacity`）；
 * - **未安装**：整行淡到 55%，首字加删除线；**不再额外加一行灰字**（Dart 也没有）——
 *   那句话只进无障碍标签，避免同一张卡片里行高参差；
 * - **读屏**：每行合并成一个按钮节点，标签是「平台名，分组（，未安装对应应用）」
 *   （Dart `Semantics(button: true, label: …)`）。标题与说明是可见文字，不再重复塞进标签。
 *
 * ## 有意与 Dart 不同的一处
 *
 * Dart 的品牌色 switch 漏了 `*Parcels` 两条，导致「淘宝 / 拼多多（查待取）」拿到兜底蓝；
 * 这里按品牌补齐（见 [PickupCodesModel.accentFor]），同一平台在两个分组里同色。
 */
@Composable
fun PickupCodesPage(
    onBack: () -> Unit,
    onEntryClick: (PickupCodesModel.Preset) -> Unit,
    installedOf: (PickupCodesModel.Preset) -> Boolean = { true },
    /**
     * 正在跳转的入口键（`Preset.titleKey`）；null = 空闲。
     *
     * 传键而不是整个 Preset：页面只需要「是不是我」这一件事，键在七条固定表里唯一。
     */
    busyTitleKey: String? = null,
) {
    val dark = isSystemInDarkTheme()

    QingyuPageScaffold(
        title = PickupCodesModel.title,
        onBack = onBack,
    ) {
        QingyuPageList(
            innerPadding = innerPadding,
            scrollBehavior = scrollBehavior,
            // 顶部 8 / 底部 24 是页面自己的滚动留白；系统栏那段由 innerPadding 带进来。
            contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            for (group in PickupCodesModel.groups) {
                // 一组 = 一个 item：SmallTitle 自带 28dp 左缘与 8dp 下边距，
                // Card 走 12dp 外边距 + 行内 16dp，两者落在同一条 28dp 轴线上。
                item(key = "pickup-${group.name}") {
                    QingyuSectionTitle(text = PickupCodesModel.groupTitle(group))
                    QingyuCard(
                        modifier = Modifier.padding(horizontal = QingyuPageCardMargin),
                        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
                    ) {
                        val entries = PickupCodesModel.presetsOf(group)
                        for ((index, preset) in entries.withIndex()) {
                            EntryRow(
                                preset = preset,
                                installed = installedOf(preset),
                                busy = busyTitleKey == preset.titleKey,
                                interactive = busyTitleKey == null,
                                onTap = { onEntryClick(preset) },
                            )
                        }
                    }
                }
            }
        }
    }
}

/** 一个入口行：品牌首字方块 / 进度圈 + 标题 + 说明 + 官方右箭头。 */
@Composable
private fun EntryRow(
    preset: PickupCodesModel.Preset,
    installed: Boolean,
    busy: Boolean,
    interactive: Boolean,
    onTap: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val accent = Color(PickupCodesModel.accentFor(preset, dark))

    // 透明度优先级（Dart `AnimatedOpacity`）：忙碌淡化 0.45 > 未安装 0.55 > 正常 1.0；
    // 被点中的那条保持不透明，进度圈才是视觉焦点。
    val targetAlpha = when {
        busy -> 1f
        !interactive -> 0.45f
        !installed -> 0.55f
        else -> 1f
    }
    val rowAlpha by animateFloatAsState(
        targetValue = targetAlpha,
        animationSpec = tween(durationMillis = 150),
        label = "pickupEntryAlpha",
    )

    val accessibilityLabel = PickupCodesModel.semanticsLabel(preset, installed)
    val activate = onTap

    ArrowPreference(
        modifier = Modifier
            .alpha(rowAlpha)
            // 合并成一个按钮节点：可见的标题/说明不再单独获得焦点，读屏只念
            // 「平台，分组（，未安装）」一次。clearAndSet 会清掉 clickable 自带的
            // 语义，所以点击动作在这里补回去。
            .clearAndSetSemantics {
                contentDescription = accessibilityLabel
                role = Role.Button
                if (!interactive) disabled()
                onClick {
                    if (interactive) {
                        activate()
                        true
                    } else {
                        false
                    }
                }
            },
        title = PickupCodesModel.entryTitle(preset),
        summary = preset.hint.takeIf { it.isNotBlank() },
        startAction = {
            if (busy) {
                BusyIndicator(accent = accent)
            } else {
                PlatformGlyph(
                    glyph = PickupCodesModel.glyphOf(preset),
                    accent = accent,
                    missing = !installed,
                )
            }
        },
        // null = 不可点。忙碌时所有行都不可点，避免第二次点击被宿主静默吞掉。
        onClick = if (interactive) activate else null,
    )
}

/**
 * 平台首字方块（Dart `_PickupCodeGlyph`）：40dp、圆角 13dp、品牌色 12% 底 + 品牌色首字。
 *
 * 为什么不是图标：五家平台的官方图标这仓里没有，Material/miuix 的近似图标形状又分不出
 * 谁是谁（淘宝红、拼多多红、菜鸟橙挤在一起）。首字本身就是最稳的识别线索，颜色只做辅助。
 */
@Composable
private fun PlatformGlyph(
    glyph: String,
    accent: Color,
    missing: Boolean,
) {
    Box(
        modifier = Modifier
            // 方块右侧留 4dp，加上 BasicComponent 自带的 8dp = Dart 的 12dp 间距。
            .padding(end = 4.dp)
            .size(40.dp)
            .background(
                color = accent.copy(alpha = 0.12f),
                shape = RoundedCornerShape(13.dp),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = glyph,
            style = MiuixTheme.textStyles.body1.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = accent,
            textDecoration = if (missing) TextDecoration.LineThrough else null,
        )
    }
}

/** 跳转中的行首：与首字方块同尺寸占位，整行不跳；颜色跟品牌色（Dart 同款）。 */
@Composable
private fun BusyIndicator(accent: Color) {
    Box(
        modifier = Modifier
            .padding(end = 4.dp)
            .size(40.dp),
        contentAlignment = Alignment.Center,
    ) {
        // D1 档 B′：22 / 2.2 + 透明底环，颜色随该行 accent（发布版 pickup_codes_screen.dart 同款）。
        QingyuLoadingAccentGlyph(accent = accent)
    }
}

// ── Android Studio 预览（@Preview）────────────────────────────────────────────
//
// 与 `ContributorsPage` 同一套口径：一个 `Preview<页面>` 承担「入口行状态 + 外观档位」，
// 下面每个 `@Preview` 只选一档。预览不接宿主：回调一律空实现，入口表全由模型层给。

/** 预览用的「未安装」判据：菜鸟裹裹与京东没装，其余都装了（行会淡下去）。 */
private fun previewInstalledOf(preset: PickupCodesModel.Preset): Boolean =
    preset.titleKey != "pickupCodePresetCainiao" && preset.titleKey != "pickupCodePresetJdParcels"

/** 一档预览的公共身体：安装判据 + 正在跳转的入口 + 外观档位。 */
@Composable
private fun PreviewPickupCodesPage(
    installedOf: (PickupCodesModel.Preset) -> Boolean = ::previewInstalledOf,
    busyTitleKey: String? = null,
    dark: Boolean = false,
    textScale: Float = 1f,
) {
    QingyuPageTheme(isDark = dark, textScale = textScale) {
        PickupCodesPage(
            onBack = {},
            onEntryClick = {},
            installedOf = installedOf,
            busyTitleKey = busyTitleKey,
        )
    }
}

@Suppress("unused")
@Preview(name = "1 全部已安装", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PickupCodesPagePreviewInstalled() {
    PreviewPickupCodesPage(installedOf = { true })
}

@Suppress("unused")
@Preview(name = "2 部分未安装", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PickupCodesPagePreviewMissing() {
    PreviewPickupCodesPage()
}

@Suppress("unused")
@Preview(name = "3 跳转中", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PickupCodesPagePreviewBusy() {
    PreviewPickupCodesPage(busyTitleKey = "pickupCodePresetTaobao")
}

@Suppress("unused")
@Preview(name = "4 暗色", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PickupCodesPagePreviewDark() {
    PreviewPickupCodesPage(installedOf = { true }, dark = true)
}

@Suppress("unused")
@Preview(name = "5 大字号 1.3", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PickupCodesPagePreviewLargeText() {
    PreviewPickupCodesPage(installedOf = { true }, textScale = 1.3f)
}
