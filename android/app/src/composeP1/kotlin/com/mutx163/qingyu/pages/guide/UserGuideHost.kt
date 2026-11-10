package com.mutx163.qingyu.pages.guide

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.mutx163.qingyu.pages.ShellWiring
import com.mutx163.qingyu.platform.guide.GuidePermissionProbe

/**
 * 用户指南页的**宿主接线**（从 `ShellPageIndex` 的 `i.userGuide` 分支原样抽出）。
 *
 * 为什么抽出来：首启隐私门（[FirstRunPrivacyGate]）和「设置里复看指南」需要同一套
 * 真实数据接线——权限真值、个性化设置读写、壳内跳页。两处各写一份迟早漂移
 *（一边接了权限探针、另一边忘了），所以宿主只有这一份，两个入口只差参数。
 *
 * @param requirePrivacyConsent 首启模式 = true：未勾选隐私不能翻页、不给关闭键
 * @param initialPrivacyChecked 进入时的勾选态（老用户已同意过 → true，只补看指南）
 * @param onPrivacyConsentChanged 勾选状态回传（宿主拿不到 `UserGuidePage` 的内部 state，
 *   而同意标记必须在退出时按真实勾选落盘，用户可以先勾后取消）
 */
@Composable
fun UserGuideHost(
    wiring: ShellWiring,
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
    requirePrivacyConsent: Boolean = false,
    initialPrivacyChecked: Boolean = false,
    onPrivacyConsentChanged: (Boolean) -> Unit = {},
    onFinishGuide: () -> Unit = onBack,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var permissionState by remember { mutableStateOf(GuidePermissionProbe.probe(context)) }
    var guideSettings by remember {
        mutableStateOf(GuideSettingsMapping.snapshotFrom(wiring.settingsModel.load()))
    }
    // 从系统设置页返回时重新探测权限 + 重新读设置，让「点完回来状态变了」看得见。
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                permissionState = GuidePermissionProbe.probe(context)
                guideSettings = GuideSettingsMapping.snapshotFrom(wiring.settingsModel.load())
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    UserGuidePage(
        requirePrivacyConsent = requirePrivacyConsent,
        initialPrivacyChecked = initialPrivacyChecked,
        onBack = onBack,
        permissionState = permissionState,
        settings = guideSettings,
        seedOptions = GuideSettingsMapping.seedOptions(),
        onPermissionAction = { action ->
            GuidePermissionProbe.open(context, action)
            permissionState = GuidePermissionProbe.probe(context)
        },
        onRefreshPermissions = { permissionState = GuidePermissionProbe.probe(context) },
        onSettingsPatch = { patch ->
            val next = GuideSettingsMapping.applyPatch(wiring.settingsModel.load(), patch)
            wiring.settingsModel.save(next)
            guideSettings = GuideSettingsMapping.snapshotFrom(next)
        },
        onImportCourses = { onOpenPage("g1.importEntry") },
        onRestoreBackup = { onOpenPage("f.backupList") },
        onOpenCourseOverview = { onOpenPage("d1.overview") },
        onPrivacyConsentChanged = onPrivacyConsentChanged,
        onFinishGuide = onFinishGuide,
    )
}
