package com.mutx163.qingyu

import io.flutter.plugin.common.MethodChannel

/**
 * 「一次只等一个」的 MethodChannel 权限回调登记处。
 *
 * 它存在的理由是把两条已经踩过的失效面收成一处必然发生的事：
 *
 * 1. **换槽覆盖**：`permissionResult = result` 直接覆盖，上一次还在等待的请求
 *    从此没人回它 —— 那个 Dart `Future` 永挂。
 * 2. **宿主销毁**：系统权限对话框还开着时 Activity 被销毁/重建（部分国产 ROM 的
 *    旋转与深浅色切换会重建），`onRequestPermissionsResult` 可能再也不来。
 *    本仓的日历权限专门写了 `CalendarSync.onHostDestroyed()` 来收束这件事，
 *    注释就写着"等待者若不收束，Dart 侧 Future 会永挂"；通知权限那条同形路径
 *    原先没有对应的收束。
 *
 * `replace` 与 `take` 都把"该由调用方去收束"的那个槽返回出去，所以不存在静默丢失。
 */
internal class PendingResultSlot {
    private var current: MethodChannel.Result? = null

    /** 装入新的等待者，返回**没被消费**的旧等待者（调用方必须回它）。 */
    fun replace(next: MethodChannel.Result?): MethodChannel.Result? {
        val previous = current
        current = next
        return previous
    }

    /** 取出并清空当前等待者：系统回调到达、或宿主销毁时都走这里。 */
    fun take(): MethodChannel.Result? {
        val previous = current
        current = null
        return previous
    }

    fun isPending(): Boolean = current != null
}
