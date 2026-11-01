package com.mutx163.qingyu.app

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.pages.settings.HomeMaterialRenderSpec
import com.mutx163.qingyu.pages.settings.SettingsMaterialModel
import com.mutx163.qingyu.pages.shell.HomeBackdropSnapshot
import com.mutx163.qingyu.pages.shell.HomeBackgroundModel
import com.mutx163.qingyu.pages.shell.HomeInkPolarity
import com.mutx163.qingyu.pages.shell.HomeWallpaperBackdrop
import com.mutx163.qingyu.pages.shell.cachedWallpaperInkBands
import com.mutx163.qingyu.theme.QingyuTheme

/**
 * 首页三个视图（周 / 日 / 月）共用的**壁纸 + 材质 + 墨色**一揽子快照。
 *
 * 周视图与日视图的页面签名是同一组五个参数（`backdrop` / `chromeInk` / `material` /
 * `hasBackdrop` / `pageColorArgb`），但**怎么算出来**必须只有一份：壁纸快照（取景 /
 * 对齐 / 模糊 / 解码宽 / 页底色）、材质快照（八根旋钮 + 三处降级）、顶栏墨色
 * （壁纸顶部亮度 → 极性）三件事此前只在 `TimetableHost` 里写过一遍，日视图没有，
 * 于是「周视图有壁纸、日视图是纯色底」。这里把那份推导抽出来，谁接首页谁调它。
 *
 * 快照只在「设置 / 明暗 / 视口宽」变化时重建：取景倍数、对齐、模糊强度、解码宽度
 * 全部已在模型层收口（`HomeBackgroundModel.snapshotOf`），渲染层不再二次夹。
 *
 * @param settingsModel 用户存档；`null` = 读不到设置 ⇒ 三样都为空（页面走旧的不透明行为）。
 */
class HomeBackdropChrome(
    val snapshot: HomeBackdropSnapshot?,
    val material: HomeMaterialRenderSpec?,
    /** 壁纸三档亮度带（顶栏 / 星期栏 / 正文）；无壁纸或还没量到时为 null。 */
    val bands: HomeBackgroundModel.InkBands?,
    val chromeInk: HomeInkPolarity?,
    val backdrop: (@Composable BoxScope.() -> Unit)?,
) {
    /** 当前有没有可用壁纸：页面据此决定底色透不透、要不要开采样层。 */
    val hasBackdrop: Boolean get() = snapshot?.hasWallpaper == true

    /** 无壁纸 / 实体玻璃带用的页底色（ARGB）。 */
    val pageColorArgb: Int? get() = snapshot?.pageColorArgb
}

/**
 * 建一份 [HomeBackdropChrome]（见类注释：三样东西的唯一推导点）。
 *
 * 壁纸亮度带（顶栏/字色墨色的唯一判据）**首帧同步从进程缓存取**
 * （`cachedWallpaperInkBands`）：同一张壁纸在首页早就量过，切视图 / 进外观编辑页的
 * 新组合第一帧就有正确墨色；只有「从没量过的新壁纸」才回落到主题墨色，
 * 并等解码完成后的异步回调补上。
 */
@Composable
fun rememberHomeBackdropChrome(settingsModel: TimetableSettingsModel?): HomeBackdropChrome {
    val isDark = isSystemInDarkTheme()
    val viewportWidthPx = with(LocalDensity.current) {
        LocalConfiguration.current.screenWidthDp.dp.roundToPx()
    }
    val snapshot = remember(settingsModel, isDark, viewportWidthPx) {
        settingsModel?.let { model ->
            HomeBackgroundModel.snapshotOf(
                settings = model,
                isDark = isDark,
                viewportWidthPx = viewportWidthPx,
                themeFallbackArgb = QingyuTheme.scaffoldBackground(dark = isDark),
                // 页底色：不传这一项时模型只能走主题兜底，于是「课表页面设置 → 背景色板」
                // 改了能存能读、屏幕上永远不变。
                pageColorHex = model.timetablePageBackgroundColor,
            )
        }
    }
    val hasBackdrop = snapshot?.hasWallpaper == true
    // 材质只在这一处翻译成渲染快照：顶栏玻璃带 / 课程卡片 / 玻璃坞都照它执行，
    // 页面本身不再各读一遍 `frostedBlurEnabled` 之类的原始键。
    val material = remember(settingsModel, isDark, hasBackdrop) {
        settingsModel?.let { model ->
            SettingsMaterialModel.renderSpecOf(
                model = model,
                isDark = isDark,
                hasBackdrop = hasBackdrop,
            )
        }
    }
    // 壁纸三档亮度带（顶栏 / 星期栏 / 正文）。**初值先同步查进程缓存**：切日/周视图、
    // 进外观编辑页预览卡都是新建整棵树，若初值恒为 null 就会先按主题墨色画一帧、
    // 异步量完再翻面 —— 用户看到的就是「所有字黑白闪一下」（2026-11-01 真机）。
    // 换壁纸 / 换解码宽时 key 变化 ⇒ 重新取新那张图的三档；新图还没量过则为 null
    //（按主题墨色兜底，等异步回调）。
    var wallpaperBands by remember(snapshot?.wallpaperPath, snapshot?.decodeWidthPx) {
        mutableStateOf(
            cachedWallpaperInkBands(snapshot?.wallpaperPath, snapshot?.decodeWidthPx ?: 0),
        )
    }
    // 只有「真有壁纸」才谈「壁纸上的墨色」；没壁纸 = 主题墨色（null）。
    val chromeInk: HomeInkPolarity? = if (snapshot?.hasWallpaper == true) {
        HomeBackgroundModel.chromeInkPolarity(wallpaperBands?.top)
    } else {
        null
    }
    val backdrop: (@Composable BoxScope.() -> Unit)? = snapshot?.let { snap ->
        {
            HomeWallpaperBackdrop(
                snapshot = snap,
                onInkBands = { bands -> wallpaperBands = bands },
            )
        }
    }
    return HomeBackdropChrome(
        snapshot = snapshot,
        material = material,
        bands = if (snapshot?.hasWallpaper == true) wallpaperBands else null,
        chromeInk = chromeInk,
        backdrop = backdrop,
    )
}
