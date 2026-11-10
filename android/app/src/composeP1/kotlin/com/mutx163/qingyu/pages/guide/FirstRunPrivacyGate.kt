package com.mutx163.qingyu.pages.guide

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import com.mutx163.qingyu.pages.ShellWiring
import com.mutx163.qingyu.platform.PrefsKeyValueStore

/**
 * 首启隐私门（B1，2026-11-10）。
 *
 * ## 为什么要有它
 *
 * 用户 2026-11-08 拍板「首启必选」：新装第一次启动必须看到隐私说明、勾选同意后才能
 * 进首页。此前 Compose 壳的冷启动直接进首页（`PagesShellActivity.onCreate` 不读任何
 * 引导/隐私标记），用户指南页只是「设置里复看」——`requirePrivacyConsent` 默认 false、
 * 勾选也不落盘。这个组件把缺的三段一次补齐：
 *
 * 1. **进门判定**：已同意 + 已看过（Dart 快速路径）→ 直接交给壳；
 * 2. **首次展示**：[UserGuideHost] 以 `requirePrivacyConsent = !accepted` 展示，
 *    未勾选不能翻过隐私页、没有关闭键；
 * 3. **退出落盘**：勾了才写 `accepted_privacy_policy`，同时写 `has_seen_user_guide`
 *    与 `has_completed_onboarding`（对齐 `v2.1.4.1:lib/main.dart:1372-1388`），
 *    之后才把「可以进壳」交回去。
 *
 * ## 与旧版的差异（有意为之，不是漏）
 *
 * - 旧版在指南里点「导入课程 / 恢复备份」会先跑导入流程**再回到指南**；本版在
 *   首启门里把这三个入口当作「完成首启 + 直接去目标页」——首启阶段没有壳的导航栈可
 *   承载「回指南」，硬留在门里只会把用户困住。隐私同意仍由 `UserGuidePage` 的
 *   欢迎页动作门控（未勾选时先跳到隐私页，不会越过同意）。
 * - 首启模式没有「关闭」：未同意时系统返回键会退出 App（下次冷启重来），
 *   不会把未同意的用户放进首页。
 *
 * @param onCompleted 门内动作完成、允许进壳；`routePageId` 非空表示用户是从指南里的
 *   「导入 / 恢复 / 课程总览」进来的，进壳后由壳把这一页推出来。
 */
@Composable
fun FirstRunPrivacyGate(
    wiring: ShellWiring,
    onCompleted: (routePageId: String?) -> Unit,
) {
    val context = LocalContext.current
    val privacy = remember { PrivacyConsentPreferences(PrefsKeyValueStore(context)) }
    val startup = remember { StartupFlowPreferences(PrefsKeyValueStore(context)) }
    val accepted = remember { privacy.hasAcceptedPrivacyPolicy() }
    val seen = remember { privacy.hasSeenUserGuide() }
    // 页面内部勾选态会随用户操作变（可以勾了再取消），退出时必须按**当前值**落盘。
    var consentChecked by remember { mutableStateOf(accepted) }

    if (!FirstRunPrivacyFlow.needsGuide(accepted, seen)) {
        // 快速路径：已同意 + 已看过。友盟「已同意才初始化」由壳侧统一处理。
        LaunchedEffect(Unit) { onCompleted(null) }
        return
    }

    val requireConsent = FirstRunPrivacyFlow.requiresConsent(accepted)
    val finish: (String?) -> Unit = { route ->
        if (FirstRunPrivacyFlow.complete(privacy, startup, consentChecked, accepted)) {
            onCompleted(route)
        }
    }
    // 隐私页底栏的那颗「退出应用」走的是 `onBack`（`GuideBottomBar` 的
    // `isPrivacyPage` 分支）。首启模式没有壳可退，必须真的结束 Activity，
    // 否则按钮点了没反应——用户会当成卡死。
    val activity = context.findActivity()
    val exitApp: () -> Unit = { activity?.finish() }

    UserGuideHost(
        wiring = wiring,
        // 未同意时没有关闭键（UserGuidePage 的 closeGuide 为 null），底栏的
        // 「退出应用」= 真退出；已同意但没看过指南时，返回 = 只看完不看了，
        // 按旧版口径仍写「已看过」并进首页。
        onBack = if (requireConsent) exitApp else ({ finish(null) }),
        onOpenPage = finish,
        requirePrivacyConsent = requireConsent,
        initialPrivacyChecked = accepted,
        onPrivacyConsentChanged = { consentChecked = it },
        onFinishGuide = { finish(null) },
    )
}

/**
 * 从任意 Context 找宿主 Activity。
 *
 * 不能直接 `context as? Activity`：Compose 拿到的 Context 经常是 `ContextThemeWrapper`，
 * 直接转型会一直失败，于是「退出应用」按钮点了没反应（同款坑见 `PickupCodesHost`）。
 */
private fun Context.findActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}
