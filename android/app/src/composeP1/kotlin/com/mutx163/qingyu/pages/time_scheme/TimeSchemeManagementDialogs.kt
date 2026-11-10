package com.mutx163.qingyu.pages.time_scheme

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntRect
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.rememberSheetMaxHeight
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.theme.QingyuTheme
import kotlin.math.roundToInt

import top.yukonga.miuix.kmp.basic.BasicComponent
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.ButtonDefaults
import top.yukonga.miuix.kmp.basic.DropdownDefaults
import top.yukonga.miuix.kmp.basic.DropdownImpl
import top.yukonga.miuix.kmp.basic.ListPopupColumn
import top.yukonga.miuix.kmp.basic.PopupPositionProvider
import top.yukonga.miuix.kmp.basic.HorizontalDivider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.basic.TextField
import top.yukonga.miuix.kmp.overlay.OverlayDialog
import top.yukonga.miuix.kmp.overlay.OverlayListPopup
import top.yukonga.miuix.kmp.theme.MiuixTheme
import top.yukonga.miuix.kmp.utils.overScrollVertical
import top.yukonga.miuix.kmp.utils.scrollEndHaptic

/**
 * 时间模板管理页的**全部弹层**（渲染层）。
 *
 * 与页面一样，本文件只摆像素 + 上报意图：显隐由宿主 `app/TimeSchemeHost.kt` 的
 * `TimeSchemeDialog` 状态机控制，落盘写入口也都在宿主。入参为 `null` = 不显示
 * （与 `TimeSchemeManagementPage` 的「纯函数」姿势一致）。
 *
 * ## 五个弹层各自对 Dart 的哪一段
 *
 * | 弹层 | Dart 来源 | 容器 | 为什么是这个容器 |
 * |---|---|---|---|
 * | `TimeSchemeMenuSheet` | `_openSchemeMenu`（:286-345）的条目顺序与出现条件 | `QingyuSheet`（共享底部弹层封装） | Dart 是锚点变形菜单（`HyperosAnchorMenuPopup`），需要按钮的窗口坐标；渲染层拿不到锚点坐标（那是宿主的事），所以退成官方底部动作表——同样是「从下方来的一列动作」，且不新造菜单组件 |
 * | `TimeSchemeNameSheet` | `_createScheme`（:571-612）/ `_renameScheme`（:614-658） | `OverlayDialog` | Dart `showAppTextInputDialog` 是居中对话框（标题 + 输入框 + 两个动作） |
 * | `TimeSchemeDeleteSheet` | `_deleteScheme`（:660-719）的确认框 | `OverlayDialog` | Dart `showHyperosConfirmDialog` 是居中对话框 |
 * | `TimeSchemeDeleteBlockedSheet` | `_explainDeleteBlocked`（:725-812） | `OverlayDialog` | 同上（`showHyperosDialog`），正文是占用清单，不是动作表 |
 * | `TimeSchemeUsageSheet` | `_showUsageDetails`（:1018-1179） | `OverlayDialog`（内容自己滚） | Dart 就是 `showHyperosDialog` + `SingleChildScrollView`；这里用官方 `LazyColumn` 三件套里的两件（`scrollEndHaptic` + `overScrollVertical`）承载可能很长的引用清单 |
 * | `TimeSchemeShareSheetDialog` | `_shareTimeScheme`（:851-893） | `OverlayDialog` | 同上（三个动作的对话框） |
 *
 * ## 与 Dart 的已知差异（诚实清单）
 *
 * - 菜单是**底部动作表**而不是锚点变形菜单（理由见上表）；
 * - 使用情况弹层的三段固定列表在 Dart 里是「有边框的小卡」，这里用共享 `QingyuCard`
 *   （官方 `Card` 的薄封装）承载，圆角/底色随主题；
 * - `TimeSchemeShareSheetDialog` 正文居中显示模板名（与 Dart `_shareTimeScheme` 同口径）；
 *   宿主当前也未接分享（见其文件头差异表）；
 * - 新建/重命名弹层没有用 `sheet.nameHint`：miuix `TextField` 只有 `label` 一个槽位
 *   （`useLabelAsPlaceholder` 决定它是「占位」还是「浮动标签」），给不出「标签 + 提示」两层。
 *   这里按发布版口径取 `label` 并把 `useLabelAsPlaceholder` 归 false（浮动标签）——
 *   Dart `hyperos_text_field.dart:47-48` 正是「有 label ⇒ 不用占位模式」。
 *
 * ## 常驻组合（2026-11-02 弹层债）
 *
 * 宿主把六个弹层**全部常驻**在组合里，可见性只交给 `show`——条件挂载会让官方退场动画
 * 一次都播不出来。所以每个弹层内部都用 [rememberLastNonNull] 钉住最后一份非空入参：
 * 退场动画期间标题/正文照常渲染，不会闪成空板。
 */

/**
 * 卡片「更多」菜单的一次打开会话。
 *
 * 条目在宿主打开瞬间就冻结成一份（`items`），与 Dart `_SchemeMenuSession` 同口径：
 * 弹层收起动画期间还要拿同一份条目，现算会随仓储通知变化。
 */
data class TimeSchemeMenuState(
    val schemeId: String,
    val schemeName: String,
    val items: List<TimeSchemeMenuItem>,
)

/**
 * 模板行内「更多」的**锚点菜单**（Dart `_openSchemeMenu` → `HyperosAnchorMenuPopup`）。
 *
 * ## 形态：贴 ⋮ 弹出的小面板，不是底部弹层
 *
 * 发布版 `time_scheme_management_screen.dart:286-345` 用 `HyperosAnchorMenuPopup`：
 * 锚在行内「三个点」的窗口矩形上弹出，默认宽 200（`os4GlassPopupStandardSizing`，
 * 源码注明「全软件统一口径，别为单个菜单私开数字」），条目纯文字、删除项红字、
 * **没有「取消」条目**（点空白/返回键收起）。
 *
 * 2026-11-10 用户报「整版直接列动作、难看、不直观」——那是旧的底部动作表形态；本组件
 * 换回发布版形态。配方与 `CourseOverviewPage` 的排序弹层同一套：官方 [OverlayListPopup]
 * + [ListPopupColumn] + [DropdownImpl]，遮罩 / 进出场 / 返回键 / 点空白关闭全部官方自带；
 * 定位走官方 [PopupPositionProvider] 扩展点，锚点由行内 ⋮ 的 `boundsInWindow()` 实测。
 *
 * 常驻组合、按 `state != null` 切显隐：退场动画期间沿用最后一份条目与锚点（发布版同口径，
 * 见其 `_schemeMenuSession` 注释）。
 */
@Composable
fun TimeSchemeMenuPopup(
    state: TimeSchemeMenuState?,
    anchor: Rect?,
    onDismiss: () -> Unit,
    onAction: (TimeSchemeAction) -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val current = rememberLastNonNull(state)
    // 退场期 anchor 会被宿主置空：钉住最后一份，面板不会先跳回屏幕角上再消失。
    var lastAnchor by remember { mutableStateOf<Rect?>(anchor) }
    if (anchor != null) lastAnchor = anchor

    val items = current?.items.orEmpty()
    val density = LocalDensity.current
    val positionProvider = remember(lastAnchor, density) {
        val gapPx = with(density) { 4.dp.roundToPx() }
        object : PopupPositionProvider {
            override fun calculatePosition(
                anchorBounds: IntRect,
                windowBounds: IntRect,
                layoutDirection: LayoutDirection,
                popupContentSize: IntSize,
                popupMargin: IntRect,
                alignment: PopupPositionProvider.Align,
            ): IntOffset {
                // 右对齐到 ⋮ 的右缘、贴其下方 4dp；锚点还没量到时退回窗口右上角。
                val x = (lastAnchor?.right?.roundToInt() ?: windowBounds.right) - popupContentSize.width
                val y = (lastAnchor?.bottom?.roundToInt() ?: windowBounds.top) + gapPx
                return IntOffset(
                    x = x.coerceIn(
                        windowBounds.left,
                        (windowBounds.right - popupContentSize.width).coerceAtLeast(windowBounds.left),
                    ),
                    y = y.coerceIn(
                        windowBounds.top,
                        (windowBounds.bottom - popupContentSize.height).coerceAtLeast(windowBounds.top),
                    ),
                )
            }

            override fun getMargins(): PaddingValues = PaddingValues(0.dp)
        }
    }

    // 常驻组合、按 show 切显示：进出场由官方组件内部驱动，退场动画能播完。
    OverlayListPopup(
        show = state != null,
        popupPositionProvider = positionProvider,
        alignment = PopupPositionProvider.Align.End,
        onDismissRequest = onDismiss,
    ) {
        ListPopupColumn {
            items.forEachIndexed { index, item ->
                val destructive = item.action == TimeSchemeAction.DELETE
                DropdownImpl(
                    text = item.label,
                    optionSize = items.size,
                    isSelected = false,
                    index = index,
                    // 删除项只染**字**（发布版 destructive），照常可点：点它只会开对话框
                    //（有引用时说明是什么挡住了删除）。
                    dropdownColors = if (destructive) {
                        DropdownDefaults.dropdownColors(contentColor = Color(QingyuTheme.error(dark)))
                    } else {
                        DropdownDefaults.dropdownColors()
                    },
                    onSelectedIndexChange = { onAction(item.action) },
                )
            }
        }
    }
}

/**
 * 新建 / 重命名共用的文本输入弹层（Dart `showAppTextInputDialog`）。
 *
 * 校验不在这里做：宿主拿到 `onConfirm` 的原文后调 `model.validateName`，
 * 这样「什么算合法名字」只有模型一处口径。
 */
@Composable
fun TimeSchemeNameSheet(
    sheet: TimeSchemeSheet?,
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit,
) {
    val current = rememberLastNonNull(sheet)
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = sheet != null,
        title = current?.title,
        onDismissRequest = onDismiss,
    ) {
        if (current != null) {
            var text by remember(current) { mutableStateOf(current.initialName) }
            TextField(
                value = text,
                onValueChange = { text = it },
                label = current.nameLabel,
                // 发布版这里传的是 `label:`（`hyperos_text_field.dart:47-48`：有 label 时
                // `useLabelAsPlaceholder = false`）⇒ 「模板名称」是**浮动标签**：框里空着时当占位，
                // 一输入就缩到框内上沿、始终告诉用户这格填的是什么。原来按占位模式渲染，
                // 输入第一个字标签就消失，改名时只能靠上方标题和已填内容猜这格是什么。
                singleLine = true,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
            )
            DialogActionRow(
                cancelLabel = TimeSchemeManagementStrings.cancelAction.text,
                onCancel = onDismiss,
                confirmLabel = current.confirmLabel,
                onConfirm = { onConfirm(text) },
            )
        }
    }
}

/**
 * 删除确认框（Dart `showHyperosConfirmDialog(destructive: true)`）。
 *
 * 只有「这套模板确实能删」时宿主才会用它；有引用的那一路走
 * [TimeSchemeDeleteBlockedSheet]，所以这里没有「查看使用情况」动作
 * （`onViewUsage` 仅为契约签名保留，宿主在可删分支不会用到它）。
 */
@Composable
fun TimeSchemeDeleteSheet(
    check: TimeSchemeDeleteCheck?,
    onCancel: () -> Unit,
    onConfirm: () -> Unit,
    onViewUsage: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val current = rememberLastNonNull(check)
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = check != null,
        title = current?.title,
        summary = current?.message,
        onDismissRequest = onCancel,
    ) {
        if (current != null) {
            Column(modifier = Modifier.fillMaxWidth()) {
                if (current.inUseNote.isNotBlank()) {
                    Text(
                        text = current.inUseNote,
                        style = MiuixTheme.textStyles.footnote1,
                        color = Color(QingyuTheme.secondaryText(dark)),
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                }
                DialogActionRow(
                    // Dart 的两个删除弹层里「取消」都用 `l10n.cancelAction`（`_deleteScheme:683` /
                    // `_explainDeleteBlocked:793`）；模型目前把 `cancelLabel` 灌成 `closeAction`
                    // （「关闭」），那是使用情况弹层的动作词，所以这里直接用 ARB 的 cancelAction。
                    cancelLabel = TimeSchemeManagementStrings.cancelAction.text,
                    onCancel = onCancel,
                    confirmLabel = current.confirmLabel,
                    onConfirm = onConfirm,
                    destructive = true,
                    // 可删分支不出现次要动作（Dart 的确认框只有「取消 / 删除」两项）；
                    // 只有宿主误把被占用的模板塞进来时才补一条「查看使用情况」。
                    onSecondary = if (current.canDelete) null else onViewUsage,
                )
            }
        }
    }
}

/**
 * 删除被拦弹层（Dart `_explainDeleteBlocked`，:725-812）。
 *
 * 结构逐条对：抬头一句居中说明（`blockerIntro`）→ 左对齐的占用清单（每条一段，
 * 行间 8dp）→ 两个动作「取消 / 查看使用情况」。
 *
 * 不加引导圆点：Dart 注释写明「这弹层通常只有一个占用方，圆点不携带信息」，
 * 而且主色圆点在深色主题下会被读成脏点。
 */
@Composable
fun TimeSchemeDeleteBlockedSheet(
    check: TimeSchemeDeleteCheck?,
    onCancel: () -> Unit,
    onViewUsage: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val current = rememberLastNonNull(check)
    // 占用清单条数无上界：正文限高 + 可滚，两个动作按钮固定在外。
    val maxBodyHeight = rememberSheetMaxHeight(0.45f)
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = check != null,
        title = current?.title,
        onDismissRequest = onCancel,
    ) {
        if (current != null) {
            Column(modifier = Modifier.fillMaxWidth()) {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = maxBodyHeight)
                        .scrollEndHaptic()
                        .overScrollVertical(),
                ) {
                    if (current.blockerIntro.isNotBlank()) {
                        item(key = "intro") {
                            Text(
                                text = current.blockerIntro,
                                // Dart 抬头句是 listDetail（body2 同档）+ 主文本墨色。
                                style = MiuixTheme.textStyles.body2,
                                // 抬头句沿用对话框自己的居中惯例（与 Dart 同口径）。
                                textAlign = TextAlign.Center,
                                color = Color(QingyuTheme.primaryText(dark)),
                                modifier = Modifier.fillMaxWidth(),
                            )
                            Spacer(modifier = Modifier.height(12.dp))
                        }
                    }
                    items(current.blockers) { line ->
                        Text(
                            text = line,
                            style = MiuixTheme.textStyles.body2,
                            textAlign = TextAlign.Start,
                            color = Color(QingyuTheme.secondaryText(dark)),
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 8.dp),
                        )
                    }
                }
                // Dart `HyperosDialogAction` 两个动作是**横排等宽**（`_HyperosDialogActions`
                // 的两动作分支，间距 12）——2026-11-02 弹层债 #6，不再竖排整宽。
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    TextButton(
                        modifier = Modifier.weight(1f),
                        // 同 [TimeSchemeDeleteSheet]：Dart 这里也是 `cancelAction`（「取消」），
                        // 不是使用情况弹层的 `closeAction`（「关闭」）。
                        text = TimeSchemeManagementStrings.cancelAction.text,
                        onClick = onCancel,
                    )
                    TextButton(
                        modifier = Modifier.weight(1f),
                        text = TimeSchemeManagementStrings.viewUsageAction.text,
                        colors = ButtonDefaults.textButtonColorsPrimary(),
                        onClick = onViewUsage,
                    )
                }
            }
        }
    }
}

/**
 * 使用情况详情（Dart `_showUsageDetails`，:1018-1179）。
 *
 * 结构逐条对：说明句 → 三个统计 chip（课表 / 课程 / 副时间模板）→ 三段**固定**列表
 * （直接绑定 / 跟随主模板 / 副时间模板，各有自己的空态句）→ 两个**有才显示**的段
 * （地点作息匹配 / 日期作息规则，副标题是「需先改绑到别的模板才能删除」）→ 「关闭」。
 *
 * 内容可能很长，所以清单部分走官方 `LazyColumn` + 两件滚动修饰（抽屉里没有顶栏，
 * 官方只挂 `scrollEndHaptic` + `overScrollVertical`，见 `BottomSheetSection.kt:209-213`）。
 */
@Composable
fun TimeSchemeUsageSheet(
    view: TimeSchemeUsageView?,
    onClose: () -> Unit,
) {
    val dark = isSystemInDarkTheme()
    val current = rememberLastNonNull(view)
    // 清单限高按屏高走：矮屏不再被 380dp 硬上限顶掉「关闭」按钮。
    val maxListHeight = rememberSheetMaxHeight(0.42f)
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = view != null,
        title = current?.title,
        onDismissRequest = onClose,
    ) {
        if (current != null) {
            Column(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = current.intro,
                    // Dart 说明句是 listDetail（body2 同档）——2026-11-02 弹层债 #11。
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
                Spacer(modifier = Modifier.height(12.dp))
                UsageCountChips(
                    profileLabel = current.profileCountLabel,
                    profileValue = current.profileCountValue,
                    courseLabel = current.courseCountLabel,
                    courseValue = current.courseCountValue,
                    overrideLabel = current.overrideCountLabel,
                    overrideValue = current.overrideCountValue,
                )
                Spacer(modifier = Modifier.height(16.dp))
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        // 弹窗里必须给上界，否则 LazyColumn 在无界高度里量不出来。
                        .heightIn(max = maxListHeight)
                        .scrollEndHaptic()
                        .overScrollVertical(),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    item(key = "directProfiles") {
                        UsageSection(
                            title = current.directProfilesTitle,
                            subtitle = current.directProfilesSubtitle,
                            lines = current.directProfiles,
                            emptyText = current.directProfilesEmpty,
                        )
                    }
                    item(key = "followMainCourses") {
                        UsageSection(
                            title = current.followTitle,
                            subtitle = current.followSubtitle,
                            lines = current.followLines,
                            emptyText = current.followEmpty,
                        )
                    }
                    item(key = "overrideCourses") {
                        UsageSection(
                            title = current.overrideTitle,
                            subtitle = current.overrideSubtitle,
                            lines = current.overrideLines,
                            emptyText = current.overrideEmpty,
                        )
                    }
                    // 地点规则与日期规则**有才显示**（Dart `if (…isNotEmpty)`）：
                    // 常见的「只有一个占用方」场景不该长两个空盒子。
                    if (current.locationLines.isNotEmpty()) {
                        item(key = "locationGroups") {
                            UsageSection(
                                title = current.locationTitle,
                                subtitle = current.locationSubtitle,
                                lines = current.locationLines,
                                emptyText = null,
                            )
                        }
                    }
                    if (current.dateRuleLines.isNotEmpty()) {
                        item(key = "dateRules") {
                            UsageSection(
                                title = current.dateRuleTitle,
                                subtitle = current.dateRuleSubtitle,
                                lines = current.dateRuleLines,
                                emptyText = null,
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = TimeSchemeManagementStrings.closeAction.text,
                    onClick = onClose,
                )
            }
        }
    }
}

/**
 * 分享二选一（Dart `_shareTimeScheme`，:851-893）：取消 / 二维码分享 / 系统分享文件。
 *
 * 三个动作都是「上报」，真正打包与分享在宿主。
 *
 * [qrEnabled] 只在「壳还没接上二维码发送页」时为 false：那时候二维码这条路点下去什么都不会
 * 发生，所以干脆不画这一行（宿主按 `onRequestQrSend` 是否有值传进来）。壳接上之后默认就是 true，
 * 与发布版的三动作完全一致。
 */
@Composable
fun TimeSchemeShareSheetDialog(
    sheet: TimeSchemeShareSheet?,
    onDismiss: () -> Unit,
    onShareSystem: () -> Unit,
    onShareQr: () -> Unit,
    qrEnabled: Boolean = true,
) {
    val dark = isSystemInDarkTheme()
    val current = rememberLastNonNull(sheet)
    OverlayDialog(
        insideMargin = DpSize(16.dp, 16.dp),
        show = sheet != null,
        title = current?.title,
        onDismissRequest = onDismiss,
    ) {
        if (current != null) {
            Column(modifier = Modifier.fillMaxWidth()) {
                // Dart `_shareTimeScheme:859-865`：正文居中显示模板名，且用主文本墨色
                //（默认次级灰在液态玻璃弹窗上几乎不可见）——2026-11-02 弹层债 #7 补上。
                if (current.schemeName.isNotBlank()) {
                    Text(
                        text = current.schemeName,
                        style = MiuixTheme.textStyles.body2,
                        textAlign = TextAlign.Center,
                        color = Color(QingyuTheme.primaryText(dark)),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                }
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = current.cancelLabel,
                    onClick = onDismiss,
                )
                Spacer(modifier = Modifier.height(12.dp))
                if (qrEnabled) {
                    TextButton(
                        modifier = Modifier.fillMaxWidth(),
                        text = current.viaQrLabel,
                        onClick = onShareQr,
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                }
                TextButton(
                    modifier = Modifier.fillMaxWidth(),
                    text = current.viaSystemLabel,
                    colors = ButtonDefaults.textButtonColorsPrimary(),
                    onClick = onShareSystem,
                )
            }
        }
    }
}

// ────────────────────────────── 内部小件 ──────────────────────────────

/**
 * 退场期保留最后一份非空状态（常驻组合配方的一半，见文件头「常驻组合」）。
 *
 * 宿主把弹层常驻在组合里，`show` 归 false 的退场动画期间内容 lambda 还会被组合——
 * 直接读可空入参会把标题/正文清成空板（审核报告 S10）。这里用 remember 钉住
 * 最后一份非空值，六个弹层共用。
 */
@Composable
private fun <T : Any> rememberLastNonNull(current: T?): T? {
    var shown by remember { mutableStateOf(current) }
    if (current != null) {
        shown = current
    }
    return shown
}

/**
 * 对话框底部动作区（Dart `HyperosDialogAction` 的排列，`hyperos_dialog.dart`
 * 的 `_HyperosDialogActions`）：两个动作**横排等宽**，三个及以上**竖排全宽**，
 * 间距一律 12dp（2026-11-02 弹层债 #8/#9）。
 *
 * ## 每一颗都是**实心块钮**（2026-11-10 Chief 口径）
 *
 * 发布版对话框动作统一是 `HyperosButton`（`hyperos_dialog.dart:126-137` 的 `_variantFor`，
 * `expand: true`），三档变体：取消 = `secondary`、确认 = `primary`、
 * `destructive` = `error` 底 + `onError` 字（`hyperos_controls.dart:724-729`，**不受**
 * `onFrostedPanel` 影响）。所以这里不再用文字钮：只把确认键换成实心块、
 * 取消键留细字，会成「灰文字 + 红实心块」混搭，与发布版不是同一形制
 *（在仓先例：D17 删除课表对话框 `TimetableProfilesPage.kt:740-758`）。
 *
 * ⚠️ 水洗底（`error @ 亮 .10 / 暗 .14`）是**磨砂 sheet 按钮**那一套
 *（`hyperos_controls.dart:817-846`，样板 `CourseActionSheet.kt:785-800`），两套都是发布版口径、
 * 不能互相套：对话框里的动作一律实心。
 */
@Composable
private fun DialogActionRow(
    cancelLabel: String,
    onCancel: () -> Unit,
    confirmLabel: String,
    onConfirm: () -> Unit,
    destructive: Boolean = false,
    onSecondary: (() -> Unit)? = null,
) {
    if (onSecondary == null) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            DialogActionButton(
                modifier = Modifier.weight(1f),
                label = cancelLabel,
                kind = DialogActionKind.SECONDARY,
                onClick = onCancel,
            )
            DialogActionButton(
                modifier = Modifier.weight(1f),
                label = confirmLabel,
                kind = if (destructive) DialogActionKind.DESTRUCTIVE else DialogActionKind.PRIMARY,
                onClick = onConfirm,
            )
        }
    } else {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            DialogActionButton(
                modifier = Modifier.fillMaxWidth(),
                label = cancelLabel,
                kind = DialogActionKind.SECONDARY,
                onClick = onCancel,
            )
            DialogActionButton(
                modifier = Modifier.fillMaxWidth(),
                label = TimeSchemeManagementStrings.viewUsageAction.text,
                kind = DialogActionKind.SECONDARY,
                onClick = onSecondary,
            )
            DialogActionButton(
                modifier = Modifier.fillMaxWidth(),
                label = confirmLabel,
                kind = if (destructive) DialogActionKind.DESTRUCTIVE else DialogActionKind.PRIMARY,
                onClick = onConfirm,
            )
        }
    }
}

/** 对话框动作的三档形制，与发布版 `HyperosButtonVariant` 一一对应。 */
private enum class DialogActionKind { SECONDARY, PRIMARY, DESTRUCTIVE }

/**
 * 对话框里的一颗动作钮（实心块钮，`HyperosButton(expand: true)` 的形状）。
 *
 * 两个分支（两动作横排 / 三动作竖排）共用它，免得只有一支跟着新口径走。
 * 为什么 `destructive` 不是「红字 + 淡红水洗底」：那是磨砂 sheet 按钮的变体，
 * 见 [DialogActionRow] KDoc。
 */
@Composable
private fun DialogActionButton(
    modifier: Modifier,
    label: String,
    kind: DialogActionKind,
    onClick: () -> Unit,
) {
    val colors = when (kind) {
        // 发布版 secondary = `HyperosColors.secondary` 实心底（`hyperos_controls.dart:697-711`）。
        DialogActionKind.SECONDARY -> ButtonDefaults.buttonColors()
        DialogActionKind.PRIMARY -> ButtonDefaults.buttonColorsPrimary()
        // S4 口径：实心危险底必须同时给 contentColor，否则是「红底 + 默认灰字」。
        DialogActionKind.DESTRUCTIVE -> ButtonDefaults.buttonColors(
            color = MiuixTheme.colorScheme.error,
            contentColor = MiuixTheme.colorScheme.onError,
        )
    }
    Button(modifier = modifier, onClick = onClick, colors = colors) {
        Text(text = label)
    }
}

/** 三个统计 chip（Dart `_TimeSchemeInfoChip` → `HyperosTag('label value')`，横向 Wrap）。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun UsageCountChips(
    profileLabel: String,
    profileValue: String,
    courseLabel: String,
    courseValue: String,
    overrideLabel: String,
    overrideValue: String,
) {
    // Dart 是 `Wrap(spacing: 8, runSpacing: 8)`：三个 chip 在窄屏上会折行。
    // 用固定 Row 会在弹窗内宽里把最后一个 chip 挤出去（三个中文 chip 合计约 320dp）。
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        UsageChip(text = "$profileLabel $profileValue")
        UsageChip(text = "$courseLabel $courseValue")
        UsageChip(text = "$overrideLabel $overrideValue")
    }
}

/**
 * 单个统计 chip。
 *
 * 配色逐项对 Dart `HyperosTag`（`hyperos_badge.dart:70-95`）：底是
 * `theme.colors.secondaryContainer`（带一点强调色的容器面）、字是 `theme.colors.onSurface`
 * （主文本墨色）。原来用 `surfaceContainerHighest` + 次级灰，chip 在弹窗里读成「一格格
 * 灰底灰字的说明」，和发布版的强调色小标签差一个量级——chip 本来就该显眼。
 */
@Composable
private fun UsageChip(text: String) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(6.dp))
            .background(MiuixTheme.colorScheme.secondaryContainer)
            .padding(horizontal = 8.dp, vertical = 2.dp),
    ) {
        Text(
            text = text,
            // Dart 是 12sp w500；miuix 字阶没有 12 档，取最接近的 footnote1(13)，
            // 字重差走 shiftWeight（不写死字重，用户字重/系统粗体设置仍然生效）。
            // 不限 maxLines：外语文案折行显示，不截断。
            style = MiuixTheme.textStyles.footnote1.shiftWeight(QingyuWeightDelta.MEDIUM),
            color = MiuixTheme.colorScheme.onSurface,
        )
    }
}

/**
 * 使用情况里的一段（Dart `_UsageSection`）：标题 + 副标题 + 逐条带主色小圆点的引用行。
 *
 * `emptyText` 为 null 表示「这段只在有内容时出现」，不拼空态句。
 */
@Composable
private fun UsageSection(
    title: String,
    subtitle: String,
    lines: List<TimeSchemeLine>,
    emptyText: String?,
) {
    val dark = isSystemInDarkTheme()
    QingyuCard(
        modifier = Modifier.fillMaxWidth(),
        insideMargin = PaddingValues(12.dp),
    ) {
        Text(
            text = title,
            // Dart 段标题是 listTitle（17，main 同档）——2026-11-02 弹层债 #11，原来的
            // body1(16) 比它小一档。
            style = MiuixTheme.textStyles.main,
            color = Color(QingyuTheme.primaryText(dark)),
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = subtitle,
            // Dart 副标题是 listDetail（body2 同档），原来的 footnote1(13) 小一档。
            style = MiuixTheme.textStyles.body2,
            color = Color(QingyuTheme.secondaryText(dark)),
        )
        Spacer(modifier = Modifier.height(10.dp))
        if (lines.isEmpty()) {
            val text = emptyText ?: subtitle
            Text(
                text = text,
                style = MiuixTheme.textStyles.body2,
                color = Color(QingyuTheme.secondaryText(dark)),
            )
        } else {
            for (line in lines) {
                UsageLineItem(line = line)
            }
        }
    }
}

/** 一条引用（Dart `_UsageLine`）：5dp 主色小圆点 + 主行 +（可选）副行。 */
@Composable
private fun UsageLineItem(line: TimeSchemeLine) {
    val dark = isSystemInDarkTheme()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier
                .padding(top = 6.dp)
                .size(5.dp)
                .clip(CircleShape)
                .background(Color(QingyuTheme.primary(dark = dark))),
        )
        Spacer(modifier = Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = line.title,
                // Dart 主行是 listTitle（main 同档），副行是 listDetail（body2 同档）——#11。
                style = MiuixTheme.textStyles.main,
                color = Color(QingyuTheme.primaryText(dark)),
            )
            if (line.summary.isNotBlank()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(
                    text = line.summary,
                    style = MiuixTheme.textStyles.body2,
                    color = Color(QingyuTheme.secondaryText(dark)),
                )
            }
        }
    }
}
