package com.mutx163.qingyu.app

import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsWeatherPage
import com.mutx163.qingyu.pages.settings.WeatherPageData
import com.mutx163.qingyu.pages.settings.WeatherStatus
import com.mutx163.qingyu.pages.weather.WeatherLocationFailure
import com.mutx163.qingyu.pages.weather.WeatherStrings
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
        store.save(next)
        model = next
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
                estimated -> WeatherStrings.weatherLocationEstimated.zh
                else -> null
            }
            if (message != null) showToast(message)
        }
    }

    fun toggle(rowId: String) {
        when (rowId) {
            "weather.enable" -> scope.launch {
                val nextEnabled = !provider.enabled
                withContext(Dispatchers.IO) { provider.setEnabled(nextEnabled) }
                // 打开且还没有城市时主动定位一次（否则用户会停在「开关开着、卡片却没天气」）。
                if (nextEnabled && provider.location == null) locate()
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
                        locate()
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
