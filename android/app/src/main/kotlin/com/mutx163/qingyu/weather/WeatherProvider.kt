package com.mutx163.qingyu.weather

import java.time.Duration
import java.time.LocalDateTime

/**
 * Dart `lib/providers/weather_provider.dart` 的移植（天气状态：开关 / 城市 / 预报缓存 / 刷新策略）。
 *
 * 刻意**同步**实现（所有方法阻塞返回），原因与 [WeatherService] 相同：本目录要进 JVM 单测。
 * 真正的异步由界面层负责——Compose 宿主把调用放进 `Dispatchers.IO` 的协程里，测试注入
 * 假网关即时返回即可。这样 TTL / 失败退避 / 换城市作废 / 择时刷新的语义都可以在普通单测里钉死。
 *
 * 不变式（卡片只读内存，永远不等网络）：
 * - 构造不发请求；网络只在 [initialize] / [ensureFresh] 里发生；
 * - [summaryForCourse] 是纯读、无副作用；
 * - 失败**从不**抛：拿不到就 [forecast] 为 null，由调用方决定不渲染。
 */
enum class WeatherState { IDLE, LOADING, READY, FAILED }

/** 定位失败原因（每一条对应一句用户可见引导文案，见 `WeatherStrings.locationFailureMessage`）。 */
enum class DeviceLocationFailure {
    SERVICE_DISABLED,
    PERMISSION_DENIED,
    PERMISSION_DENIED_FOREVER,
    TIMEOUT,
    FAILED,
    ADDRESS_UNAVAILABLE,
}

/** 定位 + 反查的结果：坐标与失败原因必有一个为 null。 */
class DeviceLocationOutcome(
    val location: WeatherLocation?,
    val failure: DeviceLocationFailure?,
    /** true 表示按网络 IP 估算（界面必须如实标注）。 */
    val estimated: Boolean,
) {
    companion object {
        fun success(location: WeatherLocation, estimated: Boolean = false): DeviceLocationOutcome =
            DeviceLocationOutcome(location, null, estimated)

        fun failure(failure: DeviceLocationFailure): DeviceLocationOutcome =
            DeviceLocationOutcome(null, failure, false)
    }
}

/** 设备定位能力的接缝（真实实现见 `platform/` 的 Android 定位源）。 */
interface DeviceLocationSource {
    fun locate(): DeviceLocationOutcome
}

class WeatherProvider(
    private val service: WeatherGateway,
    private val preferences: WeatherPreferences,
    private val locationSource: DeviceLocationSource,
    private val clock: () -> LocalDateTime = { LocalDateTime.now() },
) {

    companion object {
        /** 预报保鲜期：3 小时内取值变化用户无感；单城市一天最多 8 次请求。 */
        val forecastTtl: Duration = Duration.ofHours(3)

        /** 失败后的退避：日视图一屏多卡，没有退避时服务器一挂就每次重建都撞一次。 */
        val failureRetryDelay: Duration = Duration.ofMinutes(15)
    }

    var enabled: Boolean = false
        private set

    var location: WeatherLocation? = null
        private set

    /** 当前内存里的预报（可能来自缓存、可能已过期）；没有则为 null。 */
    var forecast: WeatherForecast? = null
        private set

    var state: WeatherState = WeatherState.IDLE
        private set

    var isLocating: Boolean = false
        private set

    var lastLocateFailure: DeviceLocationFailure? = null
        private set

    var lastLocateWasEstimated: Boolean = false
        private set

    /** 状态变化监听（Compose 宿主用它在变化后触发重组）；可挂多个。 */
    private val listeners = ArrayList<() -> Unit>()

    fun addListener(listener: () -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: () -> Unit) {
        listeners.remove(listener)
    }

    private var initialized = false
    private var nextRetryNotBefore: LocalDateTime? = null
    private var refreshing = false

    /**
     * 「这一格该有天气、但数据还没到手」——三处显示面据此预留等高空位（防闪动）。
     * 四个前提缺一不可，且刻意不含「已初始化」（初始化前 enabled 还是默认关）。
     */
    val isAwaitingData: Boolean
        get() = enabled && location != null && forecast == null && state != WeatherState.FAILED

    /** 读本地配置进内存，然后补一次「过期就刷」。幂等。 */
    fun initialize() {
        if (initialized) return
        initialized = true
        enabled = preferences.isEnabled()
        // 与出网/落盘同一精度：缓存按取整坐标存，读回也取整，否则换城判定会被取整误差骗。
        location = preferences.loadLocation()?.coarsened()
        val cached = preferences.loadForecast()
        val current = location
        forecast = if (cached != null && current != null && cached.matchesLocation(current)) cached else null
        notifyChanged()
        ensureFresh()
    }

    /** 过期就刷新。[force] 跳过 TTL 判定（设置页「重试」用）。 */
    fun ensureFresh(force: Boolean = false) {
        if (refreshing) return
        if (!force && !shouldRefresh()) return
        if (location == null) return
        refresh()
    }

    /** 手动重试：清掉退避并忽略 TTL，立刻拉一次。 */
    fun retry() {
        nextRetryNotBefore = null
        ensureFresh(force = true)
    }

    /** 开关。打开时才补拉数据。 */
    fun setEnabled(enabled: Boolean) {
        if (this.enabled == enabled) return
        this.enabled = enabled
        nextRetryNotBefore = null
        notifyChanged()
        preferences.setEnabled(enabled)
        if (enabled) ensureFresh()
    }

    /** 选城市。换到不同地点时旧预报立即作废并落盘清除，随后重拉。 */
    fun setLocation(location: WeatherLocation) {
        val normalized = location.coarsened()
        val samePlace = this.location?.isSamePlaceAs(normalized) ?: false
        this.location = normalized
        nextRetryNotBefore = null
        if (!samePlace) {
            forecast = null
            state = WeatherState.IDLE
            preferences.clearForecast()
        }
        preferences.saveLocation(normalized)
        notifyChanged()
        ensureFresh()
    }

    /**
     * 搜索城市（直接转发给 service，界面不必自建第二个 HTTP 客户端）。
     *
     * `null` = 请求失败（界面据此显示「搜索失败」+ 重试）；空表 = 搜到了但没有匹配，
     * 两条语义不能合并，见 [WeatherGateway.searchLocations]。
     */
    fun searchLocations(query: String): List<WeatherLocation>? = service.searchLocations(query)

    /**
     * 一键定位：取当前位置 → 反查地名 → 作为天气城市。
     * 返回失败原因（成功为 null）。**失败时不动已有城市**。
     */
    fun locateCurrentPosition(): DeviceLocationFailure? {
        if (isLocating) return null
        isLocating = true
        lastLocateFailure = null
        notifyChanged()
        try {
            val outcome = locationSource.locate()
            val located = outcome.location
            if (located != null) {
                // 复用选城市那条路：落盘、作废旧缓存、重拉。
                setLocation(located)
            }
            lastLocateFailure = outcome.failure
            lastLocateWasEstimated = outcome.estimated
            return lastLocateFailure
        } finally {
            // 复位放 finally：中途落盘抛错也不能让入口永久置灰。
            isLocating = false
            notifyChanged()
        }
    }

    /** 这节课时段内的天气摘要；任何前提不满足都返回 null（调用方据此不渲染）。纯读。 */
    fun summaryForCourse(date: LocalDateTime, startTime: String, endTime: String): CourseWeatherSummary? {
        if (!enabled) return null
        val current = forecast ?: return null
        val start = combineDateAndTime(date, startTime) ?: return null
        val end = combineDateAndTime(date, endTime) ?: return null
        return summarizeCourseWeather(current, start, end)
    }

    // ---------- 内部 ----------

    private fun shouldRefresh(): Boolean {
        if (!enabled || location == null) return false
        val now = clock()
        val nextRetry = nextRetryNotBefore
        if (nextRetry != null && now.isBefore(nextRetry)) return false
        val current = forecast ?: return true
        if (!current.matchesLocation(location!!)) return true
        if (current.hasLapsedAt(now)) return true
        return Duration.between(current.fetchedAt, now) > forecastTtl
    }

    private fun refresh() {
        val requested = location ?: return
        refreshing = true
        state = WeatherState.LOADING
        notifyChanged()
        try {
            val fetched = service.fetchForecast(requested)
            val selected = location
            if (selected != null && !requested.isSamePlaceAs(selected)) {
                // 等响应时用户换了城市：旧城市预报既不能进内存也不能落盘。就地按新城市重发。
                refreshing = false
                refresh()
                return
            }
            if (fetched == null) {
                state = WeatherState.FAILED
                nextRetryNotBefore = clock().plus(failureRetryDelay)
            } else {
                forecast = fetched
                state = WeatherState.READY
                nextRetryNotBefore = null
                preferences.saveForecast(fetched)
            }
        } finally {
            refreshing = false
            notifyChanged()
        }
    }

    private fun notifyChanged() {
        for (listener in listeners.toList()) listener()
    }
}
