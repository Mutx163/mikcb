package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 通知点击落点守卫：四处通知不得再硬编码 `MainActivity`。
 *
 * ## 为什么需要它
 *
 * `dev` / `bench` 变体把 `MainActivity` 置为禁用、由
 * `pages.PagesShellActivity` 当启动页（`android/app/src/dev/AndroidManifest.xml`）。
 * 通知如果仍指向 `MainActivity`，在这类包里点下去打不开应用——而这类问题**编译能过、
 * 单测也能过**，只有装上真机才发现。统一入口在 [NotificationLaunchTarget]，
 * 本守卫只做源码级判据：谁再写回硬编码，测试立刻红。
 *
 * 与 `FeedbackModelTest` 同款路径解析：Gradle 的工作目录可能是仓库根，也可能是
 * `android/`，逐个候选找。
 */
class NotificationLaunchTargetGuardTest {

    private val guardTargets = listOf(
        "ExamReminderScheduler.kt",
        "WeeklyReportScheduler.kt",
        "LiveUpdateService.kt",
        "LanEditForegroundService.kt",
    )

    @Test
    fun `四处通知都走统一落点，不再硬编码 MainActivity`() {
        val root = resolveSourceRoot()
        guardTargets.forEach { name ->
            val text = File(root, name).readText()
            assertTrue(
                "$name 必须通过 NotificationLaunchTarget.intent(...) 解析启动页",
                text.contains("NotificationLaunchTarget.intent("),
            )
            assertFalse(
                "$name 仍在硬编码 MainActivity 作为通知落点；dev/bench 包里该组件被禁用",
                text.contains("Intent(context, MainActivity::class.java)") ||
                    text.contains("Intent(this, MainActivity::class.java)"),
            )
        }
    }

    private fun resolveSourceRoot(): File {
        val candidates = listOf(
            File("android/app/src/main/kotlin/com/mutx163/qingyu"),
            File("app/src/main/kotlin/com/mutx163/qingyu"),
            File("../android/app/src/main/kotlin/com/mutx163/qingyu"),
            File("../../android/app/src/main/kotlin/com/mutx163/qingyu"),
        )
        return candidates.firstOrNull { it.isDirectory }
            ?: error("找不到 Kotlin 源根目录，工作目录=${File(".").absolutePath}")
    }
}
