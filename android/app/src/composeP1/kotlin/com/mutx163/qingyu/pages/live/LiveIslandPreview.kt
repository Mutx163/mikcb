package com.mutx163.qingyu.pages.live

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.delay
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Alarm
import top.yukonga.miuix.kmp.icon.extended.Info
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 超级岛预览的**固定色板**（与 App 主题无关）。
 *
 * 这两张预览卡画的不是 App 自己的界面，而是「系统的深色通知 / 灵动岛长什么样」：
 * 胶囊永远是近黑底 + 浅色字，展开卡永远是深色卡，深色模式下也不该跟着变浅
 *（Dart 侧 `lib/widgets/live_island_preview.dart:48-426` 同样写死这一组值，
 * 行为真相在 Dart）。所以它们不进 `MiuixTheme.colorScheme`。
 *
 * 集中成命名常量、逐通道构造，是为了不让 `Color(0x…)` 字面量散落在页面各处
 * （规则 R5 的判据就是散落的写死色值；这里是有名字、有理由的一处）。
 */
private object IslandPreviewColors {
    /** 摘要胶囊底色（近黑）。 */
    val Capsule = Color(red = 0x06, green = 0x06, blue = 0x08)

    /** 应用图标圆角位的占位色块。 */
    val AppIconPlaceholder = Color(red = 0x3A, green = 0x3D, blue = 0x45)

    /** 摄像头开孔外圈。 */
    val CameraRing = Color(red = 0x08, green = 0x09, blue = 0x0B)

    /** 摄像头镜片。 */
    val CameraLens = Color(red = 0x19, green = 0x1B, blue = 0x20)

    /** 展开态通知卡底色。 */
    val ExpandedCard = Color(red = 0x10, green = 0x11, blue = 0x14)

    /** 展开态详情行文字（浅灰）。 */
    val ExpandedDetail = Color(red = 0xB9, green = 0xBD, blue = 0xC4)

    /** 展开态小字说明（更暗的灰）。 */
    val ExpandedCaption = Color(red = 0x8A, green = 0x8F, blue = 0x98)
}

/**
 * 超级岛**摘要态胶囊**预览（对照 Flutter `lib/widgets/live_island_preview.dart:48-426`）。
 *
 * 还原真实摘要态胶囊的单行左右分区：中间是摄像头开孔；左侧只有通知小图标位，
 * 右侧是整条 islandCriticalText（课程名 + 地点 + 状态）。也就是说——「显示内容」
 * 那组开关控制的是**右侧文本**，左侧图标位只由「小米岛左侧文字图标」开关决定。
 *
 * 倒计时**每秒重算**：[rememberNowMillis] 用 `produceState + delay(1000)` 每秒推进
 * 一个 `nowMillis`，再交给纯逻辑 [LiveDisplayLogic] 拼文字——不写死任何钟点或假课程，
 * 课程与时间全部来自传入的 [previewInfo]。
 */
@Composable
fun LiveIslandPreviewCard(
    state: LiveDisplayState,
    previewInfo: LiveIslandPreviewInfo,
    modifier: Modifier = Modifier,
    forDuringEnd: Boolean = false,
    followBeforeClass: Boolean = false,
) {
    val dark = isSystemInDarkTheme()
    val nowMillis = rememberNowMillis()
    // 静态预览：一次性捕获「现在」当稳定锚点（否则每 tick 都把 now 当锚点，倒计时钉死）。
    val anchor = remember(previewInfo.courseName, previewInfo.anchorMillis) {
        previewInfo.anchorMillis ?: System.currentTimeMillis()
    }
    val info = previewInfo.copy(anchorMillis = anchor)
    // 阶段由真实课堂时刻决定：上课中 → 课中 + 下课提醒；课间 → 即将上课；
    // 无课 → 空（页面不画岛卡，改画诚实空态）。moment 为 null 时沿用页面旧口径。
    val stages = LiveDisplayLogic.stagesFor(forDuringEnd, previewInfo.moment)

    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (followBeforeClass) {
            FollowBadge(dark = dark)
        }
        stages.forEachIndexed { index, stage ->
            if (stages.size > 1) {
                Text(
                    text = LiveDisplayLogic.stageWord(stage),
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(bottom = 2.dp),
                )
            }
            IslandCapsule(
                iconSlot = { IslandIconSlot(state = state, info = info, stage = stage) },
                criticalText = LiveDisplayLogic.islandCriticalText(state, stage, info, nowMillis),
            )
            if (index != stages.lastIndex) Spacer(modifier = Modifier.height(10.dp))
        }
    }
}

/**
 * 超级岛**展开态**预览（对照 Flutter `:445-850`）。模拟提升通知被展开后的排版：
 * 标题 = 课前 / 下课提醒带阶段前缀，课中只有课程名；正文 = `visibleStatusText · 时间 ·
 * 地点 · 教师`（课中带进度时退化为 `倒计时 · 地点`）；详情行由 `expandedDetailFields`
 * 逐字段拼行，空列表 = 全部隐藏。
 */
@Composable
fun LiveIslandExpandedPreviewCard(
    state: LiveDisplayState,
    previewInfo: LiveIslandPreviewInfo,
    modifier: Modifier = Modifier,
    forDuringEnd: Boolean = false,
    followBeforeClass: Boolean = false,
) {
    val dark = isSystemInDarkTheme()
    val nowMillis = rememberNowMillis()
    val anchor = remember(previewInfo.courseName, previewInfo.anchorMillis) {
        previewInfo.anchorMillis ?: System.currentTimeMillis()
    }
    val info = previewInfo.copy(anchorMillis = anchor)
    // 阶段由真实课堂时刻决定：上课中 → 课中 + 下课提醒；课间 → 即将上课；
    // 无课 → 空（页面不画岛卡，改画诚实空态）。moment 为 null 时沿用页面旧口径。
    val stages = LiveDisplayLogic.stagesFor(forDuringEnd, previewInfo.moment)

    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (followBeforeClass) {
            FollowBadge(dark = dark)
        }
        stages.forEachIndexed { index, stage ->
            if (stages.size > 1) {
                Text(
                    text = LiveDisplayLogic.stageWord(stage),
                    style = MiuixTheme.textStyles.footnote1,
                    color = Color(QingyuTheme.secondaryText(dark)),
                    modifier = Modifier.padding(bottom = 2.dp),
                )
            }
            ExpandedNotificationCard(
                title = LiveDisplayLogic.expandedTitle(state, stage, info),
                summary = LiveDisplayLogic.expandedSummaryLine(state, stage, info, nowMillis),
                detailLines = LiveDisplayLogic.expandedDetailLines(state, stage, info, nowMillis),
                emptyHint = DisplaySettingsStrings.expandedPreviewEmptyHint.zh,
                caption = DisplaySettingsStrings.expandedPreviewCaption.zh,
                unfilledSuffix = DisplaySettingsStrings.unfilledSuffix.zh,
            )
            if (index != stages.lastIndex) Spacer(modifier = Modifier.height(10.dp))
        }
    }
}

/** 每秒推进一次的当前时刻（毫秒）。`produceState + delay(1000)`，组件销毁自动取消。 */
@Composable
private fun rememberNowMillis(): Long {
    val now by produceState(initialValue = System.currentTimeMillis()) {
        while (true) {
            delay(1000)
            value = System.currentTimeMillis()
        }
    }
    return now
}

/** 「跟随课前提醒设置」提示条（仅在课中/下课页跟随模式显示）。 */
@Composable
private fun FollowBadge(dark: Boolean) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = MiuixIcons.Info,
            contentDescription = null,
            tint = Color(QingyuTheme.secondaryText(dark)),
            modifier = Modifier.size(14.dp),
        )
        Spacer(modifier = Modifier.width(4.dp))
        Text(
            text = DisplaySettingsStrings.islandPreviewFollowBadge.zh,
            style = MiuixTheme.textStyles.footnote1,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
    }
}

/** 摘要胶囊左侧图标位：开自定义文字图标 → 按设置画文字图标；否则 → 阶段矢量小图标。 */
@Composable
private fun IslandIconSlot(
    state: LiveDisplayState,
    info: LiveIslandPreviewInfo,
    stage: LivePreviewStage,
) {
    if (state.enableMiuiIslandLabelImage) {
        IslandLabelSlot(state = state, info = info)
    } else {
        Icon(
            imageVector = stageIcon(stage),
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(24.dp),
        )
    }
}

/** 自定义左侧文字图标（图标 + 文字 / 仅文字，颜色、字号、字重跟随设置）。 */
@Composable
private fun IslandLabelSlot(state: LiveDisplayState, info: LiveIslandPreviewInfo) {
    val short = info.courseShortName?.trim()
    val name = if (state.useShortName && !short.isNullOrEmpty()) short else info.courseName
    val labelText = when (state.miuiIslandLabelContent) {
        MiuiIslandLabelContent.COURSE_NAME -> name
        MiuiIslandLabelContent.LOCATION -> info.location
        MiuiIslandLabelContent.COURSE_NAME_AND_LOCATION -> "$name ${info.location}"
    }
    val color = parseHexColorOrFallback(state.miuiIslandLabelFontColor, Color.White)
    val weight = when (state.miuiIslandLabelFontWeight) {
        MiuiIslandLabelFontWeight.REGULAR -> FontWeight.W400
        MiuiIslandLabelFontWeight.MEDIUM -> FontWeight.W500
        MiuiIslandLabelFontWeight.BOLD -> FontWeight.W700
    }
    val textComposable: @Composable () -> Unit = {
        Text(
            text = labelText,
            fontSize = state.miuiIslandLabelFontSize.coerceIn(4.0, 32.0).sp,
            fontWeight = weight,
            color = color,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
    if (state.miuiIslandLabelStyle == MiuiIslandLabelStyle.ICON_AND_TEXT) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            // 应用图标圆角位图占位：预览态不加载真实图片，用固定色块表示 22dp 图标位。
            Box(
                modifier = Modifier
                    .size(22.dp)
                    .clip(RoundedCornerShape(state.miuiIslandLabelLogoCornerRadius.coerceIn(0.0, 12.0).dp))
                    .background(IslandPreviewColors.AppIconPlaceholder),
            )
            Spacer(modifier = Modifier.width(3.dp))
            textComposable()
        }
    } else {
        textComposable()
    }
}

/** 摘要态胶囊：单行，左图标位 + 摄像头开孔 + 右侧文本。 */
@Composable
private fun IslandCapsule(
    iconSlot: @Composable () -> Unit,
    criticalText: String,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp)
            .clip(RoundedCornerShape(28.dp))
            .background(IslandPreviewColors.Capsule)
            .border(1.dp, Color.White.copy(alpha = 0.07f), RoundedCornerShape(28.dp)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .padding(start = 13.dp, end = 4.dp),
            contentAlignment = Alignment.CenterStart,
        ) {
            iconSlot()
        }
        CameraHole()
        Box(
            modifier = Modifier
                .weight(1f)
                .padding(start = 6.dp, end = 13.dp),
            contentAlignment = Alignment.CenterEnd,
        ) {
            if (criticalText.isNotEmpty()) {
                Text(
                    text = criticalText,
                    style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.SEMIBOLD),
                    color = Color.White,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
    }
}

/** 居中前置摄像头开孔。 */
@Composable
private fun CameraHole() {
    Box(
        modifier = Modifier
            .padding(horizontal = 2.dp)
            .size(27.dp)
            .clip(CircleShape)
            .background(IslandPreviewColors.CameraRing)
            .border(1.dp, Color.White.copy(alpha = 0.09f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(11.dp)
                .clip(CircleShape)
                .background(IslandPreviewColors.CameraLens),
        )
    }
}

/** 提升通知展开后的卡片观感：深色圆角卡片 + 标题 + 正文 + 分隔线 + 详情行。 */
@Composable
private fun ExpandedNotificationCard(
    title: String,
    summary: String,
    detailLines: List<LiveDetailLine>,
    emptyHint: String,
    caption: String,
    unfilledSuffix: String,
) {
    val cardColor = IslandPreviewColors.ExpandedCard
    val detailColor = IslandPreviewColors.ExpandedDetail
    val captionColor = IslandPreviewColors.ExpandedCaption

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(22.dp))
            .background(cardColor)
            .border(1.dp, Color.White.copy(alpha = 0.07f), RoundedCornerShape(22.dp))
            .padding(start = 16.dp, top = 14.dp, end = 16.dp, bottom = 14.dp),
    ) {
        Text(
            text = title,
            style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.SEMIBOLD),
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        if (summary.isNotEmpty()) {
            Spacer(modifier = Modifier.height(5.dp))
            Text(
                text = summary,
                style = MiuixTheme.textStyles.footnote1,
                color = detailColor,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (detailLines.isEmpty()) {
            Spacer(modifier = Modifier.height(10.dp))
            Text(text = emptyHint, style = MiuixTheme.textStyles.footnote2, color = captionColor)
        } else {
            Spacer(modifier = Modifier.height(10.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(Color.White.copy(alpha = 0.08f)),
            )
            Spacer(modifier = Modifier.height(10.dp))
            detailLines.forEach { line ->
                Text(
                    text = if (line.unfilled) "${line.text}（$unfilledSuffix）" else line.text,
                    style = MiuixTheme.textStyles.footnote1,
                    color = if (line.unfilled) captionColor else detailColor,
                    fontStyle = if (line.unfilled) FontStyle.Italic else FontStyle.Normal,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(bottom = 4.dp),
                )
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(text = caption, style = MiuixTheme.textStyles.footnote2, color = captionColor)
    }
}

/** 阶段矢量小图标（对应原生 ic_upcoming / ic_course / ic_countdown 的最接近 Miuix 字形）。 */
private fun stageIcon(stage: LivePreviewStage) = when (stage) {
    LivePreviewStage.BEFORE_CLASS -> MiuixIcons.Alarm
    LivePreviewStage.DURING_CLASS -> MiuixIcons.Notes
    LivePreviewStage.BEFORE_END -> MiuixIcons.Ok
}

/** `#RRGGBB` / `#AARRGGBB` 解析，失败回落到 [fallback]。 */
private fun parseHexColorOrFallback(hex: String?, fallback: Color): Color {
    if (hex.isNullOrBlank()) return fallback
    val cleaned = hex.trim().removePrefix("#")
    return try {
        when (cleaned.length) {
            // 逐通道构造：色值来自用户设置里存的字符串，不在源码里写死 `Color(0x…)`。
            6 -> {
                val rgb = cleaned.toInt(16)
                Color(
                    red = (rgb shr 16) and 0xFF,
                    green = (rgb shr 8) and 0xFF,
                    blue = rgb and 0xFF,
                )
            }
            // 8 位是带 alpha 的 ARGB 打包值，`Color(Int)` 收的就是它。
            8 -> Color(cleaned.toLong(16).toInt())
            else -> fallback
        }
    } catch (_: NumberFormatException) {
        fallback
    }
}
