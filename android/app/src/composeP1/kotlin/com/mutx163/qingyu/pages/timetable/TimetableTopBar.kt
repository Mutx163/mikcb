package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.DropdownImpl
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.ListPopupColumn
import top.yukonga.miuix.kmp.basic.PopupPositionProvider
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Import
import top.yukonga.miuix.kmp.icon.extended.More
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Promotions
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Tasks
import top.yukonga.miuix.kmp.overlay.OverlayListPopup
import top.yukonga.miuix.kmp.theme.MiuixTheme

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
 * * `LIST`（列表）：点「更多」在按钮正下方弹出锚定列表弹层（miuix 自带
 *   `OverlayListPopup`，带弹簧淡入、放不下自动翻到上方）。这是 Dart
 *   `homeMenuController.showTopActionsSheet` 的两条分支，默认档位就是 list。
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
    title: String = TimetableStrings.appTitle.zh,
    brand: Boolean = false,
    profileName: String? = null,
    onTitleClick: (() -> Unit)? = null,
    homeMenuStyle: HomeMenuStyle = HomeMenuStyle.LIST,
    menuItems: List<TimetableMenuItem> = emptyList(),
    onMenuSelect: (String) -> Unit = {},
) {
    val dark = isSystemInDarkTheme()
    val primaryText = Color(QingyuTheme.primaryText(dark))
    val secondaryText = Color(QingyuTheme.secondaryText(dark))
    val accent = Color(QingyuTheme.primary(dark = dark))

    var showMenu by remember { mutableStateOf(false) }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(TimetableTopBarMetrics.HEIGHT.dp)
            .padding(horizontal = TimetableTopBarMetrics.H_PADDING.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
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
                style = MiuixTheme.textStyles.title2,
                fontWeight = FontWeight.Bold,
                color = primaryText,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (brand) {
                Text(
                    text = profileName?.takeIf { it.isNotBlank() }
                        ?: TimetableStrings.switchProfileHint.zh,
                    style = MiuixTheme.textStyles.footnote2,
                    fontWeight = FontWeight.Medium,
                    color = secondaryText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        if (menuItems.isNotEmpty()) {
            // 「更多」按钮 + 列表档的锚定弹层，必须同处一个 Box：
            // miuix 的 `OverlayListPopup` 拿「父容器的窗口坐标」当锚点，包在一起才锚在按钮下。
            Box {
                Box(
                    modifier = Modifier
                        .size(TimetableTopBarMetrics.HIT.dp)
                        .clip(CircleShape)
                        .clickable { showMenu = true },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = MiuixIcons.More,
                        contentDescription = TimetableStrings.moreTooltip.zh,
                        tint = primaryText,
                        modifier = Modifier.size(TimetableTopBarMetrics.ICON.dp),
                    )
                }

                // 列表档：miuix 自带锚定列表弹层（弹簧淡入 / 淡出 + 窗外点即关）。
                // 右上角按钮 ⇒ 右对齐（Align.End）；下方空间不够时自动翻到按钮上方。
                if (homeMenuStyle == HomeMenuStyle.LIST) {
                    OverlayListPopup(
                        show = showMenu,
                        alignment = PopupPositionProvider.Align.End,
                        onDismissRequest = { showMenu = false },
                    ) {
                        ListPopupColumn {
                            menuItems.forEachIndexed { index, item ->
                                DropdownImpl(
                                    text = item.label,
                                    optionSize = menuItems.size,
                                    isSelected = false,
                                    index = index,
                                    onSelectedIndexChange = {
                                        showMenu = false
                                        onMenuSelect(item.id)
                                    },
                                )
                            }
                        }
                    }
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
            primaryText = primaryText,
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

    /** 图标按钮命中尺寸。 */
    const val HIT = 40.0
    const val ICON = 22.0

    /** 菜单网格列数（八宫格 = 4 列 × 2 行）。 */
    const val MENU_COLUMNS = 4

    /** 菜单瓷贴图标井直径与图标尺寸。 */
    const val TILE_WELL = 46.0
    const val TILE_ICON = 24.0
}

/**
 * 右上角菜单的一个条目。**只描述界面**（id + 文案 + 图标），不含任何路由/业务：
 * 点选后把 [id] 回传宿主，由壳决定推到哪一页。
 *
 * [id] 沿用 Dart `HomeGridMenu` 的稳定主键（`overview` / `statistics` / `addCourse`
 * / `exams` / `tasks` / `importCourses` / `settings` / `support`），将来接用户自定义
 * 排列时直接复用，不需要另立命名空间。
 */
data class TimetableMenuItem(
    val id: String,
    val label: String,
    val icon: ImageVector,
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
        TimetableMenuItem("overview", TimetableStrings.homeMenuOverviewTitle.zh, MiuixIcons.GridView),
        TimetableMenuItem("statistics", TimetableStrings.homeMenuStatisticsTitle.zh, MiuixIcons.Promotions),
        TimetableMenuItem("addCourse", TimetableStrings.homeMenuAddCourseTitle.zh, MiuixIcons.Add),
        TimetableMenuItem("exams", TimetableStrings.examListTitle.zh, MiuixIcons.Notes),
        TimetableMenuItem("tasks", TimetableStrings.homeMenuTasksTitle.zh, MiuixIcons.Tasks),
        TimetableMenuItem("importCourses", TimetableStrings.homeMenuImportTitle.zh, MiuixIcons.Import),
        TimetableMenuItem("settings", TimetableStrings.homeMenuSettingsTitle.zh, MiuixIcons.Settings),
        TimetableMenuItem("support", TimetableStrings.homeMenuCoffeeTitle.zh, MiuixIcons.Favorites),
    )
}

/**
 * 「更多」底部菜单：4 列图标瓷贴，点一项回传 id 并收起。
 *
 * 容器与课程操作弹层同口径（`QingyuSheet`：16dp 侧边距 + 底部让出手势区）——同一 App 的
 * 底部弹层都长这样，用户不需要为不同弹层重新建立预期。
 */
@Composable
private fun TimetableHomeMenuSheet(
    show: Boolean,
    entries: List<TimetableMenuItem>,
    accent: Color,
    primaryText: Color,
    onDismiss: () -> Unit,
    onSelect: (String) -> Unit,
) {
    QingyuSheet(
        show = show,
        title = TimetableStrings.moreTooltip.zh,
        onDismissRequest = onDismiss,
        // 瓷贴网格自带 4dp 微调（不足以顶掉套件 16dp）：保持套件侧边距 ⇒ 单边 20dp。
        contentPadsHorizontally = false,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 4.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            entries.chunked(TimetableTopBarMetrics.MENU_COLUMNS).forEach { rowItems ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    rowItems.forEach { item ->
                        TimetableMenuTile(
                            item = item,
                            accent = accent,
                            primaryText = primaryText,
                            modifier = Modifier.weight(1f),
                            onClick = { onSelect(item.id) },
                        )
                    }
                    // 尾行不满时补空位，保证每格等宽、不向中间挤。
                    repeat(TimetableTopBarMetrics.MENU_COLUMNS - rowItems.size) {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

/** 单个菜单瓷贴：图标井 + 下方一行文案。 */
@Composable
private fun TimetableMenuTile(
    item: TimetableMenuItem,
    accent: Color,
    primaryText: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
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
        Spacer(modifier = Modifier.height(6.dp))
        Text(
            text = item.label,
            style = MiuixTheme.textStyles.footnote2,
            color = primaryText,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
