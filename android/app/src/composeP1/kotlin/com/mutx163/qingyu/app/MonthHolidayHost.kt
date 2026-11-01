package com.mutx163.qingyu.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayProvider
import com.mutx163.qingyu.pages.timetable.month.MonthHolidaySettings
import com.mutx163.qingyu.pages.timetable.month.initializeMonthHolidayData
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * 月视图节假日数据的**可观察状态**。
 *
 * 只读消费：壳把 [holidayData] / [overrideEnabled] / [markingEnabled] 三个值
 * 原样传给 `MonthViewHost`。写入只发生在 [rememberMonthHolidayState] 的后台
 * effect 与 provider 的监听回调里。
 */
@Stable
class MonthHolidayState internal constructor() {

    /**
     * 官方 + 自定义合并后的年度数据（[HolidayProvider.mergedData] 口径）。
     *
     * `null` = 没有数据：月视图按「无假期」渲染，不崩、不伪造空数据。
     */
    var holidayData: HolidayData? by mutableStateOf(null)
        private set

    /** 设置存档里的 `holidayOverrideEnabled`（缺键 / 坏值 = false）。 */
    var overrideEnabled: Boolean by mutableStateOf(false)
        private set

    /** 设置存档里的 `enableHolidayMarking`（缺键 / 坏值 = true）。 */
    var markingEnabled: Boolean by mutableStateOf(true)
        private set

    internal fun applySettings(settings: MonthHolidaySettings) {
        overrideEnabled = settings.overrideEnabled
        markingEnabled = settings.markingEnabled
    }

    internal fun applyData(data: HolidayData?) {
        holidayData = data
    }
}

/**
 * 月视图假期数据的薄宿主：后台初始化 provider、订阅它的变化、顺带读两个真实设置。
 *
 * ## 用法（壳侧，`ShellPageIndex` 的 `"c2.month"` 分支）
 *
 * ```
 * val holidayState = rememberMonthHolidayState(wiring.holiday)
 * MonthViewHost(
 *     …,
 *     holidayData = holidayState.holidayData,
 *     holidayOverrideEnabled = holidayState.overrideEnabled,
 *     holidayMarkingEnabled = holidayState.markingEnabled,
 * )
 * ```
 *
 * ## 线程与失败语义
 *
 * - [HolidayProvider.initialize] 同步阻塞（读盘 / 取网 / 写盘），所以放在
 *   `Dispatchers.IO`；设置 JSON 的读盘也一并挪过去，主线程不碰存储。
 * - 初始化失败**不外抛**：[initializeMonthHolidayData] 收敛成 null（或保留旧值），
 *   月视图得到空态而不是崩溃。
 * - [HolidayProvider.initialize] 幂等：设置页已经加载过时这里只是命中内存 / 本地缓存，
 *   不会多发一次网络请求。
 * - provider 的监听保证「用户在设置页改了自定义假期 / 检查了更新」后，
 *   月视图拿到的是新数据（自定义假期已并进 [MonthHolidayState.holidayData]）。
 *
 * @param provider 与设置页、桌面小组件共用的那一份 `HolidayProvider`（壳里是 `wiring.holiday`）。
 */
@Composable
fun rememberMonthHolidayState(provider: HolidayProvider): MonthHolidayState {
    val context = LocalContext.current
    // 与 `LiveSelfCheckHost` 同形：宿主自己用应用上下文开一份只读的设置存储。
    // `ShellWiring.timetableStore` 是 private，壳侧没有可传的实例。
    val store = remember(context) { TimetableStore(PrefsKeyValueStore(context)) }
    return rememberMonthHolidayState(provider, store)
}

/**
 * 可注入 [store] 的重载（测试 / 将来的正式包宿主用；壳只调上面那个）。
 */
@Composable
internal fun rememberMonthHolidayState(
    provider: HolidayProvider,
    store: TimetableStore,
): MonthHolidayState {
    val state = remember(provider, store) { MonthHolidayState() }

    LaunchedEffect(provider, store) {
        val settings = withContext(Dispatchers.IO) {
            runCatching { MonthHolidaySettings.fromSettingsJson(store.loadSettingsJson()) }
                .getOrDefault(MonthHolidaySettings())
        }
        state.applySettings(settings)

        val fallback = state.holidayData
        val data = withContext(Dispatchers.IO) {
            initializeMonthHolidayData(provider, fallback = fallback)
        }
        state.applyData(data)
    }

    // 订阅 provider：设置页改了自定义假期 / 点了「检查更新」后，月视图跟着换数据。
    DisposableEffect(provider) {
        val listener: () -> Unit = { state.applyData(provider.mergedData()) }
        provider.addListener(listener)
        onDispose { provider.removeListener(listener) }
    }

    return state
}
