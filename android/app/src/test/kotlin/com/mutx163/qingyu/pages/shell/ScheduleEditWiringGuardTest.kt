package com.mutx163.qingyu.pages.shell

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 日程编辑页的**宿主接线**守卫（2026-11-05 建立）。
 *
 * ## 防的是什么
 *
 * `d2.addSchedule` 曾经绕过 `ScheduleEditHost`，直接调 `AddScheduleItemPage`：
 *
 * - 页面 `onSave` / `onDelete` 返回 `Unit`，**它不知道落盘成败**，壳里又没有 else 分支
 *   ⇒ 落盘失败时页面不动、零提示，用户以为没点上，反复点保存；
 * - 宿主里那套通知权限状态机（`PermissionFlow` + `rememberLauncherForActivityResult`）
 *   连同 `reminderPermissionMissing` / `onRequestNotificationPermission` / `onReminderSelected`
 *   三个参数一起没接 ⇒ 页面里「检查通知权限」那一块**永远不出现**：用户选了提醒、
 *   但系统通知被关掉，提醒不响也没有任何解释。
 *
 * 结症都是「壳绕过了宿主」。所以本守卫钉两件事：**分支必须经宿主**、**宿主必须把三个提醒参数
 * 传给页面**；再加一条「失败提示不许被删掉」，防止有人为了消警告把宿主里的失败分支摘了。
 *
 * 这是源码文本守卫：宿主与壳都带 Compose/Android 依赖，进不了 JVM 单测 classpath
 * （本仓同类做法见 `schedule/ScheduleDialogGuardTest`）。判据对格式敏感，只钉最小集合；
 * 分支里改了调用形态会先红，**请同步本文件而不是删断言**。
 */
class ScheduleEditWiringGuardTest {

    // ───────────────────── 0. 守卫自己不能空跑 ─────────────────────

    @Test
    fun `判据锚点存在且能切出 d2-addSchedule 分支`() {
        val shell = File(repoRoot(), SHELL_PAGE_INDEX).readText()
        assertTrue(
            "ShellPageIndex.kt 里找不到 `\"d2.addSchedule\" ->`（文件改名/重构后必须同步本守卫，否则空跑假绿）",
            shell.contains(ADD_SCHEDULE_ROUTE),
        )
        assertTrue(
            "找不到 d2 日程分支的终点标记 `\"d2.dateRule\"`，无法切出 d2.addSchedule 分支",
            branchOf(shell).isNotBlank(),
        )
        assertTrue(
            "ShellPageIndex.kt 没有 import ScheduleEditHost（接线改了必须同步本守卫）",
            shell.contains("import com.mutx163.qingyu.pages.schedule.ScheduleEditHost"),
        )
    }

    // ───────────────────── 1. 分支必须经宿主，不许直调页面 ─────────────────────

    @Test
    fun `d2-addSchedule 分支经 ScheduleEditHost 而不是直调页面`() {
        val branch = branchOf(File(repoRoot(), SHELL_PAGE_INDEX).readText())
        assertTrue(
            "d2.addSchedule 分支必须调 `ScheduleEditHost(`（宿主管落盘反馈 + 通知权限状态机）",
            branch.contains("ScheduleEditHost("),
        )
        assertFalse(
            "d2.addSchedule 分支又在直调 `AddScheduleItemPage(`：绕过宿主会同时丢掉失败提示与" +
                "「检查通知权限」提示（历史 bug，见类注释）",
            branch.contains("AddScheduleItemPage("),
        )
        assertTrue(
            "分支必须传 `onFinish =`（宿主成功后关页 + 清一次性意图的唯一出口）",
            branch.contains("onFinish ="),
        )
    }

    // ───────────────────── 2. 三个提醒参数必须真的喂到页面 ─────────────────────

    @Test
    fun `宿主把通知权限三个参数传给页面`() {
        val host = File(repoRoot(), SCHEDULE_EDIT_HOST).readText()
        for (param in REMINDER_PARAMS) {
            assertTrue(
                "ScheduleEditHost.kt 没有再给页面传 `$param`：用户关掉系统通知后选提醒，" +
                    "「检查通知权限」那块就不会出现（提醒不响且无解释）",
                host.contains("$param ="),
            )
        }
        assertTrue(
            "宿主里找不到权限检查（PermissionSystemActions.notificationsGranted），判据可能已失效",
            host.contains("PermissionSystemActions.notificationsGranted"),
        )
    }

    // ───────────────────── 3. 失败必须提示，不许被静默 ─────────────────────

    @Test
    fun `宿主保留保存与删除失败的提示`() {
        val host = File(repoRoot(), SCHEDULE_EDIT_HOST).readText()
        assertTrue(
            "宿主保存失败分支没在用 `ScheduleStrings.saveFailed`：失败会变成静默（页面不动、零提示）",
            host.contains("ScheduleStrings.saveFailed.text"),
        )
        assertTrue(
            "宿主删除失败分支没在用 `ScheduleStrings.deleteFailed`：失败会变成静默",
            host.contains("ScheduleStrings.deleteFailed.text"),
        )
    }

    // ------------------------------------------------------------------
    // 工具
    // ------------------------------------------------------------------

    /** 切出 `d2.addSchedule` 那一个 `when` 分支的源码（到 `d2.dateRule` 为止）。 */
    private fun branchOf(shell: String): String {
        val start = shell.indexOf(ADD_SCHEDULE_ROUTE)
        if (start < 0) return ""
        val end = shell.indexOf("\"d2.dateRule\"", start)
        return if (end <= start) "" else shell.substring(start, end)
    }

    private fun repoRoot(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "android/app/src").isDirectory) {
                var up: File? = dir
                while (up != null) {
                    if (File(up, "lib/screens").isDirectory && File(up, "pubspec.yaml").isFile) {
                        return up.path
                    }
                    up = up.parentFile
                }
                return dir.path
            }
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到仓库根（android/app/src）—— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private companion object {
        const val SHELL_PAGE_INDEX =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt"
        const val SCHEDULE_EDIT_HOST =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/schedule/ScheduleEditHost.kt"

        const val ADD_SCHEDULE_ROUTE = "\"d2.addSchedule\" ->"

        /** 页面侧三个提醒参数的形参名（宿主必须逐个传）。 */
        val REMINDER_PARAMS = listOf(
            "reminderPermissionMissing",
            "onRequestNotificationPermission",
            "onReminderSelected",
        )
    }
}
