package com.mutx163.qingyu.pages.transfer

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import kotlinx.coroutines.delay
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 应用内提示胶囊（Dart `HyperosToastCapsule` / `showAppToast` 的对位件）。
 *
 * ## 为什么要有这个共享件
 *
 * 「数据备份与迁移」页 2026-10-29 自己画了一颗胶囊（撤销动作要挂在提示尾部，
 * 系统 Toast 挂不了动作），而「情侣课表设置」页还在用 `android.widget.Toast`
 * ⇒ 同族两页的提示长得不一样、位置不一样（系统 Toast 在屏幕下方偏上、还带
 * 应用图标）。Dart 侧两页都用同一颗 `showAppToast`，所以这里抽成一份共用。
 *
 * ## 观感（2026-11-10 对照 tag v2.1.4.1 重做，M06「统一胶囊观感」）
 *
 * 旧实现是**满宽**白卡 + 左对齐正文 + 行尾一颗实心按钮，读起来像 Material 的
 * snackbar；发布版那颗是**贴着内容的居中胶囊**。逐条对齐
 * `lib/ui/hyperos/hyperos_snackbar.dart:70-221` 与
 * `lib/ui/hyperos/hyperos_miuix_spec.dart` 的 `HyperosMiuixSnackbar`：
 *
 * | 项 | 发布版 | 现在 |
 * |---|---|---|
 * | 宽度 | 贴内容（`IntrinsicWidth`），上限屏宽 × 0.78（`maxWidthFraction`） | `widthIn(max = 屏宽 × 0.78)`，不再 `fillMaxWidth` |
 * | 圆角 / 内边距 | 16；左右各 2 个字（28dp）、上下各 1 个字（14dp） | 16；28 / 14 |
 * | 正文 | 14sp / 400 / 行高 1、**居中**、最多 2 行 | body2、居中、`maxLines = 2` |
 * | 说明行 | 13sp / 1.25 / 主色 72% 透明、居中、最多 4 行、间距 3dp | footnote1 + 次要色、居中、`maxLines = 4`、间距 3dp |
 * | 动作 | **纯文字**（14sp / 500 / 主色），不是填充按钮；与正文块间距 12dp | 纯文字 + 12dp 间距，点按区自带 2dp 内边距 |
 *
 * ## 两处保持不变的取舍（不是漏做）
 *
 * 1. **背景是实底，不做毛玻璃**：发布版在「模糊开着」时才用白 62% + 背景模糊，关了就是
 *    一块实底 `surfaceContainer`（`hyperos_snackbar.dart:35-41`）。毛玻璃要一层能采到
 *    下层像素的 backdrop，而本组件的 8 个调用点都在各自的 `Box` 里按
 *    `align(BottomCenter)` 摆放、拿不到页面的采样层——「调用点不动」的前提下只能走
 *    发布版自己的实底分支。要毛玻璃得先给调用点加 backdrop 参数（另一次改动）。
 * 2. **进出场不动效**：发布版是 220ms 淡入 + 0.96→1 缩放。调用点都是
 *    `toast?.let { AppToastCapsule(...) }` 的条件挂载，退场那一刻组件已被摘出组合，
 *    只能做出「有进场、没退场」的半套动画；按「动效从简」的口径宁可不做，保持即时显隐。
 *
 * ## 口径（照抄 Dart，不是自己拍的）
 *
 * - 底部浮层、圆角 16、动作在文字右侧；
 * - 2 秒自动消失（`HyperosMiuixSnackbar.durationShortMs = 2000`，`app_toast.dart:6-8`）；
 * - 动作按钮点一下先关掉提示再执行回调（Dart 同款顺序，避免回调里又弹一条时
 *   两条叠在一起）。
 *
 * @param description 第二行说明（比正文小一号、次要色）；null = 只有一行。
 *   对应 Dart `showAppToast(description:)`，失败提示的「试试直接打开 App」放这里。
 * @param isError true = 错误样式（正文用 error 色）。发布版只有「带图标」时错误才
 *   有可见差别（图标换色），我们这颗不带图标；但本组件从落地起就用正文色标记失败，
 *   4 个调用点据此区分成功/失败，去掉等于丢信息，所以保留这一处既有契约。
 * @param autoDismissMillis ≤ 0 表示不自动消失（需要用户点一下才走）。
 */
@Composable
fun AppToastCapsule(
    message: String,
    dark: Boolean,
    modifier: Modifier = Modifier,
    description: String? = null,
    isError: Boolean = false,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    onDismiss: () -> Unit = {},
    autoDismissMillis: Long = TOAST_DURATION_MILLIS,
) {
    LaunchedEffect(message, description, actionLabel) {
        if (autoDismissMillis > 0L) {
            delay(autoDismissMillis)
            onDismiss()
        }
    }
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    // 上限 = 屏宽 × 0.78（Dart `HyperosMiuixSnackbar.maxWidthFraction`）：
    // 只用来让长文本换行，短提示仍然贴内容，绝不撑到屏幕两边。
    val maxCapsuleWidth = (LocalConfiguration.current.screenWidthDp * MAX_WIDTH_FRACTION).dp
    QingyuCard(
        modifier = modifier
            .widthIn(max = maxCapsuleWidth)
            // 自绘胶囊不会像系统 Toast 那样被读屏自动播报；合并成一个节点标成 polite
            // live region，让 TalkBack 在提示出现时补念整句（不抢焦点）。
            .semantics(mergeDescendants = true) { liveRegion = LiveRegionMode.Polite },
        cornerRadius = 16.dp,
        insideMargin = PaddingValues(horizontal = 28.dp, vertical = 14.dp),
    ) {
        // `width(IntrinsicSize.Max)` = 发布版的 `IntrinsicWidth`：宽度跟着内容走
        // （短提示就是一小颗胶囊），只有超过宽度上限时才换行。少了这一句 Row 会按
        // 默认 `MainAxisSize.Max` 铺满卡片可用宽度，又变回一条满宽横条。
        Row(
            modifier = Modifier.width(IntrinsicSize.Max),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = message,
                    style = MiuixTheme.textStyles.body2,
                    color = if (isError) {
                        Color(QingyuTheme.error(dark))
                    } else {
                        Color(QingyuTheme.primaryText(dark))
                    },
                    textAlign = TextAlign.Center,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (!description.isNullOrBlank()) {
                    Spacer(modifier = Modifier.height(3.dp))
                    Text(
                        text = description,
                        style = MiuixTheme.textStyles.footnote1,
                        color = secondaryText,
                        textAlign = TextAlign.Center,
                        maxLines = 4,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
            if (actionLabel != null && onAction != null) {
                // 发布版动作是一行纯文字（`hyperos_snackbar.dart:156-167`），
                // 不是填充按钮；字重是 **w500**（`_actionStyle` 的 `FontWeight.w500`），
                // 走仓库的字重平移 API 而不是写死 `fontWeight`，跟随用户「应用字重 / 系统粗体」。
                // 点按区靠自身 2dp 内边距撑出手指大小。
                Text(
                    text = actionLabel,
                    style = MiuixTheme.textStyles.body2.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = MiuixTheme.colorScheme.primary,
                    maxLines = 1,
                    modifier = Modifier
                        .clickable(role = Role.Button) {
                            onDismiss()
                            onAction()
                        }
                        .padding(horizontal = 2.dp, vertical = 2.dp),
                )
            }
        }
    }
}

/** Dart `HyperosMiuixSnackbar.maxWidthFraction` = 0.78（提示只换行、不铺满屏宽）。 */
private const val MAX_WIDTH_FRACTION = 0.78f

/** Dart `HyperosMiuixSnackbar.durationShortMs` = 2000（`app_toast.dart:6-8`）。 */
const val TOAST_DURATION_MILLIS: Long = 2000L
