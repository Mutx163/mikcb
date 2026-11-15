package com.mutx163.qingyu.pages.timetable

/**
 * 课卡「天气那一行」的三态。
 *
 * 2026-11-15 用户口径：打开软件先什么都没有、天气要等一会儿才出来，那一行在等待期间
 * 不该是空白，应该给一个**极小**的转圈；拿到数据就换成文字，失败或天气本身没开就
 * 什么都不画。三态只由两个入参决定，判定抽成纯函数（本文件在 main 源集、无 Compose
 * 依赖），周卡与日卡共用一个判据，JVM 单测钉住。
 */
enum class WeatherCardSlotState {
    /** 有天气文字：照旧画文字（`wet · 23° · 60%` 那一行）。 */
    TEXT,

    /** 没文字、但正在取数：画小圈（`QingyuLoadingSlot.WeatherCard`，10dp / 1.5dp）。 */
    LOADING,

    /**
     * 没文字、也没在取数：整行不画。
     *
     * 包含三种情况：天气开关关着、还没选城市、以及**取数失败**（失败不画圈——
     * 一直转的圈会被读成"还在加载"，比空白更误导；失败在设置页天气卡上说明）。
     */
    HIDDEN,
}

/**
 * 判定课卡天气那一行该画什么。
 *
 * @param weatherText 该节课的天气文字（`provider.summaryForCourse(...)` 格式化后的结果）；
 *   null 或全空白都算「没有」。
 * @param isLoading 取数器是否正在取数（页面只认 `WeatherProvider.isLoadingWeather`，
 *   不碰 provider 内部；见导入官的接口契约）。
 */
fun weatherCardSlotState(weatherText: String?, isLoading: Boolean): WeatherCardSlotState = when {
    !weatherText.isNullOrBlank() -> WeatherCardSlotState.TEXT
    isLoading -> WeatherCardSlotState.LOADING
    else -> WeatherCardSlotState.HIDDEN
}
