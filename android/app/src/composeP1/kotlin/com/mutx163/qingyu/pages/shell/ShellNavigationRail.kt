package com.mutx163.qingyu.pages.shell

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import com.mutx163.qingyu.app.TimetableSettingsModel
import java.time.LocalDate
import top.yukonga.miuix.kmp.basic.NavigationRail
import top.yukonga.miuix.kmp.basic.NavigationRailItem
import top.yukonga.miuix.kmp.basic.NavigationRailState
import top.yukonga.miuix.kmp.basic.NavigationRailValue
import top.yukonga.miuix.kmp.basic.rememberNavigationRailState

/**
 * 首页**侧边导航栏**（宽屏档玻璃坞的替身，方案 `2026-11-03-compose-widescreen-adaptive-plan.md`
 * 迁移顺序第 2 批）。
 *
 * ## 与玻璃坞的关系：同一套口径，不同落位
 *
 * - 条目排列：同一张解析表 [HomeDockNavModel.resolveIds]（用户存档驱动、空表回退默认三格、
 *   开发壳索引追加），**不另抄一份清单**；
 * - 图标与文案：同一套 `HomeNavIcons.dockItems`（与玻璃坞逐项同源，日格带今天日号、
 *   周格带开学周数）/ `HomeNavIcons.labelOf`（ARB 逐字，无中文字面量）；
 * - 选中高亮：同一个 [HomeDockNavModel.selectedIndex]（排列里没有的 id 整栏不亮）；
 * - 圆钮（加课）：同一套 `glassDockRoundButtonIcon` 解析（守卫
 *   `GlassDockRoundButtonIconWiringGuardTest` 盯的是「设置里的图标名必须被消费」，
 *   Rail 头部槽与坞圆钮消费同一函数），放在官方 [NavigationRail] 的 `header` 槽——
 *   miuix 文档对这一槽的定位就是「通常是 FAB」。
 *
 * ## 交互口径
 *
 * 坞在紧凑档会被推入页盖住，所以坞的 `onSelect` 只在主屏时点得到；Rail 在宽档**常驻**
 * （压着页面也在、也能点），所以壳层给这里的 `onSelect` 传的是「先弹回主屏再切换」的
 * 包装（demo `AppContent.kt:371` `popUntil` 同口径），见 `PagesShellActivity.railSelectRoot`。
 * 非 `rendersAsRoot` 的条目（外观编辑器等）仍由 `selectRoot` 分流为推页——与坞一致。
 *
 * @param expanded 是否展开态（≥1200dp 窗口带文字标签）：跨过阈值时经 [LaunchedEffect]
 *   调 `expand()/collapse()`，与 demo `AppContent.kt:350-363` 同一套写法。
 * @param semesterStartDate 学期开学日（与玻璃坞同一份）：周格画「开学第几周」用。
 * @param semesterWeekCount 学期总周数：越界 / 未开学 / 无数据时周格保持 `Weeks`。
 */
@Composable
fun ShellNavigationRail(
    settingsModel: TimetableSettingsModel,
    selectedId: String?,
    isNavigable: (String) -> Boolean,
    onSelect: (String) -> Unit,
    onRoundButton: () -> Unit,
    expanded: Boolean,
    semesterStartDate: LocalDate? = null,
    semesterWeekCount: Int = 0,
    modifier: Modifier = Modifier,
) {
    // 条目解析与 HomeGlassDock 完全同源（含「用户没自定义过底栏时追加开发壳索引」），
    // 走 `resolveDockIds` 合一入口：壳的 Pager 页列表、坞都由同一方法解析，三处同源。
    val dockIds = remember(settingsModel, isNavigable) {
        HomeDockNavModel.resolveDockIds(settingsModel.glassDockActions) { id ->
            isNavigable(id)
        }
    }
    // 「今天」与「id → 图标」必须和玻璃坞走**同一个入口**（2026-11-05 修）：
    // 宽屏档坞整块不组合，这条路径是日 / 周两格唯一的渲染者。原先这里直接调
    // `HomeNavIcons.iconOf(id)`，而它对 ACTION_DAY 恒返回 `Th1`、对 ACTION_WEEK 恒返回
    // `Weeks` —— 于是「日课表图标永远显示 1」在平板上原样复现。现在两处都调 [dockItems]。
    val today = rememberDockToday()
    val items = remember(dockIds, today, semesterStartDate, semesterWeekCount) {
        HomeNavIcons.dockItems(dockIds, today, semesterStartDate, semesterWeekCount)
    }
    val railState: NavigationRailState = rememberNavigationRailState(
        initialValue = if (expanded) NavigationRailValue.Expanded else NavigationRailValue.Collapsed,
    )
    LaunchedEffect(expanded) {
        if (expanded) railState.expand() else railState.collapse()
    }
    NavigationRail(
        state = railState,
        modifier = modifier,
        // 宽档圆钮去 miuix 官方的 header 槽（文档定位「通常是 FAB」）；用户关掉圆钮时不给。
        header = if (settingsModel.glassDockShowAddButton) {
            {
                val roundActionId =
                    HomeDockNavModel.roundButtonAction(settingsModel.glassDockButtonEntryId)
                GlassDockRoundButton(
                    icon = glassDockRoundButtonIcon(
                        chosenName = settingsModel.glassDockButtonIconName,
                        roundActionId = roundActionId,
                    ),
                    contentDescription = HomeNavIcons.labelOf(roundActionId),
                    onClick = onRoundButton,
                )
            }
        } else {
            null
        },
    ) {
        val selected = HomeDockNavModel.selectedIndex(dockIds, selectedId)
        dockIds.forEachIndexed { index, id ->
            // 图标 / 文案取自共享解析表（与玻璃坞同一份），日格跟着今天几号、周格带周数。
            val item = items.getOrNull(index)
            NavigationRailItem(
                selected = index == selected,
                onClick = { onSelect(id) },
                icon = item?.icon ?: HomeNavIcons.iconOf(id),
                // Rail 是「图标 + 文字」常显；label 理论上恒非空（dockItems 一律给 labelOf），
                // 兜底回 labelOf 保证永远不出现空标签。
                label = item?.label ?: HomeNavIcons.labelOf(id),
            )
        }
    }
}
