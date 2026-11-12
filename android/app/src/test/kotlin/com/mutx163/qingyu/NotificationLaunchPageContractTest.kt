package com.mutx163.qingyu

import com.mutx163.qingyu.testutil.stripKotlinComments
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 通知点击落页的**契约测试**（R09，2026-11-03）。
 *
 * 这里断言的是**目标壳页面 id 本身**，不是「某个页面被打开了」——壳的推页入口
 * 一旦映射错页，`find.byType(页面)` 那类断言仍可能因为首页本来就是课表而误绿。
 *
 * 契约（见 [NotificationLaunchTarget] 头注）：
 * - `open_route` 是 Dart 路由串，显式优先；
 * - `open_lan_edit` 是旧布尔，仅在无路由时生效；
 * - 未知路由不猜（null = 落默认主屏）。
 *
 * ## 读法：剥注释 + **中性化档**（2026-11-12 B4 批）
 *
 * 源码层那一条判的是**生产端的调用写法**（`putExtra(NotificationLaunchTarget.EXTRA_OPEN_ROUTE,
 * NotificationLaunchTarget.ROUTE_EXAMS)` / `const val EXTRA_OPEN_LAN_EDIT = …`），
 * 全是标识符与调用，一条都不判「某字面量许不许出现」——所以中性化档既不会洗白判据，
 * 又能挡住「日志 / 报错文案里出现同一片段」把 `contains` 喂饱。
 *
 * 剥注释这层是实测的洞：不剥时把 `putExtra(…)` 整行注释掉，注释掉的原文还在文本里 ⇒
 * 迁移前版本仍绿（B4 批 before/after 探针记录见提交信息）。
 */
class NotificationLaunchPageContractTest {

    @Test
    fun `考试提醒的 open_route 落到考试列表页`() {
        assertEquals(
            "d3.examList",
            NotificationLaunchTarget.pageIdFor(
                openRoute = NotificationLaunchTarget.ROUTE_EXAMS,
                openLanEdit = false,
            ),
        )
    }

    @Test
    fun `局域网编辑的旧布尔落到局域网编辑页`() {
        assertEquals(
            "g3.lanEdit",
            NotificationLaunchTarget.pageIdFor(openRoute = null, openLanEdit = true),
        )
    }

    @Test
    fun `显式路由优先于旧布尔`() {
        assertEquals(
            "d3.examList",
            NotificationLaunchTarget.pageIdFor(
                openRoute = NotificationLaunchTarget.ROUTE_EXAMS,
                openLanEdit = true,
            ),
        )
    }

    @Test
    fun `空白路由退回旧布尔`() {
        assertEquals(
            "g3.lanEdit",
            NotificationLaunchTarget.pageIdFor(openRoute = "   ", openLanEdit = true),
        )
    }

    @Test
    fun `未知路由不猜，落默认主屏`() {
        assertNull(NotificationLaunchTarget.pageIdFor("/not-a-real-page", openLanEdit = false))
        assertNull(NotificationLaunchTarget.pageIdFor(openRoute = null, openLanEdit = false))
    }

    @Test
    fun `路由两端空白不影响落点`() {
        assertEquals(
            "d3.examList",
            NotificationLaunchTarget.pageIdFor(openRoute = "  /exams  ", openLanEdit = false),
        )
    }

    /**
     * extra 键是对外契约：itest 的 Flutter 宿主、旧版本通知的 PendingIntent 都可能
     * 还带着这些字面量，改键会让老通知点开无落点。值改了必须同步这里。
     */
    @Test
    fun `extra 键值冻结`() {
        assertEquals("open_route", NotificationLaunchTarget.EXTRA_OPEN_ROUTE)
        assertEquals("open_lan_edit", NotificationLaunchTarget.EXTRA_OPEN_LAN_EDIT)
        assertEquals(
            "局域网编辑服务的键必须与统一契约同源",
            NotificationLaunchTarget.EXTRA_OPEN_LAN_EDIT,
            LanEditForegroundService.EXTRA_OPEN_LAN_EDIT,
        )
    }

    /**
     * 生产端不得再写字面量：漏改一处就会出现「生产端有 extra、消费端不认识」的
     * 静默失效（R09 之前的原状）。只做源码级判据，跨模块的值由上面两条钉住。
     */
    @Test
    fun `生产端使用统一契约常量`() {
        val root = resolveSourceRoot()
        val exam = codeOnly(root, "ExamReminderScheduler.kt")
        assertTrue(
            "考试提醒必须用 EXTRA_OPEN_ROUTE + ROUTE_EXAMS 写落页参数",
            exam.contains("putExtra(NotificationLaunchTarget.EXTRA_OPEN_ROUTE, NotificationLaunchTarget.ROUTE_EXAMS)"),
        )
        val lan = codeOnly(root, "LanEditForegroundService.kt")
        assertTrue(
            "局域网编辑服务必须引用统一的 extra 键",
            lan.contains("const val EXTRA_OPEN_LAN_EDIT = NotificationLaunchTarget.EXTRA_OPEN_LAN_EDIT"),
        )
    }

    /** 中性化档：剥注释 + 字符串内容抹成空格（判调用写法，见类注释的读法一节）。 */
    private fun codeOnly(root: File, name: String): String =
        stripKotlinComments(
            File(root, name).readText(Charsets.UTF_8).replace("\r\n", "\n"),
            neutralizeStrings = true,
        )

    /** 与 [NotificationLaunchTargetGuardTest] 同款路径解析（工作目录可能是仓库根或 android/）。 */
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
