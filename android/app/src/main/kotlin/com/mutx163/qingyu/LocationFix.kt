package com.mutx163.qingyu

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs

/**
 * 一次性取当前坐标（网络优先）。
 *
 * 这个文件存在的**全部理由**：`geolocator_android` 在没有可用 Google Play Services 的
 * 设备上会回退到系统 LocationManager，而它的 `LocationManagerClient.determineProvider`
 * 除「最低精度」外**优先 GPS_PROVIDER**（fused → GPS → NETWORK），室内冷启动永远等不到
 * 定位、只能超时；插件也没提供选择 provider 的 API，所以调它的精度参数是没用的。
 * 这里直接问系统、**两个 provider 都注册**，拿到第一份够用的就收工。
 *
 * 取舍照抄 zhishengplus/ZhishengWeather 的 `LocationSource`（MIT）：
 *  · 只用系统 LocationManager / 不引入 Google Play 服务；
 *  · 网络优先（天气按区级算，网络定位出结果最快、室内也能用）；
 *  · **总预算**十几秒，而不是把多个长超时串起来；
 *  · 预算耗尽时交回本轮拿到的最好结果，而不是直接失败；
 *  · 系统缓存只在实时定位全拿不到时兜底（避免换城市后仍停在旧定位）；
 *  · 精度差过阈值的坐标不交回，宁可让上层如实报错也不拿它反查城市。
 *
 * 权限申请仍由 Dart 侧的 geolocator 负责（那部分真机验证过是好的），这里只消费权限。
 * 低层工具函数放在文件级私有——嵌套类访问外层 object 的私有成员在 Kotlin 里不可靠。
 */
object LocationFix {

    const val CHANNEL = "com.mutx163.qingyu/location"

    fun handle(call: MethodCall, context: Context, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentPosition" -> getCurrentPosition(call, context, result)
            else -> result.notImplemented()
        }
    }

    /**
     * 返回 `{latitude, longitude, accuracy, source, ageMs}`；拿不到可用坐标时返回 null。
     *
     * **不用 channel error 表示「没拿到」**——那属于正常结果，Dart 侧要照常往下走
     * （系统缓存 → IP 估算）。异常留给真正的失败，Dart 侧对异常有回退路径。
     */
    private fun getCurrentPosition(
        call: MethodCall,
        context: Context,
        result: MethodChannel.Result,
    ) {
        if (!hasLocationPermission(context)) {
            // Dart 侧会先问权限，正常走不到这里；真到了也只是没坐标。
            result.success(null)
            return
        }
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (manager == null || !isLocationEnabled(manager)) {
            result.success(null)
            return
        }

        // 预算夹在 1~60 秒：太短来不及出结果，太长不该让用户盯着转圈。
        val budgetMs = (call.argument<Number>("budgetMs")?.toLong() ?: DEFAULT_BUDGET_MS)
            .coerceIn(1_000L, 60_000L)

        val providers = PROVIDER_PRIORITY.filter { isProviderEnabled(manager, it) }
        if (providers.isEmpty()) {
            // 没有可用的 provider：只能看缓存。
            result.success(cachedFix(manager)?.let { toMap(it, SOURCE_CACHE) })
            return
        }

        OneShotRequest(manager, budgetMs, result).start(providers)
    }
}

/** 精度好到这个程度就提前收工。天气按区级算，两公里以内绰绰有余。 */
private const val GOOD_ENOUGH_ACCURACY_M = 2000f

/** 差过这个精度的坐标不拿去反查城市：城市边界上网络定位可能反查出隔壁城市。 */
private const val USABLE_ACCURACY_M = 20000f

/** 兜底缓存的可接受年龄。缓存是兜底而非首选，所以范围收得比实时定位严。 */
private const val CACHE_MAX_AGE_MS = 15 * 60_000L

private const val DEFAULT_BUDGET_MS = 12_000L

private const val SOURCE_CACHE = "cache"
private const val SOURCE_UNKNOWN = "unknown"

/**
 * provider 注册顺序：网络在前（出结果最快），GPS 在后补精度。
 * **两个都会注册**——只等网络会让「只有 GPS 可用」的地方失败。
 */
private val PROVIDER_PRIORITY = listOf(
    LocationManager.NETWORK_PROVIDER,
    LocationManager.GPS_PROVIDER,
)

private fun hasLocationPermission(context: Context): Boolean =
    context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED ||
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
        PackageManager.PERMISSION_GRANTED

private fun isLocationEnabled(manager: LocationManager): Boolean = try {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        manager.isLocationEnabled
    } else {
        manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ||
            manager.isProviderEnabled(LocationManager.GPS_PROVIDER)
    }
} catch (_: Exception) {
    false
}

private fun isProviderEnabled(manager: LocationManager, provider: String): Boolean =
    runCatching { manager.isProviderEnabled(provider) }.getOrDefault(false)

/**
 * 系统缓存里最新且够新的一份位置；没有则为 null。
 *
 * 用 `abs` 容忍时钟轻微前跳，只判年龄上限：缓存只是兜底，宁可不用也不要拿一个
 * 几小时前、可能已经在别的城市的坐标。
 */
private fun cachedFix(manager: LocationManager): Location? {
    var best: Location? = null
    val providers = runCatching { manager.getProviders(true) }.getOrDefault(emptyList())
    for (provider in providers) {
        val location = runCatching { manager.getLastKnownLocation(provider) }.getOrNull()
            ?: continue
        if (abs(System.currentTimeMillis() - location.time) > CACHE_MAX_AGE_MS) {
            continue
        }
        if (isBetter(location, best)) {
            best = location
        }
    }
    return best
}

private fun toMap(location: Location, source: String): Map<String, Any?> = mapOf(
    "latitude" to location.latitude,
    "longitude" to location.longitude,
    "accuracy" to if (location.hasAccuracy()) location.accuracy.toDouble() else null,
    "source" to source,
    "ageMs" to (System.currentTimeMillis() - location.time),
)

private fun accuracyOf(location: Location): Float =
    if (location.hasAccuracy()) location.accuracy else Float.MAX_VALUE

private fun isUsable(location: Location): Boolean =
    accuracyOf(location) <= USABLE_ACCURACY_M

/** 更准的优先；精度相同取更新的。 */
private fun isBetter(candidate: Location, current: Location?): Boolean {
    if (current == null) {
        return true
    }
    val candidateAccuracy = accuracyOf(candidate)
    val currentAccuracy = accuracyOf(current)
    if (candidateAccuracy != currentAccuracy) {
        return candidateAccuracy < currentAccuracy
    }
    return candidate.time > current.time
}

/** 一次请求的生命周期：注册 → 等够用/等预算 → settle 一次 → 注销。 */
private class OneShotRequest(
    private val manager: LocationManager,
    private val budgetMs: Long,
    private val result: MethodChannel.Result,
) : LocationListener {

    private val handler = Handler(Looper.getMainLooper())
    private var best: Location? = null
    private var settled = false

    fun start(providers: List<String>) {
        var registered = 0
        for (provider in providers) {
            val ok = runCatching {
                manager.requestLocationUpdates(
                    provider,
                    0L,
                    0f,
                    this,
                    Looper.getMainLooper(),
                )
            }.isSuccess
            if (ok) {
                registered++
            }
        }
        if (registered == 0) {
            settle(cachedFix(manager), SOURCE_CACHE)
            return
        }
        // 预算到期：本轮拿到的最好结果优先，其次才是系统缓存。
        handler.postDelayed({ onBudgetElapsed() }, budgetMs)
    }

    override fun onLocationChanged(location: Location) {
        if (settled) {
            return
        }
        if (isBetter(location, best)) {
            best = location
        }
        val current = best ?: return
        if (accuracyOf(current) <= GOOD_ENOUGH_ACCURACY_M) {
            settle(current, current.provider ?: SOURCE_UNKNOWN)
        }
    }

    private fun onBudgetElapsed() {
        val current = best
        if (current != null && isUsable(current)) {
            settle(current, current.provider ?: SOURCE_UNKNOWN)
        } else {
            settle(cachedFix(manager), SOURCE_CACHE)
        }
    }

    /** 唯一的出口：保证只回一次结果，并注销监听、撤掉定时器。 */
    private fun settle(location: Location?, source: String) {
        if (settled) {
            return
        }
        settled = true
        runCatching { manager.removeUpdates(this) }
        handler.removeCallbacksAndMessages(null)
        result.success(location?.let { toMap(it, source) })
    }
}
