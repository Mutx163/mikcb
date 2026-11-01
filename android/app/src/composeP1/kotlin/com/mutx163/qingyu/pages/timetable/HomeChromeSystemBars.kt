package com.mutx163.qingyu.pages.timetable

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

/**
 * 在本页停留期间把状态栏图标切成浅色 / 深色，离开时还原（周视图与日视图共用）。
 *
 * ## 为什么是命令式
 *
 * Compose 没有 `AnnotatedRegion<SystemUiOverlayStyle>` 的等价物，系统栏外观的唯一入口是
 * 窗口的 insets controller。壳只在**自己的明暗主题**变化时设置一次
 * （`PagesShellActivity.applyShellSystemBars` / `ComposeP1Activity`），它不区分当前是哪一页、
 * 也不知道壁纸是什么颜色 —— 所以首页要把「壁纸上的墨色」临时覆盖上去，并在 `onDispose`
 * 还原，否则去别的页面后状态栏会一直停在壁纸那一档。
 *
 * 做法与设置页 `AppearanceEditorScreen.ApplyLightSystemBarIcons` 同一条路子
 * （那一份是 private，跨不了文件；它还额外管导航栏，这里只管状态栏）。
 *
 * @param lightIcons `true` = 深色图标（浅色壁纸），`false` = 浅色图标（深色壁纸）。
 */
@Composable
fun ApplyChromeStatusBarInk(lightIcons: Boolean) {
    val view = LocalView.current
    val context = LocalContext.current
    DisposableEffect(view, lightIcons) {
        val window = context.findHostActivityOrNull()?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, view) }
        val previous = controller?.isAppearanceLightStatusBars
        controller?.isAppearanceLightStatusBars = lightIcons
        onDispose {
            if (controller != null && previous != null) {
                controller.isAppearanceLightStatusBars = previous
            }
        }
    }
}

/**
 * 从 `LocalContext` 往上找宿主 `Activity`。
 *
 * 不能直接 `context as? Activity`：Activity 里的 Compose 上下文经常是
 * `ContextThemeWrapper`（主题包了一层），直接转型会得到 null、系统栏一句话都设不上。
 */
private fun Context.findHostActivityOrNull(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}
