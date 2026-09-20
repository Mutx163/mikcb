package com.mutx163.qingyu

import android.Manifest
import android.app.Activity
import android.content.ContentProviderOperation
import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.CalendarContract
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

/**
 * 一键把课表日程写入系统日历（CalendarProvider）。
 *
 * 设计取舍：
 *  · **不加第三方插件**（device_calendar 等），按本仓惯例自写 MethodChannel；
 *    需要的原生面只有「查/建日历 + 清旧 + 批量插入」三步，引入一个插件的
 *    AndroidX 依赖面远大于收益。
 *  · **专属本地日历**：账户用本应用自定义的 [ACCOUNT_NAME]/[ACCOUNT_TYPE]，
 *    不与任何真实云账户绑定。好处：① 系统日历里一眼认出哪些日程来自本应用；
 *    ② 用户可在系统日历应用里整体隐藏/删除；③ 删除/插入走
 *    CALLER_IS_SYNCADAPTER URI，不会留下永远无法同步的 dirty 标记
 *    （本地账户没有 sync adapter，普通 URI 写入的 dirty 行会一直挂着）。
 *  · **幂等**：每次同步先清空该日历下全部日程再整批插入。重复点击、改课
 *    后重新同步都不会产生重复日程。清空范围限定在本应用账户名下——用户
 *    在系统日历里的其他账户日程不受影响。
 *  · ContentResolver 的读写全部放后台线程（参照 FrostedBlur 的
 *    Thread + 主线程回投模式），几条跨进程 Binder 调用不该卡主线程。
 *  · 权限：READ/WRITE_CALENDAR 是运行时权限。检查在这里做，弹窗申请必须
 *    有 Activity，所以 [handle] 收一个 Activity（MainActivity 注册时传 this）；
 *    申请结果经 [onRequestPermissionsResult] 由 MainActivity 转发回来。
 */
object CalendarSync {

    const val CHANNEL = "com.mutx163.qingyu/calendar_sync"

    /** 与 MainActivity 的通知权限码（1001）错开，见 onRequestPermissionsResult。 */
    const val PERMISSION_REQUEST_CODE = 1002

    private const val TAG = "CalendarSync"

    /**
     * 本应用专属日历的虚拟账户。名字保持稳定：账户一变，旧日历就成了
     * 孤儿（新同步找不到旧日历，用户端出现两份）。改这里的值 = 弃旧日历，
     * 需要同时给老版本留清理逻辑，别随手改。
     */
    private const val ACCOUNT_NAME = "timetable@qingyu.mutx163.local"
    private const val ACCOUNT_TYPE = "com.mutx163.qingyu.local"

    /** 日历列表里的颜色（不透明 ARGB，0xFF4C8BF5），无功能作用。 */
    private const val CALENDAR_COLOR = -0x00B3740B

    private val PERMISSIONS = arrayOf(
        Manifest.permission.READ_CALENDAR,
        Manifest.permission.WRITE_CALENDAR,
    )

    private var pendingPermissionResult: MethodChannel.Result? = null

    fun handle(
        call: MethodCall,
        activity: Activity?,
        context: Context,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "checkPermission" -> result.success(hasCalendarPermission(context))
            "requestPermission" -> {
                if (hasCalendarPermission(context)) {
                    result.success(true)
                    return
                }
                if (activity == null) {
                    // 没有前台 Activity 无法弹系统对话框，如实报未授权。
                    result.success(false)
                    return
                }
                pendingPermissionResult = result
                ActivityCompat.requestPermissions(
                    activity,
                    PERMISSIONS,
                    PERMISSION_REQUEST_CODE,
                )
            }
            "sync" -> {
                val calendarName = call.argument<String>("calendarName").orEmpty()
                @Suppress("UNCHECKED_CAST")
                val events = call.argument<List<Map<String, Any?>>>("events")
                    ?: emptyList()
                Thread {
                    try {
                        val count = syncInternal(context, calendarName, events)
                        runOnMain { result.success(count) }
                    } catch (e: SecurityException) {
                        Log.w(TAG, "sync denied", e)
                        runOnMain { result.error("PERMISSION_DENIED", e.message, null) }
                    } catch (e: Exception) {
                        Log.e(TAG, "sync failed", e)
                        runOnMain { result.error("SYNC_FAILED", e.message, null) }
                    }
                }.start()
            }
            "deleteCalendar" -> {
                // 整个专属日历连带其全部日程一起删；用户反悔可直接再点同步，
                // ensureLocalCalendar 会原样重建，不存在删了回不去的状态。
                Thread {
                    try {
                        val deleted = deleteLocalCalendar(context)
                        runOnMain { result.success(deleted) }
                    } catch (e: SecurityException) {
                        Log.w(TAG, "delete denied", e)
                        runOnMain { result.error("PERMISSION_DENIED", e.message, null) }
                    } catch (e: Exception) {
                        Log.e(TAG, "delete failed", e)
                        runOnMain { result.error("DELETE_FAILED", e.message, null) }
                    }
                }.start()
            }
            else -> result.notImplemented()
        }
    }

    /** MainActivity.onRequestPermissionsResult 转发入口。 */
    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ) {
        if (requestCode != PERMISSION_REQUEST_CODE) {
            return
        }
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    /** 读+写两个权限都拿到才算可用（清旧、写入都要 WRITE）。 */
    internal fun hasCalendarPermission(context: Context): Boolean =
        PERMISSIONS.all { permission ->
            ContextCompat.checkSelfPermission(context, permission) ==
                PackageManager.PERMISSION_GRANTED
        }

    private fun syncInternal(
        context: Context,
        calendarName: String,
        events: List<Map<String, Any?>>,
    ): Int {
        val resolver = context.contentResolver
        val calendarId = ensureLocalCalendar(resolver, calendarName)
        clearCalendarEvents(resolver, calendarId)
        if (events.isEmpty()) {
            return 0
        }
        val timezone = TimeZone.getDefault().id
        val insertUri = asSyncAdapter(CalendarContract.Events.CONTENT_URI)
        val operations = ArrayList<ContentProviderOperation>(events.size)
        for (event in events) {
            val startMs = (event["startMs"] as? Number)?.toLong()
            val endMs = (event["endMs"] as? Number)?.toLong()
            if (startMs == null || endMs == null || endMs <= startMs) {
                // 时间不合法的日程宁缺毋滥：一条坏数据不该让整批 applyBatch 失败。
                continue
            }
            operations.add(
                ContentProviderOperation.newInsert(insertUri)
                    .withValue(CalendarContract.Events.CALENDAR_ID, calendarId)
                    .withValue(CalendarContract.Events.TITLE, event["title"] ?: "")
                    .withValue(CalendarContract.Events.DTSTART, startMs)
                    .withValue(CalendarContract.Events.DTEND, endMs)
                    .withValue(CalendarContract.Events.EVENT_TIMEZONE, timezone)
                    .withValue(CalendarContract.Events.EVENT_LOCATION, event["location"])
                    .withValue(CalendarContract.Events.DESCRIPTION, event["description"])
                    .build()
            )
        }
        if (operations.isEmpty()) {
            return 0
        }
        val results = resolver.applyBatch(CalendarContract.AUTHORITY, operations)
        return results.size
    }

    /**
     * 找到本应用专属日历，没有就建；返回 _ID。
     * 每次同步顺带把显示名刷成最新传入值（课表改名后旧名字不至于残留）。
     */
    private fun ensureLocalCalendar(resolver: ContentResolver, displayName: String): Long {
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
        )
        val selection =
            "${CalendarContract.Calendars.ACCOUNT_NAME}=? AND " +
                "${CalendarContract.Calendars.ACCOUNT_TYPE}=?"
        resolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            arrayOf(ACCOUNT_NAME, ACCOUNT_TYPE),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                val id = cursor.getLong(0)
                val existingName = cursor.getString(1)
                if (!existingName.isNullOrEmpty() && existingName != displayName) {
                    updateDisplayName(resolver, id, displayName)
                }
                return id
            }
        }

        val values = ContentValues().apply {
            put(CalendarContract.Calendars.ACCOUNT_NAME, ACCOUNT_NAME)
            put(CalendarContract.Calendars.ACCOUNT_TYPE, ACCOUNT_TYPE)
            put(CalendarContract.Calendars.NAME, ACCOUNT_NAME)
            put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, displayName)
            put(CalendarContract.Calendars.CALENDAR_COLOR, CALENDAR_COLOR)
            put(
                CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
                CalendarContract.Calendars.CAL_ACCESS_OWNER,
            )
            put(CalendarContract.Calendars.OWNER_ACCOUNT, ACCOUNT_NAME)
            put(CalendarContract.Calendars.SYNC_EVENTS, 1)
            put(CalendarContract.Calendars.CALENDAR_TIME_ZONE, TimeZone.getDefault().id)
            put(CalendarContract.Calendars.VISIBLE, 1)
        }
        // Calendars 表只接受 sync-adapter 身份写入，普通 URI 直接插会抛
        // IllegalArgumentException（官方文档明确的限制）。
        val uri = resolver.insert(asSyncAdapter(CalendarContract.Calendars.CONTENT_URI), values)
            ?: throw IllegalStateException("calendar provider refused to create calendar")
        val calendarId = uri.lastPathSegment?.toLongOrNull()
        if (calendarId == null || calendarId <= 0L) {
            throw IllegalStateException("calendar provider returned invalid id: $uri")
        }
        return calendarId
    }

    private fun updateDisplayName(
        resolver: ContentResolver,
        calendarId: Long,
        displayName: String,
    ) {
        val values = ContentValues().apply {
            put(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, displayName)
        }
        resolver.update(
            asSyncAdapter(CalendarContract.Calendars.CONTENT_URI),
            values,
            "${CalendarContract.Calendars._ID}=?",
            arrayOf(calendarId.toString()),
        )
    }

    /** 清空本应用日历下的全部日程（含已取消/待同步的脏行）。 */
    private fun clearCalendarEvents(resolver: ContentResolver, calendarId: Long) {
        resolver.delete(
            asSyncAdapter(CalendarContract.Events.CONTENT_URI),
            "${CalendarContract.Events.CALENDAR_ID}=?",
            arrayOf(calendarId.toString()),
        )
    }

    /**
     * 删除本应用专属日历（连带全部日程）。返回是否真的删了——
     * 从未同步过（日历不存在）返回 false，Dart 侧据此提示「无已同步日程」。
     */
    private fun deleteLocalCalendar(context: Context): Boolean {
        val resolver = context.contentResolver
        val projection = arrayOf(CalendarContract.Calendars._ID)
        val selection =
            "${CalendarContract.Calendars.ACCOUNT_NAME}=? AND " +
                "${CalendarContract.Calendars.ACCOUNT_TYPE}=?"
        val calendarId = resolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            projection,
            selection,
            arrayOf(ACCOUNT_NAME, ACCOUNT_TYPE),
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst()) cursor.getLong(0) else null
        } ?: return false
        val deletedRows = resolver.delete(
            asSyncAdapter(CalendarContract.Calendars.CONTENT_URI),
            "${CalendarContract.Calendars._ID}=?",
            arrayOf(calendarId.toString()),
        )
        return deletedRows > 0
    }

    /** 给 URI 挂上「本应用是 sync adapter + 专属账户」参数。 */
    private fun asSyncAdapter(uri: Uri): Uri =
        uri.buildUpon()
            .appendQueryParameter(CalendarContract.CALLER_IS_SYNCADAPTER, "true")
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_NAME, ACCOUNT_NAME)
            .appendQueryParameter(CalendarContract.Calendars.ACCOUNT_TYPE, ACCOUNT_TYPE)
            .build()

    /** 同步在后台线程执行；结果必须回主线程交还（平台通道要求平台主线程）。 */
    private fun runOnMain(block: () -> Unit) {
        Handler(Looper.getMainLooper()).post(block)
    }
}
