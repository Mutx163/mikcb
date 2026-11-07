package com.mutx163.qingyu.pages.timetable

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.mutx163.qingyu.pages.transfer.AppToastCapsule
import com.mutx163.qingyu.platform.ScreenCaptureWatcher

/**
 * 截屏「分享课表图」提示宿主（Dart `timetable_screen.dart:935-963` 的移植）。
 *
 * ## 链路
 *
 * 壳 `PagesShellActivity` 挂的 [ScreenCaptureWatcher] 检测到截屏（Android 14+ 官方
 * `registerScreenCaptureCallback`）→ 本宿主经 `ScreenCaptureWatcher.activeWatcher`
 * 接住事件 → [ScreenshotSharePromptGate] 过三道门（设置开关 / 本页置顶 / 6 秒冷却）
 * → 浮一条「要分享一张干净的课表图吗」胶囊（[AppToastCapsule]，5 秒自动消失）。
 *
 * ## 三道门的 Compose 对位
 *
 * * **设置开关**：由宿主参数 [enabled] 传入（TimetableHost 按用户存档
 *   `screenshotSharePromptEnabled` 喂），关掉时本宿主不组合、也不占事件出口。
 * * **本页置顶**：miuix-nav 给每个条目配了条目级 `LifecycleOwner`（顶层稳态 RESUMED、
 *   被推入页覆盖 STARTED、退场 CREATED），事件到达那一刻读它的状态——这正是
 *   Dart `ModalRoute.of(context)?.isCurrent` 的对位判据：去设置页等二级页截屏不弹。
 * * **冷却**：`ScreenshotSharePromptGate.COOLDOWN_MILLIS`（6 秒，Dart 同值），
 *   连拍截屏不叠提示。
 *
 * ## 与 Dart 的差异
 *
 * 1. **监听不跟随开关即时注册/注销**：壳恒注册（`attach` 缺省恒想听），开关只在
 *    门上拦。与 Dart「关开关就 stop 监听」的差别只是注册成本，行为一致；
 *    且本 App 的设置改动本来就只在回到首页时生效（壳同一条口径）。
 * 2. **「分享」按钮只在动作有去处时画**（[onShare] 非空才传 `actionLabel`）：
 *    2026-11-03 导出链路（[TimetableShareImageModel]/[TimetableShareImageRender]/
 *    `shareTimetableImage`）落地后由宿主喂动作，没接宿主的调用方（历史零参）不画按钮
 *    （假入口纪律：文案键 `timetableSharePromptAction` 已在六语 ARB）。
 *
 * ## 预览守卫
 *
 * 外观编辑页的缩尺预览卡复用整个 `TimetableHost`，必须显式传 `enabled = false`
 * （Dart `_isPreview` 守卫，`timetable_screen.dart:913-917`：预览再接一份监听，
 * 等于截一次屏弹两次提示）。
 *
 * @param enabled 总开关（设置 × 宿主意愿，与门控的 enabled 同源）。
 * @param onShare 点「分享」的动作（直接导出当前视图的干净课表图并拉起系统分享，
 *   Dart `_shareTimetableImage` 同口径）。null = 不画按钮。
 * @param modifier 胶囊的摆放（调用方用 `align(BottomCenter)` + 内边距定位）。
 */
@Composable
fun ScreenshotSharePromptHost(
    enabled: Boolean,
    modifier: Modifier = Modifier,
    onShare: (() -> Unit)? = null,
) {
    if (!enabled) return
    val dark = isSystemInDarkTheme()
    val entryLifecycle = LocalLifecycleOwner.current
    var promptVisible by remember { mutableStateOf(false) }
    // 上次弹出时刻（elapsedRealtime 口径）；0 = 从没弹过（Dart _lastScreenshotPromptAt 的可空语义）。
    var lastPromptAtMillis by remember { mutableStateOf(0L) }

    DisposableEffect(entryLifecycle) {
        val watcher = ScreenCaptureWatcher.activeWatcher
        if (watcher == null) {
            onDispose { }
        } else {
            watcher.onScreenshot = {
                val now = android.os.SystemClock.elapsedRealtime()
                if (
                    ScreenshotSharePromptGate.shouldShow(
                        enabled = true,
                        topMost = entryLifecycle.lifecycle.currentState == Lifecycle.State.RESUMED,
                        lastPromptAtMillis = lastPromptAtMillis.takeIf { it > 0L },
                        nowMillis = now,
                    )
                ) {
                    // 先记账再弹（Dart :952-952 同一顺序）。
                    lastPromptAtMillis = now
                    promptVisible = true
                }
            }
            onDispose { watcher.onScreenshot = null }
        }
    }

    // 可见性由状态驱动；胶囊本体（样式 / 自动消失 / 读屏播报）在共享件 AppToastCapsule，
    // 「数据备份」「情侣课表」页同款。这里传 5 秒档（Dart _screenshotPromptDuration）。
    // 「分享」按钮只在动作有去处时画（Dart showAppToastWithAction 的 actionLabel 同位）。
    if (!promptVisible) return
    AppToastCapsule(
        message = TimetableStrings.timetableSharePromptMessage.text,
        dark = dark,
        modifier = modifier.padding(horizontal = 16.dp),
        actionLabel = onShare?.let { TimetableStrings.timetableSharePromptAction.text },
        onAction = {
            promptVisible = false
            onShare?.invoke()
        },
        autoDismissMillis = ScreenshotSharePromptGate.PROMPT_DURATION_MILLIS,
        onDismiss = { promptVisible = false },
    )
}
