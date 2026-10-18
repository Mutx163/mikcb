package com.mutx163.qingyu

/**
 * 十个卡型「widgetType 字符串 ↔ Provider 类」的唯一映射表。
 *
 * 这张表有三个消费方，此前各写了一份 `when`：
 *
 * 1. 应用内「添加到桌面」——请求 pin 时要拿到 [android.content.ComponentName]；
 * 2. 「各卡片绑定管理」——列出桌面上已存在的今日课程卡片（只认今日课程系 6 种）；
 * 3. 设置页「效果预览」——按卡型实例化 Provider 出图。
 *
 * 三份各写一遍的话，新增卡型时必然漏改其中一处，而且症状很隐蔽：
 * 漏在 1 是「按钮点了没反应」，漏在 2 是「绑定列表里看不到这张卡」，
 * 漏在 3 是「能添加但预览不出来」。合并到这里后只改一处。
 *
 * 顺序有意义：[todaySeries] 的先后就是绑定列表与预览轮播里的呈现顺序。
 */
internal object WidgetProviderCatalog {

    /** 今日课程系 6 种：只有这几种支持「每张卡片单独绑定某个课表」。 */
    val todaySeries: List<Pair<String, Class<out BaseQingyuWidgetProvider>>> = listOf(
        "compact" to TodayCompactWidgetProvider::class.java,
        "mini_list" to TodayMiniListWidgetProvider::class.java,
        "medium" to TodayMediumWidgetProvider::class.java,
        "large" to TodayLargeWidgetProvider::class.java,
        "today_strip" to TodayStripWidgetProvider::class.java,
        "today_wide" to TodayWideWidgetProvider::class.java,
    )

    /** 统计与考试卡：数据源独立，不支持逐卡绑定课表。 */
    private val statsSeries: List<Pair<String, Class<out BaseQingyuWidgetProvider>>> = listOf(
        "stats_compact" to StatsCompactWidgetProvider::class.java,
        "stats_medium" to StatsMediumWidgetProvider::class.java,
        "stats_strip" to StatsStripWidgetProvider::class.java,
        "exam_card" to ExamCountdownWidgetProvider::class.java,
    )

    val all: List<Pair<String, Class<out BaseQingyuWidgetProvider>>> =
        todaySeries + statsSeries

    fun providerClass(widgetType: String): Class<out BaseQingyuWidgetProvider>? =
        all.firstOrNull { it.first == widgetType }?.second

    /**
     * 按卡型实例化一个 Provider，只用于调用 [BaseQingyuWidgetProvider.buildPreviewRemoteViews]。
     *
     * 走反射而不是再写一遍 `when`：映射已经在本文件的 [all] 里，再写一遍就又是两份真相。
     * 释放构建未开启 `minifyEnabled`（`android/app/build.gradle` 的 `release {}` 里没有），
     * 公开类的无参构造不会被裁掉；万一将来开启，[runCatching] 会退化成「预览暂不可用」
     * 而不是崩溃。
     */
    fun create(widgetType: String): BaseQingyuWidgetProvider? {
        val providerClass = providerClass(widgetType) ?: return null
        return runCatching {
            providerClass.getDeclaredConstructor().newInstance()
        }.getOrNull()
    }
}
