package com.mutx163.qingyu.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Ok
import top.yukonga.miuix.kmp.squircle.squircleBorder
import top.yukonga.miuix.kmp.squircle.squircleSurface

/**
 * 预设色快选（**全站唯一入口**）：一颗色块（[QingyuColorChip]）或一组自动换行的色块
 * （[QingyuColorChips]）。
 *
 * ## 边界
 *
 * 只服务「预设色挑一个」这种**离散快选**。**自由取色不许用它，也不许自绘**：
 * 那走官方 `ColorPicker`（连续取色盘）。miuix 0.9.4 没有离散快选组件——它的
 * `ColorPalette` / `ColorPicker` 是连续色盘，语义不同；按压面走 miuix `IconButton`
 * 内部同一条 `clickable` 通道（主题 indication），不自己模拟按压反馈。
 *
 * ## 几何（配方 v2，2026-11-10 用户拍板）
 *
 * - **自动换行**（[QingyuColorChips]）：`FlowRow`；不按固定列数切、不横向滚动——
 *   固定 `Row` 色板一加长就横向溢出（设置族真实 bug）。行列间距按「命中盒 48dp、
 *   观感仍是 12dp」反推（见 [QingyuColorChip] 的命中区说明）。
 *   需要发布版那种「一行横滑 + 行尾调色盘」形态时，用单颗 [QingyuColorChip] 自己摆 `Row`。
 * - **边长档位**：见 [QingyuColorChipSize]（42 / 40 / 36 / 32），一档对应一处发布版真实用法。
 * - **命中区**：常规档外层 48dp、视觉色块不变（`149b9da06` 的产品级决定）；QuickRow 例外。
 * - **描边**：走 `squircleBorder`（miuix demo ColorPage 的 squircle 刻度口径），
 *   未选中 1dp `outline`、选中 2dp onSurface 墨（[QingyuTheme.primaryText]）。
 * - **选中标记统一用勾**：45% 大小、按底色亮度选黑 / 白（阈值 0.55）。旧「白点」与
 *   「OK 字」两套退役，别再长回来。
 *
 * ## 只读色点（不是本组件）
 *
 * 导入页 / 重新配色页那种**只读**预览色点用 [QingyuColorPreviewDotSize] /
 * [QingyuColorPreviewDotGap] 自己画点，不要拿 chip 冒充。
 */

/** 单颗色块档位：一档一处发布版真实用法，不按视觉喜好随便挑。 */
enum class QingyuColorChipSize(
    /** 单颗边长。 */
    val edge: Dp,
) {
    /** 42dp：情侣课表「叠加颜色」（发布版 `HyperosHexColorChipGroup.chipSize` 默认值）。 */
    Couple(42.dp),

    /** 40dp：显示设置里的颜色快选。 */
    Settings(40.dp),

    /** 36dp：更紧的宿主（弹层 / 两列排布）。 */
    Small(36.dp),

    /** 32dp：新建/编辑日程顶部快速颜色行（发布版 `_buildPaletteSwatch` 的 32，圆角 8）。 */
    QuickRow(32.dp);

    /**
     * 圆角：快捷行按发布版固定 8dp（`BorderRadius.circular(8)`），
     * 其余按 Dart `HyperosRadius.chipRadius` 的 7/26 比例（42 → ≈11.3dp）。
     */
    val radius: Dp
        get() = when (this) {
            QuickRow -> 8.dp
            else -> edge * 7f / 26f
        }

    /** 勾的大小 = 边长 × 45%（发布版 `_ColorChipIcon` 的 0.45 比例）。 */
    val checkSize: Dp
        get() = edge * 0.45f
}

/**
 * **只读**色点预览的直径（导入页随机配色预览 / 重新配色页色点，不是可选 chip）。
 *
 * 出处：发布版 `lib/widgets/import_random_color_toggle.dart` 的 `width/height: 14`。
 * 与 chip 的 42/40/36/32 档位不是一回事，不要互相借用。
 */
val QingyuColorPreviewDotSize: Dp = 14.dp

/**
 * **只读**色点预览的点间距。
 *
 * 出处：同一份发布版源的 `SizedBox(width: 4)`。注意「行上 6dp」（`only(top: 6)`）
 * 是 Preference 行的排版，不属于色板刻度，留在调用方行内。
 */
val QingyuColorPreviewDotGap: Dp = 4.dp

/** 行列间距：Dart `HyperosHexColorChipGroup` 的 spacing / runSpacing 默认都是 12。 */
private val QingyuColorChipSpacing = 12.dp

/**
 * 一组预设色：按可用宽度**自动换行**（`FlowRow`，行列间距 12dp），不横向滚动。
 *
 * @param colors 预设色值（`#RRGGBB` / `RRGGBB` / `#AARRGGBB` 都收，解析失败回落主题主色）。
 * @param selectedHex 当前选中的色值；null = 一颗都不选中。
 * @param onSelect 点了某颗色块；回调原样的 [colors] 元素，调用方不需要自己规范化。
 * @param dark 是否深色主题。默认跟系统；页面主题档位与系统不一致时**必须显式传**
 *   （本仓 `QingyuPageTheme` 会覆盖 uiMode，通常默认值够用）。
 * @param size 边长档位，默认情侣页口径的 42dp。
 * @param enabled 是否可点。禁用时整颗色块淡到 50% 且不吃点击——官方 `IconButton` 的
 *   `enabled` 只管点击面、不淡色，所以淡色由组件补；调用方**不要再自己套** `alpha(0.5f)`，
 *   否则会叠成 25%。
 * @param dimWhenDisabled 禁用时要不要由组件补那 50% 的淡。**整张卡已经整段淡过**的宿主
 *   （如显示设置页的 `Modifier.alpha(sectionAlpha)`，发布版是整段 `IgnorePointer` +
 *   `AnimatedOpacity(0.5)`、只淡一次）传 `false`：点击仍由 [enabled] 挡住，明暗交给外层，
 *   避免「整卡 0.5 × 组件 0.5 = 25%」把浅色色板（#FFFFFF 这类）淡到看不见。
 * @param contentDescriptionFor 读屏用的每颗色块名称；`null` = 不朗读色名，只保留
 *   「单选 + 已选中」语义。**组件不内置任何页面自己的色名表**（全站色板不绑某一页口径）。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun QingyuColorChips(
    colors: List<String>,
    selectedHex: String?,
    onSelect: (String) -> Unit,
    dark: Boolean = isSystemInDarkTheme(),
    modifier: Modifier = Modifier,
    size: QingyuColorChipSize = QingyuColorChipSize.Couple,
    enabled: Boolean = true,
    dimWhenDisabled: Boolean = true,
    contentDescriptionFor: ((String) -> String)? = null,
) {
    val selected = selectedHex?.trim()?.uppercase()
    // 命中盒撑到 48dp 后，每格比视觉色块大一圈（两侧各 (48 − edge) / 2）。
    // 间距按「观感仍是发布版 12dp」反推：spacing = 12 − (48 − edge) = edge − 36。
    // Settings 40 → 4dp、Couple 42 → 6dp、Small 36 → 0dp。
    // QuickRow（发布版 32dp 密排快捷行）命中盒不撑大、间距保持 12，不在这个公式里。
    val spacing = if (size == QingyuColorChipSize.QuickRow) {
        QingyuColorChipSpacing
    } else {
        (size.edge - 36.dp).coerceAtLeast(0.dp)
    }
    FlowRow(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(spacing),
        verticalArrangement = Arrangement.spacedBy(spacing),
    ) {
        for (hex in colors) {
            QingyuColorChip(
                hex = hex,
                selected = hex.trim().uppercase() == selected,
                onSelect = onSelect,
                dark = dark,
                size = size,
                enabled = enabled,
                dimWhenDisabled = dimWhenDisabled,
                contentDescriptionFor = contentDescriptionFor,
            )
        }
    }
}

/**
 * 单颗色块：视觉本体 = 投影 + squircle 底 + squircle 描边；外面再套一圈 **48dp 命中盒**。
 *
 * ## 命中区（2026-11-03 `149b9da06` 的产品级决定）
 *
 * 可点区不小于 48dp、**视觉尺寸一律不变**（显示设置页为此把色点间距 12 收到 6）。
 * 官方 `IconButton` 只做 `defaultMinSize`，没有自动的最小交互区扩张；直接拿它当
 * 48dp 命中盒又会把 squircle 底一起撑到 48 ⇒ 视觉变大。所以这里外层用
 * `sizeIn(minWidth = 48.dp, minHeight = 48.dp)` + 官方同一条点击通道（`clickable`，
 * miuix 的 IconButton 内部也是它，按压反馈来自主题 indication），内层色块固定
 * `size.edge` 居中——点击面 48、观感仍是 42 / 40 / 36。
 *
 * **QuickRow（32dp）例外**：发布版加日程快捷行是 32dp 密排、间距 8；撑到 48 会让相邻
 * 命中盒互相重叠、点错色。这一档命中盒 = 视觉尺寸，保持发布版几何（提交 `149b9da06`
 * 当初也只给显示设置 / 考试 / 引导三处 48dp，不含这类密排色带）。
 *
 * @param showShadow 是否带同色 22% 投影。情侣页 / 设置页带；发布版加日程的快捷行是平的，
 *   传 false。
 * @param enabled 是否可点；禁用时整颗淡到 50%（可用 [dimWhenDisabled] 关掉，让外层整段
 *   alpha 负责唯一一次淡化）。
 * @param dimWhenDisabled 禁用时是否由本组件补 50% 淡化；默认 true。外层已整卡淡过的
 *   宿主传 false，避免叠成 25%。
 */
@Composable
fun QingyuColorChip(
    hex: String,
    selected: Boolean,
    onSelect: (String) -> Unit,
    dark: Boolean = isSystemInDarkTheme(),
    modifier: Modifier = Modifier,
    size: QingyuColorChipSize = QingyuColorChipSize.Couple,
    showShadow: Boolean = true,
    enabled: Boolean = true,
    dimWhenDisabled: Boolean = true,
    contentDescriptionFor: ((String) -> String)? = null,
) {
    val color = parseChipColor(hex, fallback = Color(QingyuTheme.primary(dark = dark)))
    val shape = RoundedCornerShape(size.radius)
    val outline = if (selected) {
        // 「选中 = onSurface 墨」：本仓主题桥里 onSurface 就是主体文字色。
        Color(QingyuTheme.primaryText(dark))
    } else {
        Color(QingyuTheme.outline(dark))
    }
    val label = contentDescriptionFor?.invoke(hex)
    // 命中盒：常规档 48dp；QuickRow 保持发布版 32dp 密排，不撑大。
    val hitEdge = if (size == QingyuColorChipSize.QuickRow) size.edge else 48.dp
    Box(
        modifier = modifier
            // 禁用态：点击由 clickable(enabled = false) 挡住；淡化只在要求时补一次。
            .alpha(if (!enabled && dimWhenDisabled) 0.5f else 1f)
            .sizeIn(minWidth = hitEdge, minHeight = hitEdge)
            .clickable(
                enabled = enabled,
                role = Role.RadioButton,
                onClick = { onSelect(hex) },
            )
            .semantics {
                if (label != null) contentDescription = label
                // 单选态交给语义属性，不写进文案。
                this.selected = selected
            },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(size.edge)
                .then(
                    if (showShadow) {
                        Modifier.shadow(
                            elevation = 4.dp,
                            shape = shape,
                            clip = false,
                            ambientColor = color.copy(alpha = 0.22f),
                            spotColor = color.copy(alpha = 0.22f),
                        )
                    } else {
                        Modifier
                    },
                )
                // 底色与描边都走 squircle 曲线（配方 v2），两条同一条刻度。
                .squircleSurface(color = color, cornerRadius = size.radius)
                .squircleBorder(
                    width = if (selected) 2.dp else 1.dp,
                    color = outline,
                    cornerRadius = size.radius,
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (selected) {
                // 亮底用黑勾、暗底用白勾（发布版 `_contrastIconColor` 阈值 0.55）。
                Icon(
                    imageVector = MiuixIcons.Ok,
                    contentDescription = null,
                    tint = if (color.luminance() > 0.55f) Color.Black else Color.White,
                    modifier = Modifier.size(size.checkSize),
                )
            }
        }
    }
}

/**
 * 十六进制色 → Compose 颜色。
 *
 * 解析不出来时用调用方给的 [fallback]（主色），**不要**写死一个字面色：
 * 写死会在换主题色 / 深色模式下与周围不一致（样式守卫 R5 也拦这条）。
 */
internal fun parseChipColor(hex: String, fallback: Color): Color {
    val trimmed = hex.trim().removePrefix("#")
    return try {
        when (trimmed.length) {
            6 -> Color(trimmed.toLong(16) or 0xFF000000)
            8 -> Color(trimmed.toLong(16))
            else -> fallback
        }
    } catch (_: NumberFormatException) {
        fallback
    }
}


// ── 预览（一屏档 400×900）────────────────────────────────────────────────

/**
 * 组件预览：容器自动换行的一屏档。
 *
 * 只给色值、不写屏上文案（`onSelect` 空实现）；外层 [QingyuPageTheme] 与加课页预览
 * 同一套包裹，AS 里看到的间距 / 描边 / 勾就是真机口径。预览名是中文：按全仓口径
 * （IDE 标签、不是屏上文案），CJK 基线的增量由提交窗统一登记。
 */
@Preview(name = "色块组 · 42dp", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewQingyuColorChipsGroup() {
    QingyuPageTheme(isDark = false) {
        QingyuColorChips(
            colors = previewColorHexes,
            selectedHex = previewColorHexes[1],
            onSelect = {},
            dark = false,
            size = QingyuColorChipSize.Couple,
            modifier = Modifier.padding(16.dp),
        )
    }
}

/** 组件预览：单颗色块的选中 / 未选中两态（勾只画在选中那颗上）。 */
@Preview(name = "单颗色块 · 选中态", showBackground = true, widthDp = 400, heightDp = 900)
@Composable
private fun PreviewQingyuColorChipStates() {
    QingyuPageTheme(isDark = false) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            QingyuColorChip(hex = previewColorHexes[0], selected = true, onSelect = {}, dark = false)
            QingyuColorChip(hex = previewColorHexes[1], selected = false, onSelect = {}, dark = false)
        }
    }
}

/** 预览用色板（只放色值，预览页不需要真数据）。 */
private val previewColorHexes = listOf(
    "#6366F1", "#0EA5E9", "#2196F3", "#8B5CF6", "#D946EF",
    "#F97316", "#22C55E", "#14B8A6", "#EF4444", "#F59E0B",
)
