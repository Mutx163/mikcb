package com.mutx163.qingyu.pages.timetable.month

import com.mutx163.qingyu.calendar.HolidayData
import com.mutx163.qingyu.calendar.HolidayProvider

/**
 * 后台初始化节假日数据，并把结果收敛成「要么有数据、要么 null」。
 *
 * ## 为什么要这层壳
 *
 * [HolidayProvider.initialize] 是**同步阻塞**的（读盘 / 取网 / 写盘，
 * 见其 KDoc 的「为什么是同步阻塞的」），调用方必须放进 `Dispatchers.IO`。
 * 同时它是「非关键数据」：网络挂了应该退到内置资产，内置资产也没有就是
 * 空数据，**任何失败都不该把月视图拖崩**。provider 自己已经保证了取网失败
 * 不外抛，这里再兜一层 `Exception`，覆盖的是「注入的网关 / 存储实现违约」
 * 这类不在 provider 承诺内的失败。
 *
 * ## 返回值的语义
 *
 * - 非 null：官方数据 + 用户自定义假期（[HolidayProvider.mergedData] 的口径，
 *   月网格按天判定假期需要的正是这一份）；
 * - null：没有数据。**这是合法的空态**，月视图据此不标假期、不标补班，
 *   与「本月没有假期」视觉一致；不会伪造一条空 [HolidayData]。
 * - [fallback]：本次初始化失败时保留调用方手里已有的数据，避免「刷新失败
 *   把已经画出来的假期底色清掉」。
 *
 * @param provider 节假日状态机（壳里是 `wiring.holiday` 那一份实例）。
 * @param fallback 本次失败时的回落值（通常是宿主上一帧已经拿到的数据）。
 */
fun initializeMonthHolidayData(
    provider: HolidayProvider,
    fallback: HolidayData? = null,
): HolidayData? {
    try {
        provider.initialize()
    } catch (_: Exception) {
        // 节假日是装饰性信息，失败落空态（或保留旧值），不向上抛。
    }
    return provider.mergedData() ?: fallback
}
