package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 课卡天气行三态判定（2026-11-15）。
 *
 * 用户口径：打开软件先没天气，等一会儿才出来；等待期间那一行要「给一个很小的圈」，
 * 不是空白。三态只由「有没有文字」与「是不是正在取数」两个入参决定，周卡与日卡
 * 共用这一份判据 —— 本测试钉四组：有数据 / 加载中 / 失败 / 未开启。
 */
class WeatherCardSlotStateTest {

    @Test
    fun `有数据画文字`() {
        assertEquals(
            WeatherCardSlotState.TEXT,
            weatherCardSlotState("小雨 · 23° · 60%", isLoading = false),
        )
    }

    @Test
    fun `加载中画小圈`() {
        assertEquals(
            WeatherCardSlotState.LOADING,
            weatherCardSlotState(null, isLoading = true),
        )
    }

    @Test
    fun `失败画空白`() {
        // 取数失败：没有文字、也不再处于加载态 ⇒ 整行不画。
        // 不许画圈：一直转的圈会被读成「还在加载」，比空白更误导。
        assertEquals(
            WeatherCardSlotState.HIDDEN,
            weatherCardSlotState(null, isLoading = false),
        )
    }

    @Test
    fun `天气未开启画空白`() {
        // 天气开关关着 / 没选城市：宿主连 provider 都不给，页面拿到的就是 null + false。
        assertEquals(
            WeatherCardSlotState.HIDDEN,
            weatherCardSlotState(weatherText = null, isLoading = false),
        )
    }

    @Test
    fun `文字优先于加载态`() {
        // 上一轮的数据还在（或刚拿到）而 provider 又在刷新：照旧画文字，不要闪成圈。
        assertEquals(
            WeatherCardSlotState.TEXT,
            weatherCardSlotState("多云 · 18°", isLoading = true),
        )
    }

    @Test
    fun `空白字符串按没有文字处理`() {
        // 格式化结果给了空串 / 全空白：不能画一条空行，也不能让 hasAnyField 变真。
        assertEquals(
            WeatherCardSlotState.LOADING,
            weatherCardSlotState("   ", isLoading = true),
        )
        assertEquals(
            WeatherCardSlotState.HIDDEN,
            weatherCardSlotState("", isLoading = false),
        )
    }
}
