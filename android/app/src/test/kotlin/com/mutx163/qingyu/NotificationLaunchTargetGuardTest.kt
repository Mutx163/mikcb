package com.mutx163.qingyu

import com.mutx163.qingyu.testutil.stripKotlinComments
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
 *
 * ## 读法：**同一个文件读两遍**，按锚分档（2026-11-12 B4 批）
 *
 * 本文件是混合型：`Intent(…)` 那几条判的是**代码调用**，`/.MainActivity` 那条判的是
 * **字符串字面量里的内容**（超级岛的 `intent:#Intent;component=…/.MainActivity;end` 协议串）。
 * 一个档位不可能同时满足，所以两个视图分开取（[codeOnly] / [literalsKept]）：
 *
 * | 判据 | 视图 | 为什么 |
 * |---|---|---|
 * | `NotificationLaunchTarget.intent(`、`Intent(context, MainActivity::class.java)`、`Intent(this, …)`、`Intent(context, PagesShellActivity::class.java)` | **中性化档** | 判的是**调用写法**。留着字符串内容时，报错文案 / 日志里出现同一片段就能把 `contains` 喂饱（假绿），或让负例假红 |
 * | `/.MainActivity` | **默认档**（剥注释、保留字符串） | 它**在字符串字面量里**。中性化会把串内容抹成空格 ⇒ `assertFalse` 从此永远通过（洗白），而这条正是超级岛唯一的机器化拦网 |
 *
 * 两档都**先剥注释**：不剥时把 `NotificationLaunchTarget.intent(context)` 整行注释掉，
 * 注释掉的原文还在文本里，`contains` 照样通过——B4 批实测过（before 绿 / after 红）。
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
        guardTargets.forEach { name ->
            val text = codeOnly(name)
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
     *
     * 本条的 `/.MainActivity` 落在**字符串字面量**里 ⇒ 必须用默认档（见类注释的档位表）。
     */
    @Test
    fun `超级岛字符串与兜底都不再指向 Flutter 入口`() {
        val live = literalsKept("LiveUpdateService.kt")
        // 否定式断言在空读上恒真：先钉一个必须存在的正向锚（AGENTS.md「源码守卫」那条纪律）。
        assertTrue(
            "LiveUpdateService.kt 读不到 `class LiveUpdateService`：路径/读法错了，" +
                "下一行的 /.MainActivity 否定式断言会在空文本上恒真",
            live.contains("class LiveUpdateService"),
        )
        assertFalse(
            "LiveUpdateService 的超级岛 actionIntent 仍写死 /.MainActivity",
            live.contains("/.MainActivity"),
        )
        val target = codeOnly("NotificationLaunchTarget.kt")
        assertTrue(
            "解析不到启动页时必须退回 Compose 壳入口",
            target.contains("Intent(context, PagesShellActivity::class.java)"),
        )
        assertFalse(
            "NotificationLaunchTarget 的兜底仍在指向 MainActivity",
            target.contains("Intent(context, MainActivity::class.java)"),
        )
    }

    /** 中性化档：剥注释 + 字符串内容抹成空格。判「调用写法」的判据用它。 */
    private fun codeOnly(name: String): String =
        stripKotlinComments(sourceOf(name), neutralizeStrings = true)

    /** 默认档：剥注释、**保留字符串内容**。判「字面量里不许出现某片段」的判据用它。 */
    private fun literalsKept(name: String): String =
        stripKotlinComments(sourceOf(name), neutralizeStrings = false)

    /** 读一份源文件并对齐行尾（工作区是 CRLF，锚点里带换行时会假红）。 */
    private fun sourceOf(name: String): String =
        File(resolveSourceRoot(), name).readText(Charsets.UTF_8).replace("\r\n", "\n")

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
