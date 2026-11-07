package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import android.widget.RemoteViews

/**
 * 全部桌面卡片的公共基类。
 *
 * 10 个 Provider 的 onUpdate / onAppWidgetOptionsChanged / onReceive /
 * onDeleted 逻辑完全同构，只有布局与渲染参数不同——下沉到基类后子类只覆写
 * [buildRemoteViews]，并声明自身类型供按类查询 widget id。
 *
 * onDeleted 统一清理 per-widget 绑定档案与专属快照（home_widget_prefs 里的
 * widget_binding_* / widget_snapshot_* key），此前 Stats 系 3 个与
 * ExamCountdown 缺 onDeleted 覆盖，卡片删除后 key 永久残留。
 *
 * 2026-10 起「拼视图」与「交给系统」拆成两步：[buildRemoteViews] 只负责把
 * 当前数据 + 当前外观设置拼成 RemoteViews，[renderWidget] 才是真正下发。
 * 设置页的「效果预览」直接复用 [buildRemoteViews]（见 [buildPreviewRemoteViews]），
 * 因此预览与桌面卡片是同一份 layout + 同一段填充逻辑，预览不会走样；
 * 反过来改渲染也只改一处，两边同时生效。
 */
abstract class BaseQingyuWidgetProvider : AppWidgetProvider() {

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        renderWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            renderWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        // 首个实例启用（首次加卡）：必达来源，强制重排一次。
        HomeWidgetStorage.rescheduleRefresh(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        // super 会把 APPWIDGET_UPDATE 分发到 onUpdate —— 但**只有 EXTRA_APPWIDGET_IDS 非空时**
        // 才会按 id 逐个派发，空 ids / 部分 ids 的广播进不去 onUpdate（刚加的卡会短暂空白）。
        super.onReceive(context, intent)
        if (intent.action != AppWidgetManager.ACTION_APPWIDGET_UPDATE) return
        // 一次取快照：本类 ids、全 app 并集、重排都用它（一次广播只查 10 次，不再 ~130 次）。
        val widgetIds = HomeWidgetStorage.collectWidgetIds(context)
        val classAllIds = widgetIds[providerClass()] ?: intArrayOf()
        val intentIds = intent.getIntArrayExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS)
        // 渲染兜底（只在「空 ids / 部分 ids」这个回落分支里做，不是无条件调用）：
        // 空 ids 或只含部分 ids 时补一次本类全量刷新。
        if (intentIds == null || intentIds.isEmpty() || intentIds.size < classAllIds.size) {
            updateAll(context)
        }
        // 重排去重：加卡（全量 ids 里出现新 id）必须必达 —— 判据是「集合内容」不是数量。
        if (broadcastDedupe.shouldHandle(
                SystemClock.elapsedRealtime(),
                HomeWidgetStorage.allWidgetIds(widgetIds),
            )
        ) {
            HomeWidgetStorage.rescheduleRefresh(context, widgetIds)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        // 卡片被移除时清掉绑定档案与专属快照，防止孤儿数据越积越多。
        appWidgetIds.forEach { appWidgetId ->
            WidgetBindingStore.remove(context, appWidgetId)
            HomeWidgetStorage.clearWidgetSnapshot(context, appWidgetId)
        }
        // 删掉 A 卡但 B 卡还在时，刷新点必须按剩余实例重算（否则 A 的时间点还在调度）。
        HomeWidgetStorage.rescheduleRefresh(context)
    }

    /**
     * 桌面上本类型的**最后一个小部件**被移除时系统会回调这里。
     *
     * 与 [HomeWidgetStorage.rescheduleRefresh] 的零实例门用同一判据
     * （[WidgetRefreshGate.shouldSchedule]）：**只有全部 Provider 都无实例时才
     * 取消刷新闹钟**，避免「删了 A 卡、B 卡还在」时误停。
     *
     * 原先没有这个覆写，删光卡片后 `updatePeriodMillis=0` 的自定义 alarm 照跑 ——
     * 用户报的「桌面上 0 个小部件、却每分钟 RTC_WAKEUP 唤醒整机」正是这条缺失。
     */
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        if (!WidgetRefreshGate.shouldSchedule(HomeWidgetStorage.widgetInstanceCounts(context))) {
            // 桌面 0 个小部件：精确闹钟 + WorkManager 兜底一起停。
            HomeWidgetStorage.cancelRefreshAlarm(context)
            WidgetRefreshWorker.cancel(context)
        }
    }

    /** 子类声明自身组件，供按类查询已添加的 widget id。 */
    protected abstract fun providerClass(): Class<out BaseQingyuWidgetProvider>

    /**
     * 子类唯一的差异点：把「当前数据 + 当前外观设置」拼成一张卡片的 RemoteViews。
     *
     * 只构建、不下发。尺寸档位仍由 [TodayWidgetSupport.sizeProfile] 决定，
     * 真实下发时它读启动器回报的格位尺寸；预览时由 [WidgetPreviewSession] 覆盖。
     */
    protected abstract fun buildRemoteViews(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ): RemoteViews

    /** 下发到桌面：构建一次，交给系统。 */
    protected open fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, buildRemoteViews(context, appWidgetManager, appWidgetId))
    }

    /**
     * 设置页预览专用：只构建、不下发。
     *
     * 预览没有真实的 appWidgetId，也不应该污染任何一张桌面卡片的 state，
     * 所以用量尺寸与明暗都由调用方显式给定（走 [WidgetPreviewSession]），
     * appWidgetId 固定为 [WidgetPreviewSession.PREVIEW_APP_WIDGET_ID]——
     * 该 id 不会命中绑定档案，读取快照时自然回落到「跟随当前课表」。
     */
    fun buildPreviewRemoteViews(
        context: Context,
        widthDp: Int,
        heightDp: Int,
        nightMode: Boolean,
    ): RemoteViews = WidgetPreviewSession.run(widthDp, heightDp, nightMode) {
        buildRemoteViews(
            context,
            AppWidgetManager.getInstance(context),
            WidgetPreviewSession.PREVIEW_APP_WIDGET_ID,
        )
    }

    /** 查询本组件当前所有 widget id 并逐张重绘。 */
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, providerClass()))
        ids.forEach { appWidgetId ->
            renderWidget(context, manager, appWidgetId)
        }
    }

    companion object {
        /** 同一次系统广播会被 10 个 Provider 各收一遍：短窗口内只让第一个处理。 */
        private val broadcastDedupe = BroadcastDedupe(windowMillis = 200L)
    }
}
