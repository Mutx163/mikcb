package com.mutx163.qingyu

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * 全部桌面卡片的公共基类。
 *
 * 10 个 Provider 的 onUpdate / onAppWidgetOptionsChanged / onReceive /
 * onDeleted 逻辑完全同构，只有布局与渲染参数不同——下沉到基类后子类只覆写
 * [renderWidget]，并声明自身类型供按类查询 widget id。
 *
 * onDeleted 统一清理 per-widget 绑定档案与专属快照（home_widget_prefs 里的
 * widget_binding_* / widget_snapshot_* key），此前 Stats 系 3 个与
 * ExamCountdown 缺 onDeleted 覆盖，卡片删除后 key 永久残留。
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

    /** 子类唯一的差异点：渲染单张卡片。 */
    protected abstract fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
    )

    /** 查询本组件当前所有 widget id 并逐张重绘。 */
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, providerClass()))
        ids.forEach { appWidgetId ->
            renderWidget(context, manager, appWidgetId)
        }
    }
}
