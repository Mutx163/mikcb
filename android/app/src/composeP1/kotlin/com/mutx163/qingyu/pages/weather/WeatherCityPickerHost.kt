package com.mutx163.qingyu.pages.weather

import android.Manifest
import android.content.pm.PackageManager
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
import androidx.core.content.ContextCompat
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
 */
@Composable
fun WeatherCityPickerHost(
    provider: WeatherProvider,
    onBack: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

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

    fun doLocate() {
        scope.launch {
            val failure = withContext(Dispatchers.IO) { provider.locateCurrentPosition() }
            if (failure == null) onBack() // 与「点选城市」一致：回到设置页那一行已显示新地点
        }
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions(),
    ) { _ ->
        // 无论用户如何选择，都再走一次 locate：真拿到权限才定位，否则 provider 回 PERMISSION_DENIED 显示。
        doLocate()
    }

    fun ensurePermissionThenLocate() {
        if (provider.isLocating) return
        val granted = ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
            context, Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            doLocate()
        } else {
            permissionLauncher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
            )
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
