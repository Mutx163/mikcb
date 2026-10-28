package com.mutx163.qingyu.platform

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import com.mutx163.qingyu.weather.DeviceLocationFailure
import com.mutx163.qingyu.weather.DeviceLocationOutcome
import com.mutx163.qingyu.weather.DeviceLocationSource
import com.mutx163.qingyu.weather.WeatherLocation
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * [DeviceLocationSource] 的 Android 实现（对应 Dart `device_location_service.dart` 的原生路径）。
 *
 * 顺序与 Dart 同口径：
 * ```
 * 权限/开关 → 实时定位（网络优先、单次、有总预算）
 *          → 网络 IP 估算（标注为估算）→ 才失败
 * ```
 * 「权限申请」不在这里做（需要 Activity 的 ActivityResult）：宿主在触发定位前先申请，
 * 未授予时本类直接回 [DeviceLocationFailure.PERMISSION_DENIED]。
 *
 * 放在 `platform/` 而不是 `main/.../weather/`：本文件 import `android.*`，进不了纯 Kotlin 的
 * JVM 单测 classpath；天气包只保留纯逻辑接口。
 */
class AndroidWeatherLocationSource(
    private val context: Context,
    private val reverseGeocode: (latitude: Double, longitude: Double) -> WeatherLocation?,
    private val networkGeocode: () -> WeatherLocation?,
) : DeviceLocationSource {

    companion object {
        private const val FIX_TIMEOUT_MS = 6_000L
    }

    override fun locate(): DeviceLocationOutcome {
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
            ?: return DeviceLocationOutcome.failure(DeviceLocationFailure.FAILED)

        if (!isLocationEnabled(manager)) {
            return DeviceLocationOutcome.failure(DeviceLocationFailure.SERVICE_DISABLED)
        }
        if (!hasPermission()) {
            return DeviceLocationOutcome.failure(DeviceLocationFailure.PERMISSION_DENIED)
        }

        val fix = currentFix(manager)
        val estimated: Boolean
        val location: WeatherLocation?
        if (fix != null) {
            estimated = false
            location = reverseGeocode(fix.first, fix.second)
        } else {
            // 实时定位拿不到才估算；结果由界面标注为「估算」。
            estimated = true
            location = networkGeocode()
        }

        if (location == null) {
            return DeviceLocationOutcome.failure(
                if (fix == null) DeviceLocationFailure.TIMEOUT else DeviceLocationFailure.ADDRESS_UNAVAILABLE,
            )
        }
        return DeviceLocationOutcome.success(location, estimated)
    }

    private fun hasPermission(): Boolean {
        val fine = context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION)
        val coarse = context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        return fine == PackageManager.PERMISSION_GRANTED || coarse == PackageManager.PERMISSION_GRANTED
    }

    private fun isLocationEnabled(manager: LocationManager): Boolean =
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                manager.isLocationEnabled
            } else {
                manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ||
                    manager.isProviderEnabled(LocationManager.GPS_PROVIDER)
            }
        } catch (_: Exception) {
            false
        }

    /** 网络优先、其次 GPS；先看缓存，再单次请求（总预算 [FIX_TIMEOUT_MS]）。 */
    private fun currentFix(manager: LocationManager): Pair<Double, Double>? {
        val providers = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
        for (provider in providers) {
            val last = lastKnown(manager, provider)
            if (last != null) return last.first to last.second
        }
        for (provider in providers) {
            val oneShot = requestSingle(manager, provider)
            if (oneShot != null) return oneShot.first to oneShot.second
        }
        return null
    }

    private fun lastKnown(manager: LocationManager, provider: String): Pair<Double, Double>? =
        try {
            val location: Location? = manager.getLastKnownLocation(provider)
            if (location == null) null else location.latitude to location.longitude
        } catch (_: SecurityException) {
            null
        } catch (_: Exception) {
            null
        }

    @Suppress("MissingPermission")
    private fun requestSingle(manager: LocationManager, provider: String): Pair<Double, Double>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        val latch = CountDownLatch(1)
        var result: Location? = null
        return try {
            manager.getCurrentLocation(
                provider,
                null,
                context.mainExecutor,
            ) { location ->
                result = location
                latch.countDown()
            }
            latch.await(FIX_TIMEOUT_MS, TimeUnit.MILLISECONDS)
            result?.let { it.latitude to it.longitude }
        } catch (_: SecurityException) {
            null
        } catch (_: Exception) {
            null
        }
    }
}
