package com.mutx163.qingyu.pages.transfer

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.util.Log
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.unit.dp
import com.mutx163.qingyu.PickupCodeLauncher
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private const val TAG = "PickupCodes"

/**
 * 「取件码」页的**宿主**：把七个固定入口接到真的外部跳转上。
 *
 * 对应 Dart `lib/screens/pickup_codes_screen.dart`（`_openEntry`，:69-114）：
 * 点一行 → 触觉反馈 → 按「直达链接 → 拉起 App → 网页兜底」多级回退（[PickupCodeRunner]）→
 * 按结果给一句话。
 *
 * ## 这一层负责什么
 *
 * 1. **一次只跑一条**：正在跳的入口键传给渲染层，对应行画进度圈、其余行淡下去；
 *    不做「静默 `if (!busy)` 吞掉第二次点击」——用户看不见为什么没反应。
 * 2. **进页面批量查安装**：七条入口共用一次 `PackageManager` 查询；查不到（null）
 *    时按「已安装」处理，不把能点的入口误标成未安装。
 * 3. **结果 → 应用内提示**：走本族共享的 [AppToastCapsule]（与数据备份页、情侣课表页同一颗），
 *    不再用系统 Toast——系统 Toast 会盖在刚拉起的 App 上，样式也与全站不一致。
 * 4. **失败可诊断**：每条结果写一行日志（入口键 / 走到哪一级 / 原因码 / 耗时），
 *    这是「点了没反应」类反馈唯一的现场线索（Dart `elapsed` 的同一用途）。
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
 */
@Composable
fun PickupCodesHost(
    onBack: () -> Unit,
    hapticsEnabled: Boolean = true,
) {
    val context = LocalContext.current
    val haptic = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val dark = isSystemInDarkTheme()

    val activity = remember(context) { context.findActivity() }
    val platform = remember(activity) { LauncherPickupCodePlatform(activity) }
    val runner = remember(platform) { PickupCodeRunner(platform) }

    /** null = 还没查到（渲染层据此**不**显示「未安装」，见 `PickupCodesModel.isInstalled`）。 */
    var installed by remember { mutableStateOf<Set<String>?>(null) }

    /** 正在跳的入口键；null = 空闲。传给渲染层画进度圈与淡化其余行。 */
    var busyTitleKey by remember { mutableStateOf<String?>(null) }

    /** 一次性的底部提示；null = 不显示。 */
    var toast by remember { mutableStateOf<PickupToast?>(null) }

    // 进页面查一次「装了没」：七个入口共用这一份结果，省掉七次重复查询。
    LaunchedEffect(platform) {
        installed = withContext(Dispatchers.IO) {
            runner.installedPackages(PickupCodesModel.allPackages())
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        PickupCodesPage(
            onBack = onBack,
            busyTitleKey = busyTitleKey,
            onEntryClick = { preset ->
                // Dart `_openEntry` 的 `if (_busyEntryId != null) return;`。渲染层此时
                // 已经把整页置为不可点，这里再挡一次是防「同一帧内连点」。
                if (busyTitleKey == null) {
                    busyTitleKey = preset.titleKey
                    // 快照读一次再进 IO：别在后台线程里读 Compose State。
                    val knownInstalled = installed
                    if (hapticsEnabled) {
                        // Dart 是 `HapticFeedback.selectionClick()`；Compose 里最接近的是
                        // TextHandleMove（系统映射到 CLOCK_TICK 那一档轻触感）。
                        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                    }
                    scope.launch {
                        val result = try {
                            withContext(Dispatchers.IO) {
                                try {
                                    runner.run(preset, alreadyInstalled = knownInstalled)
                                } catch (cancellation: CancellationException) {
                                    throw cancellation
                                } catch (error: Exception) {
                                    // 跳转通道的意外异常不该把页面卡在忙碌态，也不该崩；
                                    // 按「未知原因失败」提示，日志里留现场。
                                    Log.w(TAG, "entry=${preset.titleKey} runner threw", error)
                                    PickupCodeRunResult(
                                        status = PickupCodeRunStatus.FAILED,
                                        reason = PickupCodesModel.REASON_UNKNOWN_FALLBACK,
                                    )
                                }
                            }
                        } finally {
                            busyTitleKey = null
                        }

                        Log.i(
                            TAG,
                            "entry=${preset.titleKey} status=${result.status} " +
                                "reason=${result.reason} elapsed=${result.elapsedMillis}ms",
                        )

                        val message = PickupCodeFeedback.toastFor(preset, result)
                        if (message != null) {
                            toast = PickupToast(
                                message = message,
                                description = PickupCodeFeedback.hintFor(result),
                            )
                        }
                    }
                }
            },
            installedOf = { preset -> PickupCodesModel.isInstalled(preset, installed) },
        )

        // 应用内提示：底部居中、2 秒自动消失（Dart `HyperosMiuixSnackbar.durationShortMs`）。
        toast?.let { current ->
            AppToastCapsule(
                message = current.message,
                description = current.description,
                dark = dark,
                onDismiss = { toast = null },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 16.dp, vertical = 32.dp),
            )
        }
    }
}

/** 一条待显示的提示；`description` 是失败时的第二行建议（Dart `showAppToast` 的 description）。 */
private data class PickupToast(
    val message: String,
    val description: String?,
)

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
        // 用 probe 而不是 installedPackages：后者的契约是「查不到就算没装」，
        // 包可见性没覆盖时会把七行全标成未安装、还会让回退器跳过所有 App 兜底。
        // probe 在遇到非 NameNotFoundException 的异常时返回 null（未知），
        // 上层据此不做任何「未安装」判定。
        val result = PickupCodeLauncher.probeInstalledPackages(target, packages) ?: return null
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
