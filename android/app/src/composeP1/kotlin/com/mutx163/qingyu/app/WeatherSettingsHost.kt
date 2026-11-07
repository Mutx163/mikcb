package com.mutx163.qingyu.app

import android.Manifest
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.core.permission.PermissionFlow
import com.mutx163.qingyu.core.permission.PermissionStep
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.pages.settings.SettingsWeatherPage
import com.mutx163.qingyu.pages.settings.WeatherPageData
import com.mutx163.qingyu.pages.settings.WeatherStatus
import com.mutx163.qingyu.pages.weather.WeatherLocationFailure
import com.mutx163.qingyu.pages.weather.WeatherStrings
import com.mutx163.qingyu.platform.permission.PermissionSystemActions
import com.mutx163.qingyu.weather.DeviceLocationFailure
import com.mutx163.qingyu.weather.WeatherProvider
import com.mutx163.qingyu.weather.WeatherState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 天气设置页的**真实宿主**（取代壳里原先的 `SettingsScreen(SettingsWeatherPage.spec(SettingsPageState()))`
 * 静态 mock）。
 *
 * 数据流与设置族其它页同一套循环，但有两个来源：
 * - 设备级天气状态（开关 / 是否定位中 / 城市 / 取数状态）来自 [WeatherProvider]；
 * - 六个显示开关（日卡/周卡/弹窗/现象/温度/概率）来自 [TimetableSettingsModelStore]。
 *
 * ## 权限（对齐旧版 `settings_weather.dart:243-277` + `device_location_service.dart:302-316`）
 *
 * 旧版 geolocator 在 `locate()` 内部会**主动弹系统权限框**（denied → requestPermission）；
 * Kotlin 侧 `AndroidWeatherLocationSource` 拿不到 Activity 结果，此前直接回 PERMISSION_DENIED
 * ⇒ 用户点「使用当前位置」**永远看不到申请框**、只有一句失败 toast（静默失败缺口，本次补上）：
 * - 未授予 → 弹系统框，授予后立即定位；
 * - 拒绝一次 → 照走定位，toast 显示 PERMISSION_DENIED 解释（与旧版失败出口一致）；
 * - 永久拒绝 → toast + 跳系统应用详情页（跳设置是本次按用户要求补的出路，旧版只有文案）；
 * - 打开天气开关且还没有城市时自动定位（`settings_weather.dart:243-254`），同走本流程。
 *
 * ## 为什么单独一个宿主而不是塞进 SettingsHost
 *
 * `SettingsHost` 的状态源是 `SettingsPageBridge.toSettingsPageState(model)`（纯课表设置），
 * 不含天气 provider；把这个设备级依赖塞进共享桥会让 20 页都背上它。天气只有这一页要，
 * 单开一个宿主、只对外暴露「provider + 设置模型 store」两个依赖更干净。
 *
 * ## 线程
 *
 * [WeatherProvider] 是同步阻塞实现（见其 KDoc），所以写盘 / 取网 / 定位一律在 [Dispatchers.IO]
 * 上跑，完成后靠 `provider.addListener` 触发重组。
 */
@Composable
fun WeatherSettingsHost(
    provider: WeatherProvider,
    store: TimetableSettingsModelStore,
    onBack: () -> Unit,
    onNavigate: (String) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var model by remember(store) { mutableStateOf(store.load()) }
    var version by remember { mutableStateOf(0) }

    // 订阅 provider 变化 → 触发重组。
    DisposableEffect(provider) {
        val listener: () -> Unit = { version++ }
        provider.addListener(listener)
        onDispose { provider.removeListener(listener) }
    }
    // 首次进入读盘并补一次「过期就刷」（幂等）。
    LaunchedEffect(provider) {
        withContext(Dispatchers.IO) { provider.initialize() }
    }
    // 读取 version 建立快照订阅（值本身不参与渲染）。
    @Suppress("UNUSED_EXPRESSION")
    version

    fun writeModel(next: TimetableSettingsModel) {
        // 落盘失败绝不进内存：否则界面显示已保存、重启后回退（静默失败）。
        runCatching { store.save(next) }.fold(
            onSuccess = { model = next },
            onFailure = {
                Toast.makeText(
                    context,
                    SettingsStringsExt2.saveFailed.text,
                    Toast.LENGTH_SHORT,
                ).show()
            },
        )
    }

    fun showToast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    fun locate() {
        scope.launch {
            val failure = withContext(Dispatchers.IO) { provider.locateCurrentPosition() }
            val estimated = provider.lastLocateWasEstimated
            val message = when {
                failure != null -> WeatherStrings.locationFailureMessage(failure.toWeatherLocationFailure())
                estimated -> WeatherStrings.weatherLocationEstimated.text
                else -> null
            }
            if (message != null) showToast(message)
        }
    }

    val activity = remember(context) { PermissionSystemActions.findHostActivity(context) }
    val permissionFlow = remember {
        PermissionFlow(
            initiallyGranted = PermissionSystemActions.anyGranted(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
        )
    }
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants ->
        val granted = grants.values.any { it }
        val canAskAgain = activity?.let {
            PermissionSystemActions.canAskAgain(it, Manifest.permission.ACCESS_FINE_LOCATION)
        } ?: false
        permissionFlow.onSystemResult(granted, canAskAgain)
        when {
            granted -> locate()
            // 永久拒绝：toast 解释 + 送系统设置（系统不再弹框，只能去那里开）。
            !canAskAgain -> {
                showToast(
                    WeatherStrings.locationFailureMessage(
                        WeatherLocationFailure.PERMISSION_DENIED_FOREVER,
                    ),
                )
                PermissionSystemActions.openAppDetailsSettings(context)
            }
            // 拒绝一次：与旧版失败出口一致——走定位，toast PERMISSION_DENIED 解释。
            else -> locate()
        }
    }

    fun locateWithPermission() {
        if (provider.isLocating) return
        when (permissionFlow.onTrigger()) {
            PermissionStep.Proceed -> locate()
            PermissionStep.LaunchRequest -> permissionLauncher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
            )
            PermissionStep.OpenSettings -> {
                showToast(
                    WeatherStrings.locationFailureMessage(
                        WeatherLocationFailure.PERMISSION_DENIED_FOREVER,
                    ),
                )
                PermissionSystemActions.openAppDetailsSettings(context)
            }
        }
    }

    fun toggle(rowId: String) {
        when (rowId) {
            "weather.enable" -> scope.launch {
                val nextEnabled = !provider.enabled
                withContext(Dispatchers.IO) { provider.setEnabled(nextEnabled) }
                // 打开且还没有城市时主动定位一次（否则用户会停在「开关开着、卡片却没天气」）。
                // 定位走权限申请前置的同一入口（旧版 _toggleWeather → _locateWeather）。
                if (nextEnabled && provider.location == null) locateWithPermission()
            }
            "weather.showOnDayCard" -> writeModel(model.copy(weatherShowOnDayCard = !model.weatherShowOnDayCard))
            "weather.showOnWeekCard" -> writeModel(model.copy(weatherShowOnWeekCard = !model.weatherShowOnWeekCard))
            "weather.showOnSheet" -> writeModel(model.copy(weatherShowOnSheet = !model.weatherShowOnSheet))
            "weather.showPhenomenon" -> writeModel(model.copy(weatherShowPhenomenon = !model.weatherShowPhenomenon))
            "weather.showTemperature" -> writeModel(model.copy(weatherShowTemperature = !model.weatherShowTemperature))
            "weather.showProbability" -> writeModel(model.copy(weatherShowProbability = !model.weatherShowProbability))
        }
    }

    val data = WeatherPageData(
        enabled = provider.enabled,
        providerAvailable = true,
        status = provider.state.toWeatherPageStatus(),
        locating = provider.isLocating,
        cityDisplayName = provider.location?.displayName,
        showOnDayCard = model.weatherShowOnDayCard,
        showOnWeekCard = model.weatherShowOnWeekCard,
        showOnSheet = model.weatherShowOnSheet,
        showPhenomenon = model.weatherShowPhenomenon,
        showTemperature = model.weatherShowTemperature,
        showProbability = model.weatherShowProbability,
    )
    val spec = SettingsWeatherPage.spec(SettingsPageState(), data)

    SettingsPageScreen(
        spec = spec,
        onBack = onBack,
        onAction = { action, target, rowId ->
            when (action) {
                SettingsAction.WRITE_SETTING -> toggle(rowId)
                SettingsAction.RUN_NOW ->
                    if (rowId == "weather.useCurrentLocation") {
                        locateWithPermission()
                    } else if (rowId == "weather.retry") {
                        scope.launch { withContext(Dispatchers.IO) { provider.retry() } }
                    }
                SettingsAction.NAVIGATE -> target?.let(onNavigate)
                else -> {}
            }
        },
    )
}

private fun WeatherState.toWeatherPageStatus(): WeatherStatus = when (this) {
    WeatherState.IDLE -> WeatherStatus.IDLE
    WeatherState.LOADING -> WeatherStatus.LOADING
    WeatherState.READY -> WeatherStatus.LOADED
    WeatherState.FAILED -> WeatherStatus.FAILED
}

private fun DeviceLocationFailure.toWeatherLocationFailure(): WeatherLocationFailure = when (this) {
    DeviceLocationFailure.SERVICE_DISABLED -> WeatherLocationFailure.SERVICE_DISABLED
    DeviceLocationFailure.PERMISSION_DENIED -> WeatherLocationFailure.PERMISSION_DENIED
    DeviceLocationFailure.PERMISSION_DENIED_FOREVER -> WeatherLocationFailure.PERMISSION_DENIED_FOREVER
    DeviceLocationFailure.TIMEOUT -> WeatherLocationFailure.TIMEOUT
    DeviceLocationFailure.FAILED -> WeatherLocationFailure.FAILED
    DeviceLocationFailure.ADDRESS_UNAVAILABLE -> WeatherLocationFailure.ADDRESS_UNAVAILABLE
}
