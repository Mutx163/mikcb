package com.mutx163.qingyu.pages.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.app.HomeBackdropChrome
import com.mutx163.qingyu.pages.timetable.TimetableChromeBandGlass
import com.mutx163.qingyu.pages.timetable.TimetableTopBar
import com.mutx163.qingyu.theme.QingyuTheme
import top.yukonga.miuix.kmp.blur.layerBackdrop
import top.yukonga.miuix.kmp.blur.rememberLayerBackdrop

/**
 * 「首页标题」设置的真实预览卡（**宿主注入**，2026-11-10 用户报预览失真后重做）。
 *
 * ## 为什么重做
 *
 * 旧形态是通用样张色块（`SettingsPageRenderers.PreviewCard` → `PreviewTile`：72dp、主色蓝、
 * `body2` / `footnote1` 两行白字）。它和真标题没有一行共用代码，用户原话是「和实际差距
 * 太远，看不出来预览效果」——蓝底圆角框里写着「轻屿课表」，但真首页那行字是压在壁纸上、
 * 坐在玻璃带里、字色还会随壁纸明暗翻面。
 *
 * 发布版（`settings_appearance.dart:871-909` 的 `_HomeTitleStylePreview`）自己也是抽象样张，
 * 所以这属于**超发布版**的观感升级：用户明确要求「看得出真实效果」，不是对齐发布版。
 *
 * ## 真组件 + 真材质（仓库口径：不许烤位图示意）
 *
 * 卡片里三样东西全是现成的同一份实现，本文件不复制任何字号 / 颜色 / 玻璃参数：
 *
 * 1. **真壁纸样例**：[HomeBackdropChrome.backdrop]（`HomeWallpaperBackdrop`）——与首页、
 *    外观编辑页预览同一份 `rememberHomeBackdropChrome` 快照，取景 / 模糊口径自动一致；
 * 2. **真玻璃带**：`TimetableChromeBandGlass`（周/日/月三视图共用的那一条），材质档、
 *    实体降级、无 shader 降级全部照它自己的判据走；
 * 3. **真标题行**：`TimetableTopBar`（首页顶栏本体），`brand` 档位与副行课表名由调用方喂。
 *
 * 玻璃要采样「它底下的壁纸」，所以壁纸那层单独挂 `Modifier.layerBackdrop(...)` 录一层，
 * 带子再 `drawBackdrop` 取它 —— 与外观编辑页给玻璃坞录样的配方相同（`AppearanceEditorHost`
 * 的 `dockBackdrop`），不新造采样路径。
 *
 * ## 为什么没有「更多」球
 *
 * `TimetableTopBar` 的球是 `menuItems.isNotEmpty()` 才画的；本卡只预览**标题样式**，
 * 传空表 ⇒ 不画球。球的配方在顶栏里已经有一份，预览里不该为了像而摆一颗点不动的假球。
 *
 * ## 尺寸
 *
 * 带子 = 真顶栏高（`TimetableTopBarMetrics.HEIGHT` = 56dp）；卡片总高 96dp，
 * 带子下面留 40dp 壁纸 —— 用户要看的正是「这行字坐在什么底的上面」。
 */
@Composable
internal fun HomeTitlePreviewCard(
    chrome: HomeBackdropChrome,
    brand: Boolean,
    profileName: String?,
    modifier: Modifier = Modifier,
) {
    val dark = isSystemInDarkTheme()
    // 无壁纸 / 快照缺失时的底色：真页此刻就是页底色（主题底），不是白卡。
    val pageColor = chrome.pageColorArgb?.let { Color(it) }
        ?: Color(QingyuTheme.scaffoldBackground(dark = dark))
    // 录样层：只管「壁纸这一层」，带子画在它上面（录自己会递归）。
    val wallpaperBackdrop = rememberLayerBackdrop()

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(PREVIEW_HEIGHT_DP.dp)
            .clip(RoundedCornerShape(PREVIEW_CORNER_DP.dp))
            .background(pageColor),
    ) {
        // ① 真壁纸样例（与首页同一份快照）；录进 layerBackdrop 供玻璃采样。
        Box(
            modifier = Modifier
                .matchParentSize()
                .layerBackdrop(wallpaperBackdrop),
        ) {
            chrome.backdrop?.invoke(this)
        }
        // ② 真玻璃带 + ③ 真标题行：带子贴着卡片顶部，按真顶栏高裁一条。
        TimetableChromeBandGlass(
            material = chrome.material,
            hasBackdrop = chrome.hasBackdrop,
            backdrop = wallpaperBackdrop,
            solidColor = pageColor,
            // 卡片外沿已由 `clip` 裁掉：玻璃不需要往屏幕外推。
            overdrawDp = 0.dp,
            modifier = Modifier
                .align(Alignment.TopCenter)
                .height(BAND_HEIGHT_DP.dp),
        ) {
            // 真顶栏那一行：`menuItems` 空 ⇒ 不画更多球；`onTitleClick` 不传 ⇒ 预览不可点
            // （指针事件本来也被预览卡上层吃掉，这里只是不给"能点"的语义）。
            TimetableTopBar(
                brand = brand,
                inkPolarity = chrome.chromeInk,
                profileName = profileName,
                menuItems = emptyList(),
            )
        }
    }
}

/** 真顶栏高（`TimetableTopBarMetrics.HEIGHT = 56`）：带子与内容同高。 */
private const val BAND_HEIGHT_DP = 56

/** 卡片总高：56 带 + 40 壁纸。 */
private const val PREVIEW_HEIGHT_DP = 96

/** 卡片圆角（与设置族预览块的 12dp 同档）。 */
private const val PREVIEW_CORNER_DP = 12
