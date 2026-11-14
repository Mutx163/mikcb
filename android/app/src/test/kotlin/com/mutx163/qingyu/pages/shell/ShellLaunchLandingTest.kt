package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.core.ShellLaunchLanding
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 通知落点投递判据（2026-11-14 收紧 R09 边缘）。
 *
 * 旧判据 `savedInstanceState == null` 会把「进程恢复 + 同时点新通知」整条路径吞掉。
 * 新判据只看「这次解析出的落点」与「上次启动已投递的落点」是否相同——
 * 判据本体在纯 Kotlin 的 [ShellLaunchLanding]，所以这里能直接断言，不用真机。
 *
 * 这层为什么不写在 `NotificationLaunchTarget`：那个文件 `import android.content.Intent`，
 * 进不了 L0 的 JVM classpath（见 `scripts/test-kotlin-module.ps1` 的纯 Kotlin 判定），
 * 放那儿就只能靠 L2 覆盖。
 */
class ShellLaunchLandingTest {

    @Test
    fun `没有落点参数时不投递`() {
        assertFalse(
            "普通点图标启动没有页面 extra，不该推任何页",
            ShellLaunchLanding.shouldPostLaunchPage(launchPageId = null, restoredPageId = null),
        )
        // 恢复场景同理：没有落点参数就是不投，与 restored 值无关。
        assertFalse(
            ShellLaunchLanding.shouldPostLaunchPage(launchPageId = null, restoredPageId = "d3.examList"),
        )
    }

    @Test
    fun `冷启动带落点必须投递`() {
        assertTrue(
            "冷启动点通知：Intent 带落点、没有可恢复状态 ⇒ 必须落页",
            ShellLaunchLanding.shouldPostLaunchPage(launchPageId = "d3.examList", restoredPageId = null),
        )
        assertTrue(
            ShellLaunchLanding.shouldPostLaunchPage(launchPageId = "g3.lanEdit", restoredPageId = null),
        )
    }

    @Test
    fun `恢复同一份启动时不重复投递`() {
        // 这正是旧 savedInstanceState 守卫保护的场景：进程被回收后按原任务恢复，
        // 同一个带着 extra 的 Intent 又走一遍 onCreate——不能再把用户关掉的页推回来。
        assertFalse(
            "恢复同一份启动：落点与上次投递的相同 ⇒ 跳过",
            ShellLaunchLanding.shouldPostLaunchPage(
                launchPageId = "d3.examList",
                restoredPageId = "d3.examList",
            ),
        )
    }

    @Test
    fun `恢复的同时点了新通知必须投递`() {
        // R09 真机边缘：既有非空 savedInstanceState、又带着新页面的 Intent——
        // 旧判据在这里跳过，用户表现为「点通知回到壳却没进对应页」。
        assertTrue(
            "恢复 + 新通知（落点不同）⇒ 必须落页",
            ShellLaunchLanding.shouldPostLaunchPage(
                launchPageId = "g3.lanEdit",
                restoredPageId = "d3.examList",
            ),
        )
        assertTrue(
            ShellLaunchLanding.shouldPostLaunchPage(
                launchPageId = "d3.examList",
                restoredPageId = "g3.lanEdit",
            ),
        )
    }
}
