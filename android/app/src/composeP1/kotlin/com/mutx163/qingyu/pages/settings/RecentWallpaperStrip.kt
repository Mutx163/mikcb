package com.mutx163.qingyu.pages.settings

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image as BitmapImage
import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.mutx163.qingyu.app.imagecache.ImageSizeSelector
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Close
import top.yukonga.miuix.kmp.icon.extended.Image
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 「最近使用」整段（标题 + 缩略图条 + 移除确认条 + 删除后的反悔条）。
 *
 * 行为与数字逐条对拍 `lib/screens/settings/settings_recent_wallpaper.dart:38-397`：
 * 条高 116（`:12`）、卡内标签位 26（`:18`）、单卡宽 78（`:265`）、角标 22 /
 * 字 15 / 纯黑 45%（`:377-388`）、标签最多两行 11px × 1.2（`:315-337`）、
 * 卡间距 10（`:125`）、缩略图与标签间 6（`:312`）。尺寸常量一律取
 * [SettingsRecentWallpaperSection]，**不在这里抄第二份数**。
 *
 * ## 为什么确认条画在条外面
 *
 * 与 Dart 同一批理由（`:23-37`）：78 宽卡里平分两颗按钮只剩约 37 宽、`HyperosPressable`
 * 的 14 圆角会裁掉按钮自己的圆角。所以卡只表达「哪张被选中」，确认交给条下面那行
 * 满宽按钮（[RecentWallpaperConfirmBar]）。
 *
 * ## 为什么不弹覆盖层
 *
 * 这一段的宿主之一是「外观编辑」页的底部弹层。弹层是根覆盖层自插条目，任何再往上的
 * 弹层都会落在它**背面**（Dart `:34-37` 与 `settings_home_backdrop_flow.dart:115-149`
 * 的 2026-09-20 真机口径）。所以「确认条就地长在列表下面」在两个宿主里天然一致，
 * 本文件里**没有任何 Dialog / Sheet / 路由**。
 *
 * ## 反悔窗（删除后 2.5s 可撤销）
 *
 * Dart 用带动作按钮的 toast（`settings_home_backdrop_flow.dart:348-353`、
 * `:166-170` 的 2500ms），删除文件本身也排在同一个窗口之后（`:380-417`）。
 * 当前 Compose 壳里没有全站 toast 宿主，所以这里把「已删除 + 撤销」就地画在条下面
 * —— 位置不同、时机与语义相同：[RECENT_WALLPAPER_UNDO_WINDOW_MS] 到期后那一行自动
 * 消失，数据侧必须在这个窗口之后才真删文件（否则「撤销」只会放回一条打不开的死路径，
 * 理由见 Dart `:380-384`）。
 */

/**
 * 删除后的反悔窗口（Dart `settings_home_backdrop_flow.dart:166-170` 的
 * `_backdropDeletionGrace = 2500ms`）。
 *
 * 数据侧安排文件删除时必须读这一个常量，别自己再写一个 2500：两处数字一分叉就会出现
 * 「按撤销时文件已被删」或「窗口过了还能撤销到死路径」。
 */
const val RECENT_WALLPAPER_UNDO_WINDOW_MS = 2500L

/** 缩略图解码目标宽（Dart `cacheWidth: 240`，`settings_recent_wallpaper.dart:160`）。 */
private const val THUMB_DECODE_TARGET_PX = 240

/** 卡圆角（Dart `:274` / `:282`）。 */
private val CARD_CORNER = 14.dp

/** 缩略图内层圆角（Dart `:292`）。 */
private val THUMB_CORNER = 11.dp

/** 角标圆角（Dart `:381`）。 */
private val BADGE_CORNER = 10.dp

/** 选中 / 待删描边宽度（Dart `:288`）。 */
private val CARD_BORDER_WIDTH = 2.dp

/** 描边与缩略图之间的内衬（Dart `:290`）。 */
private val CARD_INNER_PADDING = 2.dp

/** 缩略图与标签位的间距（Dart `:312`）。 */
private val THUMB_LABEL_GAP = 6.dp

/** 相邻两张卡的间距（Dart `:125` 的 `separatorBuilder`）。 */
private val CARD_GAP = 10.dp

/** 角标距卡右上角（Dart `:344-345`）。 */
private val BADGE_INSET = 4.dp

/** 标签行高 = 11 × 1.2（Dart `:324-325`）——字号本身取主题的 `footnote2`（正好 11sp）。 */
private val LABEL_LINE_HEIGHT =
    (SettingsRecentWallpaperSection.LABEL_FONT_SIZE *
        SettingsRecentWallpaperSection.LABEL_HEIGHT_MULTIPLIER).sp

/**
 * 「最近使用」这一段的一次性界面态与回调。
 *
 * [armedKey] / [undoKey] / [notice] 都是**纯界面态**（Dart 侧是
 * `RecentWallpaperSectionState._armedKey` 与 toast），不属于设置字段；由面板宿主持有
 * （[WallpaperSheetBody]）。
 */
class RecentWallpaperPanel(
    /** 已发起移除、正等确认的那一条；null = 没有（Dart `:77`）。 */
    val armedKey: String?,
    /** 刚被删掉、还在反悔窗口内那一条；null = 没有。 */
    val undoKey: String?,
    /** 一句临时说明（目前只有「正在使用这张壁纸」那条，Dart `:841-855`）。 */
    val notice: String?,
    /** 点一张卡切回那张壁纸（Dart `:146` 的 `onSelect`）。 */
    val onSelect: (String) -> Unit,
    /** 角标 / 长按：就地进入确认态（Dart `:148-154`）。 */
    val onRequestRemove: (String) -> Unit,
    /** 正在用的那张被长按：只解释一句，什么都不改（Dart `:156`）。 */
    val onBlockedRemove: (String) -> Unit,
    /** 取消确认（Dart `:90-95` 的 `_disarm`）。 */
    val onCancelRemove: () -> Unit,
    /** 确认删除：摘条目 + 落盘 + 排删文件（数据侧照 Dart `:318-354`）。 */
    val onConfirmRemove: (String) -> Unit,
    /** 撤销最近一次删除：整份历史原样放回（Dart `:356-378`）。 */
    val onUndoRemove: (String) -> Unit,
)

/**
 * 「最近使用」整段。
 *
 * @param title 段标题（模型 `SettingsInline.label`，DB 文案 `homePageWallpaperRecentTitle`）。
 * @param subtitle 段说明（模型 `SettingsInline.value`）。
 * @param label 单张卡的标签（Dart `:135` 的 `homePageWallpaperRecentImageLabel`）。
 * @param entries 条目键（壁纸绝对路径），最新在前。
 * @param selectedKey 当前正在用的那张；它**不给移除**（Dart `:128-137`）。
 * @param horizontalInset 宿主给的左右内缩：面板宿主是 0（`HOST_SHEET_ROW_INSET`，
 *   留白由官方弹层的 `insideMargin` 给）；「课表页面」宿主是 16（卡片自己的行内缩）。
 */
@Composable
fun RecentWallpaperBlock(
    title: String,
    subtitle: String,
    label: String,
    entries: List<String>,
    selectedKey: String?,
    panel: RecentWallpaperPanel,
    modifier: Modifier = Modifier,
    horizontalInset: Dp = SettingsBackdropFlowPage.HOST_SHEET_ROW_INSET.dp,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            // 上下各 14（Dart `:100-106`），左右按宿主给。
            .padding(start = horizontalInset, top = 14.dp, end = horizontalInset, bottom = 14.dp),
    ) {
        Text(
            text = title,
            // Dart `HyperosTypography.listTitle` = 17sp / w400（`hyperos_theme.dart:522-529`）
            // → 官方 `headline1`（17sp）。
            style = MiuixTheme.textStyles.headline1,
            color = MiuixTheme.colorScheme.onBackground,
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = subtitle,
            // Dart `listDetail` = body2 字阶 + 次要色（`hyperos_theme.dart:531-540`）。
            style = MiuixTheme.textStyles.body2,
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        )
        Spacer(modifier = Modifier.height(12.dp))
        RecentWallpaperStrip(
            label = label,
            entries = entries,
            selectedKey = selectedKey,
            armedKey = panel.armedKey,
            panel = panel,
        )
        if (panel.undoKey != null) {
            Spacer(modifier = Modifier.height(14.dp))
            RecentWallpaperUndoBar(
                undoKey = panel.undoKey,
                onUndo = panel.onUndoRemove,
            )
        }
        val notice = panel.notice
        if (notice != null) {
            Spacer(modifier = Modifier.height(10.dp))
            Text(
                text = notice,
                // Dart `_warnBackdropHistoryInUse` 是 warning toast（`:849-854`），
                // 就地渲染时用危险色同一套语义（`HyperosColors.error` → 主题 error）。
                style = MiuixTheme.textStyles.footnote1,
                color = MiuixTheme.colorScheme.error,
            )
        }
    }
}

/**
 * 横向缩略图条本体（Dart `:120-168`）：116 高、卡宽 78、间距 10、横向滚动。
 */
@Composable
private fun RecentWallpaperStrip(
    label: String,
    entries: List<String>,
    selectedKey: String?,
    armedKey: String?,
    panel: RecentWallpaperPanel,
    modifier: Modifier = Modifier,
) {
    LazyRow(
        modifier = modifier
            .fillMaxWidth()
            .height(SettingsRecentWallpaperSection.STRIP_HEIGHT.dp),
        horizontalArrangement = Arrangement.spacedBy(CARD_GAP),
    ) {
        items(items = entries, key = { key -> key }) { key ->
            // 单卡的状态推导全走模型（`settings_recent_wallpaper.dart:230-356`）：
            // 选中 / 待删 / 可不可移除 / 描边色 / 是否压暗 / 角标出不出。
            val card = SettingsRecentWallpaperSection.cardState(key, selectedKey, armedKey)
            RecentWallpaperCard(
                label = label,
                entryKey = key,
                card = card,
                onTap = {
                    when (SettingsRecentWallpaperSection.tapIntent(card.armed, card.removable)) {
                        // 待删那张，单击是「取消」而不是切壁纸（`:139-147`）。
                        RecentWallpaperTapIntent.DISARM -> panel.onCancelRemove()
                        RecentWallpaperTapIntent.SELECT -> panel.onSelect(key)
                    }
                },
                onLongPress = {
                    when (SettingsRecentWallpaperSection.longPressIntent(card.armed, card.removable)) {
                        RecentWallpaperLongPressIntent.DISARM -> panel.onCancelRemove()
                        RecentWallpaperLongPressIntent.REQUEST_REMOVE -> panel.onRequestRemove(key)
                        RecentWallpaperLongPressIntent.BLOCKED_EXPLAIN -> panel.onBlockedRemove(key)
                    }
                },
                onRequestRemove = { panel.onRequestRemove(key) },
            )
        }
    }
}

/**
 * 一张缩略图卡（Dart `_WallpaperThumbnailCard`，`:230-356`）。
 *
 * 官方 preference 族没有「78 宽、带角标的缩略图卡」这种控件，所以卡片本体是
 * `Box` + 官方 `LocalIndication`（与 `SettingsPageRenderers` 里 `LongPressArrowRow`
 * 的同一套做法：官方组件表达不了的地方才自绘，且点击指示仍走主题提供的
 * `LocalIndication`，不自造按压动画）。
 */
@Composable
private fun RecentWallpaperCard(
    label: String,
    entryKey: String,
    card: RecentWallpaperCardState,
    onTap: () -> Unit,
    onLongPress: () -> Unit,
    onRequestRemove: () -> Unit,
) {
    val colors = MiuixTheme.colorScheme
    val interaction = remember { MutableInteractionSource() }
    val edgeColor = when (card.edge) {
        RecentWallpaperCardEdge.DANGER -> colors.error
        RecentWallpaperCardEdge.PRIMARY -> colors.primary
        RecentWallpaperCardEdge.NONE -> Color.Transparent
    }
    val labelColor = when {
        card.armed -> colors.error
        card.selected -> colors.primary
        else -> colors.onSurfaceVariantSummary
    }
    Box(
        modifier = Modifier
            .width(SettingsRecentWallpaperSection.CARD_WIDTH.dp)
            .fillMaxHeight(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(CARD_CORNER))
                .combinedClickable(
                    interactionSource = interaction,
                    indication = LocalIndication.current,
                    onClick = onTap,
                    onLongClick = onLongPress,
                )
                // 缩略图是装饰图，可读信息只有下方标签；合并后整张卡念成一句
                // 「壁纸名，按钮」，而不是「图片 + 壁纸名」两个孤立节点。
                .semantics(mergeDescendants = true) { role = Role.Button },
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .border(CARD_BORDER_WIDTH, edgeColor, RoundedCornerShape(CARD_CORNER))
                    .padding(CARD_INNER_PADDING),
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(RoundedCornerShape(THUMB_CORNER)),
                ) {
                    RecentWallpaperThumbnail(path = entryKey)
                    if (card.dimmed) {
                        // 「这张要被移除了」在图上也读得出来，而不只靠红边（`:293-307`）。
                        // Dart 是 `Color(0x99000000)`：纯黑、0x99/255 = 60%。
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(Color.Black.copy(alpha = 0x99 / 255f)),
                        )
                    }
                }
            }
            Spacer(modifier = Modifier.height(THUMB_LABEL_GAP))
            // 标签位定高：常态一行 / 两行、确认态按钮行，缩略图尺寸不变（`:313-337`）。
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(SettingsRecentWallpaperSection.LABEL_HEIGHT.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    // 字号取主题 `footnote2`（官方刻度里正好 11sp，与 Dart `:324` 同数），
                    // 行高按 Dart 的 1.2 显式给。
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(
                        if (card.selected || card.armed) QingyuWeightDelta.SEMIBOLD else 0,
                    ),
                    lineHeight = LABEL_LINE_HEIGHT,
                    color = labelColor,
                    maxLines = SettingsRecentWallpaperSection.LABEL_MAX_LINES,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
        // 角标画在按压区**之外**：压在卡内的话，点它会连带把壁纸也切了（`:341-351`）。
        if (card.showRemoveBadge) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(BADGE_INSET),
            ) {
                RecentWallpaperRemoveBadge(onPressed = onRequestRemove)
            }
        }
    }
}

/**
 * 缩略图本体：**能解出真图就画真图，解不出就画占位**。
 *
 * Dart 用 `Image.file(..., errorBuilder: SizedBox.shrink())`（`:157-164`）。这里不画
 * 「长得像壁纸」的假图：解不出来就退成一块中性底色 + 一个图片符号，用户看得出
 * 「这里本该有图、但这张读不出来」。
 *
 * ⚠️ `platform/AndroidImageLoader` 只吃 http(s) URL（内部是 `HttpURLConnection`），
 * 而「最近使用」的条目键是**本地绝对路径**，所以本地缩略图走 `BitmapFactory` +
 * `ImageSizeSelector`（后者是 `app/imagecache` 的纯逻辑，算 2 的幂采样值，与
 * `AndroidImageLoader` 用的是同一个）。
 */
@Composable
private fun RecentWallpaperThumbnail(path: String) {
    val bitmap by produceState<ImageBitmap?>(initialValue = null, key1 = path) {
        value = withContext(Dispatchers.IO) { decodeLocalThumbnail(path) }
    }
    val image = bitmap
    if (image != null) {
        BitmapImage(
            bitmap = image,
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
        )
    } else {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MiuixTheme.colorScheme.surfaceContainer),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = MiuixIcons.Image,
                contentDescription = null,
                tint = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}

/** 本地缩略图解码（后台线程调用）：只解到 240px 宽，别把整张原图读进内存。 */
private fun decodeLocalThumbnail(path: String): ImageBitmap? = runCatching {
    if (path.isEmpty()) return@runCatching null
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return@runCatching null
    val sample = ImageSizeSelector.inSampleSize(
        srcWidth = bounds.outWidth,
        srcHeight = bounds.outHeight,
        targetWidth = THUMB_DECODE_TARGET_PX,
        targetHeight = THUMB_DECODE_TARGET_PX,
    )
    val options = BitmapFactory.Options().apply { inSampleSize = sample }
    BitmapFactory.decodeFile(path, options)?.asImageBitmap()
}.getOrNull()

/**
 * 缩略图右上角的「×」角标（Dart `_WallpaperRemoveBadge`，`:362-397`）。
 *
 * 刻意做成**看得见的入口**而不是只有长按：移除会连图片文件一起删，藏在隐藏手势后面
 * 等于让用户自己发现 + 试错（`:358-361`）。半透明黑底 + 白 ×（`:373-388`），
 * 不加白底——压在照片上时白圆反而更抢眼。
 */
@Composable
private fun RecentWallpaperRemoveBadge(onPressed: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier = Modifier
            .size(SettingsRecentWallpaperSection.BADGE_SIZE.dp)
            .clip(RoundedCornerShape(BADGE_CORNER))
            .background(
                Color.Black.copy(alpha = SettingsRecentWallpaperSection.BADGE_ALPHA.toFloat()),
            )
            .combinedClickable(
                interactionSource = interaction,
                indication = LocalIndication.current,
                onClick = onPressed,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = MiuixIcons.Close,
            // 读屏只听得出「按钮」时不知道删的是什么（`:390-397`）。
            contentDescription = SettingsRecentWallpaperSection.BADGE_TOOLTIP.text,
            tint = Color.White,
            modifier = Modifier.size(SettingsRecentWallpaperSection.BADGE_GLYPH_SIZE.dp),
        )
    }
}

/**
 * 移除确认条的一句说明（Dart `:169-176`）：与段说明同一版式，但要**警示色**。
 *
 * 版式按发布版落在**段内**：与缩略图条同左缘（段自己已经给了 0 内缩，弹层再给 16），
 * 上方只留段块的 14 —— 以前这里借了设置列表的 `SECTION_LABEL_INSET`（16）+ `top 8`，
 * 在弹层里就变成距边 32、离条 22，比发布版各多一截（2026-11-05 修）。
 * 字号取 `body2`（= Dart `HyperosTypography.listDetail` 的 13sp）。
 */
@Composable
fun RecentWallpaperConfirmHint(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        modifier = modifier.fillMaxWidth(),
        color = MiuixTheme.colorScheme.error,
        style = MiuixTheme.textStyles.body2,
    )
}

/**
 * 移除确认条的两颗按钮（Dart `:178-202`）：删除（危险）/ 取消（次要），等宽并排。
 *
 * 键与行 id 都来自模型（`SettingsBackdropFlowPage` 的 `backdrop.recent.confirm*` 行），
 * 这里只负责版式；「点删除之后要做什么」由宿主转出去。
 */
@Composable
fun RecentWallpaperConfirmBar(
    deleteLabel: String,
    cancelLabel: String,
    onDelete: () -> Unit,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            // 发布版两颗按钮的上下间距（`:169-203`）：提示 → 按钮 10、按钮 → 段底 14。
            // 段块自己带 14 底距，所以这里只补那 10；下 14 是「按钮之后到下一块」的那一截。
            .padding(top = 10.dp, bottom = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Button(
            onClick = onDelete,
            modifier = Modifier.weight(1f),
            // Dart `HyperosButtonVariant.destructive` = error 底 + onError 字
            // （`hyperos_controls.dart:728-733`）。
            colors = ButtonDefaults.buttonColors(
                color = MiuixTheme.colorScheme.error,
                contentColor = MiuixTheme.colorScheme.onError,
            ),
        ) {
            Text(deleteLabel)
        }
        Button(
            onClick = onCancel,
            modifier = Modifier.weight(1f),
            colors = ButtonDefaults.buttonColors(),
        ) {
            Text(cancelLabel)
        }
    }
}

/**
 * 删除后的就地反悔条（替代 Dart 的带动作 toast，`settings_home_backdrop_flow.dart:348-353`）。
 *
 * 自动消失由宿主按 [RECENT_WALLPAPER_UNDO_WINDOW_MS] 计时；这一行只负责画。
 */
@Composable
private fun RecentWallpaperUndoBar(
    undoKey: String,
    onUndo: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    QingyuCard(
        modifier = modifier.fillMaxWidth(),
        cornerRadius = 12.dp,
        insideMargin = PaddingValues(horizontal = 12.dp, vertical = 6.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = SettingsBackdropFlowPage.REMOVED_TOAST.text,
                modifier = Modifier.weight(1f),
                style = MiuixTheme.textStyles.footnote1,
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            )
            TextButton(
                text = SettingsBackdropFlowPage.REMOVE_UNDO.text,
                onClick = { onUndo(undoKey) },
                colors = ButtonDefaults.textButtonColors(),
            )
        }
    }
}
