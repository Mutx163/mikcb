package com.mutx163.qingyu.pages.transfer

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import com.mutx163.qingyu.PickupCodeLauncher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 「取件码」页的**宿主**：把七个固定入口接到真的外部跳转上。
 *
 * 对应 Dart `lib/screens/pickup_codes_screen.dart`（`_openEntry`，:69-114）：
 * 点一行 → 触觉反馈 → 按「直达链接 → 拉起 App → 网页兜底」多级回退（[PickupCodeRunner]）→
 * 按结果给一句话。
 *
 * ## 这一层之前缺什么
 *
 * 壳里原来是 `PickupCodesPage(onBack = onBack, onEntryClick = {})` —— 入口表在、卡片在、
 * 七行都在，**点了没有任何反应**，而且「未安装」那行灰字永远是 false 分支。
 * 现在：进页面批量查一次「哪些 App 装了」（Android 11+ 的包可见性已在
 * `AndroidManifest.xml` 的 `<queries>` 里声明，包括五个包名与七个 scheme），
 * 点一行就走真 `Intent`。
 *
 * ## 为什么不在这里写「多级回退」
 *
 * 顺序本身是业务规则，写进 Composable 就只能靠真机点七个入口来验证。
 * 它在 `main/pages/transfer/PickupCodeLaunchLogic.kt`（纯 Kotlin，有 JVM 单测钉住
 * 「第 1 条失败了才试第 2 条」「直达成功就不许再拉起 App」）。
 *
 * ## 诚实边界
 *
 * 真机没对照过：七个入口到底能不能拉起对应 App、未安装提示准不准，全部归用户验收。
 * 本批只证明「编译通过 + JVM 单测通过」。
 */
@Composable
fun PickupCodesHost(
    onBack: () -> Unit,
    hapticsEnabled: Boolean = true,
) {
    val context = LocalContext.current
    val haptic = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()

    val activity = remember(context) { context.findActivity() }
    val platform = remember(activity) { LauncherPickupCodePlatform(activity) }
    val runner = remember(platform) { PickupCodeRunner(platform) }

    /** null = 还没查到（渲染层据此**不**显示「未安装」，见 `PickupCodesModel.isInstalled`）。 */
    var installed by remember { mutableStateOf<Set<String>?>(null) }
    var busy by remember { mutableStateOf(false) }

    // 进页面查一次「装了没」：七个入口共用这一份结果，省掉七次重复查询。
    LaunchedEffect(platform) {
        installed = withContext(Dispatchers.IO) {
            runner.installedPackages(PickupCodesModel.allPackages())
        }
    }

    PickupCodesPage(
        onBack = onBack,
        onEntryClick = { preset ->
            // Dart `_openEntry` 的 `if (_busyEntryId != null) return;`：一次只跑一条，
            // 否则用户连点两下会在两个 App 之间来回拽前台。
            if (!busy) {
                busy = true
                if (hapticsEnabled) {
                    // Dart 是 `HapticFeedback.selectionClick()`；Compose 里最接近的是
                    // TextHandleMove（系统映射到 CLOCK_TICK 那一档轻触感）。
                    haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                }
                scope.launch {
                    val result = withContext(Dispatchers.IO) {
                        runner.run(preset, alreadyInstalled = installed)
                    }
                    busy = false
                    val message = PickupCodeFeedback.toastFor(preset, result)
                    if (message != null) {
                        val hint = PickupCodeFeedback.hintFor(result)
                        val text = if (hint != null) "$message\n$hint" else message
                        Toast.makeText(
                            context,
                            text,
                            if (hint != null) Toast.LENGTH_LONG else Toast.LENGTH_SHORT,
                        ).show()
                    }
                }
            }
        },
        installedOf = { preset -> PickupCodesModel.isInstalled(preset, installed) },
    )
}

/**
 * [PickupCodePlatform] 的 Android 实现：全部动作转给 [PickupCodeLauncher]。
 *
 * 不在这里判「链接能不能接」——试一遍就知道，而 `canResolve` 在包可见性没配好时会
 * 一律返回 false，拿它做前置判断反而会把本来能跳的入口挡掉。
 */
private class LauncherPickupCodePlatform(private val activity: Activity?) : PickupCodePlatform {

    override val supported: Boolean get() = activity != null

    override fun launchUri(
        uri: String,
        packageName: String?,
        clearTask: Boolean,
    ): PickupCodeLaunchOutcome {
        val target = activity ?: return unsupported()
        return toOutcome(PickupCodeLauncher.launch(target, uri, packageName, clearTask))
    }

    override fun launchApp(packageName: String, clearTask: Boolean): PickupCodeLaunchOutcome {
        val target = activity ?: return unsupported()
        return toOutcome(PickupCodeLauncher.launchApp(target, packageName, clearTask))
    }

    override fun installedPackages(packages: List<String>): Set<String>? {
        val target = activity ?: return null
        val result = PickupCodeLauncher.installedPackages(target, packages)
        return result.filterValues { it }.keys
    }

    private fun unsupported() = PickupCodeLaunchOutcome(false, PickupCodesModel.REASON_UNSUPPORTED)

    private fun toOutcome(raw: Map<String, Any?>): PickupCodeLaunchOutcome =
        PickupCodeLaunchOutcome(
            ok = raw["ok"] == true,
            reason = (raw["reason"] as? String)?.takeIf { it.isNotBlank() },
        )
}

/**
 * 从任何 Context 找到宿主 Activity。
 *
 * 不能直接 `context as? Activity`：Compose 拿到的 Context 经常是
 * `ContextThemeWrapper`（官方页面骨架里有主题包装），直接转型会一直失败，
 * 于是「点了没反应」——`PickupCodeLauncher` 需要真 Activity 才能 `startActivity`。
 */
private fun Context.findActivity(): Activity? {
    var current: Context? = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}
