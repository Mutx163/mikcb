package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.AppLocaleRuntime
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.components.QingyuCardDefaults
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Badge
import top.yukonga.miuix.kmp.basic.BadgedBox
import top.yukonga.miuix.kmp.basic.DropdownEntry
import top.yukonga.miuix.kmp.basic.DropdownItem
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.IconButton
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.AddCircle
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.FavoritesFill
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Import
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Promotions
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Tasks
import top.yukonga.miuix.kmp.menu.OverlayIconCascadingDropdownMenu
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 顶栏的**附加状态**：待更新提示 + 情侣课表叠加开关。
 *
 * 发布版这两个东西都长在同一条标题栏上：
 * * 爱心按钮（`lib/screens/timetable_screen.dart:1036-1059`，仅绑定后出现，点一下
 *   开/关叠加并持久化到 `coupleTimetableOverlayEnabled`，默认关）；
 * * 「更多」按钮的待更新红点（同文件 `:1332-1336`）与八宫格/列表里「更新」条目的角标
 *   （`lib/widgets/home_top_menu.dart:209-224`、`home_top_menu_popup.dart:524-539`）。
 *
 * 这些东西的**真值**在宿主（仓储 / 更新检查），页面层只画、不认仓储也不认设置。
 * 三视图（周 / 日 / 月）与格档/列表档共用同一个 [TimetableTopBar]，逐个加参数会让
 * 每个调用点都要转发一遍（漏一处就漂）；改为宿主用 [LocalTimetableHomeTopBarState]
 * 注入，页面无参也拿得到。
 *
 * @param hasAvailableUpdate 是否有可用更新（false = 不画红点/角标）
 * @param coupleOverlayAvailable 是否已绑定情侣课表（false = 不画爱心）
 * @param coupleOverlayEnabled 当前是否开着叠加（决定爱心实心/空心）
 * @param onToggleCoupleOverlay 点爱心：宿主切换并持久化
 */
class TimetableHomeTopBarState(
    val hasAvailableUpdate: Boolean = false,
    val coupleOverlayAvailable: Boolean = false,
    val coupleOverlayEnabled: Boolean = false,
    val onToggleCoupleOverlay: () -> Unit = {},
)

/**
 * 顶栏附加状态的注入点（默认全关 = 预览 / 独立页的行为不变）。
 * 用 `compositionLocalOf`（带默认值的动态局部）而不是 `staticCompositionLocalOf`：
 * 值随「待更新 / 叠加开关」变化，需要订阅重组。
 */
val LocalTimetableHomeTopBarState = compositionLocalOf { TimetableHomeTopBarState() }

/**
 * 情侣叠加开关的读屏名（ARB `coupleTimetableModeEnable/DisableTooltip`，发布版
 * `timetable_screen.dart:1045-1047` 同一对键）。全仓还没有该键的 strings 绑定，
 * 就地取；六种语言的 ARB/ArbCatalog 都有译文，fallback 只兜底、正常不会命中
 *（ASCII 兜底是为了不在渲染层写中文字面量，守 CjkLiteralGate）。
 */
private val coupleOverlayEnableLabel: String
    get() = AppLocaleRuntime.text("coupleTimetableModeEnableTooltip", "Enable couple timetable")

private val coupleOverlayDisableLabel: String
    get() = AppLocaleRuntime.text("coupleTimetableModeDisableTooltip", "Disable couple timetable")

/** 「待更新」角标文案（ARB `updateLabel`，发布版八宫格瓷贴 `home_top_menu.dart:220` 同键）。 */
private val updateBadgeLabel: String
    get() = AppLocaleRuntime.text("updateLabel", "Updates")

/**
 * 课表三视图（周 / 日 / 月）共用的**顶栏标题行**。
 *
 * ## 它补的是什么
 *
 * Flutter 版三个视图顶部都有同一条「轻屿课表」标题栏（`TimetableTitleBar` →
 * `TimetableProfileSwitcherTrigger`），右上角是「更多」菜单。Compose 迁移时三视图
 * 各自只画了自己的行头，这条标题栏整条没搬过来 —— 用户看到的就是「没有 logo、
 * 也没有右上角菜单」。本组件把这一条补回来，三处共用一份，避免各写各的再漂开。
 *
 * ## 标题样式（对齐设置「标题样式」）
 *
 * * [brand] = false（Dart `HomeTitleStyle.classic`）：只显示「轻屿课表」一行大字；
 * * [brand] = true（Dart `HomeTitleStyle.brand`）：大字 + 下方小号课表名。两档
 *   其实都是文字，设置里「大 Logo」指的就是这行大字，没有图片资源。
 *
 * ## 右上角「更多」菜单（跟设置的 `homeMenuStyle` 分流，与 Flutter 一致）
 *
 * * `GRID`（八宫格）：点「更多」弹底部弹层（`QingyuSheet`），4 列图标瓷贴；
 * * `LIST`（列表）：miuix 官方**级联菜单**——图标按钮点开锚定弹层，弹层缩放弹出；
 *   「添加」展开时一级缩到 0.95、二级在新卡片里弹出。全部走官方件，零自研动画。
 *   这是 Dart `homeMenuController.showTopActionsSheet` 的两条分支，默认档位就是 list。
 *
 * ## 「添加」是二级菜单，不是普通行
 *
 * 列表档里 `addCourse`（「添加」）这一行**不直接回传**：点它，它的三个子项原地
 * 展开在下面、面板高度跟着变，给出「添加课程 / 添加日程 / 添加考试」三选
 * —— Dart `home_top_menu.dart:88-96` 的 `kAddCourseSubmenu`。子项 id 沿用 Dart 的
 * `addCourse:course|schedule|exam`，去处由壳的 `shellTimetableMenuPageId` 决定。
 *
 * 八宫格档的「添加」瓷贴仍是直接进加课页（Dart 八宫格走的是三宫格添加弹层，
 * 不是二级），两档行为不同是上游口径，不是漏做。
 *
 * ## 按压反馈
 *
 * 列表档由官方组件提供：菜单开着期间那颗按钮保持**按下态**（官方 `holdDownState`），
 * 按压高亮走主题注入的 miuix 指示。八宫格档的触发按钮用官方 `SinkFeedback`。
 *
 * 条目由 [menuItems] 注入（默认 [TimetableMenuDefaults.entries]），点选只回传
 * 稳定的 [TimetableMenuItem.id] —— 本组件不认识路由，页面/壳的分工不被污染。
 *
 * ## 样式纪律
 *
 * 字号走 [MiuixTheme.textStyles]、颜色走 [QingyuTheme] 语义槽，不写死
 * `fontSize` / `Color(0x…)`（守 `ComposePageStyleGuardTest` R4/R5）；文案全部来自
 * [TimetableStrings]（ARB 逐字），本文件不出现中文字面量（守 CjkLiteralGateTest）。
 *
 * @param brand 是否「大 Logo」档（= 设置 `homeTitleStyle == BRAND`）。
 * @param profileName brand 档副行的课表名；null/空时显示「点击切换课表」提示。
 * @param onTitleClick 点标题区（Dart 口径：打开切课表流程）。null 表示不可点。
 * @param menuItems 右上角菜单条目；空表时不画「更多」按钮。
 * @param homeMenuStyle 菜单形态：`LIST`（锚定列表，默认，对齐 Dart 默认）/
 *   `GRID`（八宫格底部弹层）。由壳从设置 `homeMenuStyle` 注入。
 * @param onMenuSelect 点菜单条目回调，参数是 [TimetableMenuItem.id]。
 */
@Composable
fun TimetableTopBar(
    modifier: Modifier = Modifier,
    title: String = TimetableStrings.appTitle.text,
    brand: Boolean = false,
    /**
     * 壁纸上的墨色（`HomeInkPolarity.Light` = 深色壁纸 ⇒ 浅墨）。
     * `null` = 没有壁纸 ⇒ 主题墨色，与旧版一致。
     *
     * 只影响本行的文字与图标；判据在宿主侧（壁纸顶部亮度 → `chromeInkPolarity`）。
     */
    inkPolarity: HomeInkPolarity? = null,
    profileName: String? = null,
    onTitleClick: (() -> Unit)? = null,
    homeMenuStyle: HomeMenuStyle = HomeMenuStyle.LIST,
    menuItems: List<TimetableMenuItem> = emptyList(),
    onMenuSelect: (String) -> Unit = {},
    /**
     * 顶栏左侧导航槽（返回键）。`null` = 不画。
     *
     * 显隐**不在这里判**：调用方按根页判据
     * [com.mutx163.qingyu.components.rememberShellShouldShowBackButton] 决定传不传，
     * 与骨架同一份取法（守卫 `RootEntryBackGuardTest` 钉住）。
     */
    navigationIcon: (@Composable () -> Unit)? = null,
) {
    val dark = isSystemInDarkTheme()
    // 压在壁纸上时，墨色跟**壁纸明暗**走（Dart `homePageChromeForegroundForLuminance`：
    // 深色壁纸用浅墨、浅色壁纸用深墨，阈值 0.45）。实现上直接复用主题的两套文字色
    // （深色档 = 近白、浅色档 = 近黑），渲染层不写颜色字面量（守 R5）。
    val inkDark = when (inkPolarity) {
        HomeInkPolarity.Light -> true
        HomeInkPolarity.Dark -> false
        null -> dark
    }
    val primaryText = Color(QingyuTheme.primaryText(inkDark))
    val secondaryText = Color(QingyuTheme.secondaryText(inkDark))
    val accent = Color(QingyuTheme.primary(dark = dark))

    var showMenu by remember { mutableStateOf(false) }
    // 宿主注入的附加状态（默认全关 = 预览 / 独立页行为不变）。
    val topBarState = LocalTimetableHomeTopBarState.current

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(TimetableTopBarMetrics.HEIGHT.dp)
            .padding(horizontal = TimetableTopBarMetrics.H_PADDING.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (navigationIcon != null) {
            navigationIcon()
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .then(
                    if (onTitleClick != null) {
                        Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .clickable(onClick = onTitleClick)
                    } else {
                        Modifier
                    },
                )
                .padding(vertical = 4.dp),
        ) {
            Text(
                text = title,
                style = MiuixTheme.textStyles.title2.shiftWeight(QingyuWeightDelta.BOLD),
                color = primaryText,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (brand) {
                Text(
                    text = profileName?.takeIf { it.isNotBlank() }
                        ?: TimetableStrings.switchProfileHint.text,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = secondaryText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        // ── 情侣课表叠加开关（发布版顶栏爱心，`timetable_screen.dart:1036-1059`）──
        // 只在已绑定时出现；点一下开/关叠加（状态与持久化由宿主负责，页面只回传点击）。
        // 实心/空心切换用 miuix 官方 `FavoritesFill` / `Favorites`，颜色走主题强调色
        //（发布版这里是硬编码粉；渲染层守 R5 不写死色值，跟随主题）。
        if (topBarState.coupleOverlayAvailable) {
            IconButton(onClick = topBarState.onToggleCoupleOverlay) {
                Icon(
                    imageVector = if (topBarState.coupleOverlayEnabled) {
                        MiuixIcons.FavoritesFill
                    } else {
                        MiuixIcons.Favorites
                    },
                    contentDescription = if (topBarState.coupleOverlayEnabled) {
                        coupleOverlayDisableLabel
                    } else {
                        coupleOverlayEnableLabel
                    },
                    tint = if (topBarState.coupleOverlayEnabled) accent else primaryText,
                    modifier = Modifier.size(TimetableTopBarMetrics.ICON.dp),
                )
            }
            // 发布版两颗球之间 8dp（`timetable_screen.dart:1060-1064`：只在与爱心
            // 同时出现时插，单独一颗与原来一致）。
            Spacer(modifier = Modifier.width(8.dp))
        }

        if (menuItems.isNotEmpty()) {
            if (homeMenuStyle == HomeMenuStyle.LIST) {
                // 列表档 = miuix **官方级联菜单**，一行自研动画都没有：
                //  * 弹层按 `scale 0.15→1 + 方向性裁剪揭示` 弹出来（官方 `ListPopupContent`）；
                //  * 「添加」展开时**一级列表缩到 0.95 让位、二级在新卡片里弹出**
                //   （官方 `CascadingListPopupLayout` 的 `PRIMARY_SHRUNK_SCALE`）；
                //  * 菜单开着期间按钮保持按下态（官方 `holdDownState`）。
                val selectState = rememberUpdatedState(onMenuSelect)
                // ⚠️ **一个 `DropdownEntry` 装全部条目**，不是"一项一个 entry"：
                // 官方 `CascadingPrimaryContent` 会在**每两个 entry 之间**插一条分隔线
                // （`HorizontalDivider`，上下各 4dp）—— 拆成 8 个 entry 就变成 7 条
                // 横线 + 每行都算首末行（上下 20dp 大内边距），菜单会被撑得又高又碎。
                // 单组 = 只有最上一行与最下一行享受首末内边距，行距紧凑。
                val updateLabel = updateBadgeLabel
                // `updateLabel` 进 key：语言切换时「更新」副文案要跟着换。
                val entries = remember(menuItems, topBarState.hasAvailableUpdate, updateLabel) {
                    listOf(
                        DropdownEntry(
                            items = menuItems.map { item ->
                                DropdownItem(
                                    text = item.label,
                                    // 「更新」有新版时给一行副文案（发布版行尾点状角标
                                    // `home_top_menu_popup.dart:524-539`）。miuix 官方
                                    // `DropdownItem` 没有行尾槽位（尾槽恒为选中勾），副文案
                                    // 是等价的可达提示，不自绘行尾点。
                                    summary = updateLabel.takeIf {
                                        topBarState.hasAvailableUpdate &&
                                            item.id == TimetableMenuDefaults.UPDATE_ID
                                    },
                                    // children 非空 = 二级触发器：点它一级让位、二级弹出。
                                    children = item.children
                                        .takeIf { it.isNotEmpty() }
                                        ?.map { child ->
                                            DropdownItem(
                                                text = child.label,
                                                onClick = { selectState.value(child.id) },
                                            )
                                        },
                                    onClick = item.children
                                        .takeIf { it.isEmpty() }
                                        ?.let { { selectState.value(item.id) } },
                                )
                            },
                        ),
                    )
                }
                OverlayIconCascadingDropdownMenu(
                    entries = entries,
                    // 跟着壳的 Scaffold（`PagesShellActivity` 的根 Scaffold 包在
                    // NavDisplay 外面）：弹层挂它下面才不会被玻璃底栏盖住。
                    renderInRootScaffold = false,
                    content = {
                        // 「更多」图标 + 待更新红点（发布版 `_buildMoreActionIcon`）。
                        BadgedBox(
                            badge = { if (topBarState.hasAvailableUpdate) Badge() },
                            content = {
                                Icon(
                                    imageVector = MiuixIcons.More,
                                    contentDescription = TimetableStrings.moreTooltip.text,
                                    tint = primaryText,
                                    modifier = Modifier.size(TimetableTopBarMetrics.ICON.dp),
                                )
                            },
                        )
                    },
                )
            } else {
                // 八宫格档：与列表档**同一颗官方 `IconButton`**（圆角 40dp ⇒ 正圆，
                // 底色跟随主题）。两档切换时按钮不会变形，用户不需要重新建立预期。
                IconButton(onClick = { showMenu = true }) {
                    // 「更多」图标 + 待更新红点（发布版 `_buildMoreActionIcon`）。
                    BadgedBox(
                        badge = { if (topBarState.hasAvailableUpdate) Badge() },
                        content = {
                            Icon(
                                imageVector = MiuixIcons.More,
                                contentDescription = TimetableStrings.moreTooltip.text,
                                tint = primaryText,
                                modifier = Modifier.size(TimetableTopBarMetrics.ICON.dp),
                            )
                        },
                    )
                }
            }
        }
    }

    // 八宫格档：底部弹层（v2.0.5.5 已发布版本的样式）。
    if (menuItems.isNotEmpty() && homeMenuStyle == HomeMenuStyle.GRID) {
        TimetableHomeMenuSheet(
            show = showMenu,
            entries = menuItems,
            accent = accent,
            hasAvailableUpdate = topBarState.hasAvailableUpdate,
            onDismiss = { showMenu = false },
            onSelect = { id ->
                showMenu = false
                onMenuSelect(id)
            },
        )
    }
}

/** 顶栏几何常量（与周视图 ActionBar 的 56 高度同口径，三个视图一致）。 */
object TimetableTopBarMetrics {
    const val HEIGHT = 56.0
    const val H_PADDING = 16.0

    /** 图标尺寸。 */
    const val ICON = 22.0

    /** 菜单网格列数（八宫格 = 4 列 × 2 行）。 */
    const val MENU_COLUMNS = 4

    /** 菜单瓷贴图标井直径与图标尺寸。 */
    const val TILE_WELL = 46.0
    const val TILE_ICON = 24.0
}

/**
 * 右上角菜单的一个条目。**只描述界面**（id + 文案 + 图标 + 可选的二级子项），
 * 不含任何路由/业务：点选后把 [id] 回传宿主，由壳决定推到哪一页。
 *
 * [id] 沿用 Dart `HomeGridMenu` 的稳定主键（`overview` / `statistics` / `addCourse`
 * / `exams` / `tasks` / `importCourses` / `settings` / `support`），将来接用户自定义
 * 排列时直接复用，不需要另立命名空间。
 *
 * [children] 非空 = 这一行在**列表档**里是二级菜单触发器（Dart 的「添加」三选）；
 * 八宫格档不看这个字段，瓷贴照旧直接回传自己的 [id]。
 */
data class TimetableMenuItem(
    val id: String,
    val label: String,
    val icon: ImageVector,
    val children: List<TimetableMenuItem> = emptyList(),
)

/**
 * 默认八宫格条目 —— 逐条对齐 Dart `HomeGridMenu.defaultActions`
 *（`timetable_settings_enums.dart:173-182`：overview / statistics / addCourse /
 * exams / tasks / importCourses / settings / support），标题复用既有 ARB 键。
 *
 * 顺序即屏上顺序（4 列 × 2 行）。用户自定义排列属后续批次（读 `homeGridMenuActions`），
 * 本批次先固定默认表，行为与「没改过排列的用户」一致。
 */
object TimetableMenuDefaults {
    fun entries(): List<TimetableMenuItem> = listOf(
        TimetableMenuItem(
            "overview",
            TimetableStrings.homeMenuOverviewTitle.text,
            MiuixIcons.GridView,
        ),
        TimetableMenuItem(
            "statistics",
            TimetableStrings.homeMenuStatisticsTitle.text,
            MiuixIcons.Promotions,
        ),
        TimetableMenuItem(
            "addCourse",
            TimetableStrings.homeMenuAddCourseTitle.text,
            MiuixIcons.Add,
            children = addCourseSubmenu(),
        ),
        TimetableMenuItem("exams", TimetableStrings.examListTitle.text, MiuixIcons.Notes),
        TimetableMenuItem("tasks", TimetableStrings.homeMenuTasksTitle.text, MiuixIcons.Tasks),
        TimetableMenuItem("importCourses", TimetableStrings.homeMenuImportTitle.text, MiuixIcons.Import),
        TimetableMenuItem("settings", TimetableStrings.homeMenuSettingsTitle.text, MiuixIcons.Settings),
        TimetableMenuItem("support", TimetableStrings.homeMenuCoffeeTitle.text, MiuixIcons.Favorites),
    )

    /**
     * 「添加」这一行的二级子项（Dart `kAddCourseSubmenu`，`home_top_menu.dart:88-96`）：
     * 添加课程 / 添加日程 / 添加考试。
     *
     * id 沿用 Dart 的 `addCourse:course|schedule|exam`（不是子项各自的目录 id）——
     * 这三个是**列表档菜单专用**的动作键，与「八宫格瓷贴点 addCourse 直接进加课页」
     * 是两条不同的路；去处由壳的 `shellTimetableMenuPageId` 决定。
     *
     * 图标在列表档里不渲染（Dart 的二级行也只有文字），但仍给全 —— [TimetableMenuItem]
     * 是「一条入口长什么样」的完整描述，缺图标会让这个类型变成两种含义。
     */
    fun addCourseSubmenu(): List<TimetableMenuItem> = listOf(
        TimetableMenuItem(
            "addCourse:course",
            TimetableStrings.addCourseTitle.text,
            MiuixIcons.Add,
        ),
        TimetableMenuItem(
            "addCourse:schedule",
            TimetableStrings.addScheduleAction.text,
            MiuixIcons.AddCircle,
        ),
        TimetableMenuItem(
            "addCourse:exam",
            TimetableStrings.addExam.text,
            MiuixIcons.AddCircle,
        ),
    )

    /**
     * 该 id 在列表档里要展开的二级子项；没有就返回空表（普通行）。
     *
     * 宿主（`HomeNavIcons.menuItem`）建条目时调这里 —— 子项的定义只此一处，
     * 不让渲染层和宿主各写一份「添加」三选。
     */
    fun childrenOf(id: String): List<TimetableMenuItem> =
        if (id == ADD_COURSE_ID) addCourseSubmenu() else emptyList()

    /** 「添加」父行的 id（Dart `kAddCourseSubmenuParentId`）。 */
    const val ADD_COURSE_ID = "addCourse"

    /**
     * 「版本更新」条目的 id（Dart `kUpdateEntryId`，`home_top_menu.dart:75`）。
     *
     * 只有它有「待更新」角标：八宫格瓷贴的 `badgeText`（`home_top_menu.dart:209-224`）
     * 与列表档行尾点状角标（`home_top_menu_popup.dart:524-539`）都只认这一条。
     */
    const val UPDATE_ID = "update"
}

/**
 * 「更多」底部菜单：4 列图标瓷贴，点一项回传 id 并收起。
 *
 * 容器与课程操作弹层同口径（`QingyuSheet`：16dp 侧边距 + 底部让出手势区）——同一 App 的
 * 底部弹层都长这样，用户不需要为不同弹层重新建立预期。
 *
 * 文字色**只看面板自己的明暗**，不接顶栏的壁纸墨色：壁纸墨色是给压在壁纸上的顶栏用的，
 * 带进不透明弹层会变成白字白底。尾行不满 4 格时居中，不在右下留一个「缺一格」的洞。
 */
@Composable
private fun TimetableHomeMenuSheet(
    show: Boolean,
    entries: List<TimetableMenuItem>,
    accent: Color,
    hasAvailableUpdate: Boolean = false,
    onDismiss: () -> Unit,
    onSelect: (String) -> Unit,
) {
    // 文字色跟**面板自己的表面**走，不接顶栏的壁纸墨色。
    //
    // 顶栏压在壁纸上：深色壁纸 ⇒ 浅墨（白字），那是给壁纸用的。弹层是不透明表面
    // （浅色近白 / 暗色近黑），把白字带进来就变成「白字白卡」——从 Flutter 版升级的
    // 用户壁纸都还在，7 个标签会全部隐形，只剩图标井（2026-11-09 用户报）。
    val sheetInk = Color(QingyuTheme.primaryText(isSystemInDarkTheme()))
    QingyuSheet(
        show = show,
        // 八宫格档**不显示顶部标题**（用户口径：显示「更多」标题很怪）。
        // 不传 `title` → QingyuSheet 的 title 默认 null，不再画那行文字。
        // 网格 / 间距 / 每格卡片全部保持不动；list 档是另一套组件，不受影响。
        onDismissRequest = onDismiss,
        // 瓷贴网格自带 4dp 微调（不足以顶掉套件 16dp）：保持套件侧边距 ⇒ 单边 20dp。
        contentPadsHorizontally = false,
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 4.dp),
        ) {
            val columns = TimetableTopBarMetrics.MENU_COLUMNS
            val gapCount = columns - 1
            // 对齐 Flutter v2.1.4.1（home_top_menu.dart:158-199）：
            // 单格宽 (可用宽-10×3)/4 再 clamp(64,112)dp；列/行间距 10dp；
            // 宽屏多出来的宽度均摊成列间隙，瓷贴本身不被拉宽。
            val spacing = 10.dp
            val rawItemWidth = (maxWidth - spacing * gapCount.toFloat()) / columns.toFloat()
            val itemWidth = rawItemWidth.coerceIn(64.dp, 112.dp)
            val itemGap = if (rawItemWidth > 112.dp) {
                (maxWidth - itemWidth * columns.toFloat()) / gapCount.toFloat()
            } else {
                spacing
            }
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(spacing),
            ) {
                entries.chunked(columns).forEach { rowItems ->
                    // 满行按 4 列均分（宽屏时 itemGap 已经把余量摊开）；
                    // 尾行不满 4 格时居中收拢，不在右下角留一个「缺了一格」的洞。
                    val fullRow = rowItems.size == columns
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = if (fullRow) {
                            Arrangement.spacedBy(itemGap)
                        } else {
                            Arrangement.spacedBy(spacing, Alignment.CenterHorizontally)
                        },
                    ) {
                        rowItems.forEach { item ->
                            TimetableMenuTile(
                                item = item,
                                accent = accent,
                                textColor = sheetInk,
                                // 「更新」瓷贴的角标：发布版 `home_top_menu.dart:209-224`
                                // 只在 `id == update && hasAvailableUpdate` 时给
                                // `badgeText = updateLabel`，其余格子不画。
                                badgeText = updateBadgeLabel.takeIf {
                                    hasAvailableUpdate && item.id == TimetableMenuDefaults.UPDATE_ID
                                },
                                modifier = Modifier.width(itemWidth),
                                onClick = { onSelect(item.id) },
                            )
                        }
                    }
                }
            }
        }
    }
}

/**
 * 单个菜单瓷贴：**整格卡片**（[QingyuCard]）+ 图标井 + 下方文案。
 *
 * 对齐 Flutter v2.1.4.1 `_HomeMenuActionTile`（`lib/widgets/home_top_menu.dart:289-346`）：
 * 每格是一块圆角 24dp 的卡片底（`HyperosFrostedSurface(borderRadius: cardBorderRadius)`，
 * 卡半径 = `HyperosMiuixSpec.settingsGroupRadius` 24），内边距 横 7 / 纵 13；
 * 卡片**无描边**（Flutter 侧无 BorderSide），底色用 [QingyuCard] 默认主题色。
 * 图标井保留原样：46dp / 圆角 14 / accent 12% / 图标 24；井到文字 7dp；文字最多 2 行，
 * 居中排（Flutter 同款 `textAlign: center`），颜色由弹层表面决定。
 *
 * [badgeText] 非空时在图标井右上角叠一枚官方 [Badge] 文字角标 —— 发布版
 * `_HomeMenuActionTile` 的 `HyperosBadge(label: updateLabel)`（`home_top_menu.dart:307-324`），
 * 目前只有「更新」瓷贴会拿到它（`:209-224`）。
 */
@Composable
private fun TimetableMenuTile(
    item: TimetableMenuItem,
    accent: Color,
    textColor: Color,
    modifier: Modifier = Modifier,
    badgeText: String? = null,
    onClick: () -> Unit,
) {
    QingyuCard(
        modifier = modifier,
        cornerRadius = QingyuCardDefaults.SettingsGroupCorner,
        insideMargin = PaddingValues(horizontal = 7.dp, vertical = 13.dp),
        onClick = onClick,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            BadgedBox(
                badge = {
                    if (badgeText != null) {
                        // 官方 `Badge` 带内容 = 小胶囊（容器色 `error`、文字 `onError`），
                        // 与发布版 HyperosBadge 的位置（图标井右上）和语义一致。
                        Badge {
                            Text(
                                text = badgeText,
                                style = MiuixTheme.textStyles.footnote2,
                            )
                        }
                    }
                },
                content = {
                    Box(
                        modifier = Modifier
                            .size(TimetableTopBarMetrics.TILE_WELL.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(accent.copy(alpha = 0.12f)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(
                            imageVector = item.icon,
                            contentDescription = item.label,
                            tint = accent,
                            modifier = Modifier.size(TimetableTopBarMetrics.TILE_ICON.dp),
                        )
                    }
                },
            )
            Spacer(modifier = Modifier.height(7.dp))
            Text(
                text = item.label,
                style = MiuixTheme.textStyles.footnote2,
                color = textColor,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}
