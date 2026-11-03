package com.mutx163.qingyu.pages.weather

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
import com.mutx163.qingyu.platform.permission.PermissionSystemActions
import com.mutx163.qingyu.weather.DeviceLocationFailure
import com.mutx163.qingyu.weather.WeatherLocation
import com.mutx163.qingyu.weather.WeatherProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 选城市页的真实宿主：把 [WeatherProvider] 接到 [WeatherCityPickerPage] 上。
 *
 * 行为对齐 Flutter `weather_city_picker_screen.dart`：
 * - 输入防抖 400ms、少于 2 字不发请求；
 * - 搜索走 Open-Meteo 地理编码（`provider.searchLocations`，联网）；
 * - 「当前位置」先申请运行期权限再定位，成功后返回上一页（与点选城市一致）；
 * - 点选城市 → 写回 provider 并返回。
 *
 * 权限走共用的 [PermissionFlow]（对齐旧版 `device_location_service.dart:302-316` 的
 * 申请→解释→永久拒绝引导三段）：
 * - 未授予 → 弹系统框；授予后立即定位（`weather_city_picker_screen.dart:90-104`）；
 * - 拒绝一次 → 照走定位，provider 回 PERMISSION_DENIED，行内红字显示解释；
 * - 永久拒绝 → 提示 + 跳系统应用详情页（旧版只有文案；跳设置是本次按用户要求补的出路）；
 * - 估算成功 → 先 toast「已按网络位置估算」再返回（旧版 `:107-109`，此前缺失）。
 */
@Composable
fun WeatherCityPickerHost(
    provider: WeatherProvider,
    onBack: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val activity = remember(context) { PermissionSystemActions.findHostActivity(context) }

    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<WeatherLocation>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    var settled by remember { mutableStateOf(false) }
    var version by remember { mutableStateOf(0) }

    DisposableEffect(provider) {
        val listener: () -> Unit = { version++ }
        provider.addListener(listener)
        onDispose { provider.removeListener(listener) }
    }
    @Suppress("UNUSED_EXPRESSION")
    version

    // 防抖搜索：query 变化 → 400ms 后再发；<2 字直接清空。
    LaunchedEffect(query) {
        val trimmed = query.trim()
        if (trimmed.length < 2) {
            results = emptyList()
            searching = false
            settled = false
            return@LaunchedEffect
        }
        searching = true
        settled = false
        delay(400)
        val found = withContext(Dispatchers.IO) { provider.searchLocations(trimmed) }
        results = found
        settled = true
        searching = false
    }

    fun toast(message: String) {
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }

    fun doLocate() {
        scope.launch {
            val failure = withContext(Dispatchers.IO) { provider.locateCurrentPosition() }
            if (failure == null) {
                // 按网络 IP 估算的位置要如实标注（旧版 weather_city_picker_screen.dart:107-109），
                // 标注后照常返回——它仍是可用结果。
                if (provider.lastLocateWasEstimated) {
                    toast(WeatherStrings.weatherLocationEstimated.zh)
                }
                onBack() // 与「点选城市」一致：回到设置页那一行已显示新地点
            }
        }
    }

    fun openPermissionSettings() {
        toast(WeatherStrings.locationFailureMessage(WeatherLocationFailure.PERMISSION_DENIED_FOREVER))
        PermissionSystemActions.openAppDetailsSettings(context)
    }

    // 状态机要在回调间保持阶段，用 remember 持有；初始态按系统真实权限对齐。
    // 声明在 launcher 之前：Kotlin 局部变量没有前向引用，回调里要读它。
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
        if (granted) {
            doLocate()
        } else if (!canAskAgain) {
            openPermissionSettings()
        } else {
            // 拒绝一次：仍走一次定位，provider 回 PERMISSION_DENIED，由行内副标题显示解释。
            doLocate()
        }
    }

    fun ensurePermissionThenLocate() {
        if (provider.isLocating) return
        when (permissionFlow.onTrigger()) {
            PermissionStep.Proceed -> doLocate()
            PermissionStep.LaunchRequest -> permissionLauncher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
            )
            PermissionStep.OpenSettings -> openPermissionSettings()
        }
    }

    val state = WeatherCityPickerUiState(
        query = query,
        results = results,
        searching = searching,
        settled = settled,
        locating = provider.isLocating,
        currentCity = provider.location,
        error = provider.lastLocateFailure?.let { locationFailureText(it) },
    )

    WeatherCityPickerPage(
        state = state,
        onBack = onBack,
        onQueryChange = { query = it },
        onSelect = { location ->
            scope.launch {
                withContext(Dispatchers.IO) { provider.setLocation(location) }
                onBack()
            }
        },
        onRelocate = { ensurePermissionThenLocate() },
    )
}

private fun locationFailureText(failure: DeviceLocationFailure): String =
    WeatherStrings.locationFailureMessage(
        when (failure) {
            DeviceLocationFailure.SERVICE_DISABLED -> WeatherLocationFailure.SERVICE_DISABLED
            DeviceLocationFailure.PERMISSION_DENIED -> WeatherLocationFailure.PERMISSION_DENIED
            DeviceLocationFailure.PERMISSION_DENIED_FOREVER -> WeatherLocationFailure.PERMISSION_DENIED_FOREVER
            DeviceLocationFailure.TIMEOUT -> WeatherLocationFailure.TIMEOUT
            DeviceLocationFailure.FAILED -> WeatherLocationFailure.FAILED
            DeviceLocationFailure.ADDRESS_UNAVAILABLE -> WeatherLocationFailure.ADDRESS_UNAVAILABLE
        },
    )
