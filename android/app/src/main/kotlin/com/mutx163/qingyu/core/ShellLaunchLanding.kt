package com.mutx163.qingyu.core

/**
 * 壳冷启动时「这次通知落点该不该投递」的纯判据（2026-11-14 收紧 R09 真机边缘）。
 *
 * ## 为什么从 Activity 里拆出来
 *
 * 判据原先写成 `if (savedInstanceState == null) postLaunchPage(intent)`。它把
 * 「进程被回收后按原任务恢复**并同时点了新通知**」整条路径一起吞掉——那种情况下既有
 * 非空 `savedInstanceState`、又有带页面 extra 的新 `Intent`，用户看到的是「点通知回到
 * 壳却没进对应页」。
 *
 * 判据留在 `NotificationLaunchTarget` 里就没法被 L0 覆盖：那个文件 `import
 * android.content.Intent`，进不了 JVM classpath（`scripts/test-kotlin-module.ps1` 的
 * 纯 Kotlin 判定会整目录跳过）。所以这里只放**两个字符串的比较**，壳负责把 Intent
 * 解析成页 id，本对象不碰 Android。
 *
 * ## 判据
 *
 * - 解析不出落点（[launchPageId] 为 null）⇒ 不投：普通点图标启动不产生推页；
 * - 落点与「上次启动已投递的那个」（[restoredPageId]）相同 ⇒ 不投：等同旧判据对
 *   「同一份启动被恢复」的保护，避免把用户已经关掉的页面推回来；
 * - 其余（含恢复的同时点了**不同**目标页的新通知）⇒ 投。
 *
 * ## 已知残留边缘（刻意不处理，别当 bug）
 *
 * 进程恢复的同时点了**同一目标页**的新通知：两边页 id 相同、无从区分，本次仍会跳过。
 * 根治要给通知 Intent 加一次性流水号（契约扩展），不在本笔范围。
 */
object ShellLaunchLanding {

    fun shouldPostLaunchPage(launchPageId: String?, restoredPageId: String?): Boolean {
        if (launchPageId == null) return false
        return launchPageId != restoredPageId
    }
}
