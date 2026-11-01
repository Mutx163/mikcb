package com.mutx163.qingyu.pages.shell

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.HomeNavigationForm
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import top.yukonga.miuix.kmp.basic.FloatingActionButton
import top.yukonga.miuix.kmp.basic.Icon
import top.yukonga.miuix.kmp.blur.Backdrop
import top.yukonga.miuix.kmp.theme.MiuixTheme

/**
 * 首页**玻璃坞**（药丸 + 右侧圆钮）的唯一渲染入口。
 *
 * ## 为什么要有这个文件（2026-11-01 搬层）
 *
 * 底栏原先由壳（`PagesShellActivity`）画在 `NavDisplay` **之上**，是页面栈的兄弟节点。
 * 后果有三个，都是用户真机上看到的：
 *
 * 1. **它不跟着页面动**：页面推入 / 缩放时底栏纹丝不动，只能整块消失；
 * 2. **预览卡里没有它**：外观编辑页的缩尺预览只渲染课表页本体，底栏不在那棵树里；
 * 3. **条目解析散在两处**：壳里一份、别处想复用只能再抄一份。
 *
 * 现在它由**栈底条目**（`ShellRoute.Dock`）的内容自己画：底栏于是和首页同属一棵子树，
 * 跟着页面转场（覆盖视差、将来的缩放）一起动；外观编辑页的预览卡也调这同一个组件，
 * 卡片里从此有底栏。条目解析 / 材质 / 圆钮图标的口径只在这里维护一份。
 *
 * ## 调用方要给的
 *
 * * [settingsModel]：底栏排列、形态、圆钮图标、材质都从它读（预览卡传**草稿**，
 *   拖材质滑杆时卡片里的坞当场跟着变）；
 * * [selectedId]：当前主屏内容对应的条目 id（`week` / `day` / `tasks` …），
 *   决定高亮第几格；排列里没有它时整栏不亮（Dart 同口径）；
 * * [isNavigable]：「这个 id 点得开吗」——壳传真实页面映射表，预览卡传同一张表；
 * * [onSelect] / [onRoundButton]：预览卡传空实现（那一层本来就吞掉所有输入）。
 *
 * @param backdrop 玻璃采样源：调用方把**页面内容**（不含底栏自己）录进这个 backdrop，
 *   坞才采得到「它底下的画面」。null = 不采样，坞退回实体档（低版本无 runtime shader 时同此）。
 */
@Composable
fun HomeGlassDock(
    settingsModel: TimetableSettingsModel,
    selectedId: String?,
    isNavigable: (String) -> Boolean,
    onSelect: (String) -> Unit,
    onRoundButton: () -> Unit,
    modifier: Modifier = Modifier,
    backdrop: Backdrop? = null,
) {
    if (!homeDockVisible(settingsModel)) return

    // 底栏条目：**由用户存档决定**（Dart `resolveGlassDockActionIds`）。空表回退默认三格；
    // 用户没自定义过时，开发壳的「页面索引」追加到末尾（与拆壳前的壳层口径一致）。
    val dockIds = remember(settingsModel, isNavigable) {
        val resolved = HomeDockNavModel.resolveIds(settingsModel.glassDockActions) { id ->
            isNavigable(id)
        }
        if (settingsModel.glassDockActions.isEmpty() &&
            resolved.size < HomeDockNavModel.MAX_SLOTS
        ) {
            resolved + HomeDockNavModel.DEV_INDEX_ID
        } else {
            resolved
        }
    }
    val isDark = isSystemInDarkTheme()
    val hasBackdrop = !settingsModel.homePageWallpaperPath.isNullOrEmpty() ||
        !settingsModel.homePageBackgroundImagePath.isNullOrEmpty()
    val material: HomeMaterialRenderSpec? = remember(settingsModel, isDark, hasBackdrop) {
        SettingsMaterialModel.renderSpecOf(
            model = settingsModel,
            isDark = isDark,
            hasBackdrop = hasBackdrop,
        )
    }
    val roundActionId = HomeDockNavModel.roundButtonAction(settingsModel.glassDockButtonEntryId)

    GlassDockNavigationBar(
        items = dockIds.map { HomeNavIcons.dockItem(it) },
        selectedIndex = HomeDockNavModel.selectedIndex(dockIds, selectedId),
        onSelect = { index -> onSelect(dockIds[index]) },
        // 设备不支持 runtime shader 时别把 backdrop 传进去：传了也画不出模糊，
        // 反而会多录一层、白费一次采样（与壳层同一条纪律）。
        backdrop = backdrop,
        material = material,
        modifier = modifier,
        trailingContent = if (settingsModel.glassDockShowAddButton) {
            {
                GlassDockRoundButton(
                    // 用户挑的图标名优先；没挑 / 名字已撤 / 矢量表缺项时回退到圆钮
                    // 绑定动作的目录图标（缺省动作 = 加课 = 加号）。
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
    )
}

/**
 * 玻璃坞形态下才画底栏。
 *
 * Dart `home_chrome_spec.dart:78-80`：`glassDockForm = homeNavigationForm == glassDock`，
 * 非坞档直接返回 `dockContent`，**坞层连建都不建**。调用方（壳的录制门控、预览卡）
 * 与 [HomeGlassDock] 自己都按这一条判，避免「坞不画了但还在录屏」这类半吊子状态。
 */
fun homeDockVisible(settingsModel: TimetableSettingsModel): Boolean =
    settingsModel.homeNavigationForm == HomeNavigationForm.GLASS_DOCK

/**
 * 玻璃坞右侧的独立圆钮（Flutter `glassDockShowAddButton` 那个「加课」按钮）。
 *
 * 用官方 [FloatingActionButton]（miuix 基础件）而不是自绘一块玻璃：本仓对「自研形状/
 * 动画」有禁令，而官方这颗按钮的按压反馈、阴影、无障碍语义都是现成的。
 * 直径与药丸同高（[GlassDockGeometry.HeightDp]），右侧留 8dp 由底栏负责。
 *
 * 原先是 `PagesShellActivity` 的私有件；底栏搬进页面层时一并搬到这里，
 * 让壳与预览卡用的是同一颗按钮（守卫 `GlassDockRoundButtonIconWiringGuardTest`
 * 盯的仍是「设置里的图标名必须传到这里」）。
 */
@Composable
private fun GlassDockRoundButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    FloatingActionButton(
        onClick = onClick,
        containerColor = MiuixTheme.colorScheme.primary,
        shadowElevation = 6.dp,
        minWidth = GlassDockGeometry.HeightDp.dp,
        minHeight = GlassDockGeometry.HeightDp.dp,
    ) {
        Icon(
            imageVector = icon,
            // 有可见文字的场景不存在（圆钮只有图标），所以这里必须给语义名。
            contentDescription = contentDescription,
            tint = MiuixTheme.colorScheme.onPrimary,
            modifier = Modifier.size(24.dp),
        )
    }
}
