package com.mutx163.qingyu

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 点击落点守卫：通知、超级岛、桌面小组件都不得再硬编码 `MainActivity`。
 *
 * ## 为什么需要它
 *
 * `dev` / `perf` 变体把 `MainActivity` 置为禁用、由
 * `pages.PagesShellActivity` 当启动页（`android/app/src/dev/AndroidManifest.xml`）；
 * 正式包自 2026-11-02 起也以壳为启动页。点击入口如果仍指向 `MainActivity`，
 * 在这些包里点下去打不开应用——而这类问题**编译能过、单测也能过**，
 * 只有装上真机才发现。统一入口在 [NotificationLaunchTarget]，
 * 本守卫只做源码级判据：谁再写回硬编码，测试立刻红。
 *
 * 超级岛走字符串协议而不是 `Intent` 对象，单靠 `Intent(..., MainActivity::class.java)`
 * 的文本判据抓不到，所以另有一条断言盯住 `/.MainActivity` 与兜底分支。
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
        "TodayWidgetSupport.kt",
    )

    @Test
    fun `通知与小组件都走统一落点，不再硬编码 MainActivity`() {
        val root = resolveSourceRoot()
        guardTargets.forEach { name ->
            val text = File(root, name).readText()
            assertTrue(
                "$name 必须通过 NotificationLaunchTarget.intent(...) 解析启动页",
                text.contains("NotificationLaunchTarget.intent("),
            )
            assertFalse(
                "$name 仍在硬编码 MainActivity 作为点击落点；dev/perf 包里该组件被禁用",
                text.contains("Intent(context, MainActivity::class.java)") ||
                    text.contains("Intent(this, MainActivity::class.java)"),
            )
        }
    }

    /**
     * 超级岛走的是字符串协议（`intent:#Intent;component=…;end`），上面那条
     * `Intent(..., MainActivity::class.java)` 的文本判据抓不到它；兜底同样单独钉住。
     */
    @Test
    fun `超级岛字符串与兜底都不再指向 Flutter 入口`() {
        val root = resolveSourceRoot()
        val live = File(root, "LiveUpdateService.kt").readText()
        assertFalse(
            "LiveUpdateService 的超级岛 actionIntent 仍写死 /.MainActivity",
            live.contains("/.MainActivity"),
        )
        val target = File(root, "NotificationLaunchTarget.kt").readText()
        assertTrue(
            "解析不到启动页时必须退回 Compose 壳入口",
            target.contains("Intent(context, PagesShellActivity::class.java)"),
        )
        assertFalse(
            "NotificationLaunchTarget 的兜底仍在指向 MainActivity",
            target.contains("Intent(context, MainActivity::class.java)"),
        )
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
