package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
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

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
            updateAll(context)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        // 卡片被移除时清掉绑定档案与专属快照，防止孤儿数据越积越多。
        appWidgetIds.forEach { appWidgetId ->
            WidgetBindingStore.remove(context, appWidgetId)
            HomeWidgetStorage.clearWidgetSnapshot(context, appWidgetId)
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
}
