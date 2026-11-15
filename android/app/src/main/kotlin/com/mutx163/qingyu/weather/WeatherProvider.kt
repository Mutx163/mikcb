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

    /** 最近一次取数失败的分类（成功取数后清空）；界面与诊断页据此说清「为什么没有」。 */
    var lastFetchFailure: WeatherFetchFailure? = null
        private set

    /** 最近一次取数用的数据源（`open-meteo` / `met.no`；还没取过为 null）。 */
    var lastFetchSource: String? = null
        private set

    /** 最近一次失败时的 HTTP 状态码（只有非 200 才有；网络/解析失败为 null）。 */
    var lastFetchHttpStatus: Int? = null
        private set

    /**
     * 「天气开着、城市也有，但这次没拿到数据」——首页据此显示一行可读失败状态，
     * 而不是整块空白（2026-11-14：老板问「首页为什么什么都不显示」）。
     */
    val weatherUnavailable: Boolean
        get() = enabled && location != null && forecast == null && state == WeatherState.FAILED

    /** 状态变化监听（Compose 宿主用它在变化后触发重组）；可挂多个。 */
    private val listeners = ArrayList<() -> Unit>()

    fun addListener(listener: () -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: () -> Unit) {
        listeners.remove(listener)
    }

    private var initialized = false
    /** [loadCached] 是否已跑过（网络刷新开关与「本地已读」是两件事）。 */
    private var loaded = false
    private var nextRetryNotBefore: LocalDateTime? = null
    private var refreshing = false

    /**
     * 本进程是否还没跑过第一次取数（冷启动重试用）。
     *
     * 只在**第一次**取数且失败分类是 NETWORK / TIMEOUT 时重试一次：进程刚起时网络
     * （Wi-Fi 关联 / DNS / TLS）可能尚未就绪，这一次失败不代表服务不可用；用户手动
     * 重试时网络已好，所以「点重试就好」不是错觉。HTTP 4xx / 解析失败不重试
     * （确定性失败，重试只会再错一次），也不进退避之外的额外状态。
     */
    private var firstFetchInProcess = true

    /**
     * 「这一格该有天气、但数据还没到手」——三处显示面据此预留等高空位（防闪动）。
     * 四个前提缺一不可，且刻意不含「已初始化」（初始化前 enabled 还是默认关）。
     */
    val isAwaitingData: Boolean
        get() = enabled && location != null && forecast == null && state != WeatherState.FAILED

    /**
     * 「正在取数」——页面据此画加载小圈（2026-11-15 用户要求：课卡上给一个很小的圈）。
     *
     * 与 [isAwaitingData] 的区别：本判据只在 `LOADING` 为真；失败后为 false（由
     * [weatherUnavailable] 表达）。天气关着 / 没城市 / 已有数据也都为 false。
     */
    val isLoadingWeather: Boolean
        get() = enabled && location != null && forecast == null && state == WeatherState.LOADING

    /** 读本地配置进内存，然后补一次「过期就刷」。幂等。 */
    fun initialize() {
        // 先同步读盘（冷启动首帧前会先单独调一次 [loadCached]），再补网。
        loadCached()
        if (initialized) return
        initialized = true
        ensureFresh()
    }

    /**
     * **只读本地配置与上次的预报**进内存：同步、不发网、可重复调用。
     *
     * 冷启动时在首帧前调用一次（`ShellWiring` 构造）：日卡 / 周卡的天气行按
     * [forecast] 现算，缓存命中时首帧就带着天气，不会再出现「卡片先画好、过一会儿
     * 突然多出一行天气」的跳变。没有缓存时 [isAwaitingData] 立刻为真，界面据此
     * 先占住那一行的高度。
     *
     * 网络刷新仍然只走 [initialize] / [ensureFresh]（本方法一行网络代码都没有）。
     */
    fun loadCached() {
        if (loaded) return
        loaded = true
        enabled = preferences.isEnabled()
        // 与出网/落盘同一精度：缓存按取整坐标存，读回也取整，否则换城判定会被取整误差骗。
        location = preferences.loadLocation()?.coarsened()
        val cached = preferences.loadForecast()
        val current = location
        forecast = if (cached != null && current != null && cached.matchesLocation(current)) cached else null
        notifyChanged()
    }

    /** 过期就刷新。[force] 跳过 TTL 判定（设置页「重试」用）。 */
    fun ensureFresh(force: Boolean = false) {
        if (refreshing) return
        if (!force && !shouldRefresh()) return
        if (location == null) return
        refresh()
    }

    /** 手动重试：清掉退避并忽略 TTL，立刻拉一次（取数日志由 WeatherService 统一写）。 */
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
            val coldStart = firstFetchInProcess
            firstFetchInProcess = false
            // 带诊断的取数：失败分类写进应用日志（诊断页可见）。
            var result = service.fetchForecastWithDiagnostics(requested)
            val firstFailure = result.diagnostics.failure
            if (coldStart &&
                result.forecast == null &&
                (firstFailure == WeatherFetchFailure.NETWORK ||
                    firstFailure == WeatherFetchFailure.TIMEOUT)
            ) {
                // 冷启动第一次失败（网络/超时）→ 同一次调用内立刻再试一次，每次启动最多一次。
                // 不 sleep、不占后台协程：调用方本来就在 IO 线程上，第二次请求用的是同一份配置。
                val retried = service.fetchForecastWithDiagnostics(requested)
                result = if (retried.forecast != null) {
                    retried
                } else {
                    retried.copy(
                        diagnostics = retried.diagnostics.copy(
                            detail = listOfNotNull(
                                "coldStartFirst=${firstFailure.name.lowercase()}",
                                retried.diagnostics.detail,
                            ).joinToString(separator = "; "),
                        ),
                    )
                }
            }
            val fetched = result.forecast
            val selected = location
            if (selected != null && !requested.isSamePlaceAs(selected)) {
                // 等响应时用户换了城市：旧城市预报既不能进内存也不能落盘。就地按新城市重发。
                refreshing = false
                refresh()
                return
            }
            lastFetchSource = result.diagnostics.source
            if (fetched == null) {
                state = WeatherState.FAILED
                nextRetryNotBefore = clock().plus(failureRetryDelay)
                // 失败原因已由 WeatherService 按统一字段写进应用日志（NetLog）；
                // 这里只留状态给界面/诊断页读。
                lastFetchFailure = result.diagnostics.failure ?: WeatherFetchFailure.UNKNOWN
                lastFetchHttpStatus = result.diagnostics.httpStatus
            } else {
                forecast = fetched
                state = WeatherState.READY
                nextRetryNotBefore = null
                lastFetchFailure = null
                lastFetchHttpStatus = null
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
