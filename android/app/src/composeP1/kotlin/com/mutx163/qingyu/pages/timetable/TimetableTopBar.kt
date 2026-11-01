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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.HomeMenuStyle
import com.mutx163.qingyu.components.QingyuSheet
import com.mutx163.qingyu.components.QingyuWeightDelta
import com.mutx163.qingyu.components.shiftWeight
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.icon.MiuixIcons
import top.yukonga.miuix.kmp.icon.extended.Add
import top.yukonga.miuix.kmp.icon.extended.AddCircle
import top.yukonga.miuix.kmp.icon.extended.Favorites
import top.yukonga.miuix.kmp.icon.extended.GridView
import top.yukonga.miuix.kmp.icon.extended.Import
import top.yukonga.miuix.kmp.icon.extended.Notes
import top.yukonga.miuix.kmp.icon.extended.Promotions
import top.yukonga.miuix.kmp.icon.extended.Settings
import top.yukonga.miuix.kmp.icon.extended.Tasks
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
 * * `LIST`（列表）：**容器变换**——那颗按钮自己长成菜单面板，收起时缩回按钮。
 *   实现在 [HomeMenuMorphButton]（登记在 `miuix-component-first-standard.md`
 *   的例外表第三条）。这是 Dart `homeMenuController.showTopActionsSheet` 的两条
 *   分支，默认档位就是 list。
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
 * ## 按压反馈（官方 `SinkFeedback`）
 *
 * 「更多」按钮按下会**下沉缩放**（0.94 + 弹簧）。这是 miuix 的官方手感件
 * （`top.yukonga.miuix.kmp.utils.SinkFeedback`，也就是 `PressFeedbackType.Sink`
 * 的底层，`Card(pressFeedbackType = Sink)` 用的同一个）。不换成 `IconButton`
 * 是因为官方 `IconButton` 没有开放 `indication` 口子，拿不到这档缩放。
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
                style = MiuixTheme.textStyles.title2.shiftWeight(QingyuWeightDelta.BOLD),
                color = primaryText,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (brand) {
                Text(
                    text = profileName?.takeIf { it.isNotBlank() }
                        ?: TimetableStrings.switchProfileHint.zh,
                    style = MiuixTheme.textStyles.footnote2.shiftWeight(QingyuWeightDelta.MEDIUM),
                    color = secondaryText,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        if (menuItems.isNotEmpty()) {
            if (homeMenuStyle == HomeMenuStyle.LIST) {
                // 列表档：按钮自己长成菜单（容器变换）。组件内部自带触发按钮，
                // 收起态与下面那颗八宫格按钮同一个形状 / 同一个颜色，两档切换不会跳。
                HomeMenuMorphButton(
                    items = menuItems,
                    contentDescription = TimetableStrings.moreTooltip.zh,
                    onSelect = onMenuSelect,
                )
            } else {
                HomeMenuTriggerButton(
                    contentDescription = TimetableStrings.moreTooltip.zh,
                    onClick = { showMenu = true },
                )
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

    /** 图标尺寸。按钮本身的直径归 `HomeMenuMorphModel.TRIGGER_DIAMETER_DP` 一处管。 */
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
            TimetableStrings.homeMenuOverviewTitle.zh,
            MiuixIcons.GridView,
        ),
        TimetableMenuItem(
            "statistics",
            TimetableStrings.homeMenuStatisticsTitle.zh,
            MiuixIcons.Promotions,
        ),
        TimetableMenuItem(
            "addCourse",
            TimetableStrings.homeMenuAddCourseTitle.zh,
            MiuixIcons.Add,
            children = addCourseSubmenu(),
        ),
        TimetableMenuItem("exams", TimetableStrings.examListTitle.zh, MiuixIcons.Notes),
        TimetableMenuItem("tasks", TimetableStrings.homeMenuTasksTitle.zh, MiuixIcons.Tasks),
        TimetableMenuItem("importCourses", TimetableStrings.homeMenuImportTitle.zh, MiuixIcons.Import),
        TimetableMenuItem("settings", TimetableStrings.homeMenuSettingsTitle.zh, MiuixIcons.Settings),
        TimetableMenuItem("support", TimetableStrings.homeMenuCoffeeTitle.zh, MiuixIcons.Favorites),
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
            TimetableStrings.addCourseTitle.zh,
            MiuixIcons.Add,
        ),
        TimetableMenuItem(
            "addCourse:schedule",
            TimetableStrings.addScheduleAction.zh,
            MiuixIcons.AddCircle,
        ),
        TimetableMenuItem(
            "addCourse:exam",
            TimetableStrings.addExam.zh,
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
